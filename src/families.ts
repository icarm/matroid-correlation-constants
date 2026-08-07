// The family pages: cards and per-family detail, rendered from the D1
// catalog (src/familyStore.ts). A family is a reviewed claim: proposals
// arrive 'pending' through the on-site form and an admin must accept one
// before it appears here and on the chart. All family-sourced text —
// including the TeX — is rendered HTML-escaped; MathJax reads the DOM text,
// so escaping costs the math nothing and makes proposals safe to render.

import { escapeHtml, familyEditSection, layout, type User } from './pages'
import { fmtFrac, type Family } from './familyData'

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

/** The AI-disclosure paragraph: curated rows carry handwritten prose, and
 * proposals compose one from the structured declaration. */
const disclosureHtml = (f: Family): string => {
  if (f.aiDisclosure) return escapeHtml(f.aiDisclosure)
  if (f.aiUsed === false) return 'The discovery record declares that no AI was used.'
  if (f.aiUsed === true) {
    const chat = f.aiChatUrl
      ? ` <a class="external" href="${escapeHtml(f.aiChatUrl)}">Public chat/run link.</a>`
      : ' No public chat link is recorded.'
    return `${escapeHtml(f.aiModel ?? '')} &mdash; ${escapeHtml(f.aiRole ?? '')}.${chat}`
  }
  return 'No AI-use declaration is recorded.'
}

const DEFAULT_PENDING_COLOR = '#8a8578'

export function familiesPage(
  families: Family[],
  pending: Family[],
  user: User | null = null,
): string {
  const cards = families
    .map(
      (f) => `
    <a class="family-card" href="/family/${escapeHtml(f.slug)}" style="--family-color: ${escapeHtml(f.color ?? DEFAULT_PENDING_COLOR)}">
      <p class="eyebrow">${claimBadge(f)}</p>
      <h3>${escapeHtml(f.name)}</h3>
      <p class="family-formula">\\(${escapeHtml(f.formulaTex)}\\)</p>
      <p class="family-summary">${escapeHtml(f.summary)}</p>
      <p class="family-meta">${supremumLine(f)}</p>
      <p class="family-meta muted">${escapeHtml(f.contributors)} &middot; ${escapeHtml(f.discoveryDate)}</p>
    </a>`,
    )
    .join('\n')
  const pendingSection =
    pending.length === 0
      ? ''
      : `
      <h3>Pending review <span class="muted">(admin)</span></h3>
      <ul class="pending-list">
        ${pending
          .map(
            (f) => `<li><a href="/family/${escapeHtml(f.slug)}">${escapeHtml(f.name)}</a>
              <span class="muted">&mdash; claims supremum ${fmtFrac(f.supremum.num, f.supremum.den)},
              proposed by ${escapeHtml(f.submitterName ?? 'unknown')}, ${escapeHtml(f.submittedAt)}</span></li>`,
          )
          .join('\n')}
      </ul>`
  const body = `
    <section class="prose">
      <p class="eyebrow">Parameterized constructions</p>
      <h2>Families</h2>
      <p>
        The curves on the <a href="/">Explore</a> chart, as objects: each family is a
        parameterized construction with a proved formula. A <em>solid</em> curve is a proved
        value of the full invariant; a <em>dashed</em> curve certifies a distinguished-pair
        lower bound. Proofs live on the <a href="/mathematics">mathematics page</a> or behind each
        family&rsquo;s own proof link.
      </p>
      <div class="family-grid">${cards}</div>
      ${pendingSection}
      <h3 id="propose">Propose a family</h3>
      <p>
        Unlike concrete matroids, a family claim &mdash; a formula for every parameter, a
        supremum &mdash; cannot be verified by enumeration; it needs a proof and human review.
        Propose one with the <a href="/#submit-family">submission form</a> (switch it to
        &ldquo;infinite family&rdquo;): the parameter domain, the construction, the exact curve
        values, the claimed supremum, a proof or stable reference, and the discovery record
        with an AI-use declaration. Proposals wait as <em>pending</em> until a site admin
        reviews the mathematics and accepts them &mdash; nothing is automatic &mdash; and an
        accepted family gains its curve, card, and page together.
      </p>
      <p>
        A strong proposal comes with evidence: <a href="/#submit">verify your family&rsquo;s
        small members</a> through the concrete form first &mdash; each one becomes a
        machine-checked record entry reviewers can lean on, as the uniform self-sum family's
        members \\(P_2,\\ldots,P_5\\) do.
      </p>
      <p class="hero-actions">
        <a class="hero-cta" href="/#submit-family">Propose a family</a>
      </p>
    </section>`
  return layout('Families — Matroid Correlation Constants', body, user, MATHJAX_HEAD)
}

/** The review panel an admin sees on a pending proposal. */
function reviewPanel(f: Family): string {
  const extraordinary =
    3 * f.supremum.num >= 4 * f.supremum.den
      ? `<p class="review-flag">&#9888; Claims a supremum of ${fmtFrac(f.supremum.num, f.supremum.den)}
         &ge; 4/3 &mdash; an extraordinary claim; review the proof with extra scrutiny.</p>`
      : ''
  return `
      <section class="panel review-panel">
        <h3>Review this proposal <span class="muted">(admin)</span></h3>
        ${extraordinary}
        <p class="muted">Accepting publishes the family: its curve joins the chart and its card
        the catalog. The screen above verified only shapes and bounds, no mathematics.</p>
        <form method="post" action="/family/${escapeHtml(f.slug)}/review">
          <label for="review-note">Note <span class="hint">(recorded with the decision; shown to the submitter)</span></label>
          <textarea id="review-note" name="note" rows="2" maxlength="2000"></textarea>
          <div class="review-actions">
            <button type="submit" name="action" value="accept">Accept &mdash; publish</button>
            <button type="submit" name="action" value="reject" class="danger">Reject</button>
          </div>
        </form>
      </section>`
}

function statusBanner(f: Family): string {
  if (f.status === 'pending') {
    return `<div class="status-banner pending"><strong>Pending review.</strong> This proposal is
      visible only to its submitter and the site admins until an admin accepts it.</div>`
  }
  if (f.status === 'rejected') {
    const note = f.reviewNote
      ? ` <span class="muted">Reviewer&rsquo;s note: ${escapeHtml(f.reviewNote)}</span>`
      : ''
    return `<div class="status-banner rejected"><strong>Not accepted.</strong> This proposal was
      reviewed and declined; it is visible only to its submitter and the site admins.${note}</div>`
  }
  return ''
}

export function familyPage(f: Family, user: User | null = null, viewerIsAdmin = false): string {
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
      <h4>${
        s.label
          ? `${escapeHtml(s.label)} <span class="muted">(${s.points.length} plotted members)</span>`
          : `<span class="muted">${s.points.length} plotted members</span>`
      }</h4>
      <div class="family-table-scroll">
        <table class="tokens-table family-table">
          <thead><tr><th>parameter</th><th class="num">|E|</th><th class="num">rank</th>
            <th class="num">${f.claim === 'exact' ? 'α' : 'R<sub>ef</sub>'}</th><th class="num">&approx;</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>`
    })
    .join('\n')
  const proofLink = f.mathAnchor
    ? ` <a href="/mathematics#${escapeHtml(f.mathAnchor)}">Full proof on the mathematics page &rarr;</a>`
    : f.proofUrl
      ? ` <a class="external" href="${escapeHtml(f.proofUrl)}">Proof / reference &rarr;</a>`
      : ''
  const submitterLine = f.submitterName
    ? `<dt>proposed by</dt><dd>${escapeHtml(f.submitterName)}</dd>`
    : ''
  const body = `
    <section class="prose family-page" style="--family-color: ${escapeHtml(f.color ?? DEFAULT_PENDING_COLOR)}">
      <p class="page-nav"><a href="/families">&larr; all families</a></p>
      ${statusBanner(f)}
      <p class="eyebrow">${claimBadge(f)}</p>
      <h2>${escapeHtml(f.name)}</h2>
      <p>${escapeHtml(f.summary)}</p>
      <div class="math-panel emphasized">
      \\[ ${escapeHtml(f.formulaTex)} \\]
      \\[ ${escapeHtml(f.sizeRankTex)} \\]
      </div>
      <dl class="detail-meta">
        <dt>parameter</dt><dd>${escapeHtml(f.parameter)}</dd>
        <dt>supremum</dt><dd>${supremumLine(f)}</dd>
        <dt>discovered by</dt><dd>${escapeHtml(f.contributors)}</dd>
        <dt>discovery date</dt><dd>${escapeHtml(f.discoveryDate)}</dd>
        ${submitterLine}
      </dl>
      <h3>Construction</h3>
      <p>${escapeHtml(f.construction)}</p>
      <h3>What the curve shows</h3>
      <p>${escapeHtml(f.curveExplanation)}</p>
      <h3>Proof status</h3>
      <p>${escapeHtml(f.proofStatus)}${proofLink}</p>
      <h3>AI disclosure</h3>
      <p>${disclosureHtml(f)}</p>
      <h3>Plotted members</h3>
      ${seriesTables}
      ${viewerIsAdmin && f.status === 'pending' ? reviewPanel(f) : ''}
      ${viewerIsAdmin && f.status !== 'rejected' ? familyEditSection(f, user) : ''}
    </section>`
  return layout(`${f.name} — Matroid Correlation Constants`, body, user, MATHJAX_HEAD)
}
