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
  CommentView,
  MatroidListRow,
  MatroidView,
  RecordStatus,
} from './store'
import { COMMENT_MAX } from './store'
import { familiesChartData, type Family } from './familyData'

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
  is_current: number // SQLite boolean: 1 when still the record for n
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
    <main>${bodyInner}</main>
    <footer>
      <div class="inner">
        <nav class="footer-links">
          <a href="/recent">recent activity</a> &nbsp;&middot;&nbsp;
          <a href="/database.json" download>download the records (JSON)</a> &nbsp;&middot;&nbsp;
          <a class="external" href="https://icarm.zulipchat.com/#narrow/channel/589006-Matroid-Database">discuss on Zulip</a> &nbsp;&middot;&nbsp;
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

// The four basis-count classes, in Chris Eur's bracket notation:
// B[∋i,∋j], B[∌i,∌j], B[∋i,∌j], B[∌i,∋j].
const bc = (i: string, j: string): string => `B[${i}<var>i</var>, ${j}<var>j</var>]`
const IN = '&ni;'
const OUT = '&#8716;'

// The wide hero: the pitch on the left, the standing record on the right —
// so the page opens wide-into-wide against the wide chart below it, and
// narrow prose only appears further down where it reads as article body.
function heroSection(records: RecordPoint[]): string {
  let best: RecordPoint | null = null
  for (const r of records) {
    if (r.is_current && (best === null || r.alpha_value > best.alpha_value)) best = r
  }
  const bestLine = best
    ? `Best single matroid: <a href="/matroid/${best.id}">${alphaVar} = ${fmtAlpha(best.alpha_num, best.alpha_den)}
       &approx; ${best.alpha_value.toFixed(4)}</a>${best.name ? ` &mdash; ${escapeHtml(best.name)}` : ''}
       (${best.n} elements${best.field ? `, GF(${escapeHtml(best.field)})` : ''})`
    : 'No verified records yet &mdash; be the first dot on the board.'
  const card = `<div class="record-card">
        <p class="eyebrow">The record to beat</p>
        <p class="record-card-value">4/3</p>
        <p class="record-card-approx">&approx; 1.3333 &mdash; reached by known families only in the limit</p>
        <p class="record-card-meta">${bestLine}</p>
      </div>`
  return `
  <section class="hero">
    <div class="hero-copy">
      <h2 class="hero-title">How correlated can the bases of a&nbsp;matroid&nbsp;be?</h2>
      <p class="lede">Pick a basis uniformly at random. Elements usually repel &mdash; seeing one
      in the basis makes another <em>less</em> likely. But in some matroids a pair of elements
      attracts, and nobody knows how strong the attraction can get. The challenge:
      <strong>find a concrete matroid whose correlation constant reaches 4/3.</strong></p>
      <p class="hero-actions"><a class="hero-cta" href="#submit">Submit a matroid</a>
      <a class="hero-link" href="#definition">the definition &darr;</a></p>
    </div>
    ${card}
  </section>`
}

// A minimal definition beside the submission form; the mathematics page
// carries the full background, discovery record, and proofs.
function definitionSection(): string {
  return `
  <section class="prose" id="definition">
    <h2>The correlation constant, at a glance</h2>
    <p>
      For a matroid <var>M</var> on <span class="math">{0, &hellip;, n&minus;1}</span>, write
      ${bc(IN, IN)} for the number of bases containing both elements <var>i</var> and
      <var>j</var>, ${bc(OUT, OUT)} for the number avoiding both, and so on. Then
    </p>
    <p class="display-eq">
      <span class="eq-part"><var>R</var><sub>ij</sub>(<var>M</var>) =
        <span class="frac"><span class="num">${bc(IN, IN)} &middot; ${bc(OUT, OUT)}</span><span class="den">${bc(IN, OUT)} &middot; ${bc(OUT, IN)}</span></span></span>
      <span class="eq-part">${alphaVar}(<var>M</var>) = max<sub><var>i</var> &ne; <var>j</var></sub> <var>R</var><sub>ij</sub>(<var>M</var>)</span>
    </p>
    <p>
      with the maximum over pairs of nonloop, noncoloop elements; ${alphaVar}(<var>M</var>) &gt; 1
      means some pair is positively correlated in a uniformly random basis.
      <a href="/mathematics">Why this is interesting, what is known, and proofs of every family
      formula &rarr;</a>
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

/** A stored matroid as a plot point: the row id, ground-set size, its
 * constant, and whether it is still the record for its n. */
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
  is_current: number // SQLite boolean
}

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
      const title = `n = ${p.n}: ${p.is_current ? 'record' : 'superseded record'} α = ${fmtAlpha(
        p.alpha_num,
        p.alpha_den,
      )} ≈ ${p.alpha_value.toFixed(4)} (rank ${p.rank}, ${p.num_bases.toLocaleString('en-US')} bases)`
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
      <text class="axis-title" transform="rotate(-90)" x="${-(PLOT.T + INNER_H / 2)}" y="15" text-anchor="middle">correlation constant &#945; &#8594;</text>
    </svg>`
}

function recordsSection(records: RecordPoint[], families: Family[]): string {
  const fallbackInner =
    records.length === 0
      ? '<p class="muted">No verified records yet &mdash; submit a matroid to put the first dot on the board.</p>'
      : `<div class="plot-panel">${recordsPlot(records)}</div>
    <p class="muted plot-caption">Each dot is a record-setting matroid &mdash; the current record
    for its n, or a superseded one kept as history. Dots with ${alphaVar} &le; 1 fall below the
    frame. Huh&ndash;Schr&ouml;ter&ndash;Wang: ${alphaVar}(<var>M</var>) &le; 2 for every matroid.
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
      current: !!r.is_current,
    })),
  }).replace(/</g, '\\u003c')
  const check = (id: string, label: string, checked: boolean): string =>
    `<label class="check-row"><input id="${id}" type="checkbox"${checked ? ' checked' : ''} /> ${label}</label>`
  return `
  <section class="panel records">
    <div id="records-fallback">${fallbackInner}</div>
    <div id="records-explorer" hidden>
      <p class="muted explorer-note">Solid curves are proved exact family values; dashed curves are
      certified lower bounds from a distinguished pair (from the
      <a class="external" href="https://arxiv.org/abs/1806.02675">HSW</a> and August 2026 discovery
      records). Dots are this site&rsquo;s verified record submissions &mdash; click one for its page.</p>
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
            <option value="5">GF(5)</option>
            <option value="7">GF(7)</option>
          </select>
          <label class="field-label" for="rank-filter">Rank</label>
          <select id="rank-filter"><option value="all">All ranks</option></select>
          <div class="range-label">
            <label class="field-label" for="max-n">Ground-set size</label>
            <output id="max-n-output" for="max-n">&le; 300</output>
          </div>
          <input id="max-n" type="range" min="20" max="1000" value="300" step="10" />
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

function verifierForm(state: FormState, user: User | null, openAttribution = false): string {
  const submit = user
    ? '<button type="submit">Verify</button>'
    : '<a class="login-to-submit" href="/auth/github">Log in to submit</a>'
  const selectedType =
    state.typeValue && state.typeValue in DATA_PLACEHOLDERS ? state.typeValue : 'matrix'
  const typeOption = (value: string, label: string): string =>
    `<option value="${value}"${selectedType === value ? ' selected' : ''}>${label}</option>`
  return `
  <section class="panel" id="submit">
    <h2>Submit a matroid</h2>
    <form method="post" action="/verify">
      <div class="form-row">
        <label for="n">Elements <var>n</var> <span class="hint">(ground set 0, &hellip;, n&minus;1)</span>
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
        <label for="claimed_alpha">Claimed ${alphaVar} <span class="hint">(optional; exact fraction &mdash;
          a mismatch with the computed value fails the submission, catching paste mistakes)</span>
        <input id="claimed_alpha" name="claimed_alpha" type="text" maxlength="40"
               placeholder="e.g. 100/81" value="${escapeHtml(state.claimedAlphaValue ?? '')}" /></label>
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
  '[{"label": "q = 2", "points": [\n' +
  '  {"parameter": "d = 3", "n": 10, "rank": 7, "alpha": "6/7"},\n' +
  '  {"parameter": "d = 4", "n": 18, "rank": 9, "alpha": "8/7"}\n' +
  ']}]'

/** The infinite-family proposal form. Unlike the concrete form nothing here
 * is machine-verified: a proposal lands as a pending row that a site admin
 * must review and accept before it appears anywhere public. */
function familyFormSection(state: FamilyFormState, user: User | null): string {
  const v = (name: string): string => escapeHtml(state[name] ?? '')
  const sel = (name: string, value: string, dflt = false): string =>
    (state[name] ?? '') === value || (dflt && (state[name] ?? '') === '') ? ' selected' : ''
  const submit = user
    ? '<button type="submit">Propose this family</button>'
    : '<a class="login-to-submit" href="/auth/github">Log in to propose</a>'
  return `
  <section class="panel" id="submit-family">
    <h2>Propose an infinite family</h2>
    <p class="muted">A family is a reviewed claim, not a computation: no enumeration can check a
    formula for every parameter. What you submit here waits as <em>pending</em> &mdash; visible
    only to you and the site admins &mdash; until an admin reviews the mathematics and accepts
    it. An accepted family gets its curve on the chart, a card, and a page. TeX is welcome in
    the formula and prose fields (<code>\\( &hellip; \\)</code> inline).</p>
    <form method="post" action="/families/propose">
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
      <label for="fam-series">Plotted members <span class="hint">(JSON: series with exact values;
        "field" optional; at most 400 points)</span></label>
      <textarea id="fam-series" name="series" rows="7" required
                placeholder='${escapeHtml(SERIES_PLACEHOLDER)}'>${v('series')}</textarea>
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
      ${submit}
      <p class="muted form-note">Strengthen the proposal before it reaches review:
      <a href="/#submit">verify the family&rsquo;s small members</a> with the concrete form
      first &mdash; each becomes a machine-checked entry a reviewer can lean on. An automatic
      screen compares the claimed values against the Huh&ndash;Schr&ouml;ter&ndash;Wang bound
      and flags a supremum &ge; 4/3 for extra scrutiny; it verifies no mathematics.</p>
    </form>
  </section>`
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
        function fromHash() {
          if (location.hash === '#submit-family') {
            show('submit-family');
            var panel = document.getElementById('submit-family');
            if (panel) panel.scrollIntoView();
          } else if (location.hash === '#submit') {
            show('submit');
          }
        }
        bar.hidden = false;
        show('submit');
        fromHash();
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
    <section class="prose">
      <p class="page-nav"><a href="/">&larr; home</a></p>
    </section>
    <section class="result result-error">
      <h2>Error</h2>
      <p>${escapeHtml(error)}</p>
    </section>
    ${familyFormSection(form, user)}`
  return layout(`Result — ${SITE_NAME}`, body, user)
}

function recordSection(result: { alphaNum: number; alphaDen: number; n: number }, record?: RecordStatus): string {
  if (!record) return ''
  const recordLink = (text: string) =>
    record.matroidId ? `<a href="/matroid/${record.matroidId}">${text}</a>` : text
  const recordAlpha = fmtAlphaLong(record.recordAlphaNum, record.recordAlphaDen)
  if (record.needsDiscovery) {
    return `<p class="record-new">This matroid would set the record for n = ${result.n} &mdash; but
      record entries need a discovery record. Fill in <em>discovered by</em>, the
      <em>discovery date</em>, and the <em>AI-use declaration</em> under
      &ldquo;Attribution &amp; discovery&rdquo; below, then resubmit to record it.</p>`
  }
  if (record.recorded) {
    return `<p class="record-new">New record: the largest verified ${alphaVar} for n = ${result.n}. Saved as ${recordLink(
      `matroid #${record.matroidId}`,
    )}.</p>`
  }
  if (record.recordAlphaNum === result.alphaNum && record.recordAlphaDen === result.alphaDen) {
    if (record.tiedExact) {
      const cert = record.certificateAttached
        ? ' Your matrix was attached to it as a representability certificate — the record now carries the field badge.'
        : ''
      return `<p class="muted">This is exactly the ${recordLink('current record matroid')} for n = ${result.n} (${alphaVar} = ${recordAlpha}), basis for basis.${cert}</p>`
    }
    return `<p class="muted">Ties the ${recordLink('current record')} for n = ${result.n} (${alphaVar} = ${recordAlpha}) with a <em>different</em> matroid of the same constant &mdash; the standing record keeps its place.</p>`
  }
  return `<p class="muted">The ${recordLink('record matroid')} for n = ${result.n} has ${alphaVar} = ${recordAlpha}, so this one was not saved.</p>`
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
      ${recordSection(result, record)}
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
    ${heroSection(records)}
    ${expiredNote}
    ${recordsSection(records, families)}
    ${definitionSection()}
    ${submitTabs()}
    ${verifierForm({}, user)}
    ${familyFormSection({}, user)}
    ${SUBMIT_TABS_SCRIPT}`
  return layout(SITE_NAME, body, user)
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
    <section class="prose">
      <p class="page-nav"><a href="/">&larr; home</a></p>
    </section>
    ${resultSection(result, record)}
    ${verifierForm(form, user, record?.needsDiscovery === true)}`
  return layout(`Result — ${SITE_NAME}`, body, user)
}

function userMatroidsSection(rows: UserMatroidRow[]): string {
  const heading = `<h3>Your record matroids <span class="muted">(${rows.length})</span></h3>`
  if (rows.length === 0) {
    return `<section class="my-matroids">
      ${heading}
      <p class="muted">None yet &mdash; a matroid is saved here when it sets the record for its
      ground-set size. <a href="/">Submit one &rarr;</a></p>
    </section>`
  }
  const trs = rows
    .map(
      (m) => `<tr>
        <td class="num"><a href="/matroid/${m.id}">${m.n}</a></td>
        <td class="num">${m.rank}</td>
        <td class="num">${fmtAlpha(m.alpha_num, m.alpha_den)}</td>
        <td>${escapeHtml(m.created_at)}</td>
        <td>${m.is_current ? 'current record' : '<span class="muted">superseded</span>'}</td>
      </tr>`,
    )
    .join('\n')
  return `<section class="my-matroids">
      ${heading}
      <p class="muted">Matroids that set the record for their ground-set size when you submitted them, largest constant first.</p>
      <table class="tokens-table">
        <thead><tr><th class="num">n</th><th class="num">rank</th><th class="num">${alphaVar}</th><th>Submitted</th><th>Status</th></tr></thead>
        <tbody>${trs}</tbody>
      </table>
    </section>`
}

export function profilePage(user: User, matroids: UserMatroidRow[] = []): string {
  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/">&larr; home</a></p>
      <h2>Profile</h2>
      <p class="muted">Signed in as ${escapeHtml(user.display_name || user.email || 'user')} (via ${escapeHtml(
        user.provider,
      )}).</p>
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


// Linkify `matroid#123` references in commentary text; everything else is escaped.
function renderCommentary(content: string): string {
  let out = ''
  let last = 0
  for (const m of content.matchAll(/matroid#(\d+)/g)) {
    out += escapeHtml(content.slice(last, m.index))
    out += `<a href="/matroid/${m[1]}">matroid#${m[1]}</a>`
    last = (m.index ?? 0) + m[0].length
  }
  return out + escapeHtml(content.slice(last))
}

function commentarySection(matroidId: number, comment: CommentView | null, user: User | null): string {
  const hasContent = !!comment && comment.content.length > 0
  const body = hasContent
    ? `<div class="comment-body">${renderCommentary(comment!.content)}</div>`
    : `<p class="muted">No commentary yet.</p>`
  const meta = comment
    ? `<p class="comment-meta">last edited ${comment.author ? `by ${escapeHtml(comment.author)} ` : ''}at ${escapeHtml(
        comment.created_at,
      )} UTC &middot; <a href="/matroid/${matroidId}/commentary-history">history</a></p>`
    : ''
  const editor = user
    ? `<details class="comment-edit">
        <summary>edit</summary>
        <form method="post" action="/matroid/${matroidId}/commentary">
          <textarea name="content" rows="6" maxlength="${COMMENT_MAX}">${escapeHtml(comment?.content ?? '')}</textarea>
          <div><button type="submit">save</button> <span class="muted">submit empty to clear</span></div>
        </form>
      </details>`
    : `<p class="muted"><a href="/auth/github">Log in</a> to add commentary.</p>`
  return `<section class="comment-section">
      <h3>Commentary</h3>
      ${body}
      ${meta}
      ${editor}
    </section>`
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
  comment: CommentView | null = null,
  user: User | null = null,
  justRecorded = false,
): string {
  const submitter = m.submitter_name
    ? escapeHtml(m.submitter_name)
    : '<span class="muted">anonymous</span>'
  const isCurrent = m.id === m.record_id
  const status = isCurrent
    ? 'current record for this ground-set size'
    : `superseded &mdash; the record is now <a href="/matroid/${m.record_id}">${alphaVar} = ${fmtAlpha(m.record_alpha_num, m.record_alpha_den)}</a>`
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
        <div class="comment-body">${escapeHtml(m.provenance)}</div>
      </section>`
    : ''
  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/">&larr; home</a> &nbsp;&middot;&nbsp; <a href="/matroids">all matroids</a></p>
      ${justRecorded ? `<p class="record-new">New record: the largest verified ${alphaVar} for n = ${m.n}. Saved. &#127941;</p>` : ''}
      <h2>matroid #${m.id}${m.name ? ` <span class="matroid-name">&mdash; ${escapeHtml(m.name)}</span>` : ''}</h2>
      <dl class="stats">
        <div><dt>n</dt><dd><a href="/matroids?n=${m.n}" title="all record matroids for this ground-set size">${m.n}</a></dd></div>
        <div><dt>rank</dt><dd>${m.rank}</dd></div>
        <div><dt>bases</dt><dd>${m.num_bases.toLocaleString('en-US')}</dd></div>
        <div><dt>${alphaVar}(M)</dt><dd class="score">${fmtAlphaLong(m.alpha_num, m.alpha_den)}</dd></div>
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
      ${commentarySection(m.id, comment, user)}
    </section>`
  return layout(
    `matroid #${m.id}${m.name ? ` (${m.name})` : ''} — ${SITE_NAME}`,
    body,
    user,
  )
}

export function commentaryHistoryPage(
  m: MatroidView,
  entries: CommentView[],
  user: User | null = null,
): string {
  const list = entries.length
    ? entries
        .map(
          (e) => `<li>
        <p class="comment-meta">${e.author ? escapeHtml(e.author) : '<span class="muted">(deleted user)</span>'} &middot; ${escapeHtml(
            e.created_at,
          )} UTC</p>
        ${e.content.length > 0 ? `<div class="comment-body">${renderCommentary(e.content)}</div>` : `<p class="muted">(cleared)</p>`}
      </li>`,
        )
        .join('\n')
    : `<li class="muted">No commentary yet.</li>`
  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/matroid/${m.id}">&larr; matroid #${m.id}</a></p>
      <h2>Commentary history</h2>
      <p class="muted">${entries.length} edit${entries.length === 1 ? '' : 's'}.</p>
      <ul class="comment-history">${list}</ul>
    </section>`
  return layout(`Commentary history — ${SITE_NAME}`, body, user)
}

function clip(s: string, n: number): string {
  return s.length > n ? s.slice(0, n) + '…' : s
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

// Recent-activity feed: record matroids and commentary edits, newest first.
export function activityPage(
  items: ActivityItem[],
  page: number,
  hasOlder: boolean,
  user: User | null = null,
): string {
  const who = (u: string | null) => (u ? escapeHtml(u) : '<span class="muted">anonymous</span>')
  const entry = (a: ActivityItem): string => {
    const link = `<a href="/matroid/${a.matroid_id}">matroid #${a.matroid_id}</a>`
    const meta = `<p class="activity-meta">${relativeTime(a.ts)} &middot; ${who(a.user)}</p>`
    if (a.kind === 'record') {
      return `<li>
        ${meta}
        <p class="activity-line">set a record for n = ${a.n} with ${link} &mdash; ${alphaVar} = ${fmtAlphaLong(
          a.alpha_num,
          a.alpha_den,
        )}</p>
      </li>`
    }
    const cleared = !a.content || a.content.length === 0
    return `<li>
        ${meta}
        <p class="activity-line">${cleared ? `cleared commentary on ${link}` : `edited commentary on ${link}`}</p>
        ${cleared ? '' : `<div class="comment-body">${renderCommentary(clip(a.content!, 280))}</div>`}
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
      <p class="page-nav"><a href="/">&larr; home</a></p>
      <h2>Recent activity</h2>
      <p class="muted">Record matroids and commentary edits, newest first.</p>
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
  query: { sort?: string; dir?: string; current?: string; n?: string },
  user: User | null = null,
): string {
  const sort: MatroidSortKey = (MATROID_SORT_KEYS as readonly string[]).includes(query.sort ?? '')
    ? (query.sort as MatroidSortKey)
    : 'alpha'
  const dir: 'asc' | 'desc' =
    query.dir === 'asc' || query.dir === 'desc' ? query.dir : MATROID_SORT_DEFAULT_DIR[sort]
  const currentOnly = query.current === '1'
  const nFilter = /^\d+$/.test(query.n ?? '') ? Number(query.n) : null

  const keyValue: Record<MatroidSortKey, (m: MatroidListRow) => number | string> = {
    id: (m) => m.id,
    n: (m) => m.n,
    rank: (m) => m.rank,
    bases: (m) => m.num_bases,
    alpha: (m) => m.alpha_value,
    date: (m) => m.created_at,
  }

  const shown = rows.filter(
    (r) => (!currentOnly || r.is_current) && (nFilter === null || r.n === nFilter),
  )
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
    n: number | null = nFilter,
  ): string => {
    const q = new URLSearchParams()
    if (!(s === 'alpha' && d === 'desc')) {
      q.set('sort', s)
      q.set('dir', d)
    }
    if (current) q.set('current', '1')
    if (n !== null) q.set('n', String(n))
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
        <td class="num"><a href="${href(sort, dir, currentOnly, m.n)}" title="show only n = ${m.n}">${m.n}</a></td>
        <td class="num">${m.rank}</td>
        <td class="num">${m.num_bases.toLocaleString('en-US')}</td>
        <td class="num">${fmtAlpha(m.alpha_num, m.alpha_den)}</td>
        <td class="num">${m.alpha_value.toFixed(4)}</td>
        <td>${escapeHtml(m.representation_type)}${m.field ? ` ${fieldBadge(m.field)}` : m.cert_field ? ` ${fieldBadge(m.cert_field)}` : ''}</td>
        <td>${m.submitter ? escapeHtml(m.submitter) : '<span class="muted">anonymous</span>'}</td>
        <td>${escapeHtml(m.created_at)}</td>
        <td>${m.is_current ? 'current' : '<span class="muted">superseded</span>'}</td>
      </tr>`,
    )
    .join('\n')

  const filterToggle = currentOnly
    ? `<a href="${href(sort, dir, false)}">all</a> &middot; <strong>current records only</strong>`
    : `<strong>all</strong> &middot; <a href="${href(sort, dir, true)}">current records only</a>`
  // The size filter is a plain GET form (the page has no JS); hidden inputs
  // mirror href() so submitting preserves the sort and current-only state.
  const hiddenState =
    (sort === 'alpha' && dir === 'desc'
      ? ''
      : `<input type="hidden" name="sort" value="${sort}"><input type="hidden" name="dir" value="${dir}">`) +
    (currentOnly ? '<input type="hidden" name="current" value="1">' : '')
  const sizeFilter =
    `<form class="inline-form size-filter" method="get" action="/matroids">${hiddenState}` +
    `<label>n&nbsp;=&nbsp;<input name="n" type="number" min="1" max="${MAX_ELEMENTS}" step="1" ` +
    `value="${nFilter ?? ''}" placeholder="any"></label> ` +
    `<button class="link-button" type="submit">filter</button></form>` +
    (nFilter === null
      ? ''
      : ` &middot; <a href="${href(sort, dir, currentOnly, null)}">clear</a>`)
  const nLabel = nFilter === null ? '' : ` for n = ${nFilter}`
  const heading = (currentOnly ? 'Current record matroids' : 'All matroids') + nLabel

  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/">&larr; home</a></p>
      <h2>${heading}</h2>
      <p class="muted">Every record-setting matroid ever submitted; a superseded row was the
      record for its ground-set size until a larger constant beat it. Click a column header to
      sort; click again to reverse.</p>
      <div class="table-controls muted">showing ${shown.length} of ${rows.length} matroids
        &nbsp;&middot;&nbsp; ${filterToggle}
        &nbsp;&middot;&nbsp; ${sizeFilter}
        &nbsp;&middot;&nbsp; <a href="/database.json" download>Download (JSON) &darr;</a></div>
      <div class="table-scroll">
      <table class="tokens-table matroids-table">
        <thead><tr>
          ${th('id', 'matroid')}
          ${th('n', 'n', 'num')}
          ${th('rank', 'rank', 'num')}
          ${th('bases', 'bases', 'num')}
          ${th('alpha', '&alpha;', 'num', 'the correlation constant, exact')}
          <th class="num">&approx;</th>
          <th>description</th>
          <th>submitter</th>
          ${th('date', 'submitted')}
          <th>status</th>
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
      <p class="page-nav"><a href="/">&larr; home</a></p>
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
