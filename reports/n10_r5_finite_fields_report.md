# Unweighted correlation ratios for rank-5 matroids on 10 elements

This report studies rank 5. For every distributional table and matroid-level distribution figure, the analysis population excludes disconnected matroids and all matroids with zero correlation ratio; equivalently, it uses `connected = 1` and `alpha_num > 0`.

## Reproducibility and validation

- SQLite database: [`results.sqlite`](../data/n10_finite_fields/r5/results.sqlite)
- Stored matroid observations in this rank scope: 800000
- Eligible pairs represented in aggregate tables: 35682910
- Eligible pairs expected from matroid summaries: 35682910
- Matroids selected for detailed pair profiles: 8
- Detailed selected-pair rows: 360
- Selected matroids whose $\overline{\alpha}$ disagrees with their recomputed pair maximum: 0
- Selected pairs with a nonpositive mixed cell or denominator: 0
- Element labels and maximizing pairs are zero-based.

Every matroid is stored losslessly as a packed hexadecimal form of its polyDB-compatible `REVLEX_BASIS_ENCODING`. Decoding gives one character for each rank-sized subset in reverse-lexicographic/colex order, with `*` for a basis and `0` for a nonbasis. Complete pair profiles are reproducible derived data and are retained only for selected examples.

## Runs

| Run | Rank | Ensemble | Field | Accepted | Rejected | Seed |
|---|---:|---|---:|---:|---:|---:|
| n10_r5_q2_random_rep1 | 5 | projective_subsets_random | 2 | 20000 | 42 | 202650231 |
| n10_r5_q2_random_rep2 | 5 | projective_subsets_random | 2 | 20000 | 49 | 202650232 |
| n10_r5_q2_random_rep3 | 5 | projective_subsets_random | 2 | 20000 | 28 | 202650233 |
| n10_r5_q2_random_rep4 | 5 | projective_subsets_random | 2 | 20000 | 41 | 202650234 |
| n10_r5_q2_random_rep5 | 5 | projective_subsets_random | 2 | 20000 | 42 | 202650235 |
| n10_r5_q2_replacement_rep1 | 5 | projective_points_with_replacement_random | 2 | 20000 | 416 | 202650271 |
| n10_r5_q2_replacement_rep2 | 5 | projective_points_with_replacement_random | 2 | 20000 | 425 | 202650272 |
| n10_r5_q2_replacement_rep3 | 5 | projective_points_with_replacement_random | 2 | 20000 | 445 | 202650273 |
| n10_r5_q2_replacement_rep4 | 5 | projective_points_with_replacement_random | 2 | 20000 | 457 | 202650274 |
| n10_r5_q2_replacement_rep5 | 5 | projective_points_with_replacement_random | 2 | 20000 | 445 | 202650275 |
| n10_r5_q3_random_rep1 | 5 | projective_subsets_random | 3 | 20000 | 22 | 202650331 |
| n10_r5_q3_random_rep2 | 5 | projective_subsets_random | 3 | 20000 | 15 | 202650332 |
| n10_r5_q3_random_rep3 | 5 | projective_subsets_random | 3 | 20000 | 12 | 202650333 |
| n10_r5_q3_random_rep4 | 5 | projective_subsets_random | 3 | 20000 | 20 | 202650334 |
| n10_r5_q3_random_rep5 | 5 | projective_subsets_random | 3 | 20000 | 23 | 202650335 |
| n10_r5_q3_replacement_rep1 | 5 | projective_points_with_replacement_random | 3 | 20000 | 44 | 202650371 |
| n10_r5_q3_replacement_rep2 | 5 | projective_points_with_replacement_random | 3 | 20000 | 40 | 202650372 |
| n10_r5_q3_replacement_rep3 | 5 | projective_points_with_replacement_random | 3 | 20000 | 31 | 202650373 |
| n10_r5_q3_replacement_rep4 | 5 | projective_points_with_replacement_random | 3 | 20000 | 43 | 202650374 |
| n10_r5_q3_replacement_rep5 | 5 | projective_points_with_replacement_random | 3 | 20000 | 43 | 202650375 |
| n10_r5_q5_random_rep1 | 5 | projective_subsets_random | 5 | 20000 | 0 | 202650531 |
| n10_r5_q5_random_rep2 | 5 | projective_subsets_random | 5 | 20000 | 3 | 202650532 |
| n10_r5_q5_random_rep3 | 5 | projective_subsets_random | 5 | 20000 | 0 | 202650533 |
| n10_r5_q5_random_rep4 | 5 | projective_subsets_random | 5 | 20000 | 1 | 202650534 |
| n10_r5_q5_random_rep5 | 5 | projective_subsets_random | 5 | 20000 | 1 | 202650535 |
| n10_r5_q5_replacement_rep1 | 5 | projective_points_with_replacement_random | 5 | 20000 | 1 | 202650571 |
| n10_r5_q5_replacement_rep2 | 5 | projective_points_with_replacement_random | 5 | 20000 | 3 | 202650572 |
| n10_r5_q5_replacement_rep3 | 5 | projective_points_with_replacement_random | 5 | 20000 | 0 | 202650573 |
| n10_r5_q5_replacement_rep4 | 5 | projective_points_with_replacement_random | 5 | 20000 | 3 | 202650574 |
| n10_r5_q5_replacement_rep5 | 5 | projective_points_with_replacement_random | 5 | 20000 | 3 | 202650575 |
| n10_r5_q7_random_rep1 | 5 | projective_subsets_random | 7 | 20000 | 0 | 202650731 |
| n10_r5_q7_random_rep2 | 5 | projective_subsets_random | 7 | 20000 | 1 | 202650732 |
| n10_r5_q7_random_rep3 | 5 | projective_subsets_random | 7 | 20000 | 0 | 202650733 |
| n10_r5_q7_random_rep4 | 5 | projective_subsets_random | 7 | 20000 | 1 | 202650734 |
| n10_r5_q7_random_rep5 | 5 | projective_subsets_random | 7 | 20000 | 0 | 202650735 |
| n10_r5_q7_replacement_rep1 | 5 | projective_points_with_replacement_random | 7 | 20000 | 0 | 202650771 |
| n10_r5_q7_replacement_rep2 | 5 | projective_points_with_replacement_random | 7 | 20000 | 1 | 202650772 |
| n10_r5_q7_replacement_rep3 | 5 | projective_points_with_replacement_random | 7 | 20000 | 1 | 202650773 |
| n10_r5_q7_replacement_rep4 | 5 | projective_points_with_replacement_random | 7 | 20000 | 0 | 202650774 |
| n10_r5_q7_replacement_rep5 | 5 | projective_points_with_replacement_random | 7 | 20000 | 0 | 202650775 |

## Distribution summary

`Included N` is the number remaining after removing disconnected and $\overline{\alpha}$ = 0 matroids. `Excluded` reports how many stored observations were removed. For polyDB, these are counts of matroids up to isomorphism. For finite-field runs, they are counts of accepted projective configurations or draws, not deduplicated isomorphism classes.

| Ensemble | Included N | Excluded | Distinct encodings | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) | $\overline{\alpha}$ ≥ 8/7 | $\overline{\alpha}$ ≥ 100/81 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, no replacement | 94375 | 5625 | 90273 | 1.000000 | 1.066667 | 8/7 (1.142857) | 27382 (29.01%) [95% CI 28.73%–29.30%] | 120 | 0 |
| GF(2) random, with replacement | 72231 | 27769 | 72176 | 0.997826 | 1.066667 | 8/7 (1.142857) | 9985 (13.82%) [95% CI 13.57%–14.08%] | 19 | 0 |
| GF(3) random, no replacement | 97880 | 2120 | 97877 | 0.959574 | 1.031973 | 256/225 (1.137778) | 13049 (13.33%) [95% CI 13.12%–13.55%] | 0 | 0 |
| GF(3) random, with replacement | 95722 | 4278 | 95720 | 0.966981 | 1.031973 | 256/225 (1.137778) | 11083 (11.58%) [95% CI 11.38%–11.78%] | 0 | 0 |
| GF(5) random, no replacement | 99743 | 257 | 99743 | 0.864055 | 0.963794 | 27/25 (1.080000) | 829 (0.83%) [95% CI 0.78%–0.89%] | 0 | 0 |
| GF(5) random, with replacement | 99700 | 300 | 99700 | 0.868085 | 0.965517 | 490/459 (1.067538) | 780 (0.78%) [95% CI 0.73%–0.84%] | 0 | 0 |
| GF(7) random, no replacement | 99946 | 54 | 99946 | 0.812500 | 0.909226 | 129/124 (1.040323) | 39 (0.04%) [95% CI 0.03%–0.05%] | 0 | 0 |
| GF(7) random, with replacement | 99946 | 54 | 99946 | 0.813605 | 0.911437 | 35/34 (1.029412) | 51 (0.05%) [95% CI 0.04%–0.07%] | 0 | 0 |

The normalized histogram below uses every included observation and 45 equal-width bins; each curve's bin masses sum to one. The staircase traces the bin heights and is not a CDF. Since $\overline{\alpha}$ is an exact rational statistic on a finite matroid population, many classes can share the same value. Thus some jaggedness is genuine atomic mass, while its precise placement also depends on the bin edges. The black dashed line is $\overline{\alpha}$ = 1, the gray dotted line is 8/7, and the red dash-dot line is 100/81. To avoid overplotting, the finite-field curves are split into four panels: GF(2)/GF(3) with replacement, GF(5)/GF(7) with replacement, GF(2)/GF(3) without replacement, and GF(5)/GF(7) without replacement. An exhaustive subset population, when present, belongs to the corresponding without-replacement panel. Common bin edges make the panels directly comparable.

![Probability histogram of $\overline{\alpha}$](../figures/n10_finite_fields/r5/alpha_histogram.png)

## Distribution after excluding sparse paving matroids

Sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, so they cannot contribute to the positive tail beyond 1. The table and companion histogram therefore condition the usual connected, positive-$\overline{\alpha}$ population further on `sparse_paving = 0`. Each histogram curve is renormalized within this smaller population; `N` in its legend and the retained-percentage column below prevent that conditional normalization from hiding the amount of data removed. The companion figure uses exactly the same bin edges, panels, and reference lines as the preceding figure.

| Ensemble | Non-sparse-paving N | Retained | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) |
|---|---:|---:|---:|---:|---:|---:|
| GF(2) random, no replacement | 94375 | 100.00% | 1.000000 | 1.066667 | 8/7 (1.142857) | 27382 (29.01%) |
| GF(2) random, with replacement | 72231 | 100.00% | 0.997826 | 1.066667 | 8/7 (1.142857) | 9985 (13.82%) |
| GF(3) random, no replacement | 97880 | 100.00% | 0.959574 | 1.031973 | 256/225 (1.137778) | 13049 (13.33%) |
| GF(3) random, with replacement | 95722 | 100.00% | 0.966981 | 1.031973 | 256/225 (1.137778) | 11083 (11.58%) |
| GF(5) random, no replacement | 99674 | 99.93% | 0.864055 | 0.963810 | 27/25 (1.080000) | 829 (0.83%) |
| GF(5) random, with replacement | 99637 | 99.94% | 0.868217 | 0.965517 | 490/459 (1.067538) | 780 (0.78%) |
| GF(7) random, no replacement | 98693 | 98.75% | 0.813131 | 0.909605 | 129/124 (1.040323) | 39 (0.04%) |
| GF(7) random, with replacement | 98689 | 98.74% | 0.814583 | 0.911911 | 35/34 (1.029412) | 51 (0.05%) |

As a consistency check, the primary ensembles in this report contain 0 stored sparse paving observations with $\overline{\alpha}$ > 1.

![Probability histogram of $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n10_finite_fields/r5/alpha_histogram_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ after excluding sparse paving matroids

This analysis uses the same connected, positive-$\overline{\alpha}$, non-sparse-paving population as the preceding conditional histogram. Pearson's `r` measures linear association, while Spearman's `ρ` uses weighted midranks and measures monotone association. The final column is the fitted change in $\overline{\alpha}$ associated with a 0.1 increase in basis density.

For random finite-field ensembles, the table gives two-sided tests of zero association. Pearson intervals and tests use the Fisher transformation; the Spearman test uses the usual large-sample normal approximation after assigning midranks to ties. A `census` entry means the row is polyDB or exhaustive, so its coefficient is an exact population description and an inferential p-value would be inappropriate. With the very large random samples here, effect sizes are more informative than tiny p-values.

| Ensemble | N | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, no replacement | 94375 | -0.0710 | [-0.0774, -0.0647] | < 1e-15 | +0.1713 | < 1e-15 | -0.0065 |
| GF(2) random, with replacement | 72231 | +0.1462 | [+0.1391, +0.1533] | < 1e-15 | +0.2853 | < 1e-15 | +0.0066 |
| GF(3) random, no replacement | 97880 | -0.5389 | [-0.5434, -0.5345] | < 1e-15 | -0.5529 | < 1e-15 | -0.0418 |
| GF(3) random, with replacement | 95722 | -0.4373 | [-0.4424, -0.4322] | < 1e-15 | -0.4310 | < 1e-15 | -0.0232 |
| GF(5) random, no replacement | 99674 | -0.7547 | [-0.7573, -0.7520] | < 1e-15 | -0.8089 | < 1e-15 | -0.0703 |
| GF(5) random, with replacement | 99637 | -0.7208 | [-0.7238, -0.7178] | < 1e-15 | -0.8002 | < 1e-15 | -0.0568 |
| GF(7) random, no replacement | 98693 | -0.8063 | [-0.8085, -0.8042] | < 1e-15 | -0.8534 | < 1e-15 | -0.0853 |
| GF(7) random, with replacement | 98689 | -0.7894 | [-0.7917, -0.7870] | < 1e-15 | -0.8566 | < 1e-15 | -0.0760 |

The scatterplots show the filtered observations and the weighted least-squares lines used for the final table column. Legend values of `r` and all fitted lines use every observation. Only the point clouds are thinned, at deterministic evenly spaced indices, when a group exceeds 15,000 observations.

![Basis density versus $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n10_finite_fields/r5/basis_density_vs_alpha_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ for sparse paving matroids

This companion instead conditions on `sparse_paving = 1`, while retaining the report's connected and positive-$\overline{\alpha}$ filters. `Retained` is the percentage of that main analysis population which is sparse paving. The number of distinct basis-density levels is included because sparse paving samples often have many ties or only a few possible basis counts.

The coefficients, intervals, tests, and fitted effect use the same definitions as in the preceding non-sparse-paving analysis. A dash means that the ensemble has no retained sparse paving observations or that a coefficient is undefined because one variable is constant. Census and exhaustive rows again receive no inferential p-value.

| Ensemble | N | Retained | Density levels | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, no replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(2) random, with replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(3) random, no replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(3) random, with replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(5) random, no replacement | 69 | 0.07% | 6 | -0.1625 | [-0.3844, +0.0771] | 0.183 | -0.0631 | 0.605 | -0.0663 |
| GF(5) random, with replacement | 63 | 0.06% | 5 | -0.1904 | [-0.4185, +0.0602] | 0.135 | -0.1989 | 0.113 | -0.1000 |
| GF(7) random, no replacement | 1253 | 1.25% | 9 | +0.0102 | [-0.0452, +0.0656] | 0.717 | +0.1531 | 4.24e-08 | +0.0034 |
| GF(7) random, with replacement | 1257 | 1.26% | 10 | -0.0073 | [-0.0625, +0.0481] | 0.797 | +0.1090 | 0.000103 | -0.0024 |

The sparse-paving plots use all observations for correlations and fitted lines and the same deterministic 15,000-point rendering cap. Empty panels explicitly say that no observations survived the filter. Because sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, only the black $\overline{\alpha}$ = 1 reference line is drawn.

![Basis density versus $\overline{\alpha}$ for sparse paving matroids](../figures/n10_finite_fields/r5/basis_density_vs_alpha_sparse_paving.png)

## Structural prevalence

This table uses the complete stored rank scope before the distribution filter, so the connected column also documents how much of the original population is retained for distributional analysis.

| Ensemble | N | Simple | Cosimple | Connected | 3-connected | Paving | Sparse paving |
|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, no replacement | 100000 | 100.00% | 46.77% | 94.38% | 46.02% | 0.00% | 0.00% |
| GF(2) random, with replacement | 100000 | 19.90% | 18.77% | 72.23% | 9.16% | 0.00% | 0.00% |
| GF(3) random, no replacement | 100000 | 100.00% | 75.79% | 97.88% | 74.37% | 0.00% | 0.00% |
| GF(3) random, with replacement | 100000 | 68.57% | 66.83% | 95.72% | 50.84% | 0.00% | 0.00% |
| GF(5) random, no replacement | 100000 | 100.00% | 94.81% | 99.74% | 94.58% | 0.14% | 0.07% |
| GF(5) random, with replacement | 100000 | 94.34% | 94.16% | 99.70% | 89.23% | 0.12% | 0.06% |
| GF(7) random, no replacement | 100000 | 100.00% | 98.38% | 99.95% | 98.34% | 3.14% | 1.25% |
| GF(7) random, with replacement | 100000 | 98.37% | 98.32% | 99.95% | 96.77% | 3.14% | 1.26% |

Each row uses one of the same four field-pair/replacement comparison groups. The left column relates $\overline{\alpha}$ to the fraction of rank-sized subsets that are bases; the right column compares $\overline{\alpha}$ with the fraction of eligible element pairs having positive association. Every panel uses the connected, positive-$\overline{\alpha}$ population. For rendering only, groups larger than 15,000 are thinned at deterministic evenly spaced indices; summary tables and histograms remain exact.

![Matroid-level scatterplots](../figures/n10_finite_fields/r5/matroid_scatterplots.png)

## Pair-association distribution

The pair histogram also uses only connected matroids with $\overline{\alpha}$ > 0. Within each matroid, every eligible pair receives weight `1 / eligible_pair_count`, so each matroid contributes total weight one regardless of how many eligible pairs it has. Zero ratios cannot be shown on the logarithmic axis; their probability mass is reported in the legend. The vertical reference lines have the same meanings as in the $\overline{\alpha}$ histogram after taking logarithms. The four panels use the same field-pair/replacement split as the matroid-level histogram.

![Pair log-ratio probability histogram](../figures/n10_finite_fields/r5/pair_logratio_histogram.png)

The next scatterplot compares the maximum odds ratio $\overline{\alpha}$ with the largest Pearson correlation among eligible pairs. It shows whether a large odds ratio is also a large standardized effect. It uses the same filtered population and deterministic rendering sample as the other scatterplots, again separated into the four field-pair/replacement panels.

![Odds ratio versus Pearson correlation](../figures/n10_finite_fields/r5/odds_ratio_vs_pearson.png)

## Upper-tail observations

The table lists the ten largest connected, positive-$\overline{\alpha}$ observations in this rank scope. PolyDB rows are isomorphism-class representatives.

| Source | Rank | Field | Identifier | Bases | $\overline{\alpha}$ | Maximizing pair | Positive-pair fraction |
|---|---:|---:|---|---:|---:|---|---:|
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650271_draw_00007573 | 136 | 8/7 | {7, 8} | 2.22% |
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650271_draw_00008446 | 136 | 8/7 | {4, 7} | 2.22% |
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650271_draw_00018848 | 136 | 8/7 | {1, 6} | 2.22% |
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650272_draw_00001009 | 136 | 8/7 | {6, 9} | 2.22% |
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650272_draw_00001205 | 136 | 8/7 | {2, 4} | 2.22% |
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650272_draw_00005480 | 136 | 8/7 | {4, 9} | 2.22% |
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650272_draw_00019659 | 136 | 8/7 | {5, 7} | 2.22% |
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650273_draw_00004485 | 136 | 8/7 | {0, 8} | 2.22% |
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650273_draw_00005855 | 136 | 8/7 | {0, 4} | 2.22% |
| projective points with replacement random | 5 | 2 | pg2_replacement_seed202650273_draw_00013234 | 136 | 8/7 | {5, 9} | 2.22% |

For the maximum in each primary ensemble, the following 2×2 panel shows the raw basis counts and, in parentheses, their normalized cell probabilities. Rows and columns indicate exclusion or inclusion of the maximizing elements.

![Maximizing-pair contingency tables](../figures/n10_finite_fields/r5/maximizing_pair_profiles.png)

The final heatmap shows `log Rᵢⱼ` for every eligible element pair of the same selected matroid. Red indicates positive association, blue negative association, and light gray marks the diagonal or an ineligible pair. Exact zero ratios are displayed at the plotting floor -3. Element labels match the stored zero-based basis encoding.

![Pair heatmaps for ensemble maxima](../figures/n10_finite_fields/r5/top_pair_heatmaps.png)

## Data exports

- [`runs.csv`](../data/n10_finite_fields/r5/exports/runs.csv)
- [`selected_matroids.csv`](../data/n10_finite_fields/r5/exports/selected_matroids.csv)
- [`selected_pairs.csv`](../data/n10_finite_fields/r5/exports/selected_pairs.csv)

The SQLite tables are authoritative. Bulk `matroids` and `pair_ratio_aggregates` CSV files duplicate SQLite and are generated only on demand with `scripts/export_bulk_tables.jl`. Exact $\overline{\alpha}$ values, aggregate ratio keys, and selected pair ratios use reduced integer numerators and denominators; floating-point columns are supplied for summaries and visualization.
