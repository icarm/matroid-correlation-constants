# Matroid correlation constants

A record-keeping site for the correlation constants of matroids: live at
[matroid-correlation-constants.icarm.cloud](https://matroid-correlation-constants.icarm.cloud).

This website was created by Chris Eur using ChatGPT-5.6 Sol Max. (His
original implementation lives on the `github-flow` branch.)

## The problem

Choose a basis of a matroid M uniformly at random. For distinct elements
i, j, write B_ij for the set of bases containing both, B^ij for the set
avoiding both, and B^i_j for the set avoiding i and containing j
(subscripts contained, superscripts avoided). The correlation constant is

    α(M) = max over i ≠ j of  |B^ij|·|B_ij| / (|B^i_j|·|B^j_i|)

(maximum over nonloop, noncoloop pairs). α(M) ≤ 1 means every pair is
negatively correlated; this holds for graphic, regular, and many other
matroids, but not in general. [Huh–Schröter–Wang](https://arxiv.org/abs/1806.02675)
proved α(M) ≤ 2 for every matroid and reached 8/7; the largest verified
value is 100/81 (12 elements over GF(3), August 2026), and known infinite
families approach 4/3. The challenge: a concrete matroid with α(M) ≥ 4/3.

## The site

- **Submit matroids** (GitHub login required) as a matrix over ℚ or a
  finite field — any prime GF(p), or GF(p^d) up to order 1024 using the
  Conway polynomial convention (as in Sage/GAP/Macaulay2; the polynomials
  are computed from the definition, not transcribed) — or as the complete
  list of bases, circuits, or hyperplanes. An optional claimed α is
  cross-checked exactly, so a record entry is a verified claim; entering
  the record book requires a discovery record (discoverers, date, and an
  explicit AI-use declaration). An exact resubmission of a record as a
  matrix attaches a representability certificate instead of being
  discarded.
  Verification is pure TypeScript (`src/verify.ts`): the matroid axioms are
  checked (basis exchange, or the circuit axioms), every basis is
  enumerated, and all ratios are compared by exact integer cross
  multiplication. Bases stream through constant-memory accumulators — the
  pair counts behind α, a canonical JSON kept only while small, and a
  chunked SHA-256 of the ascending mask stream (the canonical matroid hash
  used for exact-tie detection) — so nothing scales with the number of
  bases. Limits: n ≤ 30, ≤ 5,000 listed sets, ≤ 5,000 matrix entries. (The
  ceiling is enumeration CPU: everything on ≤ 24 elements is accepted;
  beyond that, only ranks whose independent sets number at most 2^25 —
  e.g. rank ≤ 12 at n = 26, rank ≤ 9 at n = 30, ~45 s worst. Circuit and
  hyperplane descriptions stop at 24 elements, since their axiom checks
  tabulate all 2^n subsets.)
- **Records.** A submission whose constant strictly beats the record for
  its ground-set size n is saved and attributed; beaten records are kept
  as history. The landing page opens with a hero and an interactive
  explorer (`public/chart.js`, progressive enhancement over a
  server-rendered SVG): every stored matroid plotted against the twelve
  known family curves, with the draft site's filters and the 4/3 target
  line. Families live in the database too: a family is a reviewed claim
  (a formula for every parameter cannot be verified by enumeration), so
  the submission form's "infinite family" tab files a proposal — formula,
  construction, exact curve values, proof link, discovery record — that
  stays pending until a site admin accepts it, at which point it gains
  its curve, card, and `/family/:slug` page together. A `/mathematics` page
  carries the definitions, background, and full proofs of the family
  formulas (the one page that loads MathJax).
- **Matroid pages** with the description, the maximizing pair's 2×2 basis
  counts, and optional attribution (discoverers, date, AI disclosure),
  plus a paginated recent-activity feed.
- **Open data**: the full record book as one JSON download
  (`GET /database.json`, ETag-revalidated). Submissions themselves are
  form-only — the site emphasizes humans filling out the forms, and the
  earlier JSON API (bearer tokens, `POST /api/verify`) was removed; it
  can be restored from git history if programmatic demand appears.

Infinite families are out of scope for direct submission — they need human
proof review and are handled via pull requests instead.

## Architecture

[Cloudflare Workers](https://developers.cloudflare.com/workers/) with
[Hono](https://hono.dev). Users, matroids, and families live in D1
(`migrations/`); login sessions and post-submit result flashes live in
KV. Session cookies are stored only as SHA-256 hashes.

## Development

    npm install
    npx wrangler d1 migrations apply matroid-correlation-constants --local
    npm run dev        # local server
    npm run typecheck
    npm test           # verifier tests (Node 22.6+)

GitHub login needs a dev OAuth app (callback
`http://localhost:8787/auth/github/callback`) with its credentials in
`.dev.vars`:

    GITHUB_CLIENT_ID=...
    GITHUB_CLIENT_SECRET=...

## Deploy

Pushes to `main` on GitHub deploy automatically
(`.github/workflows/deploy.yml`): typecheck and tests run first, then the
remote D1 migrations are applied, then the worker is deployed. The workflow
needs a `CLOUDFLARE_API_TOKEN` repository secret (the "Edit Cloudflare
Workers" token template, plus D1 edit permission for migrations).

Manual deploys work the same way:

    npx wrangler d1 migrations apply matroid-correlation-constants --remote
    npm run deploy

One-time setup: create the D1 database and KV namespace (ids in
`wrangler.jsonc`), and set `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` via
`wrangler secret put` from a GitHub OAuth app whose callback URL is
`https://matroid-correlation-constants.icarm.cloud/auth/github/callback`.
