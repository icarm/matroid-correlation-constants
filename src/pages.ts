// Server-rendered HTML pages, plain template literals.

import {
  MAX_ELEMENTS,
  MAX_DP_ELEMENTS,
  MAX_EXT_FIELD_ORDER,
  MAX_LISTED_SETS,
  MAX_MATRIX_CELLS,
  type VerifyResult,
} from './verify'
import type {
  ActivityItem,
  MatroidListRow,
  MatroidView,
  RecordStatus,
} from './store'
import { familiesChartData, type Family } from './familyData'
import { familyToFormState } from './familyStore'

export interface User {
  id: number
  provider: string
  email?: string | null
  display_name?: string | null
  avatar_url?: string | null
}

export interface UserMatroidRow {
  id: number
  n: number
  rank: number
  alpha_num: number
  alpha_den: number
  alpha_value: number
  created_at: string
  titles: string | null // current titles ('club' and/or field orders), CSV
}

/** The store's GROUP_CONCAT of current titles ('club,5') as display names
 * ('GF(5) record', '4/3 club'), field records first. */
function titleNames(titles: string | null): string[] {
  if (!titles) return []
  const parts = titles.split(',')
  const names = parts
    .filter((p) => p !== 'club')
    .map(Number)
    .sort((a, b) => a - b)
    .map((f) => `GF(${f}) record`)
  if (parts.includes('club')) names.push('4/3 club')
  return names
}

export function escapeHtml(s: unknown): string {
  if (s == null) return ''
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

const SITE_NAME = 'Matroid Correlation Constants'
const SITE_DESCRIPTION =
  'Pick a random basis of a matroid: can one element make another more likely? ' +
  'The record book for the matroid correlation constant α(M). ' +
  'Find a concrete matroid with α ≥ 4/3.'

/** α(M) as a reduced fraction, '100/81' or '2'. */
export const fmtAlpha = (num: number, den: number): string =>
  den === 1 ? String(num) : `${num}/${den}`

/** Fraction plus a decimal approximation when they differ. */
const fmtAlphaLong = (num: number, den: number): string =>
  den === 1 ? String(num) : `${num}/${den} &approx; ${(num / den).toFixed(4)}`

/** Does the fraction reach the 4/3 challenge? */
const beatsGoal = (num: number, den: number): boolean => 3 * num >= 4 * den

const alphaVar = '<var>&alpha;</var>'
// The landing page uses the unweighted invariant's full notation without
// loading MathJax: the precomposed U+1FB1 (alpha with macron) supplies the
// overline in ordinary HTML, SVG, and plain-text chart tooltips. A single
// glyph carries its own bar; the combining U+0305 slides off italic alphas
// in fonts without mark anchors.
const alphaBarText = 'ᾱ'
const alphaBarVar = `<var>${alphaBarText}</var>`

function authNav(user: User | null): string {
  if (user) {
    const name = escapeHtml(user.display_name || user.email || 'user')
    return (
      `<a href="/profile" class="auth-user">${name}</a>` +
      `<form class="auth-logout" method="post" action="/auth/logout"><button type="submit">log out</button></form>`
    )
  }
  return `<a class="auth-login" href="/auth/github">log in with GitHub</a>`
}

export function layout(
  title: string,
  bodyInner: string,
  user: User | null = null,
  headExtra = '',
  // Wide pages share the header's full-width container (the landing page);
  // everything else keeps the narrow reading column.
  wide = false,
): string {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapeHtml(title)}</title>
    <meta name="description" content="${escapeHtml(SITE_DESCRIPTION)}" />
    <meta property="og:site_name" content="${escapeHtml(SITE_NAME)}" />
    <meta property="og:type" content="website" />
    <meta property="og:title" content="${escapeHtml(title)}" />
    <meta property="og:description" content="${escapeHtml(SITE_DESCRIPTION)}" />
    <meta property="og:image" content="https://matroid-correlation-constants.icarm.cloud/og.png" />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta name="twitter:card" content="summary_large_image" />
    <link rel="stylesheet" href="/style.css" />
    <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
    ${headExtra}
  </head>
  <body>
    <header>
      <div class="header-inner">
        <a class="brand" href="/" aria-label="${escapeHtml(SITE_NAME)} home">
          <svg class="brand-mark" viewBox="0 0 64 64" aria-hidden="true">
            <circle cx="32" cy="32" r="23" fill="none" stroke="currentColor" stroke-width="2.5"/>
            <path d="M16 32h32M32 16v32M20 20l24 24M44 20 20 44" fill="none" stroke="currentColor" stroke-width="1.6"/>
            <g fill="var(--bg-bright)" stroke="var(--accent)" stroke-width="2.5">
              <circle cx="32" cy="16" r="4.5"/><circle cx="48" cy="32" r="4.5"/>
              <circle cx="32" cy="48" r="4.5"/><circle cx="16" cy="32" r="4.5"/>
              <circle cx="32" cy="32" r="4.5"/>
            </g>
          </svg>
          <h1>Matroid Correlation<br/>Constants</h1>
        </a>
        <nav class="primary-nav" aria-label="Primary navigation">
          <a href="/">Explore</a>
          <a href="/families">Families</a>
          <a href="/matroids">Matroids</a>
          <a href="/mathematics">Mathematics</a>
        </nav>
        <a class="button-dark" href="/#submit">Submit a matroid</a>
        <span class="auth-nav">${authNav(user)}</span>
      </div>
    </header>
    <main${wide ? ' class="wide"' : ''}>${bodyInner}</main>
    <footer>
      <div class="inner">
        <nav class="footer-links">
          <a href="/recent">recent activity</a> &nbsp;&middot;&nbsp;
          <a href="/database.json" download>download the records (JSON)</a> &nbsp;&middot;&nbsp;
          <a class="external" href="https://icarm.zulipchat.com/#narrow/channel/519875-general/topic/Matroid.20Correlation.20Constants/near/615280760">discuss on Zulip</a> &nbsp;&middot;&nbsp;
          <a class="external" href="https://github.com/icarm/matroid-correlation-constants">source</a> &nbsp;&middot;&nbsp;
          <a class="external" href="https://icarm.io">icarm.io</a>
        </nav>
        <p class="acknowledgment">This website was created by Chris Eur using ChatGPT-5.6 Sol Max, and is maintained by the
        NSF Institute for Computer-Aided Reasoning in Mathematics <span class="nowrap">(<a class="external" href="https://icarm.io">ICARM</a>)</span>.
        Please <a href="/acknowledge">acknowledge</a> ICARM and NSF Grant DMS 2425401 in related
        publications, projects, or other scholarly work.</p>
      </div>
    </footer>
  </body>
</html>`
}

// The basis-set classes, in the mathematics page's notation: subscripts are
// contained elements, superscripts avoided ones — B_ij (bases containing i
// and j), B^ij (avoiding both), B^i_j (avoiding i, containing j).
const bset = (sup: string, sub: string): string =>
  `<var>B</var>${sup ? `<sup><var>${sup}</var></sup>` : ''}${sub ? `<sub><var>${sub}</var></sub>` : ''}(<var>M</var>)`
const bcount = (sup: string, sub: string): string => `|${bset(sup, sub)}|`

// The hero: the pitch on the left, the standing record on the right — the
// text-beside-card geometry every landing section repeats at full width.
function heroSection(records: RecordPoint[], families: Family[]): string {
  // Derived from the live catalog, not asserted: how close the accepted
  // families come to 4/3. If a family attaining it is ever accepted, the
  // card points at the remaining step instead of going stale.
  const reaching = families.filter((f) => 3 * f.supremum.num >= 4 * f.supremum.den)
  const attainer = reaching.find((f) => f.supremumKind === 'attained')
  const familiesLine = attainer
    ? `attained by members of <a href="/family/${escapeHtml(attainer.slug)}">${escapeHtml(
        attainer.short,
      )}</a> &mdash; verify one concretely to claim it`
    : reaching.length > 0
      ? 'reached by <a href="/families">known families</a> only in the limit'
      : 'beyond every <a href="/families">known family</a>, even in the limit'

  // The 4/3 club's live status. Note "reaches", not "comes closest":
  // family members over large fields get arbitrarily close to 4/3, so
  // distance-to-goal is not a meaningful frontier — attainment is.
  const club = records.filter((r) => r.club).sort((a, b) => b.alpha_value - a.alpha_value)
  const clubLine =
    club.length > 0
      ? `Reached by ${club.length === 1 ? 'one concrete matroid' : `${club.length} concrete matroids`}:
         <a href="/matroid/${club[0].id}">${alphaBarVar} = ${fmtAlpha(club[0].alpha_num, club[0].alpha_den)}</a>${
           club[0].name ? ` &mdash; ${escapeHtml(club[0].name)}` : ''
         }${club.length > 1 ? ' leads the 4/3 club' : ''}`
      : 'No concrete matroid has reached it.'
  const card = `<div class="record-card">
        <p class="eyebrow">The record to beat</p>
        <p class="record-card-value">4/3</p>
        <p class="record-card-approx">&approx; 1.3333 &mdash; ${familiesLine}</p>
        <p class="record-card-meta">${clubLine}</p>
      </div>`
  return `
  <section class="hero">
    <div class="hero-copy">
      <h2 class="hero-title">How correlated can the bases of a&nbsp;matroid&nbsp;be?</h2>
      <p class="lede">Pick a basis uniformly at random. Elements usually repel &mdash; seeing one
      in the basis makes another <em>less</em> likely. But in some matroids a pair of elements
      attracts, and nobody knows how strong the attraction can get. The challenge:
      <strong>find matroids with large correlation constants.</strong></p>
    </div>
    ${card}
  </section>`
}

// A minimal definition beside the submission form; the mathematics page
// carries the full background, discovery record, and proofs. Prose on the
// left, the defining equation as a card on the right (the hero's geometry).
function definitionSection(): string {
  return `
  <section class="prose glance" id="definition">
    <div class="glance-copy">
      <h2>The correlation constant, at a glance</h2>
      <p>
        For a matroid <var>M</var> on <span class="math">{0, &hellip;, n&minus;1}</span> and
        distinct elements <var>i</var>, <var>j</var>, write ${bset('', 'ij')} for the set of
        bases containing both <var>i</var> and <var>j</var>, ${bset('ij', '')} for the set
        avoiding both, and ${bset('i', 'j')} for the set avoiding <var>i</var> and containing
        <var>j</var>.
      </p>
      <p>
        The correlation constant is the largest ratio <var>R</var><sub><var>ij</var></sub>,
        over pairs of nonloop, noncoloop elements; ${alphaBarVar}(<var>M</var>) &gt; 1
        means some pair is positively correlated in a uniformly random basis.
        <a href="/mathematics">Why this is interesting, what is known, and full proofs &rarr;</a>
      </p>
    </div>
    <p class="display-eq">
      <span class="eq-part"><var>R</var><sub><var>ij</var></sub>(<var>M</var>) =
        <span class="frac"><span class="num">${bcount('ij', '')} &middot; ${bcount('', 'ij')}</span><span class="den">${bcount('i', 'j')} &middot; ${bcount('j', 'i')}</span></span></span>
      <span class="eq-part">${alphaBarVar}(<var>M</var>) = max<sub><var>i</var> &ne; <var>j</var></sub> <var>R</var><sub><var>ij</var></sub>(<var>M</var>)</span>
    </p>
  </section>`
}

export interface FormState {
  nValue?: string
  typeValue?: string
  fieldValue?: string
  dataValue?: string
  nameValue?: string
  discoverersValue?: string
  discoveryDateValue?: string
  aiUsedValue?: string
  aiModelValue?: string
  aiRoleValue?: string
  aiChatUrlValue?: string
  citationValue?: string
  provenanceValue?: string
  claimedAlphaValue?: string
}

/** A record-book entry as a plot point: the row id, ground-set size, its
 * constant, and the titles it holds — the field records (2/3/4/5/7) and/or
 * 4/3-club membership. Only current title-holders are plotted. */
export interface RecordPoint {
  id: number
  name: string | null
  n: number
  rank: number
  num_bases: number
  alpha_num: number
  alpha_den: number
  alpha_value: number
  field: string | null
  cert_field: string | null
  recordFields: number[]
  club: boolean
}

/** A record point's titles as display names, field records first. */
const pointTitles = (p: RecordPoint): string[] => [
  ...p.recordFields.map((f) => `GF(${f}) record`),
  ...(p.club ? ['4/3 club'] : []),
]

// Server-rendered SVG scatter of the record constants against the ground-set
// size n, in a fixed 720x440 frame. No JS; tooltips via <title>.
const PLOT = { W: 720, H: 440, L: 56, R: 18, T: 18, B: 46 }
const INNER_W = PLOT.W - PLOT.L - PLOT.R
const INNER_H = PLOT.H - PLOT.T - PLOT.B
const NMIN = 1
const plotX = (n: number) => PLOT.L + ((n - NMIN) / (MAX_ELEMENTS - NMIN)) * INNER_W

// The frame starts at α = 1: negatively correlated records are not
// interesting enough for wall space, and the action lives between 1 and 4/3.
const PLOT_YMIN = 1

function recordsPlot(pts: RecordPoint[]): string {
  let ymax = 1.45
  for (const p of pts) ymax = Math.max(ymax, p.alpha_value + 0.1)
  const Y = (v: number) => PLOT.T + INNER_H - ((v - PLOT_YMIN) / (ymax - PLOT_YMIN)) * INNER_H

  let grid = ''
  for (let n = 2; n <= MAX_ELEMENTS; n += 2) {
    const x = plotX(n).toFixed(1)
    grid += `<line class="grid" x1="${x}" y1="${PLOT.T}" x2="${x}" y2="${PLOT.T + INNER_H}"/>`
    grid += `<text class="tick" x="${x}" y="${PLOT.T + INNER_H + 18}" text-anchor="middle">${n}</text>`
  }
  for (let t = 10; t / 10 <= ymax + 1e-9; t++) {
    const v = t / 10
    const y = Y(v).toFixed(1)
    if (v > PLOT_YMIN) grid += `<line class="grid" x1="${PLOT.L}" y1="${y}" x2="${PLOT.W - PLOT.R}" y2="${y}"/>`
    grid += `<text class="tick" x="${PLOT.L - 8}" y="${(Y(v) + 4).toFixed(1)}" text-anchor="end">${v.toFixed(1)}</text>`
  }

  const hline = (v: number, cls: string, label: string, dy: number): string =>
    `<line class="${cls}" x1="${PLOT.L}" y1="${Y(v).toFixed(1)}" x2="${PLOT.W - PLOT.R}" y2="${Y(v).toFixed(1)}"/>
      <text class="guide-label" x="${PLOT.W - PLOT.R - 8}" y="${(Y(v) + dy).toFixed(1)}" text-anchor="end">${label}</text>`
  const guides =
    hline(8 / 7, 'guide guide-known', '8/7', -5) +
    hline(4 / 3, 'guide guide-goal', 'the 4/3 challenge', -6)

  const dots = pts
    .filter((p) => p.alpha_value >= PLOT_YMIN)
    .map((p) => {
      const beats = beatsGoal(p.alpha_num, p.alpha_den)
      const title = `${pointTitles(p).join(', ')}: ${alphaBarText} = ${fmtAlpha(
        p.alpha_num,
        p.alpha_den,
      )} ≈ ${p.alpha_value.toFixed(4)} (n = ${p.n}, rank ${p.rank}, ${p.num_bases.toLocaleString('en-US')} bases)`
      return `<a href="/matroid/${p.id}"><circle class="dot${beats ? ' beats-goal' : ''}" cx="${plotX(p.n).toFixed(
        1,
      )}" cy="${Y(p.alpha_value).toFixed(1)}" r="${beats ? 4.5 : 3.5}"><title>${escapeHtml(title)}</title></circle></a>`
    })
    .join('\n      ')

  return `<svg class="records-plot" viewBox="0 0 ${PLOT.W} ${PLOT.H}" role="img" aria-label="record correlation constant versus ground-set size, scatter plot">
      ${grid}
      ${guides}
      ${dots}
      <line class="axis" x1="${PLOT.L}" y1="${PLOT.T}" x2="${PLOT.L}" y2="${PLOT.T + INNER_H}"/>
      <line class="axis" x1="${PLOT.L}" y1="${PLOT.T + INNER_H}" x2="${PLOT.W - PLOT.R}" y2="${PLOT.T + INNER_H}"/>
      <text class="axis-title" x="${PLOT.L + INNER_W / 2}" y="${PLOT.H - 6}" text-anchor="middle">ground-set size n &#8594;</text>
      <text class="axis-title" transform="rotate(-90)" x="${-(PLOT.T + INNER_H / 2)}" y="15" text-anchor="middle">correlation constant ${alphaBarText} &#8594;</text>
    </svg>`
}

function recordsSection(records: RecordPoint[], families: Family[]): string {
  const fallbackInner =
    records.length === 0
      ? '<p class="muted">No verified records yet &mdash; submit a matroid to put the first dot on the board.</p>'
      : `<div class="plot-panel">${recordsPlot(records)}</div>
    <p class="muted plot-caption">Each dot is a standing record: the best verified ${alphaBarVar}
    over each of GF(2), GF(3), GF(4), GF(5), and GF(7) &mdash; plus any concrete matroid
    reaching 4/3, over any field or none.
    Huh&ndash;Schr&ouml;ter&ndash;Wang: ${alphaBarVar}(<var>M</var>) &le; 2 for every matroid.
    Matroids on at most 7 elements never exceed 1.</p>`
  // Data for the interactive explorer (progressive enhancement in /chart.js);
  // <-escaping keeps the JSON safe inside a script element.
  const chartData = JSON.stringify({
    families: familiesChartData(families),
    records: records.map((r) => ({
      id: r.id,
      n: r.n,
      rank: r.rank,
      bases: r.num_bases,
      label: fmtAlpha(r.alpha_num, r.alpha_den),
      value: r.alpha_value,
      field: r.field,
      certField: r.cert_field,
      titles: pointTitles(r),
    })),
  }).replace(/</g, '\\u003c')
  const check = (id: string, label: string, checked: boolean): string =>
    `<label class="check-row"><input id="${id}" type="checkbox"${checked ? ' checked' : ''} /> ${label}</label>`
  return `
  <section class="panel records">
    <div id="records-fallback">${fallbackInner}</div>
    <div id="records-explorer" hidden>
      <div class="explorer-shell">
        <aside class="filter-panel" aria-label="Chart filters">
          <div class="filter-heading"><h3>Filter</h3>
            <button class="link-button" id="reset-filters" type="button">reset</button></div>
          <label class="field-label" for="search-input">Search</label>
          <input id="search-input" type="search" placeholder="family, parameter, matroid&hellip;" />
          <label class="field-label" for="field-filter">Verified field</label>
          <select id="field-filter">
            <option value="all">All fields</option>
            <option value="2">GF(2)</option>
            <option value="3">GF(3)</option>
            <option value="4">GF(4)</option>
            <option value="5">GF(5)</option>
            <option value="7">GF(7)</option>
          </select>
          <label class="field-label" for="rank-filter">Rank</label>
          <select id="rank-filter"><option value="all">All ranks</option></select>
          <div class="range-label">
            <label class="field-label" for="max-n">Ground-set size</label>
            <output id="max-n-output" for="max-n">&le; 100</output>
          </div>
          <input id="max-n" type="range" min="20" max="1000" value="100" step="10" />
          <fieldset><legend>Show</legend>
            ${check('show-points', 'Record submissions', true)}
            ${check('show-exact', 'Exact family curves', true)}
            ${check('show-lower', 'Lower-bound curves', true)}
          </fieldset>
          <fieldset><legend>Scale</legend>
            ${check('show-below-one', 'Include values below 1', false)}
            ${check('full-y-scale', 'Use full 1&ndash;2 scale', false)}
          </fieldset>
        </aside>
        <div class="chart-panel">
          <div class="chart-toolbar">
            <div class="muted"><span id="visible-count"></span> &middot; <span id="visible-series-count"></span></div>
            <button class="link-button" id="toggle-x-axis" type="button" aria-pressed="false"
              title="Switch the horizontal axis between ground-set size and rank">x-axis: |E|</button>
          </div>
          <svg id="atlas-chart" class="atlas-chart" viewBox="0 0 980 520" role="img"></svg>
          <p id="empty-chart" class="muted" hidden>Nothing matches the current filters.</p>
          <div id="chart-legend" class="chart-legend"></div>
        </div>
      </div>
    </div>
    <div id="chart-tooltip" class="chart-tooltip" hidden></div>
    <script type="application/json" id="chart-data">${chartData}</script>
    <script src="/chart.js" defer></script>
  </section>`
}

// Per-description placeholders and hints for the data box — all four are the
// same matroid, U(2,4), so the examples double as a format tutorial. Swapped
// by a small inline script when the selection changes; without JS the
// matrix-flavored default stays, which is still accurate guidance.
const DATA_PLACEHOLDERS: Record<string, string> = {
  matrix: 'e.g. [[1,0,1,1],[0,1,1,2]] over GF(3) — rows of a matrix whose columns are the elements',
  bases: 'e.g. [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]] — every basis, as lists of element labels',
  circuits: 'e.g. [[0,1,2],[0,1,3],[0,2,3],[1,2,3]] — every circuit, as lists of element labels',
  hyperplanes: 'e.g. [[0],[1],[2],[3]] — every hyperplane, as lists of element labels',
}
const DATA_HINTS: Record<string, string> = {
  matrix: '(JSON: a list of rows; columns are the elements)',
  bases: '(JSON: the complete list of bases, as lists of element labels)',
  circuits: '(JSON: the complete list of circuits, as lists of element labels)',
  hyperplanes: '(JSON: the complete list of hyperplanes, as lists of element labels)',
}

interface VerifierFormOptions {
  openAttribution?: boolean
  homepage?: boolean
}

function verifierForm(
  state: FormState,
  user: User | null,
  { openAttribution = false, homepage = false }: VerifierFormOptions = {},
): string {
  const submit = user
    ? '<button type="submit">Verify</button>'
    : '<a class="login-to-submit" href="/auth/github">Log in to submit</a>'
  const displayedAlpha = homepage ? alphaBarVar : alphaVar
  const recordBookRule = `the record book itself takes a matroid that
      strictly beats a standing field record &mdash; the best ${displayedAlpha} over GF(2), GF(3),
      GF(4), GF(5), or GF(7), claimed with a matrix over that field &mdash; or that reaches
      ${displayedAlpha} &ge; 4/3 by any description.`
  const displayedRecordBookRule = homepage ? `<strong>${recordBookRule}</strong>` : recordBookRule
  const selectedType =
    state.typeValue && state.typeValue in DATA_PLACEHOLDERS ? state.typeValue : 'matrix'
  const typeOption = (value: string, label: string): string =>
    `<option value="${value}"${selectedType === value ? ' selected' : ''}>${label}</option>`
  return `
  <section class="panel" id="submit">
    <h2>Submit a matroid</h2>
    <form method="post" action="/verify">
      <div class="form-main">
      <div class="form-row">
        <label for="n">Elements <var>n</var> <span class="hint">({0,&nbsp;&hellip;,&nbsp;n&minus;1})</span>
        <input id="n" name="n" type="text" inputmode="numeric" required placeholder="e.g. 4"
               value="${escapeHtml(state.nValue ?? '')}" /></label>
        <label for="type">Description
        <select id="type" name="type">
          ${typeOption('matrix', 'matrix (columns are elements)')}
          ${typeOption('bases', 'all bases')}
          ${typeOption('circuits', 'all circuits')}
          ${typeOption('hyperplanes', 'all hyperplanes')}
        </select></label>
        <label for="field">Field <span class="hint">(matrix only)</span>
        <input id="field" name="field" type="text" placeholder="e.g. 3, 7, or Q"
               value="${escapeHtml(state.fieldValue ?? '')}" /></label>
      </div>
      <label for="data">Data <span class="hint" id="data-hint">${DATA_HINTS[selectedType]}</span></label>
      <textarea id="data" name="data" rows="8" required
                placeholder="${escapeHtml(DATA_PLACEHOLDERS[selectedType])}">${escapeHtml(state.dataValue ?? '')}</textarea>
      <div class="form-row">
        <label for="claimed_alpha">Claimed ${displayedAlpha} <span class="hint">(optional; exact fraction &mdash;
          a mismatch with the computed value fails the submission, catching paste mistakes)</span>
        <input id="claimed_alpha" name="claimed_alpha" type="text" maxlength="40"
               placeholder="e.g. 100/81" value="${escapeHtml(state.claimedAlphaValue ?? '')}" /></label>
      </div>
      </div>
      <details class="attribution"${
        openAttribution ||
        [
          state.nameValue,
          state.discoverersValue,
          state.discoveryDateValue,
          state.aiUsedValue,
          state.citationValue,
          state.provenanceValue,
        ].some((v) => v)
          ? ' open'
          : ''
      }>
        <summary>Attribution &amp; discovery <span class="hint">(required for a matroid to be
        recorded; you can verify without it)</span></summary>
        <div class="form-row">
          <label for="name">Name <span class="hint">(for display)</span>
          <input id="name" name="name" type="text" maxlength="200" placeholder="e.g. Ternary rank-6 benchmark"
                 value="${escapeHtml(state.nameValue ?? '')}" /></label>
          <label for="discoverers">Discovered by
          <input id="discoverers" name="discoverers" type="text" maxlength="500" placeholder="names, as they should be credited"
                 value="${escapeHtml(state.discoverersValue ?? '')}" /></label>
          <label for="discovery_date">Discovery date <span class="hint">(YYYY-MM or YYYY-MM-DD)</span>
          <input id="discovery_date" name="discovery_date" type="text" maxlength="10" placeholder="e.g. 2026-08"
                 value="${escapeHtml(state.discoveryDateValue ?? '')}" /></label>
        </div>
        <div class="form-row">
          <label for="ai_used">AI used in the discovery?
          <select id="ai_used" name="ai_used">
            <option value=""${(state.aiUsedValue ?? '') === '' ? ' selected' : ''}>&mdash;</option>
            <option value="no"${state.aiUsedValue === 'no' ? ' selected' : ''}>no</option>
            <option value="yes"${state.aiUsedValue === 'yes' ? ' selected' : ''}>yes</option>
          </select></label>
          <label for="ai_model">AI model &amp; version
          <input id="ai_model" name="ai_model" type="text" maxlength="200" placeholder="e.g. ChatGPT 5.6 Sol Ultra"
                 value="${escapeHtml(state.aiModelValue ?? '')}" /></label>
          <label for="ai_chat_url">Public chat/run link <span class="hint">(if one exists)</span>
          <input id="ai_chat_url" name="ai_chat_url" type="text" maxlength="500" placeholder="https://&hellip;"
                 value="${escapeHtml(state.aiChatUrlValue ?? '')}" /></label>
        </div>
        <label for="ai_role">AI role <span class="hint">(one or two sentences)</span></label>
        <textarea id="ai_role" name="ai_role" rows="2" maxlength="1000"
                  placeholder="what the AI did in the discovery">${escapeHtml(state.aiRoleValue ?? '')}</textarea>
        <div class="form-row">
          <label for="citation">Citation <span class="hint">(paper or preprint, if published)</span>
          <input id="citation" name="citation" type="text" maxlength="500" placeholder="e.g. arXiv:1806.02675"
                 value="${escapeHtml(state.citationValue ?? '')}" /></label>
        </div>
        <label for="provenance">Notes</label>
        <textarea id="provenance" name="provenance" rows="2"
                  placeholder="anything else worth recording about this matroid">${escapeHtml(state.provenanceValue ?? '')}</textarea>
      </details>
      ${submit}
      <p class="muted form-note">Verification is exact: the matroid axioms are checked, every basis is
      enumerated, and all ratios are compared by integer cross multiplication. Limits:
      n &le; ${MAX_ELEMENTS} (more than 24 elements only in low rank, where enumeration stays
      feasible; circuit and hyperplane descriptions up to ${MAX_DP_ELEMENTS}), at most
      ${MAX_LISTED_SETS.toLocaleString('en-US')} listed sets or
      ${MAX_MATRIX_CELLS.toLocaleString('en-US')} matrix entries; matrix fields are &#8474;, any
      prime GF(p) with p &lt; 10<sup>6</sup>, or a proper prime power GF(p<sup>d</sup>) up to
      order ${MAX_EXT_FIELD_ORDER}. Over &#8474;,
      entries may be integers or fraction strings like <code>"-3/5"</code>; over
      GF(p<sup>d</sup>), integers (subfield constants) or coefficient lists like
      <code>[0,1]</code> in the Conway polynomial basis, as in Sage or GAP.
      Anything within the limits can be verified; ${displayedRecordBookRule}
      Proposing an <em>infinite family</em> instead? That takes a proof and human review
      &mdash; see <a href="/families#propose">how family proposals work</a>.</p>
    </form>
    <script>
      // Progressive enhancement only: match the data box's placeholder and
      // hint to the selected description, and dim the field input when it
      // does not apply. Without JS the server-rendered text stands.
      (function () {
        var type = document.getElementById('type');
        var data = document.getElementById('data');
        var hint = document.getElementById('data-hint');
        var field = document.getElementById('field');
        var placeholders = ${JSON.stringify(DATA_PLACEHOLDERS)};
        var hints = ${JSON.stringify(DATA_HINTS)};
        function update() {
          data.placeholder = placeholders[type.value] || '';
          hint.textContent = hints[type.value] || '';
          field.disabled = type.value !== 'matrix';
        }
        type.addEventListener('change', update);
        update();
      })();
    </script>
  </section>`
}

/** Raw form echoes for the family proposal form, keyed by field name. */
export type FamilyFormState = Record<string, string>

const SERIES_PLACEHOLDER =
  '[{"parameter": "r = 2", "n": 10, "rank": 5, "alpha": "16/17"},\n' +
  ' {"parameter": "r = 3", "n": 14, "rank": 7, "alpha": "18/17"},\n' +
  ' {"parameter": "r = 4", "n": 18, "rank": 9, "alpha": "64/57"}]'

/** Where the family form posts and how it announces itself: the landing
 * page's propose flow by default, a pending proposal's admin edit when
 * overridden. */
interface FamilyFormOptions {
  id: string
  title: string // '' omits the heading (e.g. inside a <details> summary)
  intro: string
  action: string
  submitLabel: string
  note: string // '' omits the closing form-note
}

const PROPOSE_FORM_OPTIONS: FamilyFormOptions = {
  id: 'submit-family',
  title: 'Propose an infinite family',
  intro: `A family is a reviewed claim, not a computation: no enumeration can check a
    formula for every parameter. What you submit here waits as <em>pending</em> &mdash; visible
    only to you and the site admins &mdash; until an admin reviews the mathematics and accepts
    it. An accepted family gets its curve on the chart, a card, and a page. TeX is welcome in
    the formula and prose fields (<code>\\( &hellip; \\)</code> inline).`,
  action: '/families/propose',
  submitLabel: 'Propose this family',
  note: `Strengthen the proposal before it reaches review:
      <a href="/#submit">verify the family&rsquo;s small members</a> with the concrete form
      first &mdash; each becomes a machine-checked entry a reviewer can lean on. An automatic
      screen compares the claimed values against the Huh&ndash;Schr&ouml;ter&ndash;Wang bound
      and flags a supremum &ge; 4/3 for extra scrutiny; it verifies no mathematics.`,
}

const editFormOptions = (slug: string, live: boolean): FamilyFormOptions => ({
  id: 'edit-family',
  title: '',
  intro: live
    ? `This family is live: saving publishes the changes immediately, validated exactly as a
      proposal would be. The URL keeps its slug; the curve color and any mathematics-page
      proof link are kept. The AI declaration below becomes the authoritative disclosure,
      replacing any handwritten prose.`
    : `Every field is validated exactly as at proposal time and saved onto the pending
    proposal; the URL keeps its slug. Editing does not decide anything &mdash; accepting or
    rejecting still happens in the review panel.`,
  action: `/family/${escapeHtml(slug)}/edit`,
  submitLabel: 'Save changes',
  note: '',
})

/** The infinite-family proposal form. Unlike the concrete form nothing here
 * is machine-verified: a proposal lands as a pending row that a site admin
 * must review and accept before it appears anywhere public. */
function familyFormSection(
  state: FamilyFormState,
  user: User | null,
  opts: FamilyFormOptions = PROPOSE_FORM_OPTIONS,
): string {
  const v = (name: string): string => escapeHtml(state[name] ?? '')
  const sel = (name: string, value: string, dflt = false): string =>
    (state[name] ?? '') === value || (dflt && (state[name] ?? '') === '') ? ' selected' : ''
  const submit = user
    ? `<button type="submit">${opts.submitLabel}</button>`
    : '<a class="login-to-submit" href="/auth/github">Log in to propose</a>'
  return `
  <section class="panel" id="${opts.id}">
    ${opts.title ? `<h2>${opts.title}</h2>` : ''}
    <p class="muted">${opts.intro}</p>
    <form method="post" action="${opts.action}">
      <div class="form-main">
      <div class="form-row">
        <label for="fam-name">Family name
        <input id="fam-name" name="name" type="text" required maxlength="120"
               placeholder="e.g. Steiner-system sparse-paving extensions" value="${v('name')}" /></label>
        <label for="fam-short">Short name <span class="hint">(chart legend)</span>
        <input id="fam-short" name="short" type="text" required maxlength="40"
               placeholder="e.g. Steiner extensions" value="${v('short')}" /></label>
        <label for="fam-parameter">Parameter
        <input id="fam-parameter" name="parameter" type="text" required maxlength="200"
               placeholder="e.g. integer \\(r \\ge 2\\)" value="${v('parameter')}" /></label>
      </div>
      <div class="form-row">
        <label for="fam-claim">Claim type
        <select id="fam-claim" name="claim">
          <option value="lower"${sel('claim', 'lower', true)}>certified lower bound (dashed curve)</option>
          <option value="exact"${sel('claim', 'exact')}>proved exact value (solid curve)</option>
        </select></label>
        <label for="fam-supremum">Supremum <span class="hint">(exact fraction)</span>
        <input id="fam-supremum" name="supremum" type="text" required maxlength="40"
               placeholder="e.g. 4/3" value="${v('supremum')}" /></label>
        <label for="fam-supremum-kind">Supremum is
        <select id="fam-supremum-kind" name="supremum_kind">
          <option value="approached"${sel('supremum_kind', 'approached', true)}>approached, never attained</option>
          <option value="attained"${sel('supremum_kind', 'attained')}>attained by members</option>
          <option value="iterated limit"${sel('supremum_kind', 'iterated limit')}>an iterated limit</option>
        </select></label>
      </div>
      <div class="form-row">
        <label for="fam-formula">Formula <span class="hint">(TeX, without delimiters)</span>
        <input id="fam-formula" name="formula_tex" type="text" required maxlength="500"
               placeholder="e.g. R_{ef}(P_r) = \\frac{4r^2}{3r^2+2r+1}" value="${v('formula_tex')}" /></label>
        <label for="fam-size-rank">Size and rank <span class="hint">(TeX, without delimiters)</span>
        <input id="fam-size-rank" name="size_rank_tex" type="text" required maxlength="500"
               placeholder="e.g. |E(P_r)| = 4r+2, \\qquad \\operatorname{rk}(P_r) = 2r+1" value="${v('size_rank_tex')}" /></label>
      </div>
      <label for="fam-summary">Summary <span class="hint">(one or two sentences, for the card)</span></label>
      <textarea id="fam-summary" name="summary" rows="2" required maxlength="1000"
                placeholder="what the family is and what its curve certifies">${v('summary')}</textarea>
      <label for="fam-construction">Construction</label>
      <textarea id="fam-construction" name="construction" rows="4" required maxlength="4000"
                placeholder="how a member is built for each parameter value">${v('construction')}</textarea>
      <label for="fam-curve">What the curve shows</label>
      <textarea id="fam-curve" name="curve_explanation" rows="3" required maxlength="4000"
                placeholder="what is exact, what is a bound, and how the limit behaves">${v('curve_explanation')}</textarea>
      <div class="form-row">
        <label for="fam-proof-status">Proof status
        <input id="fam-proof-status" name="proof_status" type="text" required maxlength="2000"
               placeholder="what is proved, and what remains open" value="${v('proof_status')}" /></label>
        <label for="fam-proof-url">Proof / reference link <span class="hint">(arXiv, paper, or writeup)</span>
        <input id="fam-proof-url" name="proof_url" type="text" maxlength="500"
               placeholder="https://arxiv.org/abs/&hellip;" value="${v('proof_url')}" /></label>
      </div>
      <label for="fam-series">Plotted members <span class="hint">(JSON: one point per member you
        want on the chart. <code>"parameter"</code> names the member for the tooltip, like
        <code>"r = 3"</code>; <code>"n"</code> and <code>"rank"</code> place the dot;
        <code>"alpha"</code> is the exact value your formula gives it; add
        <code>"field": q</code> for members verified over GF(q). Plotting several curves,
        e.g. one per q? Group the points into <code>{"label", "points"}</code> objects, one
        per curve; at most 400 points)</span></label>
      <textarea id="fam-series" name="series" rows="7" required
                placeholder='${escapeHtml(SERIES_PLACEHOLDER)}'>${v('series')}</textarea>
      </div>
      <div class="form-side">
      <h3 class="form-subhead">Discovery record <span class="hint">(required &mdash; as for matroid record entries)</span></h3>
      <div class="form-row">
        <label for="fam-contributors">Discovered by
        <input id="fam-contributors" name="contributors" type="text" required maxlength="500"
               placeholder="names, as they should be credited" value="${v('contributors')}" /></label>
        <label for="fam-discovery-date">Discovery date <span class="hint">(YYYY-MM or YYYY-MM-DD)</span>
        <input id="fam-discovery-date" name="discovery_date" type="text" required maxlength="10"
               placeholder="e.g. 2026-08" value="${v('discovery_date')}" /></label>
      </div>
      <div class="form-row">
        <label for="fam-ai-used">AI used in the discovery?
        <select id="fam-ai-used" name="ai_used" required>
          <option value=""${sel('ai_used', '', true)}>&mdash;</option>
          <option value="no"${sel('ai_used', 'no')}>no</option>
          <option value="yes"${sel('ai_used', 'yes')}>yes</option>
        </select></label>
        <label for="fam-ai-model">AI model &amp; version
        <input id="fam-ai-model" name="ai_model" type="text" maxlength="200"
               placeholder="e.g. ChatGPT 5.6 Sol Ultra" value="${v('ai_model')}" /></label>
        <label for="fam-ai-chat">Public chat/run link <span class="hint">(if one exists)</span>
        <input id="fam-ai-chat" name="ai_chat_url" type="text" maxlength="500"
               placeholder="https://&hellip;" value="${v('ai_chat_url')}" /></label>
      </div>
      <label for="fam-ai-role">AI role <span class="hint">(one or two sentences)</span></label>
      <textarea id="fam-ai-role" name="ai_role" rows="2" maxlength="1000"
                placeholder="what the AI did in the discovery">${v('ai_role')}</textarea>
      </div>
      ${submit}
      ${opts.note ? `<p class="muted form-note">${opts.note}</p>` : ''}
    </form>
  </section>`
}

/** The admin edit form on a family's page — pending proposals and accepted
 * families alike: the full proposal form, prefilled from the stored row,
 * posting to the family's edit route. */
export function familyEditSection(f: Family, user: User | null): string {
  const live = f.status === 'accepted'
  return `
      <details class="review-edit">
        <summary>Edit this ${live ? 'family' : 'proposal'} <span class="hint">(admin)</span></summary>
        ${familyFormSection(familyToFormState(f), user, editFormOptions(f.slug, live))}
      </details>`
}

/** Post target for a failed admin edit: the error plus the edit form,
 * pre-filled with what was submitted. */
export function familyEditResultPage(
  user: User | null,
  error: string,
  form: FamilyFormState,
  slug: string,
  live: boolean,
): string {
  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/family/${escapeHtml(slug)}">&larr; back to the ${live ? 'family' : 'proposal'}</a></p>
    </section>
    <section class="result result-error">
      <h2>Error</h2>
      <p>${escapeHtml(error)}</p>
    </section>
    ${familyFormSection(form, user, editFormOptions(slug, live))}`
  return layout(`Edit — ${SITE_NAME}`, body, user)
}

/** The tab bar toggling the two submission forms. Progressive enhancement:
 * without JS the bar stays hidden and both forms render stacked. */
function submitTabs(): string {
  return `
  <div class="submit-tabs" id="submit-tabs" hidden>
    <button type="button" class="submit-tab active" data-target="submit">Concrete matroid</button>
    <button type="button" class="submit-tab" data-target="submit-family">Infinite family</button>
  </div>`
}

const SUBMIT_TABS_SCRIPT = `
    <script>
      // Progressive enhancement: collapse the two submission forms into
      // tabs. #submit-family in the URL (the /families propose links) opens
      // the family tab; without JS both forms simply render stacked.
      (function () {
        var bar = document.getElementById('submit-tabs');
        var tabs = bar ? bar.querySelectorAll('.submit-tab') : [];
        if (!bar || tabs.length === 0) return;
        function show(target) {
          for (var i = 0; i < tabs.length; i++) {
            var id = tabs[i].getAttribute('data-target');
            var panel = document.getElementById(id);
            if (panel) panel.hidden = id !== target;
            tabs[i].classList.toggle('active', id === target);
          }
        }
        for (var i = 0; i < tabs.length; i++) {
          tabs[i].addEventListener('click', function () {
            show(this.getAttribute('data-target'));
          });
        }
        function goTo(target) {
          show(target);
          var panel = document.getElementById(target);
          if (panel) panel.scrollIntoView();
        }
        function fromHash() {
          if (location.hash === '#submit-family') goTo('submit-family');
          else if (location.hash === '#submit') goTo('submit');
        }
        // Same-page links to either form ("Submit a matroid", the propose
        // CTAs) must work even when the other tab is selected and the hash
        // will not change (no hashchange event) — reveal the right panel
        // before the browser's default anchor scroll, which needs the
        // target visible.
        document.addEventListener('click', function (e) {
          var a = e.target && e.target.closest
            ? e.target.closest('a[href$="#submit"], a[href$="#submit-family"]')
            : null;
          if (!a || a.pathname !== location.pathname) return;
          show(a.hash === '#submit-family' ? 'submit-family' : 'submit');
        });
        bar.hidden = false;
        show('submit');
        if (location.hash === '#submit-family') goTo('submit-family');
        window.addEventListener('hashchange', fromHash);
      })();
    </script>`

/** Post target for a failed family proposal: the error plus the form,
 * pre-filled. (A successful proposal redirects to its pending page.) */
export function familyProposeResultPage(
  user: User | null,
  error: string,
  form: FamilyFormState,
): string {
  const body = `
    <section class="result result-error">
      <h2>Error</h2>
      <p>${escapeHtml(error)}</p>
    </section>
    ${familyFormSection(form, user)}`
  return layout(`Result — ${SITE_NAME}`, body, user)
}

/** English list: 'a', 'a and b', 'a, b, and c'. */
const andList = (items: string[]): string =>
  items.length <= 1
    ? (items[0] ?? '')
    : items.length === 2
      ? `${items[0]} and ${items[1]}`
      : `${items.slice(0, -1).join(', ')}, and ${items[items.length - 1]}`

function recordSection(record?: RecordStatus): string {
  if (!record) return ''
  if (record.noCandidateField) {
    return `<p class="muted">Verified, but outside the record book&rsquo;s scope: it keeps the
      best ${alphaVar} over each of GF(2), GF(3), GF(4), GF(5), and GF(7) &mdash; claimed with
      a matrix over that field &mdash; plus any matroid reaching ${alphaVar} &ge; 4/3 by any
      description.</p>`
  }
  // What the submission took (or would take), as prose.
  const stakes = [
    ...record.fieldsTaken.map((f) => `the GF(${f}) record`),
    ...(record.club ? ['a place in the 4/3 club'] : []),
  ]
  if (record.needsDiscovery) {
    return `<p class="record-new">This matroid would take ${andList(stakes)} &mdash; but
      record entries need a discovery record. Fill in <em>discovered by</em>, the
      <em>discovery date</em>, and the <em>AI-use declaration</em> under
      &ldquo;Attribution &amp; discovery&rdquo; below, then resubmit to record it.</p>`
  }
  if (record.recorded) {
    return `<p class="record-new">New record: this matroid takes ${andList(stakes)}. Saved as
      <a href="/matroid/${record.matroidId}">matroid #${record.matroidId}</a>.</p>`
  }
  if (record.tiedExact) {
    const cert = record.certificateAttached
      ? ' Your matrix was attached to it as a representability certificate &mdash; new information about a known matroid.'
      : ''
    return `<p class="muted">Already in the record book: this is exactly
      <a href="/matroid/${record.matroidId}">matroid #${record.matroidId}</a>, basis for
      basis.${cert}</p>`
  }
  const bars = (record.standing ?? []).map(
    (s) =>
      `the GF(${s.field}) record is <a href="/matroid/${s.matroidId}">${alphaVar} = ${fmtAlphaLong(
        s.alphaNum,
        s.alphaDen,
      )}</a>`,
  )
  const barText = bars.length
    ? `${andList(bars)}, and a record entry must strictly beat it${bars.length > 1 ? 's' : ''}; `
    : ''
  return `<p class="muted">Not a record: ${barText}the 4/3 club takes any matroid with
    ${alphaVar} &ge; 4/3. This submission was not saved.</p>`
}

/** Maximizing pairs, clipped for display. Accepts the current shape
 * ({i, j, counts}) and the pre-migration one ([i, j]). */
type PairLike = { i: number; j: number } | [number, number]
const pairIJ = (p: PairLike): [number, number] => (Array.isArray(p) ? [p[0], p[1]] : [p.i, p.j])
function pairsHtml(pairs: PairLike[]): string {
  const shown = pairs.slice(0, 12).map((p) => {
    const [i, j] = pairIJ(p)
    return `(${i},&thinsp;${j})`
  })
  const more = pairs.length - 12
  return shown.join(', ') + (more > 0 ? ` <span class="muted">&hellip; and ${more} more</span>` : '')
}

function countsTable(counts: { containBoth: number; avoidBoth: number; onlyI: number; onlyJ: number }): string {
  const f = (x: number) => x.toLocaleString('en-US')
  return `<table class="counts-table">
        <thead><tr><th></th><th><var>j</var> &isin; <var>B</var></th><th><var>j</var> &notin; <var>B</var></th></tr></thead>
        <tbody>
          <tr><th><var>i</var> &isin; <var>B</var></th><td>${f(counts.containBoth)}</td><td>${f(counts.onlyI)}</td></tr>
          <tr><th><var>i</var> &notin; <var>B</var></th><td>${f(counts.onlyJ)}</td><td>${f(counts.avoidBoth)}</td></tr>
        </tbody>
      </table>`
}

function loopsNote(loops: number[], coloops: number[]): string {
  const parts: string[] = []
  if (loops.length) parts.push(`loops: ${loops.join(', ')}`)
  if (coloops.length) parts.push(`coloops: ${coloops.join(', ')}`)
  return parts.length ? `<p class="muted">${parts.join(' &nbsp;&middot;&nbsp; ')} (excluded from the maximum)</p>` : ''
}

function resultSection(result: VerifyResult, record?: RecordStatus): string {
  if (!result.ok) {
    return `
    <section class="result result-error">
      <h2>Error</h2>
      <p>${escapeHtml(result.error)}</p>
    </section>`
  }
  const stats = `
      <dl class="stats">
        <div><dt>n</dt><dd>${result.n}</dd></div>
        <div><dt>rank</dt><dd>${result.rank}</dd></div>
        <div><dt>bases</dt><dd>${result.numBases.toLocaleString('en-US')}</dd></div>
        ${result.field ? `<div><dt>field</dt><dd>${result.field === 'Q' ? '&#8474;' : `GF(${result.field})`}</dd></div>` : ''}
        <div><dt>${alphaVar}(M)</dt><dd class="score">${fmtAlphaLong(result.alphaNum, result.alphaDen)}</dd></div>
      </dl>`
  const noPairs = result.maxCounts === null
  const detail = noPairs
    ? `<p class="muted">Every element is a loop or a coloop, so there is no eligible pair and ${alphaVar}(<var>M</var>) = 0 by convention.</p>`
    : `<p>Maximum attained at pair${result.maximizingPairs.length === 1 ? '' : 's'} ${pairsHtml(result.maximizingPairs)}; basis counts at (<var>i</var>,&thinsp;<var>j</var>) = ${pairsHtml(result.maximizingPairs.slice(0, 1))}:</p>
      ${countsTable(result.maxCounts!)}`
  const verdict = beatsGoal(result.alphaNum, result.alphaDen)
    ? `<p class="beats">This matroid reaches 4/3! &#127942;</p>`
    : result.alphaValue > 1
      ? `<p class="beats-one">Positively correlated: ${alphaVar}(<var>M</var>) &gt; 1. A constant of 4/3 or more would settle the challenge.</p>`
      : `<p class="muted">All pairs are negatively correlated (${alphaVar} &le; 1).</p>`
  return `
    <section class="result result-valid">
      <h2>Verified &#10003;</h2>
      <p>A valid matroid; ${alphaVar}(<var>M</var>) was computed exactly from all
      ${result.numBases.toLocaleString('en-US')} bases.</p>
      ${stats}
      ${loopsNote(result.loops, result.coloops)}
      ${detail}
      ${recordSection(record)}
      ${verdict}
    </section>`
}

export function landingPage(
  user: User | null = null,
  records: RecordPoint[] = [],
  families: Family[] = [],
  resultExpired = false,
): string {
  const expiredNote = resultExpired
    ? '<section class="prose"><p class="muted">That result link has expired &mdash; submit the matroid again below.</p></section>'
    : ''
  const body = `
    ${heroSection(records, families)}
    ${expiredNote}
    ${recordsSection(records, families)}
    ${definitionSection()}
    ${submitTabs()}
    ${verifierForm({}, user, { homepage: true })}
    ${familyFormSection({}, user)}
    ${SUBMIT_TABS_SCRIPT}`
  return layout(SITE_NAME, body, user, '', true)
}

// Post/Redirect/Get target for non-record submissions: the verdict plus the
// form, pre-filled for quick iteration. Served from a short-lived KV flash,
// so reloading is harmless.
export function resultPage(
  user: User | null,
  result: VerifyResult,
  record: RecordStatus | undefined,
  form: FormState,
): string {
  const body = `
    ${resultSection(result, record)}
    ${verifierForm(form, user, { openAttribution: record?.needsDiscovery === true })}`
  return layout(`Result — ${SITE_NAME}`, body, user)
}

function userMatroidsSection(rows: UserMatroidRow[]): string {
  const heading = `<h3>Your record matroids <span class="muted">(${rows.length})</span></h3>`
  if (rows.length === 0) {
    return `<section class="my-matroids">
      ${heading}
      <p class="muted">None yet &mdash; a matroid is saved here when it enters the record book:
      beating a field record, or reaching ${alphaVar} &ge; 4/3. <a href="/">Submit one &rarr;</a></p>
    </section>`
  }
  const trs = rows
    .map(
      (m) => `<tr>
        <td class="num"><a href="/matroid/${m.id}">${m.n}</a></td>
        <td class="num">${m.rank}</td>
        <td class="num">${fmtAlpha(m.alpha_num, m.alpha_den)}</td>
        <td>${escapeHtml(m.created_at)}</td>
        <td>${m.titles ? titleNames(m.titles).join(', ') : '<span class="muted">history</span>'}</td>
      </tr>`,
    )
    .join('\n')
  return `<section class="my-matroids">
      ${heading}
      <p class="muted">Matroids that entered the record book when you submitted them, largest constant first.</p>
      <table class="tokens-table">
        <thead><tr><th class="num">n</th><th class="num">rank</th><th class="num">${alphaVar}</th><th>Submitted</th><th>Status</th></tr></thead>
        <tbody>${trs}</tbody>
      </table>
    </section>`
}

export function profilePage(user: User, matroids: UserMatroidRow[] = [], admin = false): string {
  const body = `
    <section class="prose">
      <h2>Profile</h2>
      <p class="muted">Signed in as ${escapeHtml(user.display_name || user.email || 'user')} (via ${escapeHtml(
        user.provider,
      )}).${admin ? ' <strong class="admin-badge">site admin</strong> &mdash; you can review, edit, accept, and reject family proposals.' : ''}</p>
      <section class="profile-name">
        <h3>Display name</h3>
        <form method="post" action="/profile/name" class="profile-name-form">
          <input type="text" name="name" value="${escapeHtml(user.display_name || '')}" maxlength="100" required />
          <button type="submit">save</button>
        </form>
      </section>
      ${userMatroidsSection(matroids)}
    </section>`
  return layout(`Profile — ${SITE_NAME}`, body, user)
}


/** Pretty-print a JSON list of rows/sets, one entry per line. */
function formatListJson(json: string): string {
  try {
    const data = JSON.parse(json)
    if (Array.isArray(data) && data.length > 0) {
      return '[' + data.map((row) => JSON.stringify(row)).join(',\n ') + ']'
    }
    return JSON.stringify(data)
  } catch {
    return json
  }
}

const fieldBadge = (field: string | null): string =>
  field === null ? '' : `<span class="field-badge">${field === 'Q' ? '&#8474;' : `GF(${escapeHtml(field)})`}</span>`

export function matroidDetailPage(
  m: MatroidView,
  user: User | null = null,
  justRecorded = false,
): string {
  const submitter = m.submitter_name
    ? escapeHtml(m.submitter_name)
    : '<span class="muted">anonymous</span>'
  const currentTitles = titleNames(m.titles)
  const pastFields = (m.past_fields ?? '')
    .split(',')
    .filter(Boolean)
    .map(Number)
    .sort((a, b) => a - b)
  const status = currentTitles.length
    ? `current ${andList(currentTitles.map((t) => (t === '4/3 club' ? '4/3 club member' : t)))}`
    : pastFields.length
      ? `superseded &mdash; held the ${andList(pastFields.map((f) => `GF(${f})`))} record${pastFields.length > 1 ? 's' : ''} until beaten`
      : 'kept as history &mdash; not a current record holder'
  let maxPairs: PairLike[] = []
  try {
    maxPairs = JSON.parse(m.max_pairs)
  } catch {
    /* leave empty */
  }
  let counts: { containBoth: number; avoidBoth: number; onlyI: number; onlyJ: number } | null = null
  try {
    counts = m.max_counts ? JSON.parse(m.max_counts) : null
  } catch {
    /* leave null */
  }
  const pairBlock = counts
    ? `<section class="max-pair">
        <h3>Maximizing pair${maxPairs.length === 1 ? '' : 's'}</h3>
        <p>${pairsHtml(maxPairs)}; basis counts at (<var>i</var>,&thinsp;<var>j</var>) = ${pairsHtml(maxPairs.slice(0, 1))}:</p>
        ${countsTable(counts)}
      </section>`
    : `<p class="muted">Every element is a loop or a coloop; ${alphaVar}(<var>M</var>) = 0 by convention.</p>`
  let basesBlock = `<p class="muted">The full basis list is too large to store; recompute it from the description above.</p>`
  if (m.bases !== null) {
    basesBlock = `<details class="bases-details">
        <summary>show all ${m.num_bases.toLocaleString('en-US')} bases</summary>
        <pre class="elements">${escapeHtml(formatListJson(m.bases))}</pre>
      </details>`
  }
  // Discovery record: structured fields first, free-text notes after.
  const discoveryRows: string[] = []
  if (m.discoverers) discoveryRows.push(`<dt>discovered by</dt><dd>${escapeHtml(m.discoverers)}</dd>`)
  if (m.discovery_date) discoveryRows.push(`<dt>discovery date</dt><dd>${escapeHtml(m.discovery_date)}</dd>`)
  if (m.ai_used !== null) {
    let ai = m.ai_used ? 'yes' : 'no'
    if (m.ai_used && m.ai_model) {
      ai = `yes &mdash; ${escapeHtml(m.ai_model)}${m.ai_role ? `: ${escapeHtml(m.ai_role)}` : ''}`
      if (m.ai_chat_url) ai += ` (<a class="external" href="${escapeHtml(m.ai_chat_url)}">chat/run link</a>)`
    }
    discoveryRows.push(`<dt>AI use</dt><dd>${ai}</dd>`)
  }
  if (m.citation) discoveryRows.push(`<dt>citation</dt><dd>${escapeHtml(m.citation)}</dd>`)
  const provenanceBlock = m.provenance
    ? `<section class="provenance">
        <h3>Notes</h3>
        <div class="note-body">${escapeHtml(m.provenance)}</div>
      </section>`
    : ''
  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/matroids">&larr; all matroids</a></p>
      ${justRecorded ? `<p class="record-new">New record entry &mdash; saved. &#127941;</p>` : ''}
      <h2>matroid #${m.id}${m.name ? ` <span class="matroid-name">&mdash; ${escapeHtml(m.name)}</span>` : ''}</h2>
      <dl class="stats">
        <div><dt>n</dt><dd>${m.n}</dd></div>
        <div><dt>rank</dt><dd>${m.rank}</dd></div>
        <div><dt>bases</dt><dd>${m.num_bases.toLocaleString('en-US')}</dd></div>
        <div><dt>${alphaBarVar}(M)</dt><dd class="score">${fmtAlphaLong(m.alpha_num, m.alpha_den)}</dd></div>
      </dl>
      <dl class="detail-meta">
        <dt>status</dt><dd>${status}</dd>
        ${discoveryRows.join('\n        ')}
        <dt>submitted by</dt><dd>${submitter}</dd>
        <dt>submitted at</dt><dd>${escapeHtml(m.created_at)} UTC</dd>
      </dl>
      <section class="representation">
        <h3>Description <span class="muted">(${escapeHtml(m.representation_type)})</span> ${fieldBadge(m.field)}</h3>
        <pre class="elements">${escapeHtml(formatListJson(m.representation))}</pre>
        ${basesBlock}
      </section>
      ${
        m.cert_matrix
          ? `<section class="representation">
        <h3>Representability certificate ${fieldBadge(m.cert_field)}</h3>
        <p class="muted">A matrix later verified to define exactly this matroid, basis for basis.</p>
        <pre class="elements">${escapeHtml(formatListJson(m.cert_matrix))}</pre>
      </section>`
          : ''
      }
      ${pairBlock}
      ${provenanceBlock}
    </section>`
  return layout(
    `matroid #${m.id}${m.name ? ` (${m.name})` : ''} — ${SITE_NAME}`,
    body,
    user,
  )
}

// A SQLite CURRENT_TIMESTAMP string ('YYYY-MM-DD HH:MM:SS', UTC) as a
// timezone-free relative time ("3 hours ago"), with the exact UTC instant
// in the tooltip and a machine-readable datetime attribute.
function relativeTime(ts: string): string {
  const then = new Date(ts.replace(' ', 'T') + 'Z').getTime()
  if (Number.isNaN(then)) return escapeHtml(ts)
  const s = Math.max(0, Math.floor((Date.now() - then) / 1000))
  const units: [number, string][] = [
    [31536000, 'year'],
    [2592000, 'month'],
    [86400, 'day'],
    [3600, 'hour'],
    [60, 'minute'],
  ]
  let text = 'just now'
  for (const [secs, name] of units) {
    if (s >= secs) {
      const k = Math.floor(s / secs)
      text = `${k} ${name}${k === 1 ? '' : 's'} ago`
      break
    }
  }
  return `<time datetime="${ts.replace(' ', 'T')}Z" title="${escapeHtml(ts)} UTC">${text}</time>`
}

// Recent-activity feed: record matroids, newest first.
export function activityPage(
  items: ActivityItem[],
  page: number,
  hasOlder: boolean,
  user: User | null = null,
): string {
  const who = (u: string | null) => (u ? escapeHtml(u) : '<span class="muted">anonymous</span>')
  const entry = (a: ActivityItem): string => {
    const link = `<a href="/matroid/${a.matroid_id}">matroid #${a.matroid_id}</a>`
    // The titles this matroid ever took; older rows entered the book under
    // its pre-2026-08 per-ground-set-size rules and hold none.
    const took = titleNames(a.titles).map((t) => (t === '4/3 club' ? 'a place in the 4/3 club' : `the ${t}`))
    const deed = took.length ? `took ${andList(took)} with` : 'entered the record book with'
    return `<li>
        <p class="activity-meta">${relativeTime(a.ts)} &middot; ${who(a.user)}</p>
        <p class="activity-line">${deed} ${link} &mdash; ${alphaVar} = ${fmtAlphaLong(
          a.alpha_num,
          a.alpha_den,
        )}</p>
      </li>`
  }
  const list = items.length
    ? `<ul class="activity">${items.map(entry).join('\n')}</ul>`
    : `<p class="muted">No activity yet.</p>`
  const newer =
    page > 0
      ? `<a href="/recent${page - 1 === 0 ? '' : `?p=${page - 1}`}">&larr; newer</a>`
      : `<span class="muted">&larr; newer</span>`
  const older = hasOlder
    ? `<a href="/recent?p=${page + 1}">older &rarr;</a>`
    : `<span class="muted">older &rarr;</span>`
  const body = `
    <section class="prose">
      <h2>Recent activity</h2>
      <p class="muted">Record matroids, newest first.</p>
      ${list}
      <nav class="pager">${newer} <span class="muted">page ${page + 1}</span> ${older}</nav>
    </section>`
  return layout(`Recent activity — ${SITE_NAME}`, body, user)
}

// The /matroids table. Sorting is server-side via query params — the column
// header links carry the target sort state, so the page needs no JS.
const MATROID_SORT_KEYS = ['id', 'n', 'rank', 'bases', 'alpha', 'date'] as const
type MatroidSortKey = (typeof MATROID_SORT_KEYS)[number]

// First-click direction per column: the constant is most interesting
// large-first, ids/sizes small-first.
const MATROID_SORT_DEFAULT_DIR: Record<MatroidSortKey, 'asc' | 'desc'> = {
  id: 'asc',
  n: 'asc',
  rank: 'asc',
  bases: 'desc',
  alpha: 'desc',
  date: 'desc',
}

export function matroidsPage(
  rows: MatroidListRow[],
  query: { sort?: string; dir?: string; current?: string; field?: string },
  user: User | null = null,
): string {
  const sort: MatroidSortKey = (MATROID_SORT_KEYS as readonly string[]).includes(query.sort ?? '')
    ? (query.sort as MatroidSortKey)
    : 'alpha'
  const dir: 'asc' | 'desc' =
    query.dir === 'asc' || query.dir === 'desc' ? query.dir : MATROID_SORT_DEFAULT_DIR[sort]
  const currentOnly = query.current === '1'
  // Field values are the verifier's strings: 'Q' or the field order.
  const fieldFilter = /^(Q|\d{1,9})$/.test(query.field ?? '') ? (query.field as string) : null
  const matchesField = (m: MatroidListRow): boolean =>
    fieldFilter === null || m.field === fieldFilter || m.cert_field === fieldFilter

  const keyValue: Record<MatroidSortKey, (m: MatroidListRow) => number | string> = {
    id: (m) => m.id,
    n: (m) => m.n,
    rank: (m) => m.rank,
    bases: (m) => m.num_bases,
    alpha: (m) => m.alpha_value,
    date: (m) => m.created_at,
  }

  const shown = rows.filter((r) => (!currentOnly || r.titles !== null) && matchesField(r))
  const val = keyValue[sort]
  const flip = dir === 'desc' ? -1 : 1
  shown.sort((a, b) => {
    const av = val(a), bv = val(b)
    const cmp = av < bv ? -1 : av > bv ? 1 : 0
    return cmp !== 0 ? cmp * flip : a.n - b.n || a.id - b.id
  })

  const href = (
    s: MatroidSortKey,
    d: 'asc' | 'desc',
    current: boolean,
    field: string | null = fieldFilter,
  ): string => {
    const q = new URLSearchParams()
    if (!(s === 'alpha' && d === 'desc')) {
      q.set('sort', s)
      q.set('dir', d)
    }
    if (current) q.set('current', '1')
    if (field !== null) q.set('field', field)
    const qs = q.toString()
    return '/matroids' + (qs ? '?' + qs : '')
  }
  const th = (key: MatroidSortKey, label: string, cls = '', title = ''): string => {
    const active = key === sort
    const target = active ? (dir === 'asc' ? 'desc' : 'asc') : MATROID_SORT_DEFAULT_DIR[key]
    return `<th${cls ? ` class="${cls}"` : ''}><a class="sort${active ? ` ${dir}` : ''}" href="${href(
      key,
      target,
      currentOnly,
    )}"${title ? ` title="${title}"` : ''}>${label}</a></th>`
  }

  const trs = shown
    .map(
      (m) => `<tr>
        <td><a href="/matroid/${m.id}">#${m.id}</a></td>
        <td class="num">${m.n}</td>
        <td class="num">${m.rank}</td>
        <td class="num">${m.num_bases.toLocaleString('en-US')}</td>
        <td class="num">${fmtAlpha(m.alpha_num, m.alpha_den)}</td>
        <td class="num">${m.alpha_value.toFixed(4)}</td>
        <td>${escapeHtml(m.representation_type)}${(() => {
          const f = m.field ?? m.cert_field
          return f
            ? ` <a href="${href(sort, dir, currentOnly, f)}" title="show only matroids verified or certified over this field">${fieldBadge(f)}</a>`
            : ''
        })()}</td>
        <td>${m.titles ? titleNames(m.titles).join(', ') : '<span class="muted">history</span>'}</td>
        <td>${m.discoverers ? escapeHtml(m.discoverers) : '<span class="muted">&mdash;</span>'}</td>
        <td>${m.submitter ? escapeHtml(m.submitter) : '<span class="muted">anonymous</span>'}</td>
        <td>${escapeHtml(m.created_at)}</td>
      </tr>`,
    )
    .join('\n')

  const filterToggle = currentOnly
    ? `<a href="${href(sort, dir, false)}">all</a> &middot; <strong>current record holders only</strong>`
    : `<strong>all</strong> &middot; <a href="${href(sort, dir, true)}">current record holders only</a>`
  // The field filter is a plain GET form (the page has no JS); hidden inputs
  // mirror href() so submitting preserves the sort and current-only state.
  // Options come from the data: every field a stored row is verified or
  // certified over, ℚ first, then by field order.
  const hiddenState =
    (sort === 'alpha' && dir === 'desc'
      ? ''
      : `<input type="hidden" name="sort" value="${sort}"><input type="hidden" name="dir" value="${dir}">`) +
    (currentOnly ? '<input type="hidden" name="current" value="1">' : '')
  const fieldsPresent = [
    ...new Set(rows.flatMap((r) => [r.field, r.cert_field]).filter((f): f is string => f !== null)),
  ].sort((a, b) => (a === 'Q' ? -1 : b === 'Q' ? 1 : Number(a) - Number(b)))
  // Literal ℚ, not the entity: the label also lands in the escaped <title>.
  const fieldName = (f: string): string => (f === 'Q' ? 'ℚ' : `GF(${escapeHtml(f)})`)
  const fieldOptions = fieldsPresent
    .map(
      (f) =>
        `<option value="${escapeHtml(f)}"${f === fieldFilter ? ' selected' : ''}>${fieldName(f)}</option>`,
    )
    .join('')
  const fieldFilterForm =
    `<form class="inline-form field-filter" method="get" action="/matroids">${hiddenState}` +
    `<label>field&nbsp;<select name="field"><option value="">any</option>${fieldOptions}</select></label> ` +
    `<button class="link-button" type="submit">filter</button></form>` +
    (fieldFilter === null
      ? ''
      : ` &middot; <a href="${href(sort, dir, currentOnly, null)}">clear</a>`)
  const fieldLabel = fieldFilter === null ? '' : ` over ${fieldName(fieldFilter)}`
  const heading = (currentOnly ? 'Current record holders' : 'All matroids') + fieldLabel

  const body = `
    <section class="prose">
      <h2>${heading}</h2>
      <p class="muted">Every matroid ever to enter the record book. A current holder has the
      best verified ${alphaVar} over one of GF(2), GF(3), GF(4), GF(5), GF(7), or reached 4/3;
      every other row is kept as history. Click a column header to sort; click again to
      reverse.</p>
      <div class="table-controls muted">showing ${shown.length} of ${rows.length} matroids
        &nbsp;&middot;&nbsp; ${filterToggle}
        &nbsp;&middot;&nbsp; ${fieldFilterForm}
        &nbsp;&middot;&nbsp; <a href="/database.json" download>Download (JSON) &darr;</a></div>
      <div class="table-scroll">
      <table class="tokens-table matroids-table">
        <thead><tr>
          ${th('id', 'matroid')}
          ${th('n', 'n', 'num')}
          ${th('rank', 'rank', 'num')}
          ${th('bases', 'bases', 'num')}
          ${th('alpha', alphaBarVar, 'num', 'the correlation constant, exact')}
          <th class="num">&approx;</th>
          <th>description</th>
          <th>status</th>
          <th>discovered by</th>
          <th>submitter</th>
          ${th('date', 'submitted')}
        </tr></thead>
        <tbody>${trs}</tbody>
      </table>
      </div>
    </section>`
  return layout(`${heading} — ${SITE_NAME}`, body, user)
}

export function acknowledgePage(user: User | null = null): string {
  const body = `
    <section class="prose">
      <h2>Acknowledgement</h2>
      <p>The Institute for Computer-Aided Reasoning in Mathematics
      <span class="nowrap">(<a class="external" href="https://icarm.io">ICARM</a>)</span> is supported by
      U.S. National Science Foundation Grant DMS 2425401. The views expressed on these pages do not
      necessarily reflect those of the NSF.</p>
      <p>If any ICARM meetings, resources, or innovation engineers are helpful to you, you can indicate
      that in associated publications with a brief acknowledgment, such as the following:</p>
      <ul>
        <li>&ldquo;Part of this research has been carried out at the Institute for Computer-Aided
        Reasoning (ICARM), which is supported by NSF Grant DMS 2425401.&rdquo;</li>
        <li>&ldquo;This research made use of the matroid correlation constants site, maintained by the
        Institute for Computer-Aided Reasoning (ICARM) under NSF Grant DMS 2425401.&rdquo;</li>
        <li>&ldquo;We are grateful to the Institute for Computer-Aided Reasoning (ICARM) for technical
        support provided under NSF Grant DMS 2425401.&rdquo;</li>
      </ul>
    </section>`
  return layout(`Acknowledgement — ${SITE_NAME}`, body, user)
}

export function notFoundPage(user: User | null = null): string {
  return layout('Not found', `<section class="prose"><p>Page not found.</p></section>`, user)
}
