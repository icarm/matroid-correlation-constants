// Exercises the pure record policy (src/recordPolicy.ts): which field
// records a submission contends for and what it takes to beat one. Run via
// `npm test`.
import {
  atLeast,
  beatsStanding,
  candidateFields,
  reachesGoal,
  RECORD_FIELDS,
} from './src/recordPolicy.ts'

let failures = 0
const check = (name, cond, detail = '') => {
  if (cond) {
    console.log(`ok   ${name}`)
  } else {
    failures++
    console.error(`FAIL ${name}${detail ? ` — ${detail}` : ''}`)
  }
}

// --- the field menu --------------------------------------------------------

check('menu: exactly GF(2/3/4/5/7)', JSON.stringify([...RECORD_FIELDS]) === '[2,3,4,5,7]')

// --- candidateFields -------------------------------------------------------

check('candidates: GF(2) matrix contends for GF(2) and GF(4)',
  JSON.stringify(candidateFields('2')) === '[2,4]')
check('candidates: GF(4) matrix contends only for GF(4)',
  JSON.stringify(candidateFields('4')) === '[4]')
check('candidates: GF(3) matrix contends only for GF(3)',
  JSON.stringify(candidateFields('3')) === '[3]')
check('candidates: GF(5)', JSON.stringify(candidateFields('5')) === '[5]')
check('candidates: GF(7)', JSON.stringify(candidateFields('7')) === '[7]')
check('candidates: Q contends for nothing', candidateFields('Q').length === 0)
check('candidates: off-menu prime contends for nothing', candidateFields('11').length === 0)
check('candidates: off-menu prime power contends for nothing', candidateFields('8').length === 0)
check('candidates: GF(9) is not GF(3)', candidateFields('9').length === 0)
check('candidates: big prime (Q stand-in) contends for nothing', candidateFields('999983').length === 0)
check('candidates: no field (bases/circuits/hyperplanes)', candidateFields(null).length === 0)

// --- exact comparison ------------------------------------------------------

check('atLeast: strict', atLeast(8, 7, 100, 81) === false && atLeast(100, 81, 8, 7) === true)
check('atLeast: equality counts', atLeast(8, 7, 16, 14) === true)
// Cross products past 2^63: the reason this lives in BigInt, not SQL.
// (2^40+1)/2^40 vs 2^40/(2^40-1): the cross products are 2^80-1 and 2^80.
const p40 = 2 ** 40
check('atLeast: huge cross products stay exact',
  atLeast(p40 + 1, p40, p40, p40 - 1) === false &&
  atLeast(p40, p40 - 1, p40 + 1, p40) === true)

// --- the 4/3 club ----------------------------------------------------------

check('club: 4/3 exactly qualifies', reachesGoal(4, 3) === true)
check('club: above qualifies', reachesGoal(3, 2) === true)
check('club: just below does not', reachesGoal(280043, 243256) === false)

// --- beating a standing record ---------------------------------------------

const standing = { alphaNum: 8, alphaDen: 7 }
check('beats: strictly larger wins', beatsStanding(100, 81, standing) === true)
check('beats: an exact tie does not win', beatsStanding(8, 7, standing) === false)
check('beats: smaller does not win', beatsStanding(9, 8, standing) === false)
check('beats: empty slot taken by a positively correlated matroid',
  beatsStanding(9, 8, null) === true)
check('beats: empty slot refuses α = 1', beatsStanding(1, 1, null) === false)
check('beats: empty slot refuses α < 1', beatsStanding(6, 7, null) === false)

if (failures > 0) {
  console.error(`\n${failures} failure(s)`)
  process.exit(1)
}
console.log('\nall record-policy tests passed')
