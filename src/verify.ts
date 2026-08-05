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
// finite field, the list of all bases, all circuits, or all hyperplanes.
// Every description is reduced to a stream of basis bitmasks in ascending
// numeric order (subsets of the ground set fit an int32). The bases are
// never stored: the correlation constant needs only O(n²) pair counts, the
// canonical JSON is kept only while small, and the canonical hash is a
// chunked SHA-256 over the stream. The matroid axioms are checked exactly,
// and every ratio is compared by exact integer cross multiplication (in
// BigInt: the products can exceed 2^53).

// The ground-set ceiling: subsets are int32 bitmasks, so n ≤ 30. What is
// actually verifiable is decided by enumeration cost, not n — the search
// visits every independent set, so the driver is Σ_{k ≤ rank} C(n, k),
// bounded by INDEPENDENT_SET_BUDGET. Everything on ≤ 24 elements fits
// (2^24 < the bound); larger ground sets are admitted only in low enough
// rank (e.g. rank ≤ 12 at n = 26, rank ≤ 9 at n = 30). Since bases stream
// through constant-memory accumulators rather than being stored, the bound
// is sized purely against the worker CPU limit.
export const MAX_ELEMENTS = 30
const INDEPENDENT_SET_BUDGET = 2 ** 25

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
const OP_BUDGET = 16_000_000_000

/** Stamped on every stored verification, so rows can be re-audited when the
 * verifier evolves (the canonical hash scheme has already changed once). */
export const VERIFIER_VERSION = '2.0.0'

export const REPRESENTATION_TYPES = ['matrix', 'bases', 'circuits', 'hyperplanes'] as const
export type RepresentationType = (typeof REPRESENTATION_TYPES)[number]

export interface MaxCounts {
  containBoth: number
  avoidBoth: number
  onlyI: number
  onlyJ: number
}

/** One maximizing pair with its own 2×2 basis-count table (tied pairs share
 * the ratio but not necessarily the table). */
export interface MaximizingPair {
  i: number
  j: number
  counts: MaxCounts
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
  /** Every pair (i < j) attaining the maximum, each with its counts. */
  maximizingPairs: MaximizingPair[]
  /** The 2×2 basis counts at the first maximizing pair (convenience). */
  maxCounts: MaxCounts | null
  representationType: RepresentationType
  /** Normalized JSON of the submitted description. */
  representation: string
  /** 'Q' or the prime p as text, for matrix submissions. */
  field: string | null
  /** Canonical JSON list of bases, each sorted, in sorted order; null when
   * there are more than BASES_JSON_MAX_COUNT bases. */
  basesJson: string | null
  /** Canonical matroid hash: chunked SHA-256 over the basis-mask stream in
   * ascending numeric order (little-endian 4-byte masks in 2^16-mask blocks;
   * the final digest hashes the concatenated block digests). */
  basesHash: string
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

/** Finite-field ops also parse matrix cells; the rational path instead
 * clears denominators row-by-row before any elimination. */
type FiniteFieldOps = FieldOps<number> & {
  fromCell(cell: unknown, row: number, col: number): number | Fail
}

function gfOps(p: number): FiniteFieldOps {
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
function gfExtOps(p: number, d: number): FiniteFieldOps {
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

/** Row-reduce to at most `n` independent rows, then DFS-stream every basis
 * (in ascending mask order) into `visit`. Returns null on success. */
function enumerateBases<T>(
  columns: T[][],
  ops: FieldOps<T>,
  budget: { ops: number },
  visit: (mask: number) => void,
): Fail | null {
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
  if (rank === 0) {
    visit(0) // every column is zero: the empty set is the basis
    return null
  }

  // The search visits every independent set; bound their possible number
  // before starting. Everything on ≤ 24 elements passes (Σ_k C(24,k) = 2^24
  // is under the budget); on larger ground sets this admits only low ranks,
  // where the count stays small.
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

  // Depth-first search choosing each basis's LARGEST column first, iterating
  // candidates in ascending order — this emits bases in ascending numeric
  // (colex) mask order, the canonical stream order shared by every
  // description path. The current independent set's elimination state lives
  // on an explicit stack.
  const stack: { vec: T[]; pos: number }[] = []
  const dfs = (limit: number, mask: number): Fail | null => {
    if (stack.length === rank) {
      visit(mask)
      return null
    }
    // A column c must leave room for the (need - 1) smaller columns below it.
    const need = rank - stack.length
    for (let c = need - 1; c < limit; c++) {
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
      const failure = dfs(c, mask | (1 << c))
      stack.pop()
      if (failure) return failure
    }
    return null
  }
  return dfs(n, 0)
}

function matroidFromMatrix(
  n: number,
  fieldText: string,
  data: unknown,
  visit: (mask: number) => void,
): { field: string } | Fail {
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
    const failure = enumerateBases(columns, rationalOps(), budget, visit)
    if (failure) return failure
    return { field: 'Q' }
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
  const failure = enumerateBases(columns, gf, budget, visit)
  if (failure) return failure
  return { field: String(p ** d) }
}

// ---------------------------------------------------------------------------
// Streaming consumption of the basis stream.

// Minimal synchronous SHA-256: crypto.subtle.digest is async with no
// streaming interface, and the canonical hash must interleave with basis
// enumeration without buffering the stream.
const SHA256_K = new Uint32Array([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
])

export function sha256(data: Uint8Array): Uint8Array {
  const H = new Int32Array([
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ])
  const byteLen = data.length
  const padded = new Uint8Array((((byteLen + 8) >> 6) + 1) << 6)
  padded.set(data)
  padded[byteLen] = 0x80
  const dv = new DataView(padded.buffer)
  dv.setUint32(padded.length - 8, Math.floor(byteLen / 0x20000000))
  dv.setUint32(padded.length - 4, (byteLen << 3) >>> 0)
  const w = new Int32Array(64)
  for (let off = 0; off < padded.length; off += 64) {
    for (let t = 0; t < 16; t++) w[t] = dv.getUint32(off + t * 4)
    for (let t = 16; t < 64; t++) {
      const x = w[t - 15]
      const y = w[t - 2]
      const s0 = ((x >>> 7) | (x << 25)) ^ ((x >>> 18) | (x << 14)) ^ (x >>> 3)
      const s1 = ((y >>> 17) | (y << 15)) ^ ((y >>> 19) | (y << 13)) ^ (y >>> 10)
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) | 0
    }
    let a = H[0], b = H[1], c = H[2], d = H[3], e = H[4], f = H[5], g = H[6], h = H[7]
    for (let t = 0; t < 64; t++) {
      const S1 = ((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7))
      const ch = (e & f) ^ (~e & g)
      const t1 = (h + S1 + ch + SHA256_K[t] + w[t]) | 0
      const S0 = ((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10))
      const maj = (a & b) ^ (a & c) ^ (b & c)
      const t2 = (S0 + maj) | 0
      h = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0
    }
    H[0] = (H[0] + a) | 0; H[1] = (H[1] + b) | 0; H[2] = (H[2] + c) | 0; H[3] = (H[3] + d) | 0
    H[4] = (H[4] + e) | 0; H[5] = (H[5] + f) | 0; H[6] = (H[6] + g) | 0; H[7] = (H[7] + h) | 0
  }
  const out = new Uint8Array(32)
  const ov = new DataView(out.buffer)
  for (let i = 0; i < 8; i++) ov.setUint32(i * 4, H[i] >>> 0)
  return out
}

const toHex = (bytes: Uint8Array): string =>
  [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('')

const HASH_BLOCK_MASKS = 65536 // 256 KiB of masks per hashed block

/** Consumes the ascending stream of basis masks with constant memory: O(n²)
 * pair counts for the correlation constant, the first BASES_JSON_MAX_COUNT
 * masks for the canonical JSON, and a chunked SHA-256 for the canonical
 * matroid hash. Nothing scales with the number of bases. */
class BasesConsumer {
  private readonly n: number
  private count = 0
  private firstMask = 0
  private union = 0
  private inter: number
  private readonly single: Float64Array // counts < 2^53, exact in doubles
  private readonly both: Float64Array
  private readonly els: Int32Array
  private kept: number[] | null = []
  private readonly block = new Uint8Array(HASH_BLOCK_MASKS * 4)
  private readonly blockView = new DataView(this.block.buffer)
  private blockLen = 0
  private readonly blockDigests: Uint8Array[] = []

  constructor(n: number) {
    this.n = n
    this.inter = (1 << n) - 1
    this.single = new Float64Array(n)
    this.both = new Float64Array(n * n)
    this.els = new Int32Array(n)
  }

  visit(mask: number): void {
    if (this.count === 0) this.firstMask = mask
    this.count++
    this.union |= mask
    this.inter &= mask
    if (this.kept) {
      if (this.kept.length < BASES_JSON_MAX_COUNT) this.kept.push(mask)
      else this.kept = null
    }
    this.blockView.setUint32(this.blockLen, mask, true)
    this.blockLen += 4
    if (this.blockLen === this.block.length) this.flushBlock()
    // Accumulate, for every element and pair of elements, how many bases
    // contain them; the four 2x2 cells for a pair follow by
    // inclusion-exclusion in finish().
    const els = this.els
    let m = mask
    let k = 0
    while (m) {
      const low = m & -m
      els[k++] = 31 - Math.clz32(low)
      m ^= low
    }
    for (let a = 0; a < k; a++) {
      this.single[els[a]]++
      const row = els[a] * this.n
      for (let c = a + 1; c < k; c++) this.both[row + els[c]]++
    }
  }

  private flushBlock(): void {
    this.blockDigests.push(sha256(this.block.subarray(0, this.blockLen)))
    this.blockLen = 0
  }

  finish(): Pick<
    VerifiedMatroid,
    | 'rank'
    | 'numBases'
    | 'loops'
    | 'coloops'
    | 'alphaNum'
    | 'alphaDen'
    | 'alphaValue'
    | 'maximizingPairs'
    | 'maxCounts'
    | 'basesJson'
    | 'basesHash'
  > {
    if (this.blockLen > 0 || this.blockDigests.length === 0) this.flushBlock()
    const concat = new Uint8Array(this.blockDigests.length * 32)
    this.blockDigests.forEach((d, i) => concat.set(d, i * 32))
    const basesHash = toHex(sha256(concat))

    const n = this.n
    const loops = bitsOf(~this.union & ((1 << n) - 1))
    const coloops = bitsOf(this.inter)
    const eligible = bitsOf(this.union & ~this.inter)
    const total = this.count
    let bestNum = 0n
    let bestDen = 1n
    let maximizingPairs: MaximizingPair[] = []
    for (let a = 0; a < eligible.length; a++) {
      for (let b = a + 1; b < eligible.length; b++) {
        const i = eligible[a]
        const j = eligible[b]
        const containBoth = this.both[i * n + j]
        const onlyI = this.single[i] - containBoth
        const onlyJ = this.single[j] - containBoth
        const avoidBoth = total - this.single[i] - this.single[j] + containBoth
        // Both denominator factors are positive for nonloop, noncoloop pairs.
        const num = BigInt(containBoth) * BigInt(avoidBoth)
        const den = BigInt(onlyI) * BigInt(onlyJ)
        const cmp = maximizingPairs.length === 0 ? 1n : num * bestDen - bestNum * den
        const entry = { i, j, counts: { containBoth, avoidBoth, onlyI, onlyJ } }
        if (cmp > 0n) {
          bestNum = num
          bestDen = den
          maximizingPairs = [entry]
        } else if (cmp === 0n) {
          maximizingPairs.push(entry)
        }
      }
    }
    const base = {
      rank: popcount(this.firstMask),
      numBases: total,
      loops,
      coloops,
      maximizingPairs,
      maxCounts: maximizingPairs.length ? maximizingPairs[0].counts : null,
      basesJson: this.kept ? JSON.stringify(this.kept.map(bitsOf)) : null,
      basesHash,
    }
    if (maximizingPairs.length === 0) {
      // Only loops and coloops: α(M) = 0 by convention.
      return { ...base, alphaNum: 0, alphaDen: 1, alphaValue: 0 }
    }
    const g = bigGcd(bestNum, bestDen)
    const alphaNum = Number(bestNum / g)
    const alphaDen = Number(bestDen / g)
    return { ...base, alphaNum, alphaDen, alphaValue: alphaNum / alphaDen }
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

  // All description paths feed the same streaming consumer, in the same
  // canonical ascending mask order.
  const consumer = new BasesConsumer(n)
  let field: string | null = null
  if (representationType === 'matrix') {
    const parsed = matroidFromMatrix(n, fieldText, data, (mask) => consumer.visit(mask))
    if (isFail(parsed)) return { ok: false, error: parsed.error }
    field = parsed.field
  } else {
    const parsed =
      representationType === 'bases'
        ? matroidFromBases(n, data)
        : representationType === 'circuits'
          ? matroidFromCircuits(n, data)
          : matroidFromHyperplanes(n, data)
    if (isFail(parsed)) return { ok: false, error: parsed.error }
    for (const mask of parsed) consumer.visit(mask)
  }

  return {
    ok: true,
    n,
    ...consumer.finish(),
    representationType,
    representation: JSON.stringify(data),
    field,
  }
}
