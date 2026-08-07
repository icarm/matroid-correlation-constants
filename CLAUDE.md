# matroid-correlation-constants (branch: github-flow — static site + Julia verifier)

This branch is Chris Eur's stack (site + verifier + GitHub intake):

- `matroid_correlation_website/` — the static site, deployed to
  Cloudflare Pages by `.github/workflows/deploy-website.yml` on pushes
  to this branch (project `matroid-correlation-website`; served at
  https://matroid-correlation.icarm.cloud, with
  matroid-correlation-website.pages.dev as the underlying URL).
- `src/`, `scripts/`, `test/` — the trusted Julia verifier (Oscar-based;
  basis enumeration optimized by shared-work DFS, outputs byte-identical
  to the handoff version). `julia --project=. test/runtests.jl`.
- `.github/ISSUE_TEMPLATE/` + issue workflows — GitHub-issue submission
  intake: `[Concrete]` issues are verified exactly in CI; `[Family]`
  issues get numeric threshold screening. NOTE: GitHub serves issue
  templates and runs issue-triggered workflows only from the default
  branch, so this intake is dormant while main (the Workers stack) is
  default.

Data convention: every catalog entry and certificate names its invariant
("unweighted-alpha-bar" today; a future weighted alpha would use
"weighted-alpha" with separate records/curves/leaderboards — never merged
or compared across invariants; weighted claims are not machine-verifiable
and would go through proof review like families).

The `main` branch (default) holds the Workers/D1/KV record-book site
served at matroid-correlation-constants.icarm.cloud (its own CLAUDE.md
documents it); its TypeScript verifier cross-validates this branch's
Julia verifier.
