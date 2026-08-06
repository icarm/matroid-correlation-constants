# matroid-correlation-constants (main: static site + Julia verifier)

This branch is Chris Eur's stack, adopted as primary on 2026-08-05:

- `matroid_correlation_website/` — the static site, deployed to
  Cloudflare Pages by `.github/workflows/deploy-website.yml` on pushes
  to main (project `matroid-correlation-website`; served at
  https://matroid-correlation.icarm.cloud, with
  matroid-correlation-website.pages.dev as the underlying URL).
- `src/`, `scripts/`, `test/` — the trusted Julia verifier (Oscar-based;
  basis enumeration optimized by shared-work DFS, outputs byte-identical
  to the handoff version). `julia --project=. test/runtests.jl`.
- `.github/ISSUE_TEMPLATE/` + issue workflows — GitHub-issue submission
  intake: `[Concrete]` issues are verified exactly in CI; `[Family]`
  issues get numeric threshold screening. Active only while this is the
  repository's default branch.

Data convention: every catalog entry and certificate names its invariant
("unweighted-alpha-bar" today; a future weighted alpha would use
"weighted-alpha" with separate records/curves/leaderboards — never merged
or compared across invariants; weighted claims are not machine-verifiable
and would go through proof review like families).

The `cloudflare-workers` branch holds the Workers/D1/KV record-book site
previously served at matroid-correlation-constants.icarm.cloud (its own
CLAUDE.md documents it); its TypeScript verifier cross-validates this
branch's Julia verifier.
