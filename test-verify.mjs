// Exercises src/verify.ts with known matroids. Run via `npm test`
// (Node 22.6+: type stripping lets Node import the .ts directly).
import { conwayPolynomial, verify } from './src/verify.ts'

let failures = 0
const check = (name, cond, detail = '') => {
  if (cond) {
    console.log(`ok   ${name}`)
  } else {
    failures++
    console.error(`FAIL ${name}${detail ? ` — ${detail}` : ''}`)
  }
}
const alphaOf = (r) => (r.ok ? `${r.alphaNum}/${r.alphaDen}` : `error: ${r.error}`)

// U(2,4) in all four descriptions: rank 2, 6 bases, α = 1/4 at every pair.
const u24 = {
  matrix: verify(4, 'matrix', '3', [[1, 0, 1, 1], [0, 1, 1, 2]]),
  bases: verify(4, 'bases', '', [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]),
  circuits: verify(4, 'circuits', '', [[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]]),
  hyperplanes: verify(4, 'hyperplanes', '', [[0], [1], [2], [3]]),
}
for (const [kind, r] of Object.entries(u24)) {
  check(`U(2,4) via ${kind}: verifies`, r.ok, alphaOf(r))
  if (!r.ok) continue
  check(`U(2,4) via ${kind}: rank 2, 6 bases`, r.rank === 2 && r.numBases === 6)
  check(`U(2,4) via ${kind}: α = 1/4`, r.alphaNum === 1 && r.alphaDen === 4, alphaOf(r))
  check(`U(2,4) via ${kind}: 6 maximizing pairs`, r.maximizingPairs.length === 6)
  check(
    `U(2,4) via ${kind}: same bases as matrix`,
    r.basesJson === u24.matrix.basesJson,
  )
}

// The 12-element rank-6 ternary record: α = 100/81 with basis counts
// (180, 180, 162, 162). Matrix from the discovery record. (That record lists
// the maximizing pair as (8, 11), but for this matrix the unique maximizer is
// (5, 10) — confirmed by an independent brute force over all 924 subsets.)
const ternary = verify(12, 'matrix', '3', [
  [1, 2, 1, 2, 2, 2, 1, 1, 0, 0, 1, 2],
  [0, 0, 2, 0, 0, 0, 0, 0, 2, 1, 1, 1],
  [0, 1, 1, 1, 0, 1, 1, 2, 1, 1, 1, 2],
  [1, 1, 1, 2, 2, 1, 1, 2, 1, 1, 0, 1],
  [0, 1, 0, 1, 2, 1, 1, 0, 2, 0, 1, 0],
  [0, 1, 1, 1, 1, 0, 2, 0, 0, 1, 0, 0],
])
check('ternary 100/81: verifies', ternary.ok, alphaOf(ternary))
if (ternary.ok) {
  check('ternary 100/81: rank 6, 684 bases', ternary.rank === 6 && ternary.numBases === 684,
    `rank ${ternary.rank}, ${ternary.numBases} bases`)
  check('ternary 100/81: α = 100/81', ternary.alphaNum === 100 && ternary.alphaDen === 81, alphaOf(ternary))
  check(
    'ternary 100/81: unique maximizing pair (5, 10)',
    ternary.maximizingPairs.length === 1 &&
      ternary.maximizingPairs[0][0] === 5 &&
      ternary.maximizingPairs[0][1] === 10,
    JSON.stringify(ternary.maximizingPairs),
  )
  check(
    'ternary 100/81: counts (180, 180, 162, 162)',
    ternary.maxCounts.containBoth === 180 &&
      ternary.maxCounts.avoidBoth === 180 &&
      ternary.maxCounts.onlyI === 162 &&
      ternary.maxCounts.onlyJ === 162,
    JSON.stringify(ternary.maxCounts),
  )
}

// The cycle matroid of K4 over GF(2) (vertex-edge incidence matrix): rank 3,
// 16 spanning trees, negatively correlated everywhere (α ≤ 1).
// Edge order: 01, 02, 03, 12, 13, 23.
const k4 = verify(6, 'matrix', '2', [
  [1, 1, 1, 0, 0, 0],
  [1, 0, 0, 1, 1, 0],
  [0, 1, 0, 1, 0, 1],
  [0, 0, 1, 0, 1, 1],
])
check('K4: verifies', k4.ok, alphaOf(k4))
if (k4.ok) {
  check('K4: rank 3, 16 spanning trees', k4.rank === 3 && k4.numBases === 16,
    `rank ${k4.rank}, ${k4.numBases} bases`)
  check('K4: α ≤ 1', k4.alphaNum <= k4.alphaDen, alphaOf(k4))
}

// Rational matrix with fraction entries: columns (1,0), (0,1), (1/2,1/3)
// give U(2,3); adjacent pairs never avoid a basis together, so α = 0.
const rational = verify(3, 'matrix', 'Q', [[1, 0, '1/2'], [0, 1, '1/3']])
check('Q matrix: verifies', rational.ok, alphaOf(rational))
if (rational.ok) {
  check('Q matrix: U(2,3) with 3 bases', rational.rank === 2 && rational.numBases === 3)
  check('Q matrix: α = 0', rational.alphaNum === 0 && rational.alphaDen === 1, alphaOf(rational))
}

// A zero column is a loop; the other column is a coloop; no eligible pair.
const loops = verify(2, 'matrix', '5', [[1, 0], [0, 0]])
check('loop/coloop: verifies with α = 0', loops.ok && loops.alphaNum === 0, alphaOf(loops))
if (loops.ok) {
  check(
    'loop/coloop: classified',
    loops.loops.length === 1 && loops.loops[0] === 1 && loops.coloops.length === 1 && loops.coloops[0] === 0,
    JSON.stringify({ loops: loops.loops, coloops: loops.coloops }),
  )
}

// Invalid inputs are rejected with pointed errors.
const badExchange = verify(4, 'bases', '', [[0, 1], [2, 3]])
check('bases failing exchange rejected', !badExchange.ok && /exchange/.test(badExchange.error), alphaOf(badExchange))

const nested = verify(3, 'circuits', '', [[0, 1], [0, 1, 2]])
check('nested circuits rejected', !nested.ok && /nested/.test(nested.error), alphaOf(nested))

const badElim = verify(3, 'circuits', '', [[0, 1], [1, 2]])
check('circuit elimination failure rejected', !badElim.ok && /eliminat/.test(badElim.error), alphaOf(badElim))

const badRow = verify(3, 'matrix', '2', [[1, 0], [0, 1]])
check('matrix row length mismatch rejected', !badRow.ok && /row/.test(badRow.error), alphaOf(badRow))

const badField = verify(4, 'matrix', '6', [[1, 0, 1, 1], [0, 1, 1, 1]])
check('GF(6) rejected as not a prime power', !badField.ok && /prime power/.test(badField.error), alphaOf(badField))

const bigExt = verify(4, 'matrix', '2^11', [[1, 0, 1, 1], [0, 1, 1, 1]])
check('GF(2^11) rejected as too large', !bigExt.ok && /up to order/.test(bigExt.error), alphaOf(bigExt))

const dupBasis = verify(2, 'bases', '', [[0], [0]])
check('duplicate basis rejected', !dupBasis.ok && /twice/.test(dupBasis.error), alphaOf(dupBasis))

// The whole ground set can never be a hyperplane.
const badHyp = verify(2, 'hyperplanes', '', [[0, 1]])
check('full-set hyperplane rejected', !badHyp.ok, alphaOf(badHyp))

// Free matroid via empty circuit list: every element a coloop.
const free = verify(3, 'circuits', '', [])
check('free matroid: α = 0, all coloops', free.ok && free.alphaNum === 0 && free.coloops.length === 3, alphaOf(free))

// Larger ground sets. A Cauchy matrix over GF(p) has every minor nonzero, so
// 10 x 20 gives the uniform matroid U(10,20) — the worst case for basis
// enumeration at n = 20. α(U(r,n)) = (r-1)(n-r-1)/(r(n-r)).
{
  const p = 65521
  const modpow = (b, e) => { let r = 1n, x = BigInt(b) % BigInt(p); for (let k = BigInt(e); k > 0n; k >>= 1n, x = (x * x) % BigInt(p)) if (k & 1n) r = (r * x) % BigInt(p); return Number(r) }
  const inv = (a) => modpow(a, p - 2)
  const cauchy = Array.from({ length: 10 }, (_, i) =>
    Array.from({ length: 20 }, (_, j) => inv(i + j + 100)),
  )
  const u = verify(20, 'matrix', String(p), cauchy)
  check('U(10,20) via Cauchy/GF: verifies', u.ok, alphaOf(u))
  if (u.ok) {
    check('U(10,20): 184,756 bases', u.numBases === 184756, String(u.numBases))
    check('U(10,20): α = 81/100', u.alphaNum === 81 && u.alphaDen === 100, alphaOf(u))
    check('U(10,20): bases JSON omitted when huge', u.basesJson === null)
  }
}

// A Vandermonde matrix over Q has every maximal minor nonzero (generalized
// Vandermonde = Schur polynomial x positive factors), so 8 x 16 gives
// U(8,16) — exercising exact BigInt elimination at scale.
{
  const vandermonde = Array.from({ length: 8 }, (_, r) =>
    Array.from({ length: 16 }, (_, j) => (j + 1) ** r),
  )
  const u = verify(16, 'matrix', 'Q', vandermonde)
  check('U(8,16) via Vandermonde/Q: verifies', u.ok, alphaOf(u))
  if (u.ok) {
    check('U(8,16): 12,870 bases', u.numBases === 12870, String(u.numBases))
    check('U(8,16): α = 49/64', u.alphaNum === 49 && u.alphaDen === 64, alphaOf(u))
  }
}

// The HSW spike M_5^5 (n = 22 > the old limit of 18): α = 8/7 with the 2x2
// counts from Section 5 of the paper, (500, 5000, 625, 3500).
{
  const p = 5, d = 5
  const cols = [[1, 0, 0, 0, 0], [0, 1, 1, 1, 1]]
  for (let m = 1; m < d; m++) {
    for (let k = 1; k <= p; k++) {
      const v = [k % p, 0, 0, 0, 0]
      v[m] = 1
      cols.push(v)
    }
  }
  const rows = Array.from({ length: d }, (_, r) => cols.map((c) => c[r]))
  const s = verify(22, 'matrix', '5', rows)
  check('spike M_5^5 (n=22): verifies', s.ok, alphaOf(s))
  if (s.ok) {
    check('spike M_5^5: rank 5, 9,625 bases', s.rank === 5 && s.numBases === 9625, String(s.numBases))
    check('spike M_5^5: α = 8/7', s.alphaNum === 8 && s.alphaDen === 7, alphaOf(s))
    check(
      'spike M_5^5: HSW counts (500, 5000, 625, 3500)',
      s.maxCounts.containBoth === 500 &&
        s.maxCounts.avoidBoth === 5000 &&
        s.maxCounts.onlyI === 625 &&
        s.maxCounts.onlyJ === 3500,
      JSON.stringify(s.maxCounts),
    )
  }
}

// Conway polynomials against their standard values (as in Sage/GAP),
// little-endian: C_{2,3} = x^3+x+1, C_{2,4} = x^4+x+1, C_{3,2} = x^2+2x+2,
// C_{5,2} = x^2+4x+2, C_{7,2} = x^2+6x+3.
for (const [p, d, expected] of [
  [2, 3, [1, 1, 0, 1]],
  [2, 4, [1, 1, 0, 0, 1]],
  [3, 2, [2, 2, 1]],
  [5, 2, [2, 4, 1]],
  [7, 2, [3, 6, 1]],
]) {
  const got = conwayPolynomial(p, d)
  check(
    `Conway C_{${p},${d}}`,
    JSON.stringify(got) === JSON.stringify(expected),
    `got ${JSON.stringify(got)}, expected ${JSON.stringify(expected)}`,
  )
}

// U(2,5) over GF(4): five pairwise-independent columns (1,0), (0,1), (1,1),
// (1,a), (1,a+1) — a matroid not representable over GF(2) or GF(3), so this
// genuinely exercises extension-field arithmetic. α(U(2,5)) = 1/3.
const u25 = verify(5, 'matrix', '4', [
  [1, 0, 1, 1, 1],
  [0, 1, 1, [0, 1], [1, 1]],
])
check('U(2,5) over GF(4): verifies', u25.ok, alphaOf(u25))
if (u25.ok) {
  check('U(2,5): rank 2, 10 bases', u25.rank === 2 && u25.numBases === 10, String(u25.numBases))
  check('U(2,5): α = 1/3', u25.alphaNum === 1 && u25.alphaDen === 3, alphaOf(u25))
  check('U(2,5): field recorded as 4', u25.field === '4', String(u25.field))
}

// The same columns as "2^2" and with the duplicate-slope check: over GF(9)
// four distinct slopes give U(2,4).
const u25b = verify(5, 'matrix', '2^2', [
  [1, 0, 1, 1, 1],
  [0, 1, 1, [0, 1], [1, 1]],
])
check('field "2^2" equals field "4"', u25b.ok && u25b.basesJson === u25.basesJson)

const u24gf9 = verify(4, 'matrix', '9', [
  [1, 0, 1, 1],
  [0, 1, 1, [0, 1]],
])
check(
  'U(2,4) over GF(9): α = 1/4',
  u24gf9.ok && u24gf9.alphaNum === 1 && u24gf9.alphaDen === 4 && u24gf9.field === '9',
  alphaOf(u24gf9),
)

// The largest supported extension field.
const gf1024 = verify(3, 'matrix', '1024', [
  [1, 0, [0, 1]],
  [0, 1, 1],
])
check('GF(1024) = GF(2^10) accepted', gf1024.ok && gf1024.field === '1024', alphaOf(gf1024))

// Chris Eur's sample challenge submission (found via ChatGPT 5.6 Sol Ultra):
// a rank-9 matroid on 26 elements over GF(7), claimed α = 280043/243256
// ≈ 1.1512 > 8/7. Also exercises the rank-aware n = 26 admission.
const eur26 = verify(26, 'matrix', '7', [
  [5, 3, 2, 4, 5, 3, 2, 3, 3, 3, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0],
  [1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  [4, 1, 6, 1, 6, 6, 2, 1, 0, 4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  [5, 2, 2, 3, 0, 1, 3, 1, 4, 1, 4, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 3, 2, 4, 5, 3, 2, 3, 3, 3, 2, 4, 1, 0],
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 6, 1, 6, 6, 2, 1, 0, 4, 4, 4, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 2, 2, 3, 0, 1, 3, 1, 4, 1, 4, 2, 0, 0],
  [1, 3, 6, 0, 5, 1, 1, 0, 5, 4, 4, 4, 5, 3, 6, 3, 4, 5, 0, 6, 2, 2, 2, 1, 3, 1],
])
check('Eur n=26 sample: verifies', eur26.ok, alphaOf(eur26))
if (eur26.ok) {
  check('Eur n=26 sample: rank 9', eur26.rank === 9, String(eur26.rank))
  check(
    'Eur n=26 sample: α = 280043/243256',
    eur26.alphaNum === 280043 && eur26.alphaDen === 243256,
    alphaOf(eur26),
  )
  check(
    'Eur n=26 sample: beats 8/7',
    eur26.alphaNum * 7 > 8 * eur26.alphaDen,
    alphaOf(eur26),
  )
}

// The HSW spike M_7^5 at n = 30, the bitmask limit: α = 8/7 with the 2x2
// counts (1372, 28812, 2401, 14406) from the Section 5 formulas at p = 7.
{
  const p = 7, d = 5
  const cols = [[1, 0, 0, 0, 0], [0, 1, 1, 1, 1]]
  for (let m = 1; m < d; m++) {
    for (let k = 1; k <= p; k++) {
      const v = [k % p, 0, 0, 0, 0]
      v[m] = 1
      cols.push(v)
    }
  }
  const rows = Array.from({ length: d }, (_, r) => cols.map((c) => c[r]))
  const s = verify(30, 'matrix', '7', rows)
  check('spike M_7^5 (n=30): verifies', s.ok, alphaOf(s))
  if (s.ok) {
    check('spike M_7^5: rank 5, 46,991 bases', s.rank === 5 && s.numBases === 46991, String(s.numBases))
    check('spike M_7^5: α = 8/7', s.alphaNum === 8 && s.alphaDen === 7, alphaOf(s))
    check(
      'spike M_7^5: HSW counts (1372, 28812, 2401, 14406)',
      s.maxCounts.containBoth === 1372 &&
        s.maxCounts.avoidBoth === 28812 &&
        s.maxCounts.onlyI === 2401 &&
        s.maxCounts.onlyJ === 14406,
      JSON.stringify(s.maxCounts),
    )
  }
}

const tooMany = verify(31, 'matrix', '2', [Array.from({ length: 31 }, () => 1)])
check('n = 31 rejected', !tooMany.ok && /at most 30/.test(tooMany.error), alphaOf(tooMany))

// High rank on 26 elements must be declined by the independent-set budget.
{
  const p = 65521
  const modpow = (b, e) => { let r = 1n, x = BigInt(b) % BigInt(p); for (let k = BigInt(e); k > 0n; k >>= 1n, x = (x * x) % BigInt(p)) if (k & 1n) r = (r * x) % BigInt(p); return Number(r) }
  const inv = (a) => modpow(a, p - 2)
  const cauchy = Array.from({ length: 13 }, (_, i) =>
    Array.from({ length: 26 }, (_, j) => inv(i + j + 100)),
  )
  const big = verify(26, 'matrix', String(p), cauchy)
  check('rank 13 on 26 elements declined', !big.ok && /too large to verify/.test(big.error), alphaOf(big))
  const cauchy30 = Array.from({ length: 9 }, (_, i) =>
    Array.from({ length: 30 }, (_, j) => inv(i + j + 100)),
  )
  const big30 = verify(30, 'matrix', String(p), cauchy30)
  check('rank 9 on 30 elements declined', !big30.ok && /too large to verify/.test(big30.error), alphaOf(big30))
}

const bigCircuits = verify(25, 'circuits', '', [[0, 1, 2]])
check('circuits on 25 elements declined', !bigCircuits.ok && /at most 24/.test(bigCircuits.error), alphaOf(bigCircuits))

if (failures > 0) {
  console.error(`\n${failures} failure(s)`)
  process.exit(1)
}
console.log('\nall tests passed')
