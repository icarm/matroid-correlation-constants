# Matroid Correlation Constants

This directory contains a static, shareable record book for exact
concrete-matroid values and proved infinite-family curves. It also contains
the public mathematics page and the GitHub-authenticated submission guide.

## Preview locally

From the repository root:

~~~bash
python3 -m http.server 8000 --directory matroid_correlation_website
~~~

Open <http://localhost:8000/>. Stop the server with
<kbd>Ctrl</kbd>+<kbd>C</kbd>. If the repository is on a remote machine,
forward TCP port $8000$ and open the forwarded localhost URL.

The site uses JavaScript modules, so serve it over HTTP rather than opening a
<code>file://</code> URL. Mathematical notation is typeset by MathJax 4 from
jsDelivr; the browser needs network access to load that library.

## Public pages

- <code>index.html</code>: records, all accepted family curves, filters, and
  challenges;
- <code>mathematics.html</code>: definitions, proofs, discovery history,
  attribution, and references;
- <code>submission-guide.html</code>: the concrete and infinite-family forms,
  exact accepted syntax, and the security model.

Solid curves are proved values of the full invariant. Dashed curves are exact
values for a specified pair and therefore certified lower bounds. The main
score compares concrete values and family limits and states whether the
leading score is attained or approached.

The explorer defaults to ground-set size on the horizontal axis. Its axis
button switches to matroid rank; copied views preserve that choice with the
URL parameter <code>x=rank</code>.

## Public submissions

The files under <code>.github/ISSUE_TEMPLATE/</code> define two short GitHub
Issue Forms. Public contributors do not need to fork the repository or open a
pull request.

Both forms require a mathematical discovery date and an explicit
AI-use declaration. When AI was used, the submitter records the model and
version, a brief description of its role, and preferably a public chat or run
link. GitHub's issue metadata separately records the submitter and submission
timestamp automatically.

The workflow
<code>.github/workflows/verify-matroid-issue.yml</code> parses a concrete form
as inert data, runs the trusted Julia verifier, comments with the exact
result, applies the machine-readable challenge policy, and uploads normalized
data and a certificate. It supports matrices
over $\mathbb Q$ and finite fields, plus complete lists of bases, circuits, or
hyperplanes.

The family workflow screens the submitted exact supremum or limsup against
$4/3$ but does not verify the proof. Passing either workflow never publishes
an entry automatically: <code>accepted and published</code> remains a human
curatorial status.

For GitHub Pages, submission links infer the repository from the page URL.
For any other static host, set <code>siteConfig.githubRepositoryUrl</code> in
<code>catalog.js</code> before deployment.

## Local verification

The form does not require a local checkout. To reproduce the worked example:

~~~bash
julia --project=. scripts/verify_matroid_submissions.jl \
  examples/submissions/uniform-u2-4-matrix.json \
  /tmp/uniform-u2-4.certificate.json
~~~

The normalized schema is
<code>schemas/matroid-submission.schema.json</code>. The batch workflow remains
available for maintainers curating accepted normalized entries.

## Deployment

The <code>matroid_correlation_website/</code> directory can be deployed to any
static host. It is self-contained and uses relative URLs throughout, so it can
be placed beneath an existing document root without affecting that document
root's own <code>index.html</code>. For example, placing the directory at
<code>public/matroid_correlation_website/</code> serves this site's
<code>index.html</code> only at the corresponding subdirectory URL.
Before opening submissions, enable GitHub Issues and GitHub Actions in the
repository. The public site has no anonymous submission backend; Issue Forms
provide GitHub identity and moderation, while unverified issues never enter
the catalog.
