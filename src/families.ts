// The family catalog: curated content following the discovery record's
// catalog (Chris Eur's draft site). Families are display data, updated via
// pull request — family *submissions* need human proof review and are out of
// scope for the form/API. The chart in public/chart.js carries its own copy
// of the point data (it is a static client asset); keep the two in step.
//
// Formula and prose strings contain TeX and render via MathJax on these
// pages, so this module's literals are String.raw.

import { escapeHtml, layout, type User } from './pages'

interface FamilyPoint {
  parameter: string
  n: number
  rank: number
  num: number
  den: number
}

interface FamilySeries {
  id: string
  label: string
  points: FamilyPoint[]
}

interface Family {
  id: string
  name: string
  short: string
  claim: 'exact' | 'lower'
  color: string
  parameter: string
  formulaTex: string
  sizeRankTex: string
  supremum: { num: number; den: number }
  supremumKind: 'attained' | 'approached' | 'iterated limit'
  contributors: string
  discoveryDate: string
  aiDisclosure: string
  summary: string
  construction: string
  curveExplanation: string
  proofStatus: string
  mathAnchor: string
  series: FamilySeries[]
}

const gcd = (a: number, b: number): number => (b ? gcd(b, a % b) : a)
const pt = (parameter: string, n: number, rank: number, num: number, den: number): FamilyPoint => {
  const g = gcd(num, den)
  return { parameter, n, rank, num: num / g, den: den / g }
}

const spikePoints = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29].map((p) =>
  pt(`p = ${p}`, 4 * p + 2, 5, 8, 7),
)
const uniformPoints: FamilyPoint[] = []
for (let r = 2; r <= 30; r++) {
  uniformPoints.push(pt(`r = ${r}`, 4 * r + 2, 2 * r + 1, 4 * r * r, 3 * r * r + 2 * r + 1))
}
const steinerTriples: FamilyPoint[] = []
for (let n = 7; n <= 74; n++) {
  if (n % 6 === 1 || n % 6 === 3) steinerTriples.push(pt(`n = ${n}`, 2 * n + 2, 7, 6 * (n - 2), 5 * n - 8))
}
const steinerQuadruples: FamilyPoint[] = []
for (let n = 8; n <= 74; n++) {
  if (n % 6 === 2 || n % 6 === 4) steinerQuadruples.push(pt(`n = ${n}`, 2 * n + 2, 9, 16 * (n - 3), 13 * n - 34))
}
const geo = (kind: string, rows: [number, number, number, number][]): FamilyPoint[] =>
  rows.map(([n, rank, a, b], i) => pt(`rank(${kind}) = ${[3, 4, 5, 6, 8][i] ?? i + 3}`, n, rank, a, b))
const affineSeries: FamilySeries[] = [
  { id: 'q2', label: 'q = 2', points: geo('A', [[10, 7, 6, 7], [18, 9, 8, 7], [34, 11, 80, 67], [66, 13, 6, 5], [258, 17, 1168, 977]]) },
  { id: 'q3', label: 'q = 3', points: geo('A', [[20, 7, 42, 37], [56, 9, 6, 5], [164, 11, 265, 218]]) },
  { id: 'q5', label: 'q = 5', points: geo('A', [[52, 7, 150, 127], [252, 9, 1168, 959]]) },
  { id: 'q7', label: 'q = 7', points: geo('A', [[100, 7, 306, 257], [688, 9, 104, 85]]) },
]
const projectiveSeries: FamilySeries[] = [
  { id: 'q2', label: 'q = 2', points: geo('PG', [[16, 7, 10, 9], [32, 9, 128, 109], [64, 11, 70, 59], [128, 13, 297, 250], [512, 17, 7456, 6275]]) },
  { id: 'q3', label: 'q = 3', points: geo('PG', [[28, 7, 36, 31], [82, 9, 256, 213], [244, 11, 1640, 1351], [730, 13, 12528, 10261]]) },
  { id: 'q5', label: 'q = 5', points: geo('PG', [[64, 7, 32, 27], [314, 9, 2944, 2417], [1564, 11, 3200, 2593]]) },
  { id: 'q7', label: 'q = 7', points: geo('PG', [[116, 7, 180, 151], [802, 9, 7296, 5963]]) },
]

export const FAMILIES: Family[] = [
  {
    id: 'hsw-finite-field-spikes',
    name: 'Huh–Schröter–Wang finite-field spikes',
    short: 'HSW spikes',
    claim: 'exact',
    color: '#8c3d2f',
    parameter: String.raw`prime \(p\)`,
    formulaTex: String.raw`\overline{\alpha}(M_p^5) = \frac{8}{7}`,
    sizeRankTex: String.raw`|E(M_p^5)| = 4p + 2, \qquad \operatorname{rk}(M_p^5) = 5`,
    supremum: { num: 8, den: 7 },
    supremumKind: 'attained',
    contributors: 'June Huh, Benjamin Schröter, Botong Wang',
    discoveryDate: 'June 2018',
    aiDisclosure: 'No AI use is reported in the cited discovery record.',
    summary: String.raw`A rank-5 family over \(\operatorname{GF}(p)\) whose correlation
      constant is exactly \(\frac{8}{7}\) for every displayed prime \(p\).`,
    construction: String.raw`For each prime \(p\), Huh, Schröter, and Wang define the
      finite-field spike \(M_p^5\) over \(\operatorname{GF}(p)\): the tip \(e_1\), the vector
      \(e_2+\cdots+e_5\), and \(k\,e_1+e_m\) for \(m=2,\ldots,5\) and \(k\in\operatorname{GF}(p)\).
      It has rank 5 and \(4p+2\) elements, so the curve consists of genuine finite matroids at
      the admissible prime parameters. The same construction works verbatim over any finite
      field; this site also verified the member at \(q=4\).`,
    curveExplanation: String.raw`The full maximum over eligible element pairs is
      \(\frac{8}{7}\) for every member, so this is a horizontal solid curve: the value is
      attained on the nose by each finite member, not merely in a limit.`,
    proofStatus: String.raw`The exact family value is proved in the cited paper. This site
      independently reconstructed every basis and recomputed the full maximum for the members
      over GF(2), GF(3), GF(4), GF(5), and GF(7).`,
    mathAnchor: 'discovery',
    series: [{ id: 'p', label: 'Mₚ⁵', points: spikePoints }],
  },
  {
    id: 'uniform-self-sum-extensions',
    name: 'Uniform self-sum extensions',
    short: 'Uniform extensions',
    claim: 'lower',
    color: '#176b72',
    parameter: String.raw`integer \(r\ge 2\)`,
    formulaTex: String.raw`R_{ef}(P_r) = \frac{4r^2}{3r^2+2r+1}`,
    sizeRankTex: String.raw`|E(P_r)| = 4r+2, \qquad \operatorname{rk}(P_r) = 2r+1`,
    supremum: { num: 4, den: 3 },
    supremumKind: 'approached',
    contributors: 'Alexander Divoux, Shouda Wang',
    discoveryDate: 'August 2026',
    aiDisclosure: String.raw`Alexander Divoux and Shouda Wang used ChatGPT 5.6 Sol Ultra to
      assist the discovery of the original transversal-matroid family. Its reinterpretation as
      a double free-extension is due to humans. No public chat link is currently recorded.`,
    summary: String.raw`A finite matroid for every integer \(r\ge2\), with a certified
      distinguished-pair value tending to \(\frac{4}{3}\) from below.`,
    construction: String.raw`Start with two copies of \(U_{r,2r}\), take their direct sum,
      freely extend by \(e\), and then freely coextend by \(f\). The resulting matroid
      \(P_r\) has \(4r+2\) elements and rank \(2r+1\).`,
    curveExplanation: String.raw`Exact basis counts for the distinguished pair \((e,f)\) give
      \(\frac{4r^2}{3r^2+2r+1}\), so every plotted point is a certified lower bound, and the
      bounds approach \(\frac{4}{3}\) as \(r\to\infty\); no finite \(r\) attains it.
      Computational remark (this site): exact enumeration confirms \((e,f)\) is the unique
      maximizing pair for \(2\le r\le 5\), so the curve is exact on those members — \(P_5\) is
      the record for 22 elements.`,
    proofStatus: String.raw`The adjacent-rank identity proves the displayed pair value and its
      limit; maximization over all pairs remains open for general \(r\).`,
    mathAnchor: 'uniform-family',
    series: [{ id: 'r', label: 'Pᵣ', points: uniformPoints }],
  },
  {
    id: 'affine-self-sum-extensions',
    name: 'Affine-geometry self-sum extensions',
    short: 'Affine extensions',
    claim: 'lower',
    color: '#6d4c93',
    parameter: String.raw`integer \(d\ge2\) and prime power \(q\)`,
    formulaTex: String.raw`\lim_{d\to\infty} R_{ef}(P_{d,q}) = \frac{4q^2}{3q^2+1}`,
    sizeRankTex: String.raw`|E(P_{d,q})| = 2q^{d-1}+2, \qquad \operatorname{rk}(P_{d,q}) = 2d+1`,
    supremum: { num: 4, den: 3 },
    supremumKind: 'iterated limit',
    contributors: 'Chris Eur',
    discoveryDate: 'August 2026',
    aiDisclosure: String.raw`Chris Eur used ChatGPT 5.6 Sol Max on Codex as a mathematical
      exploration and formula-checking aid while identifying the family through the double-free
      construction and the common 2-design mechanism. A public chat link is not currently
      recorded.`,
    summary: String.raw`Affine-geometry self-sums give characteristic-indexed lower-bound
      curves whose iterated limit is \(\frac{4}{3}\).`,
    construction: String.raw`Let \(A=\operatorname{AG}(d-1,q)\), of rank \(d\) on \(q^{d-1}\)
      points, and form \(P_{d,q}=(A\oplus A)+e\times f\). The free extension and coextension
      may require passing to a finite extension field, but the result stays representable in
      characteristic \(p\) when \(q=p^a\).`,
    curveExplanation: String.raw`Möbius inversion on the affine-flat lattice gives every
      plotted value exactly. For fixed \(q\) they tend to \(4q^2/(3q^2+1)\) as \(d\to\infty\);
      for fixed \(d\) they tend to \(4d/(3d+1)\) as \(q\to\infty\). Either subsequent limit
      approaches \(\frac43\). The curves are dashed because they certify distinguished-pair
      lower bounds rather than the full maximum.`,
    proofStatus: String.raw`Exact finite counts and both limits are proved on the mathematics
      page; maximization over every pair remains open.`,
    mathAnchor: 'geometries',
    series: affineSeries,
  },
  {
    id: 'projective-self-sum-extensions',
    name: 'Projective-geometry self-sum extensions',
    short: 'Projective extensions',
    claim: 'lower',
    color: '#b5652a',
    parameter: String.raw`integer \(d\ge2\) and prime power \(q\)`,
    formulaTex: String.raw`\lim_{d\to\infty} R_{ef}(P_{d,q}) = \frac{4q^2}{3q^2+1}`,
    sizeRankTex: String.raw`|E(P_{d,q})| = 2\tfrac{q^d-1}{q-1}+2, \qquad \operatorname{rk}(P_{d,q}) = 2d+1`,
    supremum: { num: 4, den: 3 },
    supremumKind: 'iterated limit',
    contributors: 'Chris Eur',
    discoveryDate: 'August 2026',
    aiDisclosure: String.raw`Chris Eur used ChatGPT 5.6 Sol Max on Codex as a mathematical
      exploration and formula-checking aid while identifying the family through the double-free
      construction and the common 2-design mechanism. A public chat link is not currently
      recorded.`,
    summary: String.raw`Projective-geometry self-sums give characteristic-indexed lower-bound
      curves with the same two limiting regimes as the affine geometries.`,
    construction: String.raw`Let \(G=\operatorname{PG}(d-1,q)\), of rank \(d\) on
      \((q^d-1)/(q-1)\) points, and form \(P_{d,q}=(G\oplus G)+e\times f\). A field extension
      may be necessary to carry out the free extension and coextension.`,
    curveExplanation: String.raw`Möbius inversion on the projective-flat lattice gives every
      plotted value exactly; for fixed \(q\) the values tend to \(4q^2/(3q^2+1)\), for fixed
      \(d\) to \(4d/(3d+1)\), and a subsequent limit approaches \(\frac43\).`,
    proofStatus: String.raw`The displayed pair is certified exactly; full maximization remains
      open.`,
    mathAnchor: 'geometries',
    series: projectiveSeries,
  },
  {
    id: 'steiner-system-self-sum-extensions',
    name: 'Steiner-system sparse-paving extensions',
    short: 'Steiner extensions',
    claim: 'lower',
    color: '#34745b',
    parameter: String.raw`Steiner systems \(S(r-1,r,n)\)`,
    formulaTex: String.raw`R_{ef}(P_{r,n}) = \frac{4r(n-r+1)}{(3r+1)(n-r)+4r+2}`,
    sizeRankTex: String.raw`|E(P_{r,n})| = 2n+2, \qquad \operatorname{rk}(P_{r,n}) = 2r+1`,
    supremum: { num: 4, den: 3 },
    supremumKind: 'iterated limit',
    contributors: 'Chris Eur',
    discoveryDate: 'August 2026',
    aiDisclosure: String.raw`Chris Eur used ChatGPT 5.6 Sol Max on Codex as a mathematical
      exploration and formula-checking aid while identifying the family, beginning with Steiner
      triples. A public chat link is not currently recorded.`,
    summary: String.raw`Sparse-paving matroids from Steiner systems give nonuniform 2-design
      bases and distinguished-pair values approaching \(\frac43\).`,
    construction: String.raw`Take the blocks of a Steiner system \(S(r-1,r,n)\) as the
      circuit-hyperplanes of a rank-\(r\) sparse-paving matroid \(M_{r,n}\), then form
      \(P_{r,n}=(M_{r,n}\oplus M_{r,n})+e\times f\). The plotted series use Steiner triple and
      quadruple systems, whose admissible orders are explicit.`,
    curveExplanation: String.raw`For fixed \(r\), the formula tends to \(4r/(3r+1)\) as
      \(n\to\infty\); those limits tend to \(\frac43\) as \(r\to\infty\). Keevash's
      design-existence theorem supplies the general fixed-rank families at all sufficiently
      large admissible orders.`,
    proofStatus: String.raw`The adjacent-rank counts prove the displayed pair value exactly;
      full maximization remains open.`,
    mathAnchor: 'steiner',
    series: [
      { id: 's23', label: 'S(2,3,n)', points: steinerTriples },
      { id: 's34', label: 'S(3,4,n)', points: steinerQuadruples },
    ],
  },
]

const MATHJAX_HEAD = `
    <script>
      window.MathJax = { tex: { processEscapes: true }, chtml: { scale: 0.98 } };
    </script>
    <script defer src="https://cdn.jsdelivr.net/npm/mathjax@4/tex-chtml.js"></script>`

const fmt = (num: number, den: number): string => (den === 1 ? String(num) : `${num}/${den}`)

const claimBadge = (f: Family): string =>
  f.claim === 'exact'
    ? '<span class="claim-badge exact">proved exact · solid curve</span>'
    : '<span class="claim-badge lower">certified lower bound · dashed curve</span>'

const supremumLine = (f: Family): string => {
  const kind =
    f.supremumKind === 'attained'
      ? 'attained by every member'
      : f.supremumKind === 'approached'
        ? 'approached, never attained'
        : 'an iterated limit'
  return `supremum ${fmt(f.supremum.num, f.supremum.den)} &mdash; ${kind}`
}

export function familiesPage(user: User | null = null): string {
  const cards = FAMILIES.map(
    (f) => `
    <a class="family-card" href="/family/${f.id}" style="--family-color: ${f.color}">
      <p class="eyebrow">${claimBadge(f)}</p>
      <h3>${escapeHtml(f.name)}</h3>
      <p class="family-formula">\\(${f.formulaTex}\\)</p>
      <p class="family-summary">${f.summary}</p>
      <p class="family-meta">${supremumLine(f)}</p>
      <p class="family-meta muted">${escapeHtml(f.contributors)} &middot; ${escapeHtml(f.discoveryDate)}</p>
    </a>`,
  ).join('\n')
  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/">&larr; home</a></p>
      <p class="eyebrow">Parameterized constructions</p>
      <h2>Families</h2>
      <p>
        The curves on the <a href="/">Explore</a> chart, as objects: each family is a
        parameterized construction with a proved formula. A <em>solid</em> curve is a proved
        value of the full invariant; a <em>dashed</em> curve certifies a distinguished-pair
        lower bound. Full proofs live on the <a href="/mathematics">mathematics page</a>.
        New families need human proof review and are contributed by pull request, not by the
        submission form.
      </p>
      <div class="family-grid">${cards}</div>
    </section>`
  return layout('Families — Matroid Correlation Constants', body, user, MATHJAX_HEAD)
}

export function familyPage(id: string, user: User | null = null): string | null {
  const f = FAMILIES.find((x) => x.id === id)
  if (!f) return null
  const seriesTables = f.series
    .map((s) => {
      const rows = s.points
        .map(
          (p) => `<tr>
            <td>${escapeHtml(p.parameter)}</td>
            <td class="num">${p.n}</td>
            <td class="num">${p.rank}</td>
            <td class="num">${fmt(p.num, p.den)}</td>
            <td class="num">${(p.num / p.den).toFixed(5)}</td>
          </tr>`,
        )
        .join('\n')
      return `
      <h4>${escapeHtml(s.label)} <span class="muted">(${s.points.length} plotted members)</span></h4>
      <div class="family-table-scroll">
        <table class="tokens-table family-table">
          <thead><tr><th>parameter</th><th class="num">|E|</th><th class="num">rank</th>
            <th class="num">${f.claim === 'exact' ? 'α' : 'R<sub>ef</sub>'}</th><th class="num">&approx;</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>`
    })
    .join('\n')
  const body = `
    <section class="prose family-page" style="--family-color: ${f.color}">
      <p class="page-nav"><a href="/families">&larr; all families</a></p>
      <p class="eyebrow">${claimBadge(f)}</p>
      <h2>${escapeHtml(f.name)}</h2>
      <p>${f.summary}</p>
      <div class="math-panel emphasized">
      \\[ ${f.formulaTex} \\]
      \\[ ${f.sizeRankTex} \\]
      </div>
      <dl class="detail-meta">
        <dt>parameter</dt><dd>${f.parameter}</dd>
        <dt>supremum</dt><dd>${supremumLine(f)}</dd>
        <dt>discovered by</dt><dd>${escapeHtml(f.contributors)}</dd>
        <dt>discovery date</dt><dd>${escapeHtml(f.discoveryDate)}</dd>
      </dl>
      <h3>Construction</h3>
      <p>${f.construction}</p>
      <h3>What the curve shows</h3>
      <p>${f.curveExplanation}</p>
      <h3>Proof status</h3>
      <p>${f.proofStatus}
        <a href="/mathematics#${f.mathAnchor}">Full proof on the mathematics page &rarr;</a></p>
      <h3>AI disclosure</h3>
      <p>${f.aiDisclosure}</p>
      <h3>Plotted members</h3>
      ${seriesTables}
    </section>`
  return layout(`${f.name} — Matroid Correlation Constants`, body, user, MATHJAX_HEAD)
}
