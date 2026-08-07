// Exercises the pure validation layer of src/familyStore.ts (proposal
// parsing, series JSON, fractions, slugs). Run via `npm test`.
import {
  familyToFormState,
  parseFamilyProposal,
  parseFraction,
  parseSeries,
  slugify,
} from './src/familyStore.ts'

let failures = 0
const check = (name, cond, detail = '') => {
  if (cond) {
    console.log(`ok   ${name}`)
  } else {
    failures++
    console.error(`FAIL ${name}${detail ? ` — ${detail}` : ''}`)
  }
}
const errorOf = (r) => (r && typeof r === 'object' && 'error' in r ? r.error : null)

// --- parseFraction ---------------------------------------------------------

check('fraction: reduces', JSON.stringify(parseFraction('100/75')) === '{"num":4,"den":3}')
check('fraction: integer', JSON.stringify(parseFraction(' 2 ')) === '{"num":2,"den":1}')
check('fraction: decimal refused', errorOf(parseFraction('1.333')) !== null)
check('fraction: zero denominator refused', errorOf(parseFraction('4/0')) !== null)
check('fraction: negative refused', errorOf(parseFraction('-1/3')) !== null)

// --- parseSeries -----------------------------------------------------------

const goodSeries = JSON.stringify([
  {
    label: 'q = 2',
    points: [
      { parameter: 'd = 3', n: 10, rank: 7, alpha: '6/7' },
      { parameter: 'd = 4', n: 18, rank: 9, alpha: '8/7', field: 2 },
    ],
  },
])
{
  const s = parseSeries(goodSeries)
  check('series: parses', Array.isArray(s), errorOf(s) ?? '')
  if (Array.isArray(s)) {
    check('series: generated ids', s[0].id === 's1')
    check('series: reduced fractions kept', s[0].points[0].num === 6 && s[0].points[0].den === 7)
    check('series: field carried', s[0].points[1].field === 2)
  }
}
// The single-curve shorthand: a flat list of points wraps into one
// unlabeled series.
{
  const s = parseSeries(
    JSON.stringify([
      { parameter: 'r = 2', n: 10, rank: 5, alpha: '16/17' },
      { parameter: 'r = 3', n: 14, rank: 7, alpha: '18/17', field: 2 },
    ]),
  )
  check('series: flat point list parses', Array.isArray(s), errorOf(s) ?? '')
  if (Array.isArray(s)) {
    check(
      'series: flat list becomes one unlabeled series',
      s.length === 1 && s[0].label === '' && s[0].points.length === 2,
    )
    check('series: flat list keeps point data', s[0].points[1].field === 2 && s[0].points[0].num === 16)
  }
}
check(
  'series: flat list validates points',
  errorOf(parseSeries(JSON.stringify([{ parameter: 'p', n: 4, rank: 2, alpha: '9/4' }]))) !== null,
)
check(
  'series: grouped form still requires a label',
  errorOf(parseSeries(JSON.stringify([{ points: [{ parameter: 'p', n: 4, rank: 2, alpha: '1' }] }]))) !== null,
)
check('series: bad JSON refused', errorOf(parseSeries('[{')) !== null)
check('series: empty list refused', errorOf(parseSeries('[]')) !== null)
check(
  'series: HSW bound enforced on points',
  /Huh–Schröter–Wang/.test(
    errorOf(parseSeries(JSON.stringify([{ label: 'x', points: [{ parameter: 'p', n: 4, rank: 2, alpha: '9/4' }] }]))) ?? '',
  ),
)
check(
  'series: rank > n refused',
  errorOf(parseSeries(JSON.stringify([{ label: 'x', points: [{ parameter: 'p', n: 4, rank: 5, alpha: '1' }] }]))) !== null,
)
check(
  'series: alpha must be a string fraction',
  errorOf(parseSeries(JSON.stringify([{ label: 'x', points: [{ parameter: 'p', n: 4, rank: 2, alpha: 1.5 }] }]))) !== null,
)

// --- parseFamilyProposal ---------------------------------------------------

const goodProposal = {
  name: 'Test family',
  short: 'Test',
  claim: 'lower',
  parameter: String.raw`integer \(r \ge 2\)`,
  formula_tex: String.raw`R_{ef}(P_r) = \frac{4r^2}{3r^2+2r+1}`,
  size_rank_tex: String.raw`|E(P_r)| = 4r+2`,
  supremum: '4/3',
  supremum_kind: 'approached',
  summary: 'A test family.',
  construction: 'Built as a test.',
  curve_explanation: 'The curve is a test.',
  proof_status: 'Proved in the test suite.',
  proof_url: 'https://example.org/proof',
  series: goodSeries,
  contributors: 'A. Tester',
  discovery_date: '2026-08',
  ai_used: 'no',
}
{
  const p = parseFamilyProposal(goodProposal)
  check('proposal: parses', errorOf(p) === null, errorOf(p) ?? '')
  if (errorOf(p) === null) {
    check('proposal: supremum reduced', p.supremum.num === 4 && p.supremum.den === 3)
    check('proposal: aiUsed false', p.aiUsed === false && p.aiModel === null)
  }
}
check(
  'proposal: missing name refused',
  /name/.test(errorOf(parseFamilyProposal({ ...goodProposal, name: '  ' })) ?? ''),
)
check(
  'proposal: supremum above 2 refused',
  /Huh–Schröter–Wang/.test(errorOf(parseFamilyProposal({ ...goodProposal, supremum: '5/2' })) ?? ''),
)
check(
  'proposal: bad date refused',
  errorOf(parseFamilyProposal({ ...goodProposal, discovery_date: 'August 2026' })) !== null,
)
check(
  'proposal: AI declaration required',
  errorOf(parseFamilyProposal({ ...goodProposal, ai_used: '' })) !== null,
)
check(
  'proposal: AI yes needs model and role',
  errorOf(parseFamilyProposal({ ...goodProposal, ai_used: 'yes' })) !== null,
)
{
  const p = parseFamilyProposal({
    ...goodProposal,
    ai_used: 'yes',
    ai_model: 'TestGPT 1',
    ai_role: 'suggested the construction',
  })
  check('proposal: AI yes with model+role parses', errorOf(p) === null, errorOf(p) ?? '')
}
check(
  'proposal: non-http proof link refused',
  errorOf(parseFamilyProposal({ ...goodProposal, proof_url: 'ftp://example.org' })) !== null,
)

// --- familyToFormState (the admin edit form's prefill) ----------------------
// Round trip: a parsed proposal rendered back to form strings must re-parse
// to the same proposal.
{
  const p = parseFamilyProposal(goodProposal)
  if (errorOf(p) === null) {
    const p2 = parseFamilyProposal(familyToFormState(p))
    check('edit prefill: round-trips', errorOf(p2) === null, errorOf(p2) ?? '')
    if (errorOf(p2) === null) {
      check('edit prefill: fields survive', JSON.stringify(p2) === JSON.stringify(p))
    }
  } else {
    check('edit prefill: round-trips', false, errorOf(p))
  }
}
// The single-curve shorthand round-trips through the flat-list form.
{
  const flat = parseFamilyProposal({
    ...goodProposal,
    series: JSON.stringify([{ parameter: 'r = 2', n: 10, rank: 5, alpha: '16/17' }]),
  })
  if (errorOf(flat) === null) {
    const state = familyToFormState(flat)
    check('edit prefill: unlabeled series prints flat', !state.series.includes('"label"'))
    const flat2 = parseFamilyProposal(state)
    check(
      'edit prefill: flat round-trips',
      errorOf(flat2) === null && JSON.stringify(flat2) === JSON.stringify(flat),
      errorOf(flat2) ?? '',
    )
  } else {
    check('edit prefill: unlabeled series prints flat', false, errorOf(flat))
  }
}

// --- slugify ---------------------------------------------------------------

check('slug: basic', slugify('Steiner-system sparse-paving extensions') === 'steiner-system-sparse-paving-extensions')
check('slug: accents and symbols', slugify('Huh–Schröter–Wang spikes!') === 'huh-schroter-wang-spikes')
check('slug: empty fallback', slugify('***') === 'family')

if (failures > 0) {
  console.error(`\n${failures} failure(s)`)
  process.exit(1)
}
console.log('\nall family tests passed')
