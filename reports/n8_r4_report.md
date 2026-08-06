# Unweighted correlation ratios for rank-4 matroids on 8 elements

This report studies rank 4. For every distributional table and matroid-level distribution figure, the analysis population excludes disconnected matroids and all matroids with zero correlation ratio; equivalently, it uses `connected = 1` and `alpha_num > 0`.

## Reproducibility and validation

- SQLite database: [`results.sqlite`](../data/n8_r4_compact/results.sqlite)
- Stored matroid observations in this rank scope: 22375
- Eligible pairs represented in aggregate tables: 622830
- Eligible pairs expected from matroid summaries: 622830
- Matroids selected for detailed pair profiles: 5
- Detailed selected-pair rows: 140
- Selected matroids whose $\overline{\alpha}$ disagrees with their recomputed pair maximum: 0
- Selected pairs with a nonpositive mixed cell or denominator: 0
- Element labels and maximizing pairs are zero-based.

Every matroid is stored losslessly as a packed hexadecimal form of its polyDB-compatible `REVLEX_BASIS_ENCODING`. Decoding gives one character for each rank-sized subset in reverse-lexicographic/colex order, with `*` for a basis and `0` for a nonbasis. Complete pair profiles are reproducible derived data and are retained only for selected examples.

## Runs

| Run | Rank | Ensemble | Field | Accepted | Rejected | Seed |
|---|---:|---|---:|---:|---:|---:|
| pg_q2_exhaustive | 4 | projective_subsets_exhaustive | 2 | 6435 | 0 | — |
| pg_q3_random | 4 | projective_subsets_random | 3 | 5000 | 2 | 20260733 |
| pg_q5_random | 4 | projective_subsets_random | 5 | 5000 | 2 | 20260735 |
| pg_q7_random | 4 | projective_subsets_random | 7 | 5000 | 0 | 20260737 |
| polydb_n8_r4 | 4 | polydb_isomorphism_classes | — | 940 | 0 | — |

## Distribution summary

`Included N` is the number remaining after removing disconnected and $\overline{\alpha}$ = 0 matroids. `Excluded` reports how many stored observations were removed. For polyDB, these are counts of matroids up to isomorphism. For finite-field runs, they are counts of accepted projective configurations or draws, not deduplicated isomorphism classes.

| Ensemble | Included N | Excluded | Distinct encodings | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) | $\overline{\alpha}$ ≥ 8/7 | $\overline{\alpha}$ ≥ 100/81 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 731 | 209 | 731 | 0.777778 | 0.962963 | 9/8 (1.125000) | 4 (0.55%) | 0 | 0 |
| polyDB simple | 592 | 25 | 592 | 0.764706 | 0.938889 | 9/8 (1.125000) | 4 (0.68%) | 0 | 0 |
| GF(2) exhaustive, no replacement | 6315 | 120 | 2233 | 1.000000 | 1.125000 | 9/8 (1.125000) | 840 (13.30%) | 0 | 0 |
| GF(3) random, no replacement | 4889 | 111 | 4782 | 0.953333 | 1.056250 | 18/17 (1.058824) | 325 (6.65%) [95% CI 5.98%–7.38%] | 0 | 0 |
| GF(5) random, no replacement | 4965 | 35 | 4957 | 0.855263 | 0.953333 | 18/17 (1.058824) | 20 (0.40%) [95% CI 0.26%–0.62%] | 0 | 0 |
| GF(7) random, no replacement | 4991 | 9 | 4990 | 0.781250 | 0.907407 | 18/17 (1.058824) | 4 (0.08%) [95% CI 0.03%–0.21%] | 0 | 0 |

The normalized histogram below uses every included observation and 45 equal-width bins; each curve's bin masses sum to one. The staircase traces the bin heights and is not a CDF. Since $\overline{\alpha}$ is an exact rational statistic on a finite matroid population, many classes can share the same value. Thus some jaggedness is genuine atomic mass, while its precise placement also depends on the bin edges. The black dashed line is $\overline{\alpha}$ = 1, the gray dotted line is 8/7, and the red dash-dot line is 100/81. To avoid overplotting, the finite-field curves are split into four panels: GF(2)/GF(3) with replacement, GF(5)/GF(7) with replacement, GF(2)/GF(3) without replacement, and GF(5)/GF(7) without replacement. An exhaustive subset population, when present, belongs to the corresponding without-replacement panel. Common bin edges make the panels directly comparable.

![Probability histogram of $\overline{\alpha}$](../figures/n8_r4_compact/alpha_histogram.png)

## Distribution after excluding sparse paving matroids

Sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, so they cannot contribute to the positive tail beyond 1. The table and companion histogram therefore condition the usual connected, positive-$\overline{\alpha}$ population further on `sparse_paving = 0`. Each histogram curve is renormalized within this smaller population; `N` in its legend and the retained-percentage column below prevent that conditional normalization from hiding the amount of data removed. The companion figure uses exactly the same bin edges, panels, and reference lines as the preceding figure.

| Ensemble | Non-sparse-paving N | Retained | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) |
|---|---:|---:|---:|---:|---:|---:|
| polyDB | 461 | 63.06% | 0.840000 | 0.972222 | 9/8 (1.125000) | 4 (0.87%) |
| polyDB simple | 322 | 54.39% | 0.820312 | 0.964286 | 9/8 (1.125000) | 4 (1.24%) |
| GF(2) exhaustive, no replacement | 6300 | 99.76% | 1.000000 | 1.125000 | 9/8 (1.125000) | 840 (13.33%) |
| GF(3) random, no replacement | 4823 | 98.65% | 0.953333 | 1.056250 | 18/17 (1.058824) | 325 (6.74%) |
| GF(5) random, no replacement | 4387 | 88.36% | 0.866667 | 0.960784 | 18/17 (1.058824) | 20 (0.46%) |
| GF(7) random, no replacement | 3582 | 71.77% | 0.823529 | 0.933333 | 18/17 (1.058824) | 4 (0.11%) |

As a consistency check, the primary ensembles in this report contain 0 stored sparse paving observations with $\overline{\alpha}$ > 1.

![Probability histogram of $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n8_r4_compact/alpha_histogram_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ after excluding sparse paving matroids

This analysis uses the same connected, positive-$\overline{\alpha}$, non-sparse-paving population as the preceding conditional histogram. Pearson's `r` measures linear association, while Spearman's `ρ` uses weighted midranks and measures monotone association. The final column is the fitted change in $\overline{\alpha}$ associated with a 0.1 increase in basis density.

For random finite-field ensembles, the table gives two-sided tests of zero association. Pearson intervals and tests use the Fisher transformation; the Spearman test uses the usual large-sample normal approximation after assigning midranks to ties. A `census` entry means the row is polyDB or exhaustive, so its coefficient is an exact population description and an inferential p-value would be inappropriate. With the very large random samples here, effect sizes are more informative than tiny p-values.

| Ensemble | N | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 461 | -0.6225 | — | census | -0.6816 | census | -0.0375 |
| polyDB simple | 322 | -0.6219 | — | census | -0.6791 | census | -0.0584 |
| GF(2) exhaustive, no replacement | 6300 | +0.0818 | — | census | -0.1166 | census | +0.0169 |
| GF(3) random, no replacement | 4823 | -0.3564 | [-0.3808, -0.3315] | < 1e-15 | -0.2663 | < 1e-15 | -0.0477 |
| GF(5) random, no replacement | 4387 | -0.5493 | [-0.5697, -0.5283] | < 1e-15 | -0.6189 | < 1e-15 | -0.0598 |
| GF(7) random, no replacement | 3582 | -0.6474 | [-0.6661, -0.6280] | < 1e-15 | -0.7180 | < 1e-15 | -0.0697 |

The scatterplots show the filtered observations and the weighted least-squares lines used for the final table column. Legend values of `r` and all fitted lines use every observation. Only the point clouds are thinned, at deterministic evenly spaced indices, when a group exceeds 15,000 observations.

![Basis density versus $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n8_r4_compact/basis_density_vs_alpha_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ for sparse paving matroids

This companion instead conditions on `sparse_paving = 1`, while retaining the report's connected and positive-$\overline{\alpha}$ filters. `Retained` is the percentage of that main analysis population which is sparse paving. The number of distinct basis-density levels is included because sparse paving samples often have many ties or only a few possible basis counts.

The coefficients, intervals, tests, and fitted effect use the same definitions as in the preceding non-sparse-paving analysis. A dash means that the ensemble has no retained sparse paving observations or that a coefficient is undefined because one variable is constant. Census and exhaustive rows again receive no inferential p-value.

| Ensemble | N | Retained | Density levels | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 270 | 36.94% | 15 | -0.0888 | — | census | -0.0181 | census | -0.0191 |
| polyDB simple | 270 | 45.61% | 15 | -0.0888 | — | census | -0.0181 | census | -0.0191 |
| GF(2) exhaustive, no replacement | 15 | 0.24% | 1 | — | — | census | — | census | +0.0000 |
| GF(3) random, no replacement | 66 | 1.35% | 3 | -0.9998 | [-0.9999, -0.9996] | < 1e-15 | -1.0000 | < 1e-15 | -0.2615 |
| GF(5) random, no replacement | 578 | 11.64% | 5 | +0.0097 | [-0.0719, +0.0912] | 0.816 | +0.0454 | 0.276 | +0.0052 |
| GF(7) random, no replacement | 1409 | 28.23% | 8 | -0.1674 | [-0.2178, -0.1162] | 2.33e-10 | -0.0264 | 0.322 | -0.0537 |

The sparse-paving plots use all observations for correlations and fitted lines and the same deterministic 15,000-point rendering cap. Empty panels explicitly say that no observations survived the filter. Because sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, only the black $\overline{\alpha}$ = 1 reference line is drawn.

![Basis density versus $\overline{\alpha}$ for sparse paving matroids](../figures/n8_r4_compact/basis_density_vs_alpha_sparse_paving.png)

## Structural prevalence

This table uses the complete stored rank scope before the distribution filter, so the connected column also documents how much of the original population is retained for distributional analysis.

| Ensemble | N | Simple | Cosimple | Connected | 3-connected | Paving | Sparse paving |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 940 | 65.64% | 65.64% | 77.77% | 54.26% | 34.26% | 28.72% |
| polyDB simple | 617 | 100.00% | 85.09% | 95.95% | 82.66% | 52.19% | 43.76% |
| GF(2) exhaustive, no replacement | 6435 | 100.00% | 52.45% | 98.14% | 52.45% | 0.23% | 0.23% |
| GF(3) random, no replacement | 5000 | 100.00% | 68.34% | 97.78% | 64.72% | 1.32% | 1.32% |
| GF(5) random, no replacement | 5000 | 100.00% | 86.90% | 99.30% | 84.96% | 18.28% | 11.56% |
| GF(7) random, no replacement | 5000 | 100.00% | 94.56% | 99.82% | 93.84% | 40.46% | 28.18% |

Each row uses one of the same four field-pair/replacement comparison groups. The left column relates $\overline{\alpha}$ to the fraction of rank-sized subsets that are bases; the right column compares $\overline{\alpha}$ with the fraction of eligible element pairs having positive association. Every panel uses the connected, positive-$\overline{\alpha}$ population. For rendering only, groups larger than 15,000 are thinned at deterministic evenly spaced indices; summary tables and histograms remain exact.

![Matroid-level scatterplots](../figures/n8_r4_compact/matroid_scatterplots.png)

## Pair-association distribution

The pair histogram also uses only connected matroids with $\overline{\alpha}$ > 0. Within each matroid, every eligible pair receives weight `1 / eligible_pair_count`, so each matroid contributes total weight one regardless of how many eligible pairs it has. Zero ratios cannot be shown on the logarithmic axis; their probability mass is reported in the legend. The vertical reference lines have the same meanings as in the $\overline{\alpha}$ histogram after taking logarithms. The four panels use the same field-pair/replacement split as the matroid-level histogram.

![Pair log-ratio probability histogram](../figures/n8_r4_compact/pair_logratio_histogram.png)

The next scatterplot compares the maximum odds ratio $\overline{\alpha}$ with the largest Pearson correlation among eligible pairs. It shows whether a large odds ratio is also a large standardized effect. It uses the same filtered population and deterministic rendering sample as the other scatterplots, again separated into the four field-pair/replacement panels.

![Odds ratio versus Pearson correlation](../figures/n8_r4_compact/odds_ratio_vs_pearson.png)

## Upper-tail observations

The table lists the ten largest connected, positive-$\overline{\alpha}$ observations in this rank scope. PolyDB rows are isomorphism-class representatives.

| Source | Rank | Field | Identifier | Bases | $\overline{\alpha}$ | Maximizing pair | Positive-pair fraction |
|---|---:|---:|---|---:|---:|---|---:|
| polyDB | 4 | — | n8r4_00000520 | 48 | 9/8 | {0, 7} | 3.57% |
| projective subsets exhaustive | 4 | 2 | pg2_subset_017f | 48 | 9/8 | {6, 7} | 3.57% |
| projective subsets exhaustive | 4 | 2 | pg2_subset_01bf | 48 | 9/8 | {6, 7} | 3.57% |
| projective subsets exhaustive | 4 | 2 | pg2_subset_01df | 48 | 9/8 | {4, 7} | 3.57% |
| projective subsets exhaustive | 4 | 2 | pg2_subset_01ef | 48 | 9/8 | {4, 7} | 3.57% |
| projective subsets exhaustive | 4 | 2 | pg2_subset_01f7 | 48 | 9/8 | {2, 7} | 3.57% |
| projective subsets exhaustive | 4 | 2 | pg2_subset_01fb | 48 | 9/8 | {2, 7} | 3.57% |
| projective subsets exhaustive | 4 | 2 | pg2_subset_01fd | 48 | 9/8 | {0, 7} | 3.57% |
| projective subsets exhaustive | 4 | 2 | pg2_subset_01fe | 48 | 9/8 | {0, 7} | 3.57% |
| projective subsets exhaustive | 4 | 2 | pg2_subset_027f | 48 | 9/8 | {4, 7} | 3.57% |

For the maximum in each primary ensemble, the following 2×2 panel shows the raw basis counts and, in parentheses, their normalized cell probabilities. Rows and columns indicate exclusion or inclusion of the maximizing elements.

![Maximizing-pair contingency tables](../figures/n8_r4_compact/maximizing_pair_profiles.png)

The final heatmap shows `log Rᵢⱼ` for every eligible element pair of the same selected matroid. Red indicates positive association, blue negative association, and light gray marks the diagonal or an ineligible pair. Exact zero ratios are displayed at the plotting floor -3. Element labels match the stored zero-based basis encoding.

![Pair heatmaps for ensemble maxima](../figures/n8_r4_compact/top_pair_heatmaps.png)

## Data exports

- [`runs.csv`](../data/n8_r4_compact/exports/runs.csv)
- [`selected_matroids.csv`](../data/n8_r4_compact/exports/selected_matroids.csv)
- [`selected_pairs.csv`](../data/n8_r4_compact/exports/selected_pairs.csv)

The SQLite tables are authoritative. Bulk `matroids` and `pair_ratio_aggregates` CSV files duplicate SQLite and are generated only on demand with `scripts/export_bulk_tables.jl`. Exact $\overline{\alpha}$ values, aggregate ratio keys, and selected pair ratios use reduced integer numerators and denominators; floating-point columns are supplied for summaries and visualization.
