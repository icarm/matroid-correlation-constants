# ICARM engineering handoff: Matroid Correlation Constants

Handoff date: 2026-08-04

This document is for the ICARM engineer receiving the first deployable draft
of **Matroid Correlation Constants**. The mathematical site, submission forms,
exact concrete-matroid verifier, and preliminary eligibility automation are
implemented. The main unfinished work is operational deployment and a safe
human-reviewed path from a verified GitHub issue into the published catalog.

## Executive summary

The project has two deliberately separate parts:

1. `matroid_correlation_website/` is a static site. It can be served from a
   subdirectory without running Julia or installing packages.
2. `.github/`, `src/`, and `scripts/` implement GitHub-mediated submissions.
   Trusted GitHub Actions code parses inert form data, runs Julia, comments on
   the issue, assigns an eligibility label, and uploads artifacts.

No submission is automatically published. The status `accepted and
published` is human-only, and the catalog in
`matroid_correlation_website/catalog.js` must currently be edited and deployed
manually.

## Automated flows

### Concrete matroid

```text
GitHub Issue Form
    -> inert form parser
    -> exact matroid reconstruction and axiom checks
    -> exact computation of every eligible pair ratio
    -> comparison with the claimed value
    -> challenge-policy classification
    -> bot comment + one status label + JSON artifacts
    -> human review
    -> manual catalog update and deployment
```

Relevant files:

- `.github/ISSUE_TEMPLATE/concrete-matroid.yml`
- `.github/workflows/verify-matroid-issue.yml`
- `scripts/verify_matroid_issue.jl`
- `src/MatroidIssueIntake.jl`
- `src/MatroidSubmissionVerifier.jl`
- `src/SubmissionEligibility.jl`
- `schemas/matroid-submission.schema.json`

### Infinite family

```text
GitHub Issue Form
    -> parse the separately entered exact numerator and denominator
    -> compare the claimed supremum or limsup with 4/3
    -> bot comment + one status label + JSON artifact
    -> human review of every mathematical assertion and proof
    -> manual catalog update and deployment
```

Relevant files:

- `.github/ISSUE_TEMPLATE/infinite-family.yml`
- `.github/workflows/classify-family-issue.yml`
- `scripts/classify_family_issue.jl`
- `src/SubmissionEligibility.jl`

The family workflow is intentionally only a numeric screen. Its result says
`verification_scope: claimed-family-limit-only` and
`mathematical_proof_verified: false`.

## Eligibility policy

The authoritative machine-readable policy is
`matroid_correlation_website/data/submission-eligibility-policy.json`.

The current rules are:

| Challenge | Automatic comparison |
|---|---|
| Finite value on the nose | Verified full value at least (4/3) |
| Infinite family in the limit | Claimed exact supremum or limsup at least (4/3); proof remains human-reviewed |
| (operatorname{GF}(2)) record | Verified exact-field representation and value strictly greater than (8/7) |
| (operatorname{GF}(3)) record | Verified exact-field representation and value strictly greater than (100/81) |
| (operatorname{GF}(5)) record | Verified exact-field representation and value strictly greater than (8/7) |
| (operatorname{GF}(7)) record | Verified exact-field representation and value strictly greater than (8/7) |

The four public states are:

1. `eligible-for-review` — an automatic threshold is met;
2. `below-publication-thresholds` — the input is validly screened or exactly
   verified but no current challenge is met;
3. `verification-failed` — form validation or exact verification failed; and
4. `accepted-and-published` — a curator reviewed the result and updated the
   public catalog.

The workflows create and maintain matching GitHub labels. They never assign
`accepted and published`. A curator may apply it after publication. Editing an
issue reruns automation and resets it to an automatic state, forcing material
edits to be reviewed again.

## What is implemented

- Static responsive website with MathJax rendering.
- Ground-set-size/rank horizontal-axis toggle.
- Exact concrete and asymptotic family records with discovery dates, credits,
  references, and AI-use disclosures.
- GitHub Issue Forms; no pull request is required from a submitter.
- Concrete descriptions by matrix, complete bases, complete circuits, or
  complete hyperplanes.
- Matrices over (mathbb Q) and finite fields, including extension fields.
- Optional matrix representability certificates for combinatorial inputs.
- Exact recomputation of (overline{alpha}) over all eligible pairs.
- Required discovery date, discoverers, AI-use declaration, model/version, and
  AI-role description; an optional public chat link is retained.
- GitHub's issue creation time retained separately as the submission date.
- Machine-readable eligibility policy and exact finite-field comparisons.
- Numeric family-limit screening with an explicit warning that the proof is
  not verified.
- Automatic bot comments, classification labels, and downloadable workflow
  artifacts.
- Julia regression suite, deterministic concrete fixture, and family issue
  fixture.

## Security and trust boundary

The public submission is never evaluated as Julia, Python, JavaScript, shell,
or a symbolic expression. The trusted default-branch workflow accepts only
bounded data:

- a maximum of 18 ground-set elements;
- at most 5000 listed sets;
- at most 5000 matrix cells;
- at most 8 additional representation certificates; and
- a 15-minute concrete verification job timeout.

All ratio comparisons are exact integer cross-multiplications. Field matrices
are normalized by trusted code. Unverified issues never enter the static
catalog automatically.

The workflows require only:

```yaml
permissions:
  contents: read
  issues: write
```

No project secret is currently required.

## Required deployment work

These steps have not been performed in this local handoff:

1. Create or choose the official GitHub repository and place the handoff
   contents at its root, preserving `.github/`.
2. Enable GitHub Issues and GitHub Actions.
3. Confirm that the organization permits the pinned action families used by
   the workflows:
   `actions/checkout`, `julia-actions/setup-julia`,
   `actions/github-script`, and `actions/upload-artifact`.
4. Confirm that workflow `issues: write` permission is allowed. The workflow
   needs it to comment and create/update classification labels.
5. Create the two optional submission labels, `submission: concrete` and
   `submission: family`. Issue templates do not create missing labels.
   Classification labels are created by the workflows on first use.
6. Set `siteConfig.githubRepositoryUrl` in
   `matroid_correlation_website/catalog.js` to the official
   `https://github.com/OWNER/REPOSITORY` URL. It is intentionally blank in the
   handoff because the destination repository is not yet known.
7. Deploy only `matroid_correlation_website/` to the public static host.
   Preserve relative paths and serve `.js`, `.json`, `.svg`, and `.css` with
   the normal MIME types.
8. Open one test concrete issue and one test family issue. Verify the bot
   comment, label, and uploaded artifact in each workflow.
9. Decide who has curatorial authority to apply `accepted and published` and
   update the catalog.

For an ICARM-hosted static page rather than GitHub Pages, step 6 is mandatory:
the site cannot infer a GitHub repository from a non-`github.io` hostname.

## Highest-priority remaining engineering work

### 1. Human-reviewed catalog promotion

There is no promotion bot yet. A recommended follow-up is a maintainer-only
`workflow_dispatch` action that:

1. takes an issue number and immutable workflow artifact or certificate;
2. reruns exact verification from the trusted default branch;
3. refuses any result not currently `eligible-for-review`, unless an explicit
   curator override and reason are supplied;
4. checks for an exact duplicate against accepted catalog entries;
5. generates, but does not directly publish, a deterministic catalog patch;
6. opens a pull request requiring mathematical and provenance review;
7. records the issue URL, discovery date, submission date, AI disclosure,
   policy version, and certificate hash; and
8. applies `accepted and published` only after the pull request is merged and
   the site deployment succeeds.

Do not let an issue-triggered workflow push directly to the default branch.

### 2. Persistent accepted data

Issue artifacts currently expire after 30 days. Accepted normalized inputs and
certificates should be committed to a versioned directory or copied to durable
object storage. The public catalog should be generated from those accepted
records rather than remaining hand-maintained JavaScript indefinitely.

### 3. Prevent policy/catalog drift

Finite-field thresholds are centralized in the JSON policy, but the accepted
records are still separately represented in `catalog.js`. Add a CI check that
derives each supported field record from accepted certificates and fails when
the policy disagrees.

### 4. Family review process

Create a reviewer checklist covering:

- precise parameter domain and existence conditions;
- whether the plotted ordinate is the full invariant or only a certified
  lower bound;
- exact finite formula;
- supremum or limsup calculation;
- attainment status;
- representability claims;
- proof completeness and references;
- discovery history and AI disclosure; and
- reproducible small cases when appropriate.

Family threshold screening alone is not evidence that any mathematical claim
is true.

### 5. Duplicate and isomorphism handling

The batch verifier detects exact duplicate basis encodings within one batch.
The issue workflow does not yet compare a submission with every accepted
matroid up to isomorphism. Add an accepted-certificate index and decide whether
isomorphic matroids with materially different representations or provenance
should be separate catalog records.

## Other decisions and hardening

- Select and add an explicit software/content license.
- Add `CODEOWNERS`, branch protection, required reviews, and required CI checks.
- Decide whether equality with an existing finite-field record should ever be
  accepted for independent provenance; the automatic policy currently
  requires a strict improvement.
- Decide whether fields beyond (2,3,5,7) should receive leaderboards.
- Distinguish exact (operatorname{GF}(q)) certificates from
  representability merely in characteristic (p); the current verifier
  correctly counts only the exact certified field for a field record.
- Consider validating real calendar dates rather than only the current
  `YYYY-MM`/`YYYY-MM-DD` syntax.
- Add per-account operational quotas if the issue volume becomes abusive.
- Review GitHub Actions major-version pins and Julia 1.12 compatibility under
  ICARM's supply-chain policy.
- Decide whether MathJax should remain CDN-hosted or be vendored for a stricter
  content-security policy.
- Run accessibility, mobile-browser, and link checks on the final ICARM host.
- Add monitoring for failed Actions runs and static-site deployment failures.

## Local validation commands

From the project root:

```bash
julia --project=. test/runtests.jl
```

Verify and classify the concrete example:

```bash
julia --project=. scripts/verify_matroid_submissions.jl \
  examples/submissions/uniform-u2-4-matrix.json \
  /tmp/uniform-u2-4.certificate.json
```

Exercise the family threshold fixture:

```bash
julia --project=. scripts/classify_family_issue.jl \
  test/fixtures/family-issue-event.json \
  /tmp/family-classification.json
```

Preview the static site:

```bash
python3 -m http.server 8000 --directory matroid_correlation_website
```

Then open `http://localhost:8000/`. Stop the server with `Ctrl-C`.

## Form-maintenance warning

The issue parsers use the visible Issue Form headings as stable field names.
If a label such as `Discovery date` or `Claimed alpha-bar` changes in YAML,
the corresponding parser and regression fixture must be updated in the same
pull request.

## Handoff archive scope

The email handoff archive includes the complete static site, workflows, forms,
Julia source, verification and analysis scripts, schemas, examples, tests,
reports, environment lockfiles, and top-level mathematical notes.

It intentionally excludes:

- `data/` (approximately 3.7 GB); and
- `figures/` (approximately 50 MB).

Those research artifacts are not required to deploy or review the website and
submission system. They should be transferred separately if ICARM needs to
reproduce the underlying statistical experiments.
