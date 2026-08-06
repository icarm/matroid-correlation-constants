# Correlation-ratio distributions for matroids

This project studies the unweighted correlation ratio

$$
\overline{\alpha}(M)
=
\max_{i\ne j}
\frac{|B^{ij}(M)|\,|B_{ij}(M)|}
{|B^i_j(M)|\,|B^j_i(M)|}
$$

through complete polyDB censuses, explicitly defined random finite-field
ensembles, and labeled sparse-paving samples obtained from independent sets
of Johnson graphs.

Distribution summaries and matroid-level distribution figures use a common
analysis population: disconnected matroids and matroids with
$\overline{\alpha}=0$ are excluded. Structural-prevalence tables retain the full stored
population and say so explicitly. For a polyDB census, every count is a count
of isomorphism classes. A random finite-field count is instead a count of
accepted draws. A Johnson-graph count is a count of labeled independent-set
outputs from its stated random-greedy law; neither random source is uniform on
matroid isomorphism classes.

Each generated report also includes a companion $\overline{\alpha}$ distribution
conditioned on the matroid not being sparse paving. It uses the same bins as
the main histogram, reports the retained sample sizes, and isolates the only
structural population in which the upper tail $\overline{\alpha}>1$ can occur. A
pair of matching basis-density analyses, one for each sparse-paving status,
reports Pearson and Spearman correlations, random-sample tests, linear effect
sizes, and scatterplots with fitted lines.

Matroid duality preserves $\overline{\alpha}$ and exchanges rank $r$ with rank $n-r$.
Consequently, routine experiments, figures, and reports use only

$$
0\leq r\leq \left\lfloor\frac n2\right\rfloor.
$$

Higher-rank results are inferred from their duals rather than recomputed or
reported separately.

The current outputs are:

- [`reports/n8_r4_report.md`](reports/n8_r4_report.md), the rank-$4$,
  $n=8$ validation experiment, including exhaustive $\operatorname{GF}(2)$ and
  random $\operatorname{GF}(3)$, $\operatorname{GF}(5)$, and
  $\operatorname{GF}(7)$ ensembles;
- [`reports/n9_r3_report.md`](reports/n9_r3_report.md) and
  [`reports/n9_r4_report.md`](reports/n9_r4_report.md) for the exact $n=9$
  polyDB census;
- [`reports/n9_all_ranks_report.md`](reports/n9_all_ranks_report.md), which
  aggregates the nonredundant ranks $0$ through $4$;
- [`reports/n10_r4_finite_fields_report.md`](reports/n10_r4_finite_fields_report.md)
  and
  [`reports/n10_r5_finite_fields_report.md`](reports/n10_r5_finite_fields_report.md),
  containing the seeded small-field experiments with and without replacement;
- [`reports/n12_r6_finite_fields_report.md`](reports/n12_r6_finite_fields_report.md),
  combining the seeded small-field experiment with four Johnson-graph
  sparse-paving populations;
- [`reports/theta_analysis_report.md`](reports/theta_analysis_report.md), a
  separate cross-experiment statistical analysis of the uniform-baseline
  density-adjusted correlation excess $\Theta$. The ordinary $\overline{\alpha}$
  reports do not include this derived analysis;
- [`reports/J_gamma_analysis_report.md`](reports/J_gamma_analysis_report.md),
  a separate cross-source analysis of
  $\mathcal J_\gamma=(\overline{\alpha}/c_{r,n})d_B^\gamma$, including Pareto geometry,
  critical exponents, worst-pair robustness, the sharp high-density deletion
  cap, and a moderate-density sensitivity population;
- [epsilon analysis report](reports/epsilon_analysis_report.md), the exact
  database analysis of the free-extension/free-coextension invariant
  $\epsilon(M)$, together with deterministic empirical direct-sum experiments
  and self-direct-sum censuses, the known finite-field spike family with
  $\overline{\alpha}=8/7$, and the supplied $\operatorname{GF}(3)$ benchmark with
  $\overline{\alpha}=100/81$;
- [base $2$-design self-sum report](reports/two_design_self_sum_report.md), an
  exact analysis of affine and projective geometries, Steiner-system
  sparse-paving matroids, and direct sums of arbitrarily many uniform
  matroids;
- [self-sum gamma-star analysis](reports/self_sum_gamma_analysis.md), deriving
  $\gamma_*(M\oplus M)$ directly from $\overline{\alpha}(M)$ and basis density and
  measuring their within-cell relationship across the current databases.

## Website and public submissions

The [Matroid Correlation Constants](matroid_correlation_website/index.html) site presents the accepted
concrete records and family curves. Its
[mathematics page](matroid_correlation_website/mathematics.html) contains the definitions, family
proofs, field-representability statements, attribution, and references. See
the [submission guide](matroid_correlation_website/submission-guide.html) for the two short,
GitHub-authenticated contribution forms.

For a concrete matroid, the submitter gives $n$, $r$, the claimed
$\overline{\alpha}$, and one of a matrix, all bases, all circuits, or all
hyperplanes. The form also records the discoverers, the discovery
date, and an explicit AI-use disclosure; GitHub separately records the
submitter and submission timestamp. An optional matrix over a finite field or $\mathbb Q$ can certify
representability. The GitHub issue workflow normalizes this data, validates
the matroid axioms and matrix certificates, recomputes every eligible pair
exactly, applies the public challenge policy, and posts a deterministic result.
Infinite-family claims receive numeric threshold screening but retain human
proof review. No workflow publishes catalog entries automatically. It never evaluates
contributor-supplied code or expressions.

## Reproducing the analyses

Instantiate the pinned Julia environment and run the tests:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. test/runtests.jl
```

### The n=8, rank-4 validation experiment

The compact rerun is kept beside, rather than overwriting, the original
schema-version-1 snapshot:

```bash
julia --project=. scripts/collect_polydb.jl \
  data/n8_r4_compact/results.sqlite 8 4 0 polydb_n8 false

julia --project=. scripts/sample_finite_fields.jl \
  data/n8_r4_compact/results.sqlite 2 0 20260732 exhaustive pg_q2_exhaustive 8 4

julia --project=. scripts/sample_finite_fields.jl \
  data/n8_r4_compact/results.sqlite 3 5000 20260733 random pg_q3_random 8 4

julia --project=. scripts/sample_finite_fields.jl \
  data/n8_r4_compact/results.sqlite 5 5000 20260735 random pg_q5_random 8 4

julia --project=. scripts/sample_finite_fields.jl \
  data/n8_r4_compact/results.sqlite 7 5000 20260737 random pg_q7_random 8 4

julia --project=. scripts/make_figures.jl \
  data/n8_r4_compact/results.sqlite figures/n8_r4_compact 8 4

julia --project=. scripts/make_report.jl \
  data/n8_r4_compact/results.sqlite \
  reports/n8_r4_report.md \
  data/n8_r4_compact/exports \
  data/n8_r4_compact/run_manifest.toml \
  figures/n8_r4_compact 8 4
```

For $q=2$, the sampler exhausts all spanning eight-point subsets of
$\operatorname{PG}(3,2)$. For $q=3,5,7$, it retains 5,000 seeded spanning
draws from the corresponding projective space.

### The complete n=9 polyDB census

`Matroids.Small` stores the required representatives through rank $4$, so no
dual materialization is needed for routine analysis:

```bash
julia --project=. scripts/collect_polydb.jl \
  data/n9_census/results.sqlite 9 0:4 0 polydb_n9 false
```

The existing database retains explicit ranks $5$ through $9$ from the initial
duality-validation audit. They remain useful provenance but are ignored by
the `all` analysis scope.

Generate the two nontrivial rank reports with `RANK` equal to `3` and `4`.
For example, rank $3$ is:

```bash
julia --project=. scripts/make_figures.jl \
  data/n9_census/results.sqlite figures/n9_census/r3 9 3

julia --project=. scripts/make_report.jl \
  data/n9_census/results.sqlite \
  reports/n9_r3_report.md \
  data/n9_census/exports/r3 \
  data/n9_census/manifests/r3.toml \
  figures/n9_census/r3 9 3
```

The aggregate report uses ranks $0$ through $4$, one side of duality. The
analysis scripts interpret `all` in exactly this nonredundant sense:

```bash
julia --project=. scripts/make_figures.jl \
  data/n9_census/results.sqlite figures/n9_census/all_ranks 9 all

julia --project=. scripts/make_report.jl \
  data/n9_census/results.sqlite \
  reports/n9_all_ranks_report.md \
  data/n9_census/exports/all_ranks \
  data/n9_census/manifests/all_ranks.toml \
  figures/n9_census/all_ranks 9 all
```

### The n=10 finite-field experiments

The batch driver uses five deterministic seeds and 20,000 accepted spanning
configurations per random cell. Rank $4$ contains the complete 3,003-member
population of ten-point subsets of $\operatorname{PG}(3,2)$, random
no-replacement samples over $\operatorname{GF}(3)$, $\operatorname{GF}(5)$,
and $\operatorname{GF}(7)$, and replacement samples over all four fields.
Rank $5$ uses both random models over
$\operatorname{GF}(2)$, $\operatorname{GF}(3)$,
$\operatorname{GF}(5)$, and $\operatorname{GF}(7)$.

```bash
julia --project=. scripts/run_n10_finite_fields.jl \
  data/n10_finite_fields/r4/results.sqlite 4 20000

julia --project=. scripts/run_n10_finite_fields.jl \
  data/n10_finite_fields/r5/results.sqlite 5 20000
```

Generate the two rank-specific artifact sets as follows, replacing `RANK`
with `4` and then `5`:

```bash
julia --project=. scripts/make_figures.jl \
  data/n10_finite_fields/rRANK/results.sqlite \
  figures/n10_finite_fields/rRANK 10 RANK

julia --project=. scripts/make_report.jl \
  data/n10_finite_fields/rRANK/results.sqlite \
  reports/n10_rRANK_finite_fields_report.md \
  data/n10_finite_fields/rRANK/exports \
  data/n10_finite_fields/rRANK/run_manifest.toml \
  figures/n10_finite_fields/rRANK 10 RANK
```

The completed databases contain 703,003 rank-$4$ observations and 800,000
rank-$5$ observations. The run manifests record every seed, proposal
rejection count, Julia/OSCAR version, ensemble definition, and conditioning
rule.

The completed rank-$4$ database is retained losslessly as
`data/n10_finite_fields/r4/results.sqlite.zst` to avoid keeping a 411 MiB
inactive SQLite file. `data/n10_finite_fields/r4/archive_manifest.toml`
records both hashes and exact byte counts. Materialize it only when a rank-$4$
query or figure regeneration is needed:

```bash
zstd -d -k data/n10_finite_fields/r4/results.sqlite.zst \
  -o data/n10_finite_fields/r4/results.sqlite
```

The standalone $\Theta$ script performs this materialization in a temporary
directory automatically.

### The $n=12$, $r=6$ finite-field and sparse-paving experiment

The completed experiment samples GF$(2)$, GF$(3)$, GF$(5)$, and GF$(7)$,
both without and with replacement. Each of the eight cells contains five
independent replicates of 20,000 accepted spanning configurations, hence
100,000 observations per cell and 800,000 in total. Cells were collected in
temporary shard databases and transactionally merged into
`data/n12_finite_fields/r6/results.sqlite`.

The same database also contains 100,000 labeled sparse paving matroids from
independent sets of $J(12,6)$. A one-pass random-priority greedy algorithm was
run at activation probabilities $p=0.01,0.05,0.2,1$, with five independent
replicates of 5,000 draws for each fixed $p$. A selected Johnson vertex is a
circuit-hyperplane and every other $6$-subset is a basis. These are exact
independent-set outputs of the stated law, not uniform independent sets or
matroid isomorphism classes. All validated temporary shards were removed
after their transactional merges. The combined rank-scoped report is
`reports/n12_r6_finite_fields_report.md`.

### ICARM $n=10$ probability samples

The ICARM experiment targets stored matroid isomorphism classes rather than
finite-field representations. Pinned public manifests and converted chunk
tables live in `data/icarm_n10/manifests`. Rank $4$ is a 100,000-class exact
simple random sample without replacement. Rank $5$ is a two-stage pilot with
128 PPS chunk draws and 100 uniform offsets per draw; its report treats chunk
draws as primary sampling units.

The reproducible workflow is:

```bash
gcc -O3 -std=c11 tools/icarm_decode_targets.c \
  -o build/icarm_decode_targets

julia --project=. scripts/prepare_icarm_sample.jl \
  data/icarm_n10/manifests/n10r04_chunks.tsv data/icarm_n10/r4 \
  srs 100000 202608104

julia --project=. scripts/prepare_icarm_sample.jl \
  data/icarm_n10/manifests/n10r05_chunks.tsv data/icarm_n10/r5 \
  cluster 128 100 202608105

julia --project=. --threads=8 scripts/extract_icarm_sample.jl \
  data/icarm_n10/r4 210 build/icarm_decode_targets

julia --project=. --threads=8 scripts/extract_icarm_sample.jl \
  data/icarm_n10/r5 252 build/icarm_decode_targets

julia --project=. scripts/analyze_icarm_sample.jl \
  data/icarm_n10/r4 10 4 data/icarm_n10/r4/results.sqlite \
  icarm_n10_r4_srs_100000 4

julia --project=. scripts/analyze_icarm_sample.jl \
  data/icarm_n10/r5 10 5 data/icarm_n10/r5/results.sqlite \
  icarm_n10_r5_cluster_128x100 4

julia --project=. scripts/pack_icarm_sample.jl data/icarm_n10/r4 10 4
julia --project=. scripts/pack_icarm_sample.jl data/icarm_n10/r5 10 5
julia --project=. scripts/make_icarm_sample_report.jl
```

The canonical `sample_basis.tsv.zst` packs retain exact sampled global indices
and basis masks after per-chunk decoding fragments are removed. The
authoritative databases also retain sampling coordinates, design weights,
automorphism-group orders, structural invariants, and hashes of every input
contract. The separate report is
`reports/icarm_n10_probability_samples.md`.

### The standalone Theta analysis

After the preceding databases exist, regenerate the separate report, its eighteen
figures, and its two compact summary exports with:

```bash
julia --project=. scripts/make_theta_report.jl
```

The command derives exact $\Theta$ values on demand and does not add a
per-matroid table or modify a source database. Its defaults are
`reports/theta_analysis_report.md`, `figures/theta_analysis`, and
`data/theta_analysis/theta_summary.csv`. Optional positional arguments may
override those three paths.

### The standalone J-gamma analysis

Regenerate the separate $\mathcal J_\gamma$ report, its 24 figures, and its
three compact derived CSV files with:

```bash
julia --project=. scripts/make_j_gamma_report.jl
```

The script reads every available nonredundant rank/source scope, computes
scores and exact observed frontiers on demand, and does not persist
per-matroid $\mathcal J_\gamma$ values. Its default outputs are
`reports/J_gamma_analysis_report.md`, `figures/j_gamma_analysis`, and
`data/j_gamma_analysis/j_gamma_summary.csv`; the frontier and extremal-profile
CSVs are written beside the summary. Optional positional arguments override
the report, figure-directory, and summary paths.

### The standalone epsilon analysis

Regenerate the $\epsilon(M)$ report, three figures, and four compact derived CSV
files with:

~~~bash
julia --project=. scripts/make_epsilon_report.jl
~~~

The script derives the exact four-count profile
$(i_{r-1},|\mathcal B|,a_r,s_{r+1})$ from each packed basis encoding and never
modifies a source database. Direct sums are evaluated from the two summand
profiles without constructing new matroids. Because the Cartesian products are
too large to enumerate, the direct-sum distribution tables use deterministic
two-stage empirical pair samples and say so explicitly. The archived
$n=10$, rank-$4$ database is decompressed only into a temporary directory.
Self-direct sums are evaluated exhaustively for every eligible stored row. The
report also recomputes the $\overline{\alpha}=100/81$ benchmark directly from its
supplied $\operatorname{GF}(3)$ matrix.

### Base $2$-design self-sums

Regenerate the exact affine/projective geometry computations, limiting-family
analysis, convergence figure, and compact CSV with:

~~~bash
julia --project=. scripts/make_two_design_self_sum_report.jl
~~~

The report also gives closed forms for Steiner-system sparse-paving families
and proves that no finite direct sum of uniform matroids exceeds $4/3$.

### Self-sum critical exponents

Regenerate the exact $\overline{\alpha}(M)$ versus $\gamma_*(M\oplus M)$ analysis,
compact summary, and figure with:

~~~bash
julia --project=. scripts/make_self_sum_gamma_report.jl
~~~

The computation uses only the summand's basis count and $\overline{\alpha}$; it does
not materialize any self-direct-sum matroid.

### Compact artifact policy

The SQLite database is authoritative. Each matroid's polyDB-compatible
reverse-lex `0`/`*` basis indicator is stored losslessly as a hexadecimal bit
mask and reconstructed on demand; the legacy text column is retained empty for
schema compatibility. Persistent reports keep only small provenance, summary,
and selected-profile CSV files. Full `matroids` and
`pair_ratio_aggregates` exports duplicate SQLite and are generated only when
needed with:

```bash
julia --project=. scripts/export_bulk_tables.jl \
  DATABASE TEMPORARY_OUTPUT_DIRECTORY N RANK_SCOPE
```

Dense point-cloud figures are retained as high-resolution PNG only, while
histograms, profiles, and heatmaps may also retain SVG versions.

The earlier compaction tool remains available for validating packed basis
masks and migrating schema-version-1 artifacts:

```bash
julia --project=. scripts/compact_storage.jl
```

## Command-line interfaces

Each script begins with its full command-line contract and every function has
an adjacent Julia docstring. In brief:

```text
collect_polydb.jl DATABASE N RANK_SPEC [LIMIT_PER_RANK] [RUN_PREFIX] [INCLUDE_DUALS]
sample_finite_fields.jl DATABASE Q TARGET SEED MODE RUN_ID [N] [RANK]
sample_sparse_paving_johnson.jl DATABASE N RANK ACTIVITY TARGET SEED RUN_ID
run_n10_finite_fields.jl DATABASE RANK [TARGET_PER_SEED]
run_finite_field_cell.jl DATABASE N RANK Q MODE [TARGET_PER_SEED] [REPLICATES]
run_johnson_cell.jl DATABASE N RANK ACTIVITY [TARGET_PER_SEED] [REPLICATES]
merge_experiment_databases.jl DESTINATION SHARD [SHARD ...]
make_figures.jl DATABASE OUTPUT_DIRECTORY [N] [RANK_SCOPE]
make_report.jl DATABASE REPORT EXPORT_DIRECTORY MANIFEST FIGURE_DIRECTORY [N] [RANK_SCOPE]
make_theta_report.jl [REPORT] [FIGURE_DIRECTORY] [SUMMARY_CSV]
make_j_gamma_report.jl [REPORT] [FIGURE_DIRECTORY] [SUMMARY_CSV]
make_epsilon_report.jl
compact_storage.jl [PROJECT_ROOT]
```

Rank specifications accept a single rank, a comma list, an inclusive range,
or, in the analysis scripts, `all`. Explicit ranks and `all` are bounded by
$\lfloor n/2\rfloor$. `INCLUDE_DUALS=true` remains available only as an
explicit validation option; normal collections use `false`. A collection
rerun resets only the named run identifiers. Figure generation selects and
caches the few complete pair profiles needed for heatmaps; it does not
populate pair rows for every matroid.

For `sample_finite_fields.jl`, `MODE=exhaustive` enumerates distinct
projective-point subsets, and `MODE=random` samples such subsets uniformly
without replacement. `MODE=replacement` instead draws an ordered sequence of
independent nonzero projective points. It permits parallel elements but not
loops. All three modes condition on spanning rank. These are distributions on
finite-field configurations or representations, not uniform distributions on
matroid isomorphism classes.

For `sample_sparse_paving_johnson.jl`, every draw uses a fresh uniform random
ordering of the vertices of $J(n,r)$. An available vertex is independently
activated with probability `ACTIVITY`; if selected, it blocks itself and all
neighbors. The resulting stable set is the collection of circuit-hyperplanes.
At activity one the stable set is maximal. This precisely specifies an
independent labeled sampling law, but it is not the uniform distribution on
all stable sets.

## Stored data

The schema keeps complete matroid-level information while avoiding one
database row for every eligible pair of every matroid:

- `runs`: ensemble definitions, ranks, seeds, versions, filters, and observed
  acceptance counts;
- `matroids`: one compact summary row per polyDB class, accepted finite-field
  draw, or labeled Johnson-graph output;
- `pair_ratio_aggregates`: exact reduced pair ratios, stratified by simplicity,
  connectivity, and whether $\overline{\alpha}$ is positive, with pair-weighted and
  equal-matroid-weight totals;
- `selected_matroids`: examples chosen for heatmaps or detailed case studies;
- `selected_pairs`: complete $2\times2$ tables and association statistics only
  for those selected examples.

All eligible pairs are evaluated while collecting a matroid. Its summary row
retains $\overline{\alpha}$, the exact numerator and denominator, maximizing pair,
second ratio, pair-distribution quantiles, positive-pair and positive-graph
summaries, structural flags, and a reversible packed basis encoding. Detailed pair data can
therefore be regenerated deterministically whenever an example is selected.

The logical basis representation follows polyDB's `REVLEX_BASIS_ENCODING`.
It has $\binom nr$ positions, one for each $r$-subset in
reverse-lexicographic/colex order: `*` means basis and `0` means nonbasis.
PolyDB records, their duals, and generated finite-field matroids all use this
identical convention. The authoritative stored value is its lossless packed
hexadecimal mask; decoding it reconstructs the exact `0`/`*` string. Random
samples also retain their normalized finite-field columns. Element and pair
labels are zero-based.

Exact comparisons use stored integer numerators and denominators. Floating
point and logarithmic columns are intended for summaries and plots.

The schema-version-1 `data/n8_r4` snapshot was removed after its 22,375
matroids and 622,830 eligible pairs were checked against the compact
replacement. The authoritative validation rerun is
`data/n8_r4_compact/results.sqlite`; fresh collections never create or
populate the legacy one-row-per-pair table.
