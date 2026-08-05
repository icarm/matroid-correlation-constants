# Matroid correlation constants

A record-keeping site for the correlation constants of matroids: live at
[matroid-correlation-constants.icarm.cloud](https://matroid-correlation-constants.icarm.cloud).

## The problem

Choose a basis of a matroid M uniformly at random. For distinct elements
i, j, write B[∋i,∋j] for the number of bases containing both, B[∌i,∌j] for
the number avoiding both, and so on. The correlation constant is

    α(M) = max over i ≠ j of  B[∋i,∋j]·B[∌i,∌j] / (B[∋i,∌j]·B[∌i,∋j])

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
  list of bases, circuits, or hyperplanes.
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
  its ground-set size n is saved and attributed; beaten records are kept as
  history. The landing page plots the record α against n with the
  negative-correlation barrier (1) and the 4/3 challenge drawn in.
- **Matroid pages** with the description, the maximizing pair's 2×2 basis
  counts, optional attribution (discoverers, date, AI disclosure), and a
  single editable commentary each (full edit history kept), plus a
  paginated recent-activity feed.
- **JSON API** (`POST /api/verify`, bearer tokens managed on the profile
  page) and a full database download (`GET /database.json`). Docs at
  [/api](https://matroid-correlation-constants.icarm.cloud/api).

Infinite families are out of scope for direct submission — they need human
proof review and are handled via pull requests instead.

## Architecture

[Cloudflare Workers](https://developers.cloudflare.com/workers/) with
[Hono](https://hono.dev). Users, matroids, commentary, and API tokens live
in D1 (`migrations/`); login sessions and post-submit result flashes live in
KV. Session cookies and API tokens are stored only as SHA-256 hashes.

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

    npx wrangler d1 migrations apply matroid-correlation-constants --remote
    npm run deploy

One-time setup: create the D1 database and KV namespace (ids in
`wrangler.jsonc`), and set `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` via
`wrangler secret put` from a GitHub OAuth app whose callback URL is
`https://matroid-correlation-constants.icarm.cloud/auth/github/callback`.
