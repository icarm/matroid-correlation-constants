# matroid-correlation-constants

This (main) is the Workers/D1/KV record-book site. The `github-flow`
branch holds Chris Eur's static site + Julia verifier stack and its
GitHub-issue intake (dormant unless that branch is made default); its
Pages deploys still run from pushes to that branch.

A record-keeping site for matroid correlation constants
(α(M) = max over pairs of B[∋i,∋j]·B[∌i,∌j] / (B[∋i,∌j]·B[∌i,∋j])).
Cloudflare Workers + Hono + D1 + KV, in the style of the sibling repos
`icarm/ruzsa-genus-one` and `icarm/elliptic-rank`. The visual design and
much of the feature set follow Chris Eur's draft site (handoff zip at
`~/Desktop/ICARM_matroid_correlation_handoff_2026-08-04.zip`; his trusted
Julia verifier lives there and agrees with ours on every cross-checked
case).

## Map

- `src/verify.ts` — the exact verifier. Reduces any description (matrix
  over ℚ/GF(p)/GF(p^d≤1024, Conway basis, computed not transcribed);
  bases; circuits; hyperplanes) to a stream of basis bitmasks in ascending
  (colex) order, checks the matroid axioms, and computes α by exact
  BigInt cross-multiplication. Bases are never stored in memory: O(n²)
  pair-count accumulators, first-5000 masks for display JSON, and a
  chunked sync-SHA-256 canonical hash. Limits: n ≤ 30 gated by the
  independent-set budget (2^25; everything n ≤ 24 passes), circuits/
  hyperplanes ≤ 24 (2^n DP), 5000 sets/cells, op budgets.
- `src/store.ts` — D1 persistence. Records are field-keyed (decided with
  Chris Eur, 2026-08): the book holds the best ᾱ over each of GF(2),
  GF(3), GF(4), GF(5), GF(7) — a field record needs a matrix over that
  field (a GF(2) matrix also contends for GF(4), the one subfield pair)
  and falls only to a strictly larger ᾱ — plus the permanent "4/3 club"
  (ᾱ ≥ 4/3, any description). Rank and ground-set size confer nothing.
  `record_titles` is append-only (current field record = max title id per
  field; club rows have field NULL); matroids rows superseded as records
  stay as history. The pure policy lives in `src/recordPolicy.ts`
  (node-importable, tested by test-records.mjs). Comparison happens in JS
  BigInt (SQL cross-mult overflows) with optimistic-concurrency guarded
  title INSERTs. Matroid identity is canonical-hash equality; a matrix
  over a field the stored row lacks attaches as a representability
  certificate (cert_field/cert_matrix, one slot). Entering the record
  book requires a discovery record (discoverers, date, AI-use
  declaration) — verification alone does not.
- `src/index.ts` — routes; also claimed-α parsing/cross-check (mismatch
  rejects with both values) and discovery-metadata validation. Submission
  is form-only: the JSON API and bearer tokens were removed 2026-08 (the
  site emphasizes humans filling out the forms; restore from git history
  before commit "Remove the JSON API" if demand appears). Per-matroid
  commentary was switched off the same way (any-account free-text writes
  = moderation surface; Zulip is the discussion venue). The api_tokens,
  commentary_log tables and matroids.current_comment_id remain in D1,
  dormant.
- `src/zulip.ts` — announces record-book entries to the ICARM Zulip topic
  via a slack_incoming webhook, as in the sibling ruzsa-genus-one. Fired
  with `waitUntil` from the submit route; the `ZULIP_WEBHOOK_URL` secret
  (`wrangler secret put`) bakes in stream + topic, unset = silently off.
- `src/pages.ts` — server-rendered template-literal pages. `src/mathematics.ts`
  — the proofs page (the only page loading MathJax, from CDN).
- `src/familyData.ts` — the family model (types + chart-data mapper);
  the data lives in the D1 `families` table (seeded from the old catalog
  by migration 0008). `src/familyStore.ts` — family persistence and the
  pure proposal validation (exercised by test-families.mjs): proposals
  from the landing form's "infinite family" tab land status='pending',
  visible only to submitter + admins (users.is_admin, read fresh from D1
  on admin paths, never from the session), until an admin accepts
  (assigns a palette color, publishes curve/card/page) or rejects. Both
  decisions reverse post-hoc from the family's page (reject retracts an
  accepted family; accept republishes a rejected one — mistaken reviews
  are undoable), though rejected rows stay frozen for edits. All
  family-sourced text incl. TeX renders HTML-escaped; MathJax reads DOM
  text, so escaping is free and makes proposals safe. The landing page
  injects accepted families (with the record points) as `#chart-data`
  JSON for the explorer.
- `public/chart.js` — the interactive explorer; all data arrives via the
  injected JSON. Progressive enhancement: server-rendered SVG stays
  without JS. Same pattern as the form's placeholder script.
- `public/style.css` — design tokens in `:root`, Chris's paper/teal/rust
  palette, serif display headings.

## Conventions and invariants

- Verification is exact everywhere: no floating point in any verdict, no
  execution of submitted content. Any change to the canonical hash scheme
  needs a data migration (see 0005) — hashes feed exact-tie detection.
- `VERIFIER_VERSION` (src/verify.ts) is stamped on stored rows; bump it
  when verification semantics change.
- Migrations are append-only in `migrations/`; several contain
  data backfills targeted at known row ids of the production DB.
- Tests: `npm test` (node ≥ 22.6 runs the .ts directly). The suite pins
  known matroids (uniform via all four descriptions, HSW spikes with the
  paper's closed-form counts, the 100/81 benchmark, Conway polynomial
  values, budget boundaries). Cross-validation harnesses against Chris's
  Julia verifier live in scratch, not the repo.

## Workflows

    npm run dev            # wrangler dev (hot-reloads)
    npm run typecheck
    npm test
    npx wrangler d1 migrations apply matroid-correlation-constants --local

Deploy is manual (CI, .github/workflows/test.yml, only typechecks and
tests; it was given no Cloudflare token because the needed permissions
were too broad). This environment has no wrangler auth — the user runs it:

    npx wrangler d1 migrations apply matroid-correlation-constants --remote
    npm run deploy

Live at https://matroid-correlation-constants.icarm.cloud. (A now-inert
production API token may linger at `~/.matroid-correlation-token.txt` —
the JSON API was removed 2026-08.)

## Known follow-ups (agreed with the user)

- Multi-certificate table: a field-record holder over several fields can
  today store only one extra representation (the single cert_field/
  cert_matrix slot).
- Records table beside the plot; structure flags (simple/connected/
  paving) for explorer filters. (The old GitHub-issue family intake was
  removed when the on-site proposal form + admin review landed.)
- If weighted-alpha support ever lands: the matroids table needs an
  invariant column (everything today is the unweighted constant), with
  separate records per invariant — mirror the catalog convention on main.
- Construction-expression DSL deliberately deferred (see project memory).
