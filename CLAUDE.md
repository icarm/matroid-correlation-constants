# matroid-correlation-constants (branch: cloudflare-workers)

Since 2026-08-05 the repository default branch (main) carries Chris
Eur's static site + Julia verifier stack; this branch holds the
Workers/D1/KV record-book site described below.

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
- `src/store.ts` — D1 persistence. Records are per ground-set size n,
  append-only, strictly increasing within an n (so current record =
  max id per n). Record comparison happens in JS BigInt (SQL cross-mult
  overflows past n = 18) with an optimistic-concurrency guarded INSERT.
  Exact ties are detected by canonical hash; a tying matrix over a new
  field attaches as a representability certificate (cert_field/
  cert_matrix). Entering the record book requires a discovery record
  (discoverers, date, AI-use declaration) — verification alone does not.
- `src/index.ts` — routes; also claimed-α parsing/cross-check (mismatch
  rejects with both values) and discovery-metadata validation.
- `src/pages.ts` — server-rendered template-literal pages. `src/mathematics.ts`
  — the proofs page (the only page loading MathJax, from CDN).
- `src/familyData.ts` — the family catalog, single source of truth:
  family pages render from it and the landing page injects it (with the
  record points) as `#chart-data` JSON for the explorer. Accepted family
  proposals are added here by PR.
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

Deploy: pushes to this branch (cloudflare-workers) on GitHub run .github/workflows/deploy.yml
(typecheck + tests, then remote migrations, then wrangler deploy; needs
the CLOUDFLARE_API_TOKEN repo secret). Manual fallback (this environment
has no wrangler auth — the user runs it):

    npx wrangler d1 migrations apply matroid-correlation-constants --remote
    npm run deploy

Live at https://matroid-correlation-constants.icarm.cloud. A production
API token may be present at `~/.matroid-correlation-token.txt`.

## Known follow-ups (agreed with the user)

- Tier 2 schema: multi-certificate table; store field-record-beaters that
  lose to their n-record (breaks the max-id-per-n invariant — rework
  is_current when doing this). Prerequisite for field leaderboards.
- Challenges section with per-field leaderboards (thresholds in the
  draft's `submission-eligibility-policy.json`).
- Records table beside the plot; structure flags (simple/connected/
  paving) for explorer filters. Family-proposal intake is BUILT
  (.github/ISSUE_TEMPLATE/propose-family.yml + screening workflow +
  /families CTA) — it activates when issues open on the GitHub repo.
- Construction-expression DSL deliberately deferred (see project memory).
