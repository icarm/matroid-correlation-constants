// The family pages: cards and per-family detail, rendered from the shared
// catalog in familyData.ts. Family *submissions* need human proof review and
// are out of scope for the form/API; accepted proposals are added to
// familyData.ts by pull request.

import { escapeHtml, layout, type User } from './pages'
import { FAMILIES, fmtFrac, type Family } from './familyData'

const MATHJAX_HEAD = `
    <script>
      window.MathJax = { tex: { processEscapes: true }, chtml: { scale: 0.98 } };
    </script>
    <script defer src="https://cdn.jsdelivr.net/npm/mathjax@4/tex-chtml.js"></script>`

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
  return `supremum ${fmtFrac(f.supremum.num, f.supremum.den)} &mdash; ${kind}`
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
            <td class="num">${fmtFrac(p.num, p.den)}</td>
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
