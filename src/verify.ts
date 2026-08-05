// Exact computation of the correlation constant of a matroid.
//
// For a matroid M on {0,...,n-1} and distinct elements i, j, write
//   B[∋i,∋j] = #{bases containing both i and j},
//   B[∌i,∌j] = #{bases avoiding both},
//   B[∋i,∌j] = #{bases containing i but not j},   and so forth.
// The correlation ratio of the pair and the correlation constant of M are
//   R_ij(M) = B[∋i,∋j]·B[∌i,∌j] / (B[∋i,∌j]·B[∌i,∋j]),
//   α(M)    = max R_ij(M) over pairs of nonloop, noncoloop elements.
// For such a pair both denominator factors are positive (exchange out of a
// basis containing both i and j). If every element is a loop or a coloop
// there is no eligible pair and the convention is α(M) = 0.
//
// A matroid is submitted as one complete description — a matrix over Q or a
// prime field GF(p), the list of all bases, all circuits, or all hyperplanes.
// Every description is reduced to the full list of bases as bitmasks over the
// ground set (n ≤ 18, so a subset is one integer), the matroid axioms are
// checked exactly, and every ratio is compared by exact integer cross
// multiplication (in BigInt: the products can exceed 2^53).

// The ground-set ceiling: subsets are int32 bitmasks, so n ≤ 30. What is
// actually verifiable is decided by enumeration cost, not n — the search
// visits every independent set, so the driver is Σ_{k ≤ rank} C(n, k),
// bounded by INDEPENDENT_SET_BUDGET. Everything on ≤ 24 elements fits (the
// bound is exactly 2^24); 25 to 30 elements are admitted only in low enough
// rank (e.g. rank ≤ 10 at n = 26, rank ≤ 8 at n = 30).
export const MAX_ELEMENTS = 30
const INDEPENDENT_SET_BUDGET = 2 ** 24

// The circuit and hyperplane checks tabulate dependence over all 2^n
// subsets, so those two descriptions stop at 24 elements (a 2^26 table plus
// its sweep would crowd the worker's memory and CPU).
export const MAX_DP_ELEMENTS = 24
export const MAX_LISTED_SETS = 5000
export const MAX_MATRIX_CELLS = 5000
export const MAX_FIELD_PRIME = 1_000_003 // p² must stay well below 2^53
export const MAX_EXT_FIELD_ORDER = 1024 // extension fields GF(p^d), d ≥ 2
export const MAX_DATA_TEXT_BYTES = 1_000_000
export const PROVENANCE_MAX = 2000

/** The canonical bases list is materialized as JSON only up to this count
 * (beyond it the list is never stored or displayed, and building it for
 * millions of bases would exhaust worker memory). */
export const BASES_JSON_MAX_COUNT = 5000

// Elementary-operation budget for basis enumeration, so runaway inputs fail
// cleanly instead of burning worker CPU (sized against the raised cpu_ms
// limit in wrangler.jsonc). Rational matrices use exact BigInt elimination
// whose per-op cost is much higher, so their ops are charged at a multiple
// (FieldOps.costFactor).
const OP_BUDGET = 8_000_000_000

export const REPRESENTATION_TYPES = ['matrix', 'bases', 'circuits', 'hyperplanes'] as const
export type RepresentationType = (typeof REPRESENTATION_TYPES)[number]

export interface MaxCounts {
  containBoth: number
  avoidBoth: number
  onlyI: number
  onlyJ: number
}

export interface VerifiedMatroid {
  ok: true
  n: number
  rank: number
  numBases: number
  loops: number[]
  coloops: number[]
  /** α(M) as a reduced fraction plus a decimal approximation. */
  alphaNum: number
  alphaDen: number
  alphaValue: number
  /** Every pair [i, j] (i < j) attaining the maximum. */
  maximizingPairs: [number, number][]
  /** The 2×2 basis counts at the first maximizing pair. */
  maxCounts: MaxCounts | null
  representationType: RepresentationType
  /** Normalized JSON of the submitted description. */
  representation: string
  /** 'Q' or the prime p as text, for matrix submissions. */
  field: string | null
  /** Canonical JSON list of bases, each sorted, in sorted order; null when
   * there are more than BASES_JSON_MAX_COUNT bases. */
  basesJson: string | null
  /** Canonical bases as sorted bitmasks (the source of truth for hashing). */
  basesMasks: ArrayLike<number>
}

export type VerifyResult = { ok: false; error: string } | VerifiedMatroid

const popcount = (m: number): number => {
  let c = 0
  while (m) {
    m &= m - 1
    c++
  }
  return c
}

const bitsOf = (mask: number): number[] => {
  const out: number[] = []
  for (let e = 0; mask >> e; e++) if ((mask >> e) & 1) out.push(e)
  return out
}

const setName = (mask: number): string => `{${bitsOf(mask).join(', ')}}`

function bigGcd(a: bigint, b: bigint): bigint {
  a = a < 0n ? -a : a
  b = b < 0n ? -b : b
  while (b) {
    ;[a, b] = [b, a % b]
  }
  return a
}

type Fail = { error: string }
const fail = (error: string): Fail => ({ error })
const isFail = (x: unknown): x is Fail =>
  typeof x === 'object' && x !== null && 'error' in (x as Fail)

// ---------------------------------------------------------------------------
// Set-list parsing shared by the bases / circuits / hyperplanes descriptions.

/** Parse a JSON list of subsets of {0,...,n-1} into bitmasks. */
function parseSetList(n: number, data: unknown, what: string): number[] | Fail {
  if (!Array.isArray(data)) return fail(`the ${what} description must be a JSON list of lists`)
  if (data.length > MAX_LISTED_SETS) {
    return fail(`at most ${MAX_LISTED_SETS.toLocaleString('en-US')} ${what} may be listed`)
  }
  const masks: number[] = []
  const seen = new Set<number>()
  for (const [idx, entry] of data.entries()) {
    if (!Array.isArray(entry)) {
      return fail(`${what} entry ${idx} is not a list`)
    }
    let mask = 0
    for (const x of entry) {
      if (typeof x !== 'number' || !Number.isInteger(x) || x < 0 || x >= n) {
        return fail(
          `${what} entry ${idx} contains ${JSON.stringify(x)}, which is not an element label in 0..${n - 1}`,
        )
      }
      if ((mask >> x) & 1) return fail(`${what} entry ${idx} repeats element ${x}`)
      mask |= 1 << x
    }
    if (seen.has(mask)) return fail(`the ${what} list contains ${setName(mask)} twice`)
    seen.add(mask)
    masks.push(mask)
  }
  return masks
}

// ---------------------------------------------------------------------------
// Description: bases. Validated via the basis-exchange axiom.

function matroidFromBases(n: number, data: unknown): number[] | Fail {
  const masks = parseSetList(n, data, 'basis')
  if (isFail(masks)) return masks
  if (masks.length === 0) return fail('a matroid has at least one basis')
  const r = popcount(masks[0])
  for (const m of masks) {
    if (popcount(m) !== r) return fail('all bases must have the same number of elements')
  }
  // ext.get(I) for an (r-1)-set I is the mask of elements e with I ∪ {e} a basis.
  const ext = new Map<number, number>()
  for (const b of masks) {
    for (const x of bitsOf(b)) {
      const key = b ^ (1 << x)
      ext.set(key, (ext.get(key) ?? 0) | (1 << x))
    }
  }
  // Exchange: for bases B1, B2 and x ∈ B1 \ B2 there is y ∈ B2 \ B1 with
  // B1 - x + y a basis, i.e. (B2 \ B1) ∩ ext(B1 - x) ≠ ∅.
  for (const b1 of masks) {
    for (const x of bitsOf(b1)) {
      const exchangeable = ext.get(b1 ^ (1 << x))!
      for (const b2 of masks) {
        if ((b2 >> x) & 1) continue
        if ((b2 & ~b1 & exchangeable) === 0) {
          return fail(
            `not the bases of a matroid: no exchange for element ${x} of basis ${setName(b1)} against basis ${setName(b2)}`,
          )
        }
      }
    }
  }
  return masks.sort((a, b) => a - b)
}

// ---------------------------------------------------------------------------
// Description: circuits. Validated via the circuit axioms (nonempty,
// antichain, weak elimination), then bases = maximum-size sets containing
// no circuit.

function matroidFromCircuits(n: number, data: unknown): number[] | Fail {
  if (n > MAX_DP_ELEMENTS) {
    return fail(
      `circuit and hyperplane descriptions support at most ${MAX_DP_ELEMENTS} elements — describe this matroid by a matrix or its bases instead`,
    )
  }
  const circuits = parseSetList(n, data, 'circuit')
  if (isFail(circuits)) return circuits
  for (const c of circuits) {
    if (c === 0) return fail('the empty set cannot be a circuit')
  }
  for (let i = 0; i < circuits.length; i++) {
    for (let j = i + 1; j < circuits.length; j++) {
      const inter = circuits[i] & circuits[j]
      if (inter === circuits[i] || inter === circuits[j]) {
        return fail(
          `not the circuits of a matroid: ${setName(circuits[i])} and ${setName(circuits[j])} are nested`,
        )
      }
    }
  }
  // dep[m] = 1 when m contains a listed circuit (upward closure by one-element
  // deletions, computed over all 2^n subsets in ascending mask order).
  const dep = new Uint8Array(1 << n)
  for (const c of circuits) dep[c] = 1
  for (let m = 1; m < 1 << n; m++) {
    if (dep[m]) continue
    for (let e = 0; e < n; e++) {
      if ((m >> e) & 1 && dep[m ^ (1 << e)]) {
        dep[m] = 1
        break
      }
    }
  }
  // Weak circuit elimination: for C1 ≠ C2 and e ∈ C1 ∩ C2, (C1 ∪ C2) - e
  // contains a circuit.
  for (let i = 0; i < circuits.length; i++) {
    for (let j = i + 1; j < circuits.length; j++) {
      const inter = circuits[i] & circuits[j]
      if (inter === 0) continue
      const union = circuits[i] | circuits[j]
      for (const e of bitsOf(inter)) {
        if (!dep[union ^ (1 << e)]) {
          return fail(
            `not the circuits of a matroid: eliminating element ${e} from ${setName(circuits[i])} and ${setName(circuits[j])} leaves no circuit`,
          )
        }
      }
    }
  }
  let rank = 0
  for (let m = 0; m < 1 << n; m++) {
    if (!dep[m]) {
      const k = popcount(m)
      if (k > rank) rank = k
    }
  }
  const bases: number[] = []
  for (let m = 0; m < 1 << n; m++) {
    if (!dep[m] && popcount(m) === rank) bases.push(m)
  }
  return bases
}

// ---------------------------------------------------------------------------
// Description: hyperplanes. The complements of the hyperplanes are the
// cocircuits, i.e. the circuits of the dual; validate those and dualize.

function matroidFromHyperplanes(n: number, data: unknown): number[] | Fail {
  if (n > MAX_DP_ELEMENTS) {
    return fail(
      `circuit and hyperplane descriptions support at most ${MAX_DP_ELEMENTS} elements — describe this matroid by a matrix or its bases instead`,
    )
  }
  const hyperplanes = parseSetList(n, data, 'hyperplane')
  if (isFail(hyperplanes)) return hyperplanes
  const full = (1 << n) - 1
  for (const h of hyperplanes) {
    if (h === full) return fail('a hyperplane cannot be the whole ground set')
  }
  const dualBases = matroidFromCircuits(
    n,
    hyperplanes.map((h) => bitsOf(full & ~h)),
  )
  if (isFail(dualBases)) {
    // The reported sets are the hyperplane complements (cocircuits).
    return fail(`invalid hyperplanes — checking their complements as cocircuits: ${dualBases.error}`)
  }
  return dualBases.map((b) => full & ~b).sort((a, b) => a - b)
}

// ---------------------------------------------------------------------------
// Description: matrix. Columns are the elements; bases are the maximal
// independent column sets, enumerated by a depth-first search that shares
// elimination work across subsets.

interface FieldOps<T> {
  fromCell(cell: unknown, row: number, col: number): T | Fail
  isZero(x: T): boolean
  /** Eliminate pivot's leading position from v (exact, scale-tolerant). */
  eliminate(v: T[], pivot: T[], pos: number): void
  /** Optionally renormalize a new pivot vector in place. */
  normalize(v: T[]): void
  /** Budget charge per vector entry eliminated (BigInt ops cost more). */
  costFactor: number
}

function isPrime(p: number): boolean {
  if (!Number.isInteger(p) || p < 2) return false
  for (let d = 2; d * d <= p; d++) if (p % d === 0) return false
  return true
}

function gfOps(p: number): FieldOps<number> {
  // Modular inverse via exponentiation is overkill; extended Euclid.
  const inv = (a: number): number => {
    let [old_r, r] = [a % p, p]
    let [old_s, s] = [1, 0]
    while (r !== 0) {
      const q = Math.floor(old_r / r)
      ;[old_r, r] = [r, old_r - q * r]
      ;[old_s, s] = [s, old_s - q * s]
    }
    return ((old_s % p) + p) % p
  }
  return {
    fromCell(cell, row, col) {
      if (typeof cell !== 'number' || !Number.isSafeInteger(cell)) {
        return fail(`matrix entry at row ${row}, column ${col} must be an integer over GF(${p})`)
      }
      return ((cell % p) + p) % p
    },
    isZero: (x) => x === 0,
    eliminate(v, pivot, pos) {
      // pivot[pos] is normalized to 1.
      const f = v[pos]
      if (f === 0) return
      for (let k = 0; k < v.length; k++) {
        v[k] = (v[k] - f * pivot[k]) % p
        if (v[k] < 0) v[k] += p
      }
    },
    normalize(v) {
      let pos = 0
      while (v[pos] === 0) pos++
      const f = inv(v[pos])
      for (let k = 0; k < v.length; k++) v[k] = (v[k] * f) % p
    },
    costFactor: 1,
  }
}

// ---------------------------------------------------------------------------
// Conway polynomials, computed from the definition rather than transcribed
// from a table (q ≤ 1024 keeps the search instant, and a computed table
// cannot be mistyped). C_{p,d} is the minimal monic degree-d polynomial over
// F_p — in the standard word order on (c_{d-1}, ..., c_0), where the word
// encodes f = x^d + Σ (−1)^{d−i} c_i x^i — that is primitive and
// norm-compatible with C_{p,m} for every proper divisor m of d. This is the
// convention used by Sage, GAP, and Macaulay2, so coefficient lists written
// in those systems mean the same field elements here.

// Polynomials over F_p as little-endian coefficient arrays.

const isOnePoly = (a: number[]): boolean => a[0] === 1 && a.every((x, i) => i === 0 || x === 0)

/** a mod m, with m monic; the result has exactly deg(m) entries in 0..p-1. */
function polyMod(a: number[], m: number[], p: number): number[] {
  const out = a.slice()
  const dm = m.length - 1
  for (let i = out.length - 1; i >= dm; i--) {
    const c = ((out[i] % p) + p) % p
    if (c === 0) continue
    for (let k = 0; k <= dm; k++) out[i - dm + k] -= c * m[k]
  }
  const res = new Array<number>(dm).fill(0)
  for (let k = 0; k < Math.min(dm, out.length); k++) res[k] = ((out[k] % p) + p) % p
  return res
}

function polyMulMod(a: number[], b: number[], m: number[], p: number): number[] {
  const prod = new Array<number>(a.length + b.length - 1).fill(0)
  for (let i = 0; i < a.length; i++) {
    if (a[i] === 0) continue
    for (let j = 0; j < b.length; j++) prod[i + j] = (prod[i + j] + a[i] * b[j]) % p
  }
  return polyMod(prod, m, p)
}

function polyPowMod(base: number[], e: number, m: number[], p: number): number[] {
  let result = [1]
  let acc = polyMod(base, m, p)
  for (let k = e; k > 0; k >>= 1) {
    if (k & 1) result = polyMulMod(result, acc, m, p)
    acc = polyMulMod(acc, acc, m, p)
  }
  return result
}

function isIrreducible(f: number[], p: number): boolean {
  const d = f.length - 1
  if (d === 1) return true
  // Trial division by every monic polynomial of degree 1..d/2.
  for (let deg = 1; deg * 2 <= d; deg++) {
    for (let w = 0; w < p ** deg; w++) {
      const g = new Array<number>(deg + 1).fill(0)
      g[deg] = 1
      for (let i = 0; i < deg; i++) g[i] = Math.floor(w / p ** i) % p
      if (polyMod(f, g, p).every((x) => x === 0)) return false
    }
  }
  return true
}

function primeFactors(x: number): number[] {
  const out: number[] = []
  for (let f = 2; f * f <= x; f++) {
    if (x % f === 0) {
      out.push(f)
      while (x % f === 0) x /= f
    }
  }
  if (x > 1) out.push(x)
  return out
}

const conwayCache = new Map<string, number[]>()

/** The Conway polynomial C_{p,d} as little-endian coefficients (length d+1,
 * leading 1). Requires p^d manageable; callers keep p^d ≤ MAX_EXT_FIELD_ORDER
 * (recursion visits smaller d for the same p). */
export function conwayPolynomial(p: number, d: number): number[] {
  const key = `${p}^${d}`
  const cached = conwayCache.get(key)
  if (cached) return cached
  const q = p ** d
  const qm1Primes = primeFactors(q - 1)
  const properDivisors: number[] = []
  for (let m = 1; m < d; m++) if (d % m === 0) properDivisors.push(m)
  const xPoly = [0, 1]
  for (let w = 0; w < q; w++) {
    // The word (c_{d-1}, ..., c_0) in lexicographic order is the base-p
    // integer w with c_{d-1} most significant.
    const f = new Array<number>(d + 1).fill(0)
    f[d] = 1
    for (let i = 0; i < d; i++) {
      const c = Math.floor(w / p ** i) % p
      f[i] = (d - i) % 2 === 0 ? c : (p - c) % p
    }
    if (f[0] === 0) continue // divisible by x
    if (!isIrreducible(f, p)) continue
    // Primitive: x has order exactly q-1 in F_p[x]/(f).
    if (qm1Primes.some((ell) => isOnePoly(polyPowMod(xPoly, (q - 1) / ell, f, p)))) continue
    // Norm-compatible: x^((q-1)/(p^m-1)) is a root of C_{p,m} for every m | d.
    const compatible = properDivisors.every((m) => {
      const cm = conwayPolynomial(p, m)
      const g = polyPowMod(xPoly, (q - 1) / (p ** m - 1), f, p)
      let acc: number[] = [cm[cm.length - 1]]
      for (let i = cm.length - 2; i >= 0; i--) {
        acc = polyMulMod(acc, g, f, p)
        acc[0] = (acc[0] + cm[i]) % p
      }
      return acc.every((x) => x === 0)
    })
    if (!compatible) continue
    conwayCache.set(key, f)
    return f
  }
  /* v8 ignore next -- every prime power has a Conway polynomial */
  throw new Error(`no Conway polynomial found for ${key}`)
}

// GF(p^d) arithmetic via the Conway modulus. Elements are integers 0..q-1
// encoding base-p digit vectors: c_0 + c_1 p + ... + c_{d-1} p^{d-1} stands
// for c_0 + c_1 a + ... + c_{d-1} a^{d-1} with a a root of C_{p,d}.
// Multiplication runs on log/antilog tables (a is primitive, so its powers
// enumerate every nonzero element); addition and negation are tabulated too.
function gfExtOps(p: number, d: number): FieldOps<number> {
  const q = p ** d
  const conway = conwayPolynomial(p, d)
  const digits = (e: number): number[] => {
    const out = new Array<number>(d).fill(0)
    for (let i = 0; i < d; i++) out[i] = Math.floor(e / p ** i) % p
    return out
  }
  const encode = (dg: number[]): number => dg.reduce((acc, c, i) => acc + c * p ** i, 0)

  const antilog = new Int32Array(q - 1)
  const logT = new Int32Array(q).fill(-1)
  let cur = new Array<number>(d).fill(0)
  cur[0] = 1
  for (let k = 0; k < q - 1; k++) {
    const e = encode(cur)
    antilog[k] = e
    logT[e] = k
    // cur ← a·cur, using a^d = −(conway_0 + conway_1 a + ...).
    const top = cur[d - 1]
    for (let i = d - 1; i > 0; i--) cur[i] = (((cur[i - 1] - top * conway[i]) % p) + p) % p
    cur[0] = (((-top * conway[0]) % p) + p) % p
  }

  const neg = new Int32Array(q)
  const add = new Uint16Array(q * q)
  const allDigits: number[][] = []
  for (let e = 0; e < q; e++) allDigits.push(digits(e))
  for (let u = 0; u < q; u++) {
    neg[u] = encode(allDigits[u].map((c) => (p - c) % p))
    for (let v = u; v < q; v++) {
      const s = encode(allDigits[u].map((c, i) => (c + allDigits[v][i]) % p))
      add[u * q + v] = s
      add[v * q + u] = s
    }
  }

  const mul = (u: number, v: number): number =>
    u === 0 || v === 0 ? 0 : antilog[(logT[u] + logT[v]) % (q - 1)]
  const inv = (u: number): number => antilog[(q - 1 - logT[u]) % (q - 1)]

  return {
    fromCell(cell, row, col) {
      if (typeof cell === 'number' && Number.isSafeInteger(cell)) {
        return ((cell % p) + p) % p // an integer is a prime-subfield constant
      }
      if (Array.isArray(cell) && cell.length >= 1 && cell.length <= d) {
        const dg = new Array<number>(d).fill(0)
        for (const [i, c] of cell.entries()) {
          if (typeof c !== 'number' || !Number.isSafeInteger(c)) {
            return fail(
              `matrix entry at row ${row}, column ${col}: coefficient lists over GF(${q}) must contain integers`,
            )
          }
          dg[i] = ((c % p) + p) % p
        }
        return encode(dg)
      }
      return fail(
        `matrix entry at row ${row}, column ${col} must be an integer or a coefficient list of length at most ${d} over GF(${q}) (Conway polynomial basis)`,
      )
    },
    isZero: (x) => x === 0,
    eliminate(v, pivot, pos) {
      // pivot[pos] is normalized to 1.
      const f = v[pos]
      if (f === 0) return
      for (let k = 0; k < v.length; k++) v[k] = add[v[k] * q + neg[mul(f, pivot[k])]]
    },
    normalize(v) {
      let pos = 0
      while (v[pos] === 0) pos++
      const f = inv(v[pos])
      for (let k = 0; k < v.length; k++) v[k] = mul(v[k], f)
    },
    costFactor: 2,
  }
}

const RATIONAL_RE = /^([+-]?\d{1,15})(?:\/([1-9]\d{0,14}))?$/

function rationalOps(): FieldOps<bigint> {
  return {
    // Cells over Q are safe integers or strings like "-3/5". Each parsed cell
    // is a pair encoded lazily: we clear denominators per row before the
    // search, so here cells stay as [num, den] via a closure-side table.
    // (fromCell is only used by the integer pipeline below; rational input is
    // pre-scaled in matroidFromMatrix.)
    fromCell(cell, row, col) {
      void cell
      return fail(`internal error parsing rational entry at row ${row}, column ${col}`)
    },
    isZero: (x) => x === 0n,
    eliminate(v, pivot, pos) {
      // Fraction-free: v ← v·pivot[pos] − pivot·v[pos], then shrink by gcd.
      const f = v[pos]
      if (f === 0n) return
      const lead = pivot[pos]
      for (let k = 0; k < v.length; k++) {
        v[k] = v[k] * lead - pivot[k] * f
      }
    },
    normalize(v) {
      let g = 0n
      for (const x of v) {
        g = bigGcd(g, x)
        if (g === 1n) return
      }
      if (g > 1n) for (let k = 0; k < v.length; k++) v[k] /= g
    },
    costFactor: 10,
  }
}

/** Row-reduce to at most `n` independent rows, then DFS-enumerate all bases. */
function enumerateBases<T>(
  columns: T[][],
  ops: FieldOps<T>,
  budget: { ops: number },
): Int32Array | Fail {
  const n = columns.length
  const cost = ops.costFactor
  const spend = (k: number): boolean => (budget.ops -= k * cost) > 0

  // First pass: rank of the whole matrix, reusing the same elimination.
  const pivots: { vec: T[]; pos: number }[] = []
  const reduce = (col: T[]): T[] | null => {
    const v = col.slice()
    for (const { vec, pos } of pivots) {
      if (!spend(v.length)) return null
      ops.eliminate(v, vec, pos)
    }
    return v
  }
  const leadingPos = (v: T[]): number => {
    for (let k = 0; k < v.length; k++) if (!ops.isZero(v[k])) return k
    return -1
  }

  for (let c = 0; c < n; c++) {
    const v = reduce(columns[c])
    if (v === null) return fail('verification budget exceeded; please submit a smaller matrix')
    const pos = leadingPos(v)
    if (pos >= 0) {
      ops.normalize(v)
      pivots.push({ vec: v, pos })
    }
  }
  const rank = pivots.length
  if (rank === 0) return Int32Array.of(0) // every column is zero: the empty set is the basis

  // The search visits every independent set; bound their possible number
  // before starting. Everything on ≤ 24 elements passes (the budget is 2^24
  // and Σ_k C(24,k) cannot exceed it); on 25 or 26 elements this admits only
  // low ranks, where the count stays small.
  let bound = 0
  let binom = 1 // C(n, 0)
  for (let k = 0; k <= rank; k++) {
    bound += binom
    binom = (binom * (n - k)) / (k + 1)
  }
  if (bound > INDEPENDENT_SET_BUDGET) {
    return fail(
      `too large to verify: a rank-${rank} matroid on ${n} elements may have ~${Math.round(bound / 1e6)}M independent sets to enumerate (limit ${Math.round(INDEPENDENT_SET_BUDGET / 1e6)}M) — on ${n} elements only lower ranks are supported`,
    )
  }

  // Depth-first search over columns in increasing order, keeping the current
  // independent set's elimination state on an explicit stack. Basis masks
  // are collected in a manually grown Int32Array: at 4 bytes per mask the
  // largest admitted case (~5.3M bases) stays ~21 MB, where a plain JS array
  // (8-byte slots plus growth copies) would crowd the worker's 128 MB.
  let bases = new Int32Array(1024)
  let count = 0
  const stack: { vec: T[]; pos: number }[] = []
  const dfs = (start: number, mask: number): Fail | null => {
    if (stack.length === rank) {
      if (count === bases.length) {
        const grown = new Int32Array(bases.length * 2)
        grown.set(bases)
        bases = grown
      }
      bases[count++] = mask
      return null
    }
    // Not enough columns left to reach full rank: prune.
    for (let c = start; c <= n - (rank - stack.length); c++) {
      const v = columns[c].slice()
      for (const { vec, pos } of stack) {
        if (!spend(v.length)) {
          return fail('verification budget exceeded; please submit a smaller matrix')
        }
        ops.eliminate(v, vec, pos)
      }
      const pos = leadingPos(v)
      if (pos < 0) continue
      ops.normalize(v)
      stack.push({ vec: v, pos })
      const failure = dfs(c + 1, mask | (1 << c))
      stack.pop()
      if (failure) return failure
    }
    return null
  }
  const failure = dfs(0, 0)
  if (failure) return failure
  return bases.subarray(0, count)
}

function matroidFromMatrix(
  n: number,
  fieldText: string,
  data: unknown,
): { bases: Int32Array; field: string } | Fail {
  if (!Array.isArray(data) || data.length === 0 || !data.every((row) => Array.isArray(row))) {
    return fail('the matrix must be a nonempty JSON list of rows')
  }
  const rows = data as unknown[][]
  for (const [idx, row] of rows.entries()) {
    if (row.length !== n) {
      return fail(`matrix row ${idx} has ${row.length} entries; expected one per element (n = ${n})`)
    }
  }
  if (rows.length * n > MAX_MATRIX_CELLS) {
    return fail(`the matrix may have at most ${MAX_MATRIX_CELLS.toLocaleString('en-US')} entries`)
  }
  const budget = { ops: OP_BUDGET }

  const field = fieldText.trim()
  if (field === 'Q' || field === 'q' || field === 'ℚ') {
    // Parse rational entries and clear denominators row by row (row scaling
    // does not change the column matroid).
    const intRows: bigint[][] = []
    for (const [ri, row] of rows.entries()) {
      const nums: bigint[] = []
      const dens: bigint[] = []
      for (const [ci, cell] of row.entries()) {
        let text: string
        if (typeof cell === 'number' && Number.isSafeInteger(cell)) text = String(cell)
        else if (typeof cell === 'string') text = cell.trim()
        else {
          return fail(
            `matrix entry at row ${ri}, column ${ci} must be an integer or a fraction string like "-3/5"`,
          )
        }
        const m = RATIONAL_RE.exec(text)
        if (!m) {
          return fail(
            `could not parse matrix entry ${JSON.stringify(text)} at row ${ri}, column ${ci} (over Q, use integers or "a/b" with at most 15 digits)`,
          )
        }
        nums.push(BigInt(m[1]))
        dens.push(m[2] ? BigInt(m[2]) : 1n)
      }
      let lcm = 1n
      for (const d of dens) lcm = (lcm / bigGcd(lcm, d)) * d
      intRows.push(nums.map((num, k) => (num * lcm) / dens[k]))
    }
    const columns: bigint[][] = Array.from({ length: n }, (_, c) => intRows.map((row) => row[c]))
    const bases = enumerateBases(columns, rationalOps(), budget)
    if (isFail(bases)) return bases
    return { bases: bases.sort(), field: 'Q' }
  }

  // GF(q): q a prime (up to MAX_FIELD_PRIME), or a prime power p^d with
  // d ≥ 2 up to MAX_EXT_FIELD_ORDER, written either as the order ("9") or
  // explicitly ("3^2").
  const spec = /^(\d{1,9})(?:\^(\d{1,2}))?$/.exec(field)
  if (!spec) {
    return fail(
      `unrecognized field ${JSON.stringify(fieldText)}: use "Q", a prime p, or a prime power p^d (e.g. "4" or "2^2")`,
    )
  }
  let p: number
  let d: number
  if (spec[2] !== undefined) {
    p = Number(spec[1])
    d = Number(spec[2])
    if (!isPrime(p)) return fail(`GF(${field}): ${p} is not prime`)
    if (d < 1) return fail(`GF(${field}): the exponent must be at least 1`)
  } else {
    const q = Number(spec[1])
    if (q < 2) return fail(`GF(${q}) is not a field`)
    p = 2
    while (q % p !== 0) p++
    d = Math.round(Math.log(q) / Math.log(p))
    if (p ** d !== q) {
      return fail(`GF(${q}): ${q} is not a prime power — use "Q", a prime p, or a prime power p^d`)
    }
  }
  if (d === 1) {
    if (p > MAX_FIELD_PRIME) {
      return fail(`prime fields are supported up to GF(${MAX_FIELD_PRIME.toLocaleString('en-US')})`)
    }
  } else if (p ** d > MAX_EXT_FIELD_ORDER) {
    return fail(`extension fields GF(p^d) are supported up to order ${MAX_EXT_FIELD_ORDER}`)
  }
  const gf = d === 1 ? gfOps(p) : gfExtOps(p, d)
  const columns: number[][] = Array.from({ length: n }, () => [])
  for (const [ri, row] of rows.entries()) {
    for (let c = 0; c < n; c++) {
      const cell = gf.fromCell(row[c], ri, c)
      if (isFail(cell)) return cell
      columns[c].push(cell)
    }
  }
  const bases = enumerateBases(columns, gf, budget)
  if (isFail(bases)) return bases
  return { bases: bases.sort(), field: String(p ** d) }
}

// ---------------------------------------------------------------------------
// The correlation constant from the list of bases.

function computeAlpha(
  n: number,
  bases: Int32Array | number[],
): Pick<
  VerifiedMatroid,
  'loops' | 'coloops' | 'alphaNum' | 'alphaDen' | 'alphaValue' | 'maximizingPairs' | 'maxCounts'
> {
  let union = 0
  let inter = (1 << n) - 1
  for (const b of bases) {
    union |= b
    inter &= b
  }
  const loops = bitsOf(~union & ((1 << n) - 1))
  const coloops = bitsOf(inter)
  const eligible = bitsOf(union & ~inter)

  // One pass over the bases accumulates, for every element and pair of
  // elements, how many bases contain them; the four 2x2 cells for a pair
  // follow by inclusion-exclusion. (A per-pair scan over millions of bases
  // would cost C(n,2) full passes instead of one.)
  const single = new Float64Array(n) // counts < 2^53, exact in doubles
  const both = new Float64Array(n * n)
  const els = new Int32Array(n)
  for (const basis of bases) {
    let m = basis
    let k = 0
    while (m) {
      const low = m & -m
      els[k++] = 31 - Math.clz32(low)
      m ^= low
    }
    for (let a = 0; a < k; a++) {
      single[els[a]]++
      const row = els[a] * n
      for (let c = a + 1; c < k; c++) both[row + els[c]]++
    }
  }

  const total = bases.length
  let bestNum = 0n
  let bestDen = 1n
  let maximizingPairs: [number, number][] = []
  let maxCounts: MaxCounts | null = null
  for (let a = 0; a < eligible.length; a++) {
    for (let b = a + 1; b < eligible.length; b++) {
      const i = eligible[a]
      const j = eligible[b]
      const containBoth = both[i * n + j]
      const onlyI = single[i] - containBoth
      const onlyJ = single[j] - containBoth
      const avoidBoth = total - single[i] - single[j] + containBoth
      // Both denominator factors are positive for nonloop, noncoloop pairs.
      const num = BigInt(containBoth) * BigInt(avoidBoth)
      const den = BigInt(onlyI) * BigInt(onlyJ)
      const cmp = maxCounts === null ? 1n : num * bestDen - bestNum * den
      if (cmp > 0n) {
        bestNum = num
        bestDen = den
        maximizingPairs = [[i, j]]
        maxCounts = { containBoth, avoidBoth, onlyI, onlyJ }
      } else if (cmp === 0n) {
        maximizingPairs.push([i, j])
      }
    }
  }
  if (maximizingPairs.length === 0) {
    // Only loops and coloops: α(M) = 0 by convention.
    return { loops, coloops, alphaNum: 0, alphaDen: 1, alphaValue: 0, maximizingPairs, maxCounts }
  }
  const g = bigGcd(bestNum, bestDen)
  const alphaNum = Number(bestNum / g)
  const alphaDen = Number(bestDen / g)
  return {
    loops,
    coloops,
    alphaNum,
    alphaDen,
    alphaValue: alphaNum / alphaDen,
    maximizingPairs,
    maxCounts,
  }
}

// ---------------------------------------------------------------------------

export function verify(
  n: number,
  type: string,
  fieldText: string,
  data: unknown,
): VerifyResult {
  if (!Number.isInteger(n) || n < 1) {
    return { ok: false, error: 'n must be a positive integer' }
  }
  if (n > MAX_ELEMENTS) {
    return { ok: false, error: `n must be at most ${MAX_ELEMENTS}` }
  }
  if (!(REPRESENTATION_TYPES as readonly string[]).includes(type)) {
    return {
      ok: false,
      error: `unknown description type ${JSON.stringify(type)}: use one of ${REPRESENTATION_TYPES.join(', ')}`,
    }
  }
  const representationType = type as RepresentationType

  let bases: Int32Array | number[]
  let field: string | null = null
  if (representationType === 'matrix') {
    const parsed = matroidFromMatrix(n, fieldText, data)
    if (isFail(parsed)) return { ok: false, error: parsed.error }
    bases = parsed.bases
    field = parsed.field
  } else {
    const parsed =
      representationType === 'bases'
        ? matroidFromBases(n, data)
        : representationType === 'circuits'
          ? matroidFromCircuits(n, data)
          : matroidFromHyperplanes(n, data)
    if (isFail(parsed)) return { ok: false, error: parsed.error }
    bases = parsed
  }

  const rank = popcount(bases[0])
  return {
    ok: true,
    n,
    rank,
    numBases: bases.length,
    ...computeAlpha(n, bases),
    representationType,
    representation: JSON.stringify(data),
    field,
    basesJson:
      bases.length <= BASES_JSON_MAX_COUNT ? JSON.stringify(Array.from(bases, bitsOf)) : null,
    basesMasks: bases,
  }
}
