# Unweighted correlation ratios for rank-4 matroids on 10 elements

This report studies rank 4. For every distributional table and matroid-level distribution figure, the analysis population excludes disconnected matroids and all matroids with zero correlation ratio; equivalently, it uses `connected = 1` and `alpha_num > 0`.

## Reproducibility and validation

- Lossless SQLite archive: [`results.sqlite.zst`](../data/n10_finite_fields/r4/results.sqlite.zst)
- Archive hashes and materialization instructions: [`archive_manifest.toml`](../data/n10_finite_fields/r4/archive_manifest.toml)
- Stored matroid observations in this rank scope: 703003
- Eligible pairs represented in aggregate tables: 31547175
- Eligible pairs expected from matroid summaries: 31547175
- Matroids selected for detailed pair profiles: 8
- Detailed selected-pair rows: 360
- Selected matroids whose $\overline{\alpha}$ disagrees with their recomputed pair maximum: 0
- Selected pairs with a nonpositive mixed cell or denominator: 0
- Element labels and maximizing pairs are zero-based.

Every matroid is stored losslessly as a packed hexadecimal form of its polyDB-compatible `REVLEX_BASIS_ENCODING`. Decoding gives one character for each rank-sized subset in reverse-lexicographic/colex order, with `*` for a basis and `0` for a nonbasis. Complete pair profiles are reproducible derived data and are retained only for selected examples.

## Runs

| Run | Rank | Ensemble | Field | Accepted | Rejected | Seed |
|---|---:|---|---:|---:|---:|---:|
| n10_r4_q2_exhaustive | 4 | projective_subsets_exhaustive | 2 | 3003 | 0 | — |
| n10_r4_q2_replacement_rep1 | 4 | projective_points_with_replacement_random | 2 | 20000 | 142 | 202640271 |
| n10_r4_q2_replacement_rep2 | 4 | projective_points_with_replacement_random | 2 | 20000 | 171 | 202640272 |
| n10_r4_q2_replacement_rep3 | 4 | projective_points_with_replacement_random | 2 | 20000 | 153 | 202640273 |
| n10_r4_q2_replacement_rep4 | 4 | projective_points_with_replacement_random | 2 | 20000 | 139 | 202640274 |
| n10_r4_q2_replacement_rep5 | 4 | projective_points_with_replacement_random | 2 | 20000 | 166 | 202640275 |
| n10_r4_q3_random_rep1 | 4 | projective_subsets_random | 3 | 20000 | 0 | 202640331 |
| n10_r4_q3_random_rep2 | 4 | projective_subsets_random | 3 | 20000 | 0 | 202640332 |
| n10_r4_q3_random_rep3 | 4 | projective_subsets_random | 3 | 20000 | 0 | 202640333 |
| n10_r4_q3_random_rep4 | 4 | projective_subsets_random | 3 | 20000 | 0 | 202640334 |
| n10_r4_q3_random_rep5 | 4 | projective_subsets_random | 3 | 20000 | 0 | 202640335 |
| n10_r4_q3_replacement_rep1 | 4 | projective_points_with_replacement_random | 3 | 20000 | 8 | 202640371 |
| n10_r4_q3_replacement_rep2 | 4 | projective_points_with_replacement_random | 3 | 20000 | 7 | 202640372 |
| n10_r4_q3_replacement_rep3 | 4 | projective_points_with_replacement_random | 3 | 20000 | 9 | 202640373 |
| n10_r4_q3_replacement_rep4 | 4 | projective_points_with_replacement_random | 3 | 20000 | 9 | 202640374 |
| n10_r4_q3_replacement_rep5 | 4 | projective_points_with_replacement_random | 3 | 20000 | 7 | 202640375 |
| n10_r4_q5_random_rep1 | 4 | projective_subsets_random | 5 | 20000 | 0 | 202640531 |
| n10_r4_q5_random_rep2 | 4 | projective_subsets_random | 5 | 20000 | 1 | 202640532 |
| n10_r4_q5_random_rep3 | 4 | projective_subsets_random | 5 | 20000 | 0 | 202640533 |
| n10_r4_q5_random_rep4 | 4 | projective_subsets_random | 5 | 20000 | 0 | 202640534 |
| n10_r4_q5_random_rep5 | 4 | projective_subsets_random | 5 | 20000 | 0 | 202640535 |
| n10_r4_q5_replacement_rep1 | 4 | projective_points_with_replacement_random | 5 | 20000 | 0 | 202640571 |
| n10_r4_q5_replacement_rep2 | 4 | projective_points_with_replacement_random | 5 | 20000 | 0 | 202640572 |
| n10_r4_q5_replacement_rep3 | 4 | projective_points_with_replacement_random | 5 | 20000 | 0 | 202640573 |
| n10_r4_q5_replacement_rep4 | 4 | projective_points_with_replacement_random | 5 | 20000 | 1 | 202640574 |
| n10_r4_q5_replacement_rep5 | 4 | projective_points_with_replacement_random | 5 | 20000 | 0 | 202640575 |
| n10_r4_q7_random_rep1 | 4 | projective_subsets_random | 7 | 20000 | 0 | 202640731 |
| n10_r4_q7_random_rep2 | 4 | projective_subsets_random | 7 | 20000 | 0 | 202640732 |
| n10_r4_q7_random_rep3 | 4 | projective_subsets_random | 7 | 20000 | 0 | 202640733 |
| n10_r4_q7_random_rep4 | 4 | projective_subsets_random | 7 | 20000 | 0 | 202640734 |
| n10_r4_q7_random_rep5 | 4 | projective_subsets_random | 7 | 20000 | 0 | 202640735 |
| n10_r4_q7_replacement_rep1 | 4 | projective_points_with_replacement_random | 7 | 20000 | 0 | 202640771 |
| n10_r4_q7_replacement_rep2 | 4 | projective_points_with_replacement_random | 7 | 20000 | 0 | 202640772 |
| n10_r4_q7_replacement_rep3 | 4 | projective_points_with_replacement_random | 7 | 20000 | 0 | 202640773 |
| n10_r4_q7_replacement_rep4 | 4 | projective_points_with_replacement_random | 7 | 20000 | 0 | 202640774 |
| n10_r4_q7_replacement_rep5 | 4 | projective_points_with_replacement_random | 7 | 20000 | 0 | 202640775 |

## Distribution summary

`Included N` is the number remaining after removing disconnected and $\overline{\alpha}$ = 0 matroids. `Excluded` reports how many stored observations were removed. For polyDB, these are counts of matroids up to isomorphism. For finite-field runs, they are counts of accepted projective configurations or draws, not deduplicated isomorphism classes.

| Ensemble | Included N | Excluded | Distinct encodings | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) | $\overline{\alpha}$ ≥ 8/7 | $\overline{\alpha}$ ≥ 100/81 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) exhaustive, no replacement | 3003 | 0 | 2675 | 0.900000 | 1.018519 | 55/54 (1.018519) | 840 (27.97%) | 0 | 0 |
| GF(2) random, with replacement | 84481 | 15519 | 84328 | 0.997076 | 1.047619 | 10/9 (1.111111) | 8998 (10.65%) [95% CI 10.44%–10.86%] | 0 | 0 |
| GF(3) random, no replacement | 99904 | 96 | 99654 | 0.929688 | 1.022727 | 10/9 (1.111111) | 8727 (8.74%) [95% CI 8.56%–8.91%] | 0 | 0 |
| GF(3) random, with replacement | 98439 | 1561 | 98435 | 0.960000 | 1.022727 | 10/9 (1.111111) | 7806 (7.93%) [95% CI 7.76%–8.10%] | 0 | 0 |
| GF(5) random, no replacement | 99980 | 20 | 99980 | 0.851939 | 0.955150 | 15/14 (1.071429) | 506 (0.51%) [95% CI 0.46%–0.55%] | 0 | 0 |
| GF(5) random, with replacement | 99941 | 59 | 99941 | 0.864198 | 0.962838 | 10/9 (1.111111) | 573 (0.57%) [95% CI 0.53%–0.62%] | 0 | 0 |
| GF(7) random, no replacement | 99994 | 6 | 99994 | 0.805613 | 0.901361 | 207/200 (1.035000) | 32 (0.03%) [95% CI 0.02%–0.05%] | 0 | 0 |
| GF(7) random, with replacement | 99987 | 13 | 99987 | 0.812414 | 0.909091 | 35/34 (1.029412) | 44 (0.04%) [95% CI 0.03%–0.06%] | 0 | 0 |

The normalized histogram below uses every included observation and 45 equal-width bins; each curve's bin masses sum to one. The staircase traces the bin heights and is not a CDF. Since $\overline{\alpha}$ is an exact rational statistic on a finite matroid population, many classes can share the same value. Thus some jaggedness is genuine atomic mass, while its precise placement also depends on the bin edges. The black dashed line is $\overline{\alpha}$ = 1, the gray dotted line is 8/7, and the red dash-dot line is 100/81. To avoid overplotting, the finite-field curves are split into four panels: GF(2)/GF(3) with replacement, GF(5)/GF(7) with replacement, GF(2)/GF(3) without replacement, and GF(5)/GF(7) without replacement. An exhaustive subset population, when present, belongs to the corresponding without-replacement panel. Common bin edges make the panels directly comparable.

![Probability histogram of $\overline{\alpha}$](../figures/n10_finite_fields/r4/alpha_histogram.png)

## Distribution after excluding sparse paving matroids

Sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, so they cannot contribute to the positive tail beyond 1. The table and companion histogram therefore condition the usual connected, positive-$\overline{\alpha}$ population further on `sparse_paving = 0`. Each histogram curve is renormalized within this smaller population; `N` in its legend and the retained-percentage column below prevent that conditional normalization from hiding the amount of data removed. The companion figure uses exactly the same bin edges, panels, and reference lines as the preceding figure.

| Ensemble | Non-sparse-paving N | Retained | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) |
|---|---:|---:|---:|---:|---:|---:|
| GF(2) exhaustive, no replacement | 3003 | 100.00% | 0.900000 | 1.018519 | 55/54 (1.018519) | 840 (27.97%) |
| GF(2) random, with replacement | 84481 | 100.00% | 0.997076 | 1.047619 | 10/9 (1.111111) | 8998 (10.65%) |
| GF(3) random, no replacement | 99904 | 100.00% | 0.929688 | 1.022727 | 10/9 (1.111111) | 8727 (8.74%) |
| GF(3) random, with replacement | 98439 | 100.00% | 0.960000 | 1.022727 | 10/9 (1.111111) | 7806 (7.93%) |
| GF(5) random, no replacement | 99878 | 99.90% | 0.851939 | 0.955204 | 15/14 (1.071429) | 506 (0.51%) |
| GF(5) random, with replacement | 99875 | 99.93% | 0.864329 | 0.962838 | 10/9 (1.111111) | 573 (0.57%) |
| GF(7) random, no replacement | 98064 | 98.07% | 0.807309 | 0.902458 | 207/200 (1.035000) | 32 (0.03%) |
| GF(7) random, with replacement | 98338 | 98.35% | 0.813008 | 0.909439 | 35/34 (1.029412) | 44 (0.04%) |

As a consistency check, the primary ensembles in this report contain 0 stored sparse paving observations with $\overline{\alpha}$ > 1.

![Probability histogram of $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n10_finite_fields/r4/alpha_histogram_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ after excluding sparse paving matroids

This analysis uses the same connected, positive-$\overline{\alpha}$, non-sparse-paving population as the preceding conditional histogram. Pearson's `r` measures linear association, while Spearman's `ρ` uses weighted midranks and measures monotone association. The final column is the fitted change in $\overline{\alpha}$ associated with a 0.1 increase in basis density.

For random finite-field ensembles, the table gives two-sided tests of zero association. Pearson intervals and tests use the Fisher transformation; the Spearman test uses the usual large-sample normal approximation after assigning midranks to ties. A `census` entry means the row is polyDB or exhaustive, so its coefficient is an exact population description and an inferential p-value would be inappropriate. With the very large random samples here, effect sizes are more informative than tiny p-values.

| Ensemble | N | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) exhaustive, no replacement | 3003 | -0.9663 | — | census | -1.0000 | census | -0.2966 |
| GF(2) random, with replacement | 84481 | +0.0340 | [+0.0273, +0.0407] | < 1e-15 | +0.4097 | < 1e-15 | +0.0016 |
| GF(3) random, no replacement | 99904 | -0.5978 | [-0.6017, -0.5938] | < 1e-15 | -0.6593 | < 1e-15 | -0.0752 |
| GF(3) random, with replacement | 98439 | -0.4447 | [-0.4497, -0.4397] | < 1e-15 | -0.4523 | < 1e-15 | -0.0253 |
| GF(5) random, no replacement | 99878 | -0.7619 | [-0.7645, -0.7593] | < 1e-15 | -0.8016 | < 1e-15 | -0.0933 |
| GF(5) random, with replacement | 99875 | -0.6879 | [-0.6911, -0.6846] | < 1e-15 | -0.7408 | < 1e-15 | -0.0553 |
| GF(7) random, no replacement | 98064 | -0.8026 | [-0.8048, -0.8004] | < 1e-15 | -0.8309 | < 1e-15 | -0.1017 |
| GF(7) random, with replacement | 98338 | -0.7583 | [-0.7609, -0.7556] | < 1e-15 | -0.8220 | < 1e-15 | -0.0729 |

The scatterplots show the filtered observations and the weighted least-squares lines used for the final table column. Legend values of `r` and all fitted lines use every observation. Only the point clouds are thinned, at deterministic evenly spaced indices, when a group exceeds 15,000 observations.

![Basis density versus $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n10_finite_fields/r4/basis_density_vs_alpha_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ for sparse paving matroids

This companion instead conditions on `sparse_paving = 1`, while retaining the report's connected and positive-$\overline{\alpha}$ filters. `Retained` is the percentage of that main analysis population which is sparse paving. The number of distinct basis-density levels is included because sparse paving samples often have many ties or only a few possible basis counts.

The coefficients, intervals, tests, and fitted effect use the same definitions as in the preceding non-sparse-paving analysis. A dash means that the ensemble has no retained sparse paving observations or that a coefficient is undefined because one variable is constant. Census and exhaustive rows again receive no inferential p-value.

| Ensemble | N | Retained | Density levels | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) exhaustive, no replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(2) random, with replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(3) random, no replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(3) random, with replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(5) random, no replacement | 102 | 0.10% | 6 | -0.0781 | [-0.2685, +0.1181] | 0.436 | -0.1695 | 0.0854 | -0.0202 |
| GF(5) random, with replacement | 66 | 0.07% | 4 | +0.3790 | [+0.1508, +0.5688] | 0.00155 | +0.1245 | 0.315 | +0.1106 |
| GF(7) random, no replacement | 1930 | 1.93% | 8 | +0.0759 | [+0.0314, +0.1201] | 0.000842 | +0.0204 | 0.37 | +0.0236 |
| GF(7) random, with replacement | 1649 | 1.65% | 8 | +0.0426 | [-0.0057, +0.0907] | 0.0837 | -0.0157 | 0.525 | +0.0124 |

The sparse-paving plots use all observations for correlations and fitted lines and the same deterministic 15,000-point rendering cap. Empty panels explicitly say that no observations survived the filter. Because sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, only the black $\overline{\alpha}$ = 1 reference line is drawn.

![Basis density versus $\overline{\alpha}$ for sparse paving matroids](../figures/n10_finite_fields/r4/basis_density_vs_alpha_sparse_paving.png)

## Structural prevalence

This table uses the complete stored rank scope before the distribution filter, so the connected column also documents how much of the original population is retained for distributional analysis.

| Ensemble | N | Simple | Cosimple | Connected | 3-connected | Paving | Sparse paving |
|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) exhaustive, no replacement | 3003 | 100.00% | 100.00% | 100.00% | 100.00% | 0.00% | 0.00% |
| GF(2) random, with replacement | 100000 | 1.91% | 55.47% | 84.48% | 1.91% | 0.00% | 0.00% |
| GF(3) random, no replacement | 100000 | 100.00% | 97.78% | 99.90% | 96.80% | 0.00% | 0.00% |
| GF(3) random, with replacement | 100000 | 29.58% | 89.14% | 98.44% | 28.60% | 0.00% | 0.00% |
| GF(5) random, no replacement | 100000 | 100.00% | 99.43% | 99.98% | 99.21% | 2.20% | 0.10% |
| GF(5) random, with replacement | 100000 | 74.62% | 98.82% | 99.94% | 74.02% | 1.57% | 0.07% |
| GF(7) random, no replacement | 100000 | 100.00% | 99.84% | 99.99% | 99.80% | 13.49% | 1.93% |
| GF(7) random, with replacement | 100000 | 89.25% | 99.75% | 99.99% | 89.05% | 11.95% | 1.65% |

Each row uses one of the same four field-pair/replacement comparison groups. The left column relates $\overline{\alpha}$ to the fraction of rank-sized subsets that are bases; the right column compares $\overline{\alpha}$ with the fraction of eligible element pairs having positive association. Every panel uses the connected, positive-$\overline{\alpha}$ population. For rendering only, groups larger than 15,000 are thinned at deterministic evenly spaced indices; summary tables and histograms remain exact.

![Matroid-level scatterplots](../figures/n10_finite_fields/r4/matroid_scatterplots.png)

## Pair-association distribution

The pair histogram also uses only connected matroids with $\overline{\alpha}$ > 0. Within each matroid, every eligible pair receives weight `1 / eligible_pair_count`, so each matroid contributes total weight one regardless of how many eligible pairs it has. Zero ratios cannot be shown on the logarithmic axis; their probability mass is reported in the legend. The vertical reference lines have the same meanings as in the $\overline{\alpha}$ histogram after taking logarithms. The four panels use the same field-pair/replacement split as the matroid-level histogram.

![Pair log-ratio probability histogram](../figures/n10_finite_fields/r4/pair_logratio_histogram.png)

The next scatterplot compares the maximum odds ratio $\overline{\alpha}$ with the largest Pearson correlation among eligible pairs. It shows whether a large odds ratio is also a large standardized effect. It uses the same filtered population and deterministic rendering sample as the other scatterplots, again separated into the four field-pair/replacement panels.

![Odds ratio versus Pearson correlation](../figures/n10_finite_fields/r4/odds_ratio_vs_pearson.png)

## Upper-tail observations

The table lists the ten largest connected, positive-$\overline{\alpha}$ observations in this rank scope. PolyDB rows are isomorphism-class representatives.

| Source | Rank | Field | Identifier | Bases | $\overline{\alpha}$ | Maximizing pair | Positive-pair fraction |
|---|---:|---:|---|---:|---:|---|---:|
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00000442 | 104 | 10/9 | {0, 6} | 2.22% |
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00000520 | 104 | 10/9 | {2, 8} | 2.22% |
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00000548 | 104 | 10/9 | {3, 6} | 2.22% |
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00000966 | 104 | 10/9 | {3, 5} | 2.22% |
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00001297 | 104 | 10/9 | {0, 5} | 2.22% |
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00001327 | 104 | 10/9 | {0, 5} | 2.22% |
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00001353 | 104 | 10/9 | {4, 9} | 2.22% |
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00001363 | 104 | 10/9 | {4, 8} | 2.22% |
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00002831 | 104 | 10/9 | {2, 7} | 2.22% |
| projective points with replacement random | 4 | 2 | pg2_replacement_seed202640271_draw_00002838 | 104 | 10/9 | {1, 8} | 2.22% |

For the maximum in each primary ensemble, the following 2×2 panel shows the raw basis counts and, in parentheses, their normalized cell probabilities. Rows and columns indicate exclusion or inclusion of the maximizing elements.

![Maximizing-pair contingency tables](../figures/n10_finite_fields/r4/maximizing_pair_profiles.png)

The final heatmap shows `log Rᵢⱼ` for every eligible element pair of the same selected matroid. Red indicates positive association, blue negative association, and light gray marks the diagonal or an ineligible pair. Exact zero ratios are displayed at the plotting floor -3. Element labels match the stored zero-based basis encoding.

![Pair heatmaps for ensemble maxima](../figures/n10_finite_fields/r4/top_pair_heatmaps.png)

## Data exports

- [`runs.csv`](../data/n10_finite_fields/r4/exports/runs.csv)
- [`selected_matroids.csv`](../data/n10_finite_fields/r4/exports/selected_matroids.csv)
- [`selected_pairs.csv`](../data/n10_finite_fields/r4/exports/selected_pairs.csv)

The losslessly archived SQLite database is authoritative. Bulk `matroids` and `pair_ratio_aggregates` CSV files duplicate it and are generated only on demand with `scripts/export_bulk_tables.jl` after temporary decompression. Exact $\overline{\alpha}$ values, aggregate ratio keys, and selected pair ratios use reduced integer numerators and denominators; floating-point columns are supplied for summaries and visualization.
