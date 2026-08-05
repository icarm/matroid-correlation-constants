// Server-rendered HTML pages, plain template literals.

import {
  MAX_ELEMENTS,
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

export interface User {
  id: number
  provider: string
  email?: string | null
  display_name?: string | null
  avatar_url?: string | null
}

export interface TokenRow {
  id: number
  name: string | null
  prefix: string
  created_at: string
  last_used_at: string | null
  revoked_at: string | null
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

const SITE_NAME = 'Matroid correlation constants'
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

export function layout(title: string, bodyInner: string, user: User | null = null): string {
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
  </head>
  <body>
    <header>
      <div class="inner">
        <h1><a href="/">Matroid correlation constants</a></h1>
        <nav><span class="auth-nav">${authNav(user)}</span></nav>
      </div>
    </header>
    <main>${bodyInner}</main>
    <footer>
      <div class="inner">
        <nav class="footer-links">
          <a href="/api">API</a> &nbsp;&middot;&nbsp;
          <a class="external" href="https://github.com/icarm/matroid-correlation-constants">source</a> &nbsp;&middot;&nbsp;
          <a class="external" href="https://icarm.io">icarm.io</a>
        </nav>
        <p class="acknowledgment">This website is maintained by the NSF Institute for Computer-Aided
        Reasoning in Mathematics <span class="nowrap">(<a class="external" href="https://icarm.io">ICARM</a>)</span>.
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

function problemStatement(): string {
  return `
  <section class="prose">
    <p class="lede">Choose a basis of a matroid uniformly at random. Elements usually repel:
    seeing element <var>i</var> in the random basis makes element <var>j</var> <em>less</em>
    likely to be there. But in some matroids a pair of elements <em>attracts</em> &mdash; and
    nobody knows how strong the attraction can get. The challenge:
    <strong>find a concrete matroid whose correlation constant reaches 4/3.</strong></p>
    <p>
      For a matroid <var>M</var> on <span class="math">{0, &hellip;, n&minus;1}</span> and
      distinct elements <var>i</var>, <var>j</var>, write ${bc(IN, IN)} for the number of bases
      containing both <var>i</var> and <var>j</var>, ${bc(OUT, OUT)} for the number avoiding
      both, and so on. The <em>correlation ratio</em> of the pair and the
      <em>correlation constant</em> of <var>M</var> are
    </p>
    <p class="display-eq">
      <span class="eq-part"><var>R</var><sub>ij</sub>(<var>M</var>) =
        <span class="frac"><span class="num">${bc(IN, IN)} &middot; ${bc(OUT, OUT)}</span><span class="den">${bc(IN, OUT)} &middot; ${bc(OUT, IN)}</span></span></span>
      <span class="eq-part">${alphaVar}(<var>M</var>) = max<sub><var>i</var> &ne; <var>j</var></sub> <var>R</var><sub>ij</sub>(<var>M</var>)</span>
    </p>
    <p>
      taking the maximum over pairs of nonloop, noncoloop elements (for which both denominator
      factors are positive). <var>R</var><sub>ij</sub>(<var>M</var>) &le; 1 says <var>i</var>
      and <var>j</var> are negatively correlated in a uniformly random basis; this holds for
      all pairs in graphic, regular, and rank &le; 3 matroids, in every matroid with at most 7
      elements, and in every matroid representable over both GF(3) and GF(4). It does
      <em>not</em> hold in general.
      <a class="external" href="https://arxiv.org/abs/1806.02675">Huh, Schr&ouml;ter, and Wang</a>
      proved that ${alphaVar}(<var>M</var>) &le; 2 for <em>every</em> matroid, and gave
      matroids with ${alphaVar} = 8/7. The largest value verified for a concrete matroid is
      <strong>100/81</strong>, on 12 elements over GF(3) (Eur&ndash;Renshaw and Huh,
      independently, August 2026). Known infinite families approach 4/3 without reaching it
      &mdash; whether any single matroid attains ${alphaVar}(<var>M</var>) &ge; 4/3 is open.
    </p>
  </section>`
}

export interface FormState {
  nValue?: string
  typeValue?: string
  fieldValue?: string
  dataValue?: string
  provenanceValue?: string
}

/** A current record: the row id, ground-set size, and its constant. */
export interface RecordPoint {
  id: number
  n: number
  rank: number
  num_bases: number
  alpha_num: number
  alpha_den: number
  alpha_value: number
}

// Server-rendered SVG scatter of the record constants against the ground-set
// size n, in a fixed 720x440 frame. No JS; tooltips via <title>.
const PLOT = { W: 720, H: 440, L: 56, R: 18, T: 18, B: 46 }
const INNER_W = PLOT.W - PLOT.L - PLOT.R
const INNER_H = PLOT.H - PLOT.T - PLOT.B
const NMIN = 1
const plotX = (n: number) => PLOT.L + ((n - NMIN) / (MAX_ELEMENTS - NMIN)) * INNER_W

function recordsPlot(pts: RecordPoint[]): string {
  let ymax = 1.45
  for (const p of pts) ymax = Math.max(ymax, p.alpha_value + 0.1)
  const Y = (v: number) => PLOT.T + INNER_H - (v / ymax) * INNER_H

  let grid = ''
  for (let n = 2; n <= MAX_ELEMENTS; n += 2) {
    const x = plotX(n).toFixed(1)
    grid += `<line class="grid" x1="${x}" y1="${PLOT.T}" x2="${x}" y2="${PLOT.T + INNER_H}"/>`
    grid += `<text class="tick" x="${x}" y="${PLOT.T + INNER_H + 18}" text-anchor="middle">${n}</text>`
  }
  for (let v = 0; v <= ymax + 1e-9; v += 0.5) {
    const y = Y(v).toFixed(1)
    if (v > 0) grid += `<line class="grid" x1="${PLOT.L}" y1="${y}" x2="${PLOT.W - PLOT.R}" y2="${y}"/>`
    grid += `<text class="tick" x="${PLOT.L - 8}" y="${(Y(v) + 4).toFixed(1)}" text-anchor="end">${v.toFixed(1)}</text>`
  }

  const hline = (v: number, cls: string, label: string, dy: number): string =>
    `<line class="${cls}" x1="${PLOT.L}" y1="${Y(v).toFixed(1)}" x2="${PLOT.W - PLOT.R}" y2="${Y(v).toFixed(1)}"/>
      <text class="guide-label" x="${PLOT.W - PLOT.R - 8}" y="${(Y(v) + dy).toFixed(1)}" text-anchor="end">${label}</text>`
  const guides =
    hline(1, 'guide guide-one', 'negative correlation barrier', 14) +
    hline(8 / 7, 'guide guide-known', '8/7', -5) +
    hline(4 / 3, 'guide guide-goal', 'the 4/3 challenge', -6)

  const dots = pts
    .map((p) => {
      const beats = beatsGoal(p.alpha_num, p.alpha_den)
      const title = `n = ${p.n}: record α = ${fmtAlpha(p.alpha_num, p.alpha_den)} ≈ ${p.alpha_value.toFixed(
        4,
      )} (rank ${p.rank}, ${p.num_bases.toLocaleString('en-US')} bases)`
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

function recordsSection(records: RecordPoint[]): string {
  const inner =
    records.length === 0
      ? '<p class="muted">No verified records yet &mdash; submit a matroid to put the first dot on the board.</p>'
      : `<div class="plot-panel">${recordsPlot(records)}</div>`
  return `
  <section class="panel records">
    ${inner}
    <p class="muted plot-caption">Each dot is the largest verified ${alphaVar} among submitted matroids
    on n elements. Huh&ndash;Schr&ouml;ter&ndash;Wang: ${alphaVar}(<var>M</var>) &le; 2 for every matroid.
    Matroids on at most 7 elements never exceed 1.</p>
    <p class="plot-caption"><a href="/matroids">Browse all matroids &rarr;</a> &nbsp;&middot;&nbsp;
    <a href="/recent">Recent activity &rarr;</a> &nbsp;&middot;&nbsp;
    <a class="external nowrap" href="https://icarm.zulipchat.com/#narrow/channel/589006-Matroid-Database">Discuss on Zulip</a></p>
    <p class="plot-caption"><a class="nowrap" href="/database.json" download>Download all records (JSON) &darr;</a></p>
  </section>`
}

function verifierForm(state: FormState, user: User | null): string {
  const submit = user
    ? '<button type="submit">Verify</button>'
    : '<a class="login-to-submit" href="/auth/github">Log in to submit</a>'
  const typeOption = (value: string, label: string): string =>
    `<option value="${value}"${(state.typeValue ?? 'matrix') === value ? ' selected' : ''}>${label}</option>`
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
      <label for="data">Data <span class="hint">(JSON: a list of matrix rows, or a list of sets of element labels)</span></label>
      <textarea id="data" name="data" rows="8" required
                placeholder="e.g. [[1,0,1,1],[0,1,1,2]] over GF(3), or bases [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]">${escapeHtml(state.dataValue ?? '')}</textarea>
      <label for="provenance">Attribution <span class="hint">(optional: discoverers, discovery date, AI-use disclosure)</span></label>
      <textarea id="provenance" name="provenance" rows="2"
                placeholder="e.g. found by X and Y, 2026-08, using Z; no AI / AI model and role">${escapeHtml(state.provenanceValue ?? '')}</textarea>
      ${submit}
      <p class="muted form-note">Verification is exact: the matroid axioms are checked, every basis is
      enumerated, and all ratios are compared by integer cross multiplication. Limits:
      n &le; ${MAX_ELEMENTS}, at most ${MAX_LISTED_SETS.toLocaleString('en-US')} listed sets or
      ${MAX_MATRIX_CELLS.toLocaleString('en-US')} matrix entries; matrix fields are &#8474;, a prime
      GF(p), or a prime power GF(p<sup>d</sup>) up to order ${MAX_EXT_FIELD_ORDER}. Over &#8474;,
      entries may be integers or fraction strings like <code>"-3/5"</code>; over
      GF(p<sup>d</sup>), integers (subfield constants) or coefficient lists like
      <code>[0,1]</code> in the Conway polynomial basis, as in Sage or GAP.</p>
    </form>
  </section>`
}

function recordSection(result: { alphaNum: number; alphaDen: number; n: number }, record?: RecordStatus): string {
  if (!record) return ''
  const recordLink = (text: string) =>
    record.matroidId ? `<a href="/matroid/${record.matroidId}">${text}</a>` : text
  const recordAlpha = fmtAlphaLong(record.recordAlphaNum, record.recordAlphaDen)
  if (record.recorded) {
    return `<p class="record-new">New record: the largest verified ${alphaVar} for n = ${result.n}. Saved as ${recordLink(
      `matroid #${record.matroidId}`,
    )}.</p>`
  }
  if (record.recordAlphaNum === result.alphaNum && record.recordAlphaDen === result.alphaDen) {
    if (record.tiedExact) {
      return `<p class="muted">This is exactly the ${recordLink('current record matroid')} for n = ${result.n} (${alphaVar} = ${recordAlpha}), basis for basis.</p>`
    }
    return `<p class="muted">Ties the ${recordLink('current record')} for n = ${result.n} (${alphaVar} = ${recordAlpha}) with a <em>different</em> matroid of the same constant &mdash; the standing record keeps its place.</p>`
  }
  return `<p class="muted">The ${recordLink('record matroid')} for n = ${result.n} has ${alphaVar} = ${recordAlpha}, so this one was not saved.</p>`
}

/** Maximizing pairs, clipped for display. */
function pairsHtml(pairs: [number, number][]): string {
  const shown = pairs.slice(0, 12).map(([i, j]) => `(${i},&thinsp;${j})`)
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
  resultExpired = false,
): string {
  const expiredNote = resultExpired
    ? '<section class="prose"><p class="muted">That result link has expired &mdash; submit the matroid again below.</p></section>'
    : ''
  const body = `
    ${problemStatement()}
    ${expiredNote}
    ${recordsSection(records)}
    ${verifierForm({}, user)}
    <section class="prose api-note">
      <h2>API</h2>
      <p>
        <code>POST /api/verify</code> with JSON body
        <code>{"n": 4, "type": "matrix", "field": "3", "data": [[1,0,1,1],[0,1,1,2]]}</code>
        returns the same verdict as JSON. See the <a href="/api">API docs</a>.
      </p>
    </section>`
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
    ${verifierForm(form, user)}`
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

export function profilePage(
  user: User,
  tokens: TokenRow[],
  newToken: { token: string; prefix: string } | null,
  matroids: UserMatroidRow[] = [],
): string {
  const newTokenBlock = newToken
    ? `<div class="new-token">
        <p><strong>New token created.</strong> Copy it now &mdash; this is the only time it will be shown.</p>
        <pre class="token-secret">${escapeHtml(newToken.token)}</pre>
        <p class="muted">Send it as <code>Authorization: Bearer ${escapeHtml(newToken.token)}</code> when calling the API.</p>
      </div>`
    : ''
  const tokenRows = tokens.length
    ? tokens
        .map((t) => {
          const label = t.name ? escapeHtml(t.name) : '<span class="muted">(unnamed)</span>'
          const status = t.revoked_at
            ? `<span class="muted">revoked ${escapeHtml(t.revoked_at)}</span>`
            : `<form method="post" action="/profile/tokens/${t.id}/revoke" class="inline-form"><button type="submit" class="link-button">revoke</button></form>`
          const lastUsed = t.last_used_at
            ? escapeHtml(t.last_used_at)
            : '<span class="muted">never</span>'
          return `<tr>
            <td><code>${escapeHtml(t.prefix)}&hellip;</code></td>
            <td>${label}</td>
            <td>${escapeHtml(t.created_at)}</td>
            <td>${lastUsed}</td>
            <td>${status}</td>
          </tr>`
        })
        .join('\n')
    : `<tr><td colspan="5" class="muted">No tokens yet.</td></tr>`
  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/">&larr; home</a></p>
      <h2>Profile</h2>
      <p class="muted">Signed in as ${escapeHtml(user.display_name || user.email || 'user')} (via ${escapeHtml(
        user.provider,
      )}).</p>
      ${newTokenBlock}
      <section class="profile-name">
        <h3>Display name</h3>
        <form method="post" action="/profile/name" class="profile-name-form">
          <input type="text" name="name" value="${escapeHtml(user.display_name || '')}" maxlength="100" required />
          <button type="submit">save</button>
        </form>
      </section>
      <section class="tokens">
        <h3>API tokens</h3>
        <p>Send a token in the <code>Authorization: Bearer &hellip;</code> header to call the <a href="/api">API</a> as yourself, so record matroids are attributed to you.</p>
        <table class="tokens-table">
          <thead><tr><th>Prefix</th><th>Name</th><th>Created</th><th>Last used</th><th></th></tr></thead>
          <tbody>${tokenRows}</tbody>
        </table>
        <form method="post" action="/profile/tokens" class="new-token-form">
          <label>Name (optional) <input type="text" name="name" maxlength="100" placeholder="e.g. laptop CLI" /></label>
          <button type="submit">Generate new token</button>
        </form>
      </section>
      ${userMatroidsSection(matroids)}
    </section>`
  return layout(`Profile — ${SITE_NAME}`, body, user)
}

export function apiDocsPage(user: User | null = null): string {
  const verifyReq = `curl -X POST https://matroid-correlation-constants.icarm.cloud/api/verify \\
  -H 'content-type: application/json' \\
  -H 'authorization: Bearer matroid_...' \\
  -d '{ "n": 4, "type": "matrix", "field": "3",
        "data": [[1,0,1,1],[0,1,1,2]],
        "provenance": "the uniform matroid U(2,4); classical" }'`
  const verifyResp = `{
  "ok": true,
  "n": 4,
  "rank": 2,
  "numBases": 6,
  "loops": [],
  "coloops": [],
  "alphaNum": 1,                    // α(M) as a reduced fraction ...
  "alphaDen": 4,
  "alphaValue": 0.25,               // ... and as a decimal
  "maximizingPairs": [[0,1], [0,2], [0,3], [1,2], [1,3], [2,3]],
  "maxCounts": { "containBoth": 1, "avoidBoth": 1, "onlyI": 2, "onlyJ": 2 },
  "field": "3",
  "record": { "recorded": true, "recordAlphaNum": 1, "recordAlphaDen": 4, "matroidId": 7 }
}`
  const basesReq = `{ "n": 4, "type": "bases",
  "data": [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]] }`
  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/">&larr; home</a></p>
      <h2>API</h2>

      <h3>POST <code>/api/verify</code></h3>
      <p>Verifies a matroid on ground set <span class="math">{0, &hellip;, n&minus;1}</span> and
      computes its correlation constant ${alphaVar}(<var>M</var>) exactly. The body is JSON with
      fields <code>n</code> (integer), <code>type</code> (one of <code>"matrix"</code>,
      <code>"bases"</code>, <code>"circuits"</code>, <code>"hyperplanes"</code>),
      <code>data</code>, an optional <code>provenance</code> string (attribution: discoverers,
      date, AI disclosure), and, for matrices, <code>field</code> &mdash; <code>"Q"</code>, a
      prime <code>"p"</code> for GF(p), or a prime power (<code>"4"</code> or
      <code>"2^2"</code>) up to order ${MAX_EXT_FIELD_ORDER} for GF(p<sup>d</sup>). For a matrix,
      <code>data</code> is a list of rows (columns are the elements). Over &#8474; entries may be
      integers or fraction strings like <code>"-3/5"</code>. Over GF(p<sup>d</sup>) with d &gt; 1,
      an entry is an integer (a prime-subfield constant, reduced mod p) or a coefficient list
      <code>[c0, c1, ...]</code> meaning c<sub>0</sub> + c<sub>1</sub>a + &hellip; where
      <var>a</var> is a root of the Conway polynomial C<sub>p,d</sub> &mdash; the same convention
      as Sage, GAP, and Macaulay2, so matrices copy across unchanged. For the other types,
      <code>data</code> is the complete list of bases, circuits, or hyperplanes as lists of
      element labels. Limits: n &le; ${MAX_ELEMENTS}, at most
      ${MAX_LISTED_SETS.toLocaleString('en-US')} listed sets or
      ${MAX_MATRIX_CELLS.toLocaleString('en-US')} matrix entries.</p>
      <p>Requires an <code>Authorization: Bearer &lt;token&gt;</code> header &mdash; create a token
      on your <a href="/profile">profile</a> page. Requests without a valid token receive
      <code>401</code>. A submission whose constant strictly beats the record for its ground-set
      size is saved and attributed to your account.</p>
      <pre><code>${escapeHtml(verifyReq)}</code></pre>
      <p>Returns <code>200</code> with the verdict, <code>401</code> without a valid token, or
      <code>400</code> when the body is malformed, the description violates the matroid axioms
      (the error pinpoints a failing exchange or circuit elimination), or a limit is exceeded.
      On success, <code>record.recorded</code> reports whether the record book changed; on a tie,
      <code>record.tiedExact</code> reports whether the submission is the record matroid itself
      (<code>true</code>) or a different matroid with the same constant (<code>false</code>).</p>
      <pre><code>${escapeHtml(verifyResp)}</code></pre>
      <p>The same matroid described by its bases instead:</p>
      <pre><code>${escapeHtml(basesReq)}</code></pre>

      <h3>GET <code>/database.json</code></h3>
      <p>All record matroids as one JSON download: <code>{ count, matroids }</code>, each with its
      <code>n</code>, <code>rank</code>, <code>num_bases</code>, exact <code>alpha</code> fraction,
      <code>representation_type</code> and full <code>representation</code>, <code>field</code>,
      canonical <code>bases</code> (omitted when very large), <code>max_pairs</code>,
      <code>max_counts</code>, <code>provenance</code>, <code>submitter</code>,
      <code>created_at</code>, and <code>current</code> (false for superseded records, which are
      kept as history). No auth required. Responses carry a strong <code>ETag</code>; conditional
      requests return <code>304</code> when nothing has changed.</p>
    </section>`
  return layout(`API — ${SITE_NAME}`, body, user)
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
  let maxPairs: [number, number][] = []
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
  const provenanceBlock = m.provenance
    ? `<section class="provenance">
        <h3>Attribution</h3>
        <div class="comment-body">${escapeHtml(m.provenance)}</div>
      </section>`
    : ''
  const body = `
    <section class="prose">
      <p class="page-nav"><a href="/">&larr; home</a> &nbsp;&middot;&nbsp; <a href="/matroids">all matroids</a></p>
      ${justRecorded ? `<p class="record-new">New record: the largest verified ${alphaVar} for n = ${m.n}. Saved. &#127941;</p>` : ''}
      <h2>matroid #${m.id}</h2>
      <dl class="stats">
        <div><dt>n</dt><dd><a href="/matroids?n=${m.n}" title="all record matroids for this ground-set size">${m.n}</a></dd></div>
        <div><dt>rank</dt><dd>${m.rank}</dd></div>
        <div><dt>bases</dt><dd>${m.num_bases.toLocaleString('en-US')}</dd></div>
        <div><dt>${alphaVar}(M)</dt><dd class="score">${fmtAlphaLong(m.alpha_num, m.alpha_den)}</dd></div>
      </dl>
      <dl class="witness-meta">
        <dt>status</dt><dd>${status}</dd>
        <dt>submitted by</dt><dd>${submitter}</dd>
        <dt>submitted at</dt><dd>${escapeHtml(m.created_at)} UTC</dd>
      </dl>
      <section class="representation">
        <h3>Description <span class="muted">(${escapeHtml(m.representation_type)})</span> ${fieldBadge(m.field)}</h3>
        <pre class="elements">${escapeHtml(formatListJson(m.representation))}</pre>
        ${basesBlock}
      </section>
      ${pairBlock}
      ${provenanceBlock}
      ${commentarySection(m.id, comment, user)}
    </section>`
  return layout(`matroid #${m.id} — ${SITE_NAME}`, body, user)
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
        <td>${escapeHtml(m.representation_type)}${m.field ? ` ${fieldBadge(m.field)}` : ''}</td>
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
      <table class="tokens-table witnesses-table">
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
