# Unweighted correlation ratios for rank-3 matroids on 9 elements

This report studies rank 3. For every distributional table and matroid-level distribution figure, the analysis population excludes disconnected matroids and all matroids with zero correlation ratio; equivalently, it uses `connected = 1` and `alpha_num > 0`.

## Reproducibility and validation

- SQLite database: [`results.sqlite`](../data/n9_census/results.sqlite)
- Stored matroid observations in this rank scope: 1275
- Eligible pairs represented in aggregate tables: 41824
- Eligible pairs expected from matroid summaries: 41824
- Matroids selected for detailed pair profiles: 1
- Detailed selected-pair rows: 36
- Selected matroids whose $\overline{\alpha}$ disagrees with their recomputed pair maximum: 0
- Selected pairs with a nonpositive mixed cell or denominator: 0
- Element labels and maximizing pairs are zero-based.

Every matroid is stored losslessly as a packed hexadecimal form of its polyDB-compatible `REVLEX_BASIS_ENCODING`. Decoding gives one character for each rank-sized subset in reverse-lexicographic/colex order, with `*` for a basis and `0` for a nonbasis. Complete pair profiles are reproducible derived data and are retained only for selected examples.

## Runs

| Run | Rank | Ensemble | Field | Accepted | Rejected | Seed |
|---|---:|---|---:|---:|---:|---:|
| polydb_n9_r3 | 3 | polydb_isomorphism_classes | — | 1275 | 0 | — |

## Distribution summary

`Included N` is the number remaining after removing disconnected and $\overline{\alpha}$ = 0 matroids. `Excluded` reports how many stored observations were removed. For polyDB, these are counts of matroids up to isomorphism. For finite-field runs, they are counts of accepted projective configurations or draws, not deduplicated isomorphism classes.

| Ensemble | Included N | Excluded | Distinct encodings | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) | $\overline{\alpha}$ ≥ 8/7 | $\overline{\alpha}$ ≥ 100/81 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 901 | 374 | 901 | 0.782895 | 0.952381 | 1 (1.000000) | 0 (0.00%) | 0 | 0 |
| polyDB simple | 382 | 1 | 382 | 0.721875 | 0.848485 | 35/36 (0.972222) | 0 (0.00%) | 0 | 0 |

The normalized histogram below uses every included observation and 45 equal-width bins; each curve's bin masses sum to one. The staircase traces the bin heights and is not a CDF. Since $\overline{\alpha}$ is an exact rational statistic on a finite matroid population, many classes can share the same value. Thus some jaggedness is genuine atomic mass, while its precise placement also depends on the bin edges. The black dashed line is $\overline{\alpha}$ = 1, the gray dotted line is 8/7, and the red dash-dot line is 100/81. To avoid overplotting, the finite-field curves are split into four panels: GF(2)/GF(3) with replacement, GF(5)/GF(7) with replacement, GF(2)/GF(3) without replacement, and GF(5)/GF(7) without replacement. An exhaustive subset population, when present, belongs to the corresponding without-replacement panel. Common bin edges make the panels directly comparable.

![Probability histogram of $\overline{\alpha}$](../figures/n9_census/r3/alpha_histogram.png)

## Distribution after excluding sparse paving matroids

Sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, so they cannot contribute to the positive tail beyond 1. The table and companion histogram therefore condition the usual connected, positive-$\overline{\alpha}$ population further on `sparse_paving = 0`. Each histogram curve is renormalized within this smaller population; `N` in its legend and the retained-percentage column below prevent that conditional normalization from hiding the amount of data removed. The companion figure uses exactly the same bin edges, panels, and reference lines as the preceding figure.

| Ensemble | Non-sparse-paving N | Retained | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) |
|---|---:|---:|---:|---:|---:|---:|
| polyDB | 738 | 81.91% | 0.805556 | 0.958333 | 1 (1.000000) | 0 (0.00%) |
| polyDB simple | 219 | 57.33% | 0.759868 | 0.875000 | 35/36 (0.972222) | 0 (0.00%) |

As a consistency check, the primary ensembles in this report contain 0 stored sparse paving observations with $\overline{\alpha}$ > 1.

![Probability histogram of $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n9_census/r3/alpha_histogram_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ after excluding sparse paving matroids

This analysis uses the same connected, positive-$\overline{\alpha}$, non-sparse-paving population as the preceding conditional histogram. Pearson's `r` measures linear association, while Spearman's `ρ` uses weighted midranks and measures monotone association. The final column is the fitted change in $\overline{\alpha}$ associated with a 0.1 increase in basis density.

For random finite-field ensembles, the table gives two-sided tests of zero association. Pearson intervals and tests use the Fisher transformation; the Spearman test uses the usual large-sample normal approximation after assigning midranks to ties. A `census` entry means the row is polyDB or exhaustive, so its coefficient is an exact population description and an inferential p-value would be inappropriate. With the very large random samples here, effect sizes are more informative than tiny p-values.

| Ensemble | N | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 738 | -0.7490 | — | census | -0.7678 | census | -0.0446 |
| polyDB simple | 219 | -0.6079 | — | census | -0.6548 | census | -0.0715 |

The scatterplots show the filtered observations and the weighted least-squares lines used for the final table column. Legend values of `r` and all fitted lines use every observation. Only the point clouds are thinned, at deterministic evenly spaced indices, when a group exceeds 15,000 observations.

![Basis density versus $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n9_census/r3/basis_density_vs_alpha_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ for sparse paving matroids

This companion instead conditions on `sparse_paving = 1`, while retaining the report's connected and positive-$\overline{\alpha}$ filters. `Retained` is the percentage of that main analysis population which is sparse paving. The number of distinct basis-density levels is included because sparse paving samples often have many ties or only a few possible basis counts.

The coefficients, intervals, tests, and fitted effect use the same definitions as in the preceding non-sparse-paving analysis. A dash means that the ensemble has no retained sparse paving observations or that a coefficient is undefined because one variable is constant. Census and exhaustive rows again receive no inferential p-value.

| Ensemble | N | Retained | Density levels | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 163 | 18.09% | 13 | -0.3152 | — | census | -0.2540 | census | -0.0540 |
| polyDB simple | 163 | 42.67% | 13 | -0.3152 | — | census | -0.2540 | census | -0.0540 |

The sparse-paving plots use all observations for correlations and fitted lines and the same deterministic 15,000-point rendering cap. Empty panels explicitly say that no observations survived the filter. Because sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, only the black $\overline{\alpha}$ = 1 reference line is drawn.

![Basis density versus $\overline{\alpha}$ for sparse paving matroids](../figures/n9_census/r3/basis_density_vs_alpha_sparse_paving.png)

## Structural prevalence

This table uses the complete stored rank scope before the distribution filter, so the connected column also documents how much of the original population is retained for distributional analysis.

| Ensemble | N | Simple | Cosimple | Connected | 3-connected | Paving | Sparse paving |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 1275 | 30.04% | 85.65% | 70.67% | 29.49% | 30.04% | 12.78% |
| polyDB simple | 383 | 100.00% | 99.22% | 99.74% | 98.17% | 100.00% | 42.56% |

Each row uses one of the same four field-pair/replacement comparison groups. The left column relates $\overline{\alpha}$ to the fraction of rank-sized subsets that are bases; the right column compares $\overline{\alpha}$ with the fraction of eligible element pairs having positive association. Every panel uses the connected, positive-$\overline{\alpha}$ population. For rendering only, groups larger than 15,000 are thinned at deterministic evenly spaced indices; summary tables and histograms remain exact.

![Matroid-level scatterplots](../figures/n9_census/r3/matroid_scatterplots.png)

## Pair-association distribution

The pair histogram also uses only connected matroids with $\overline{\alpha}$ > 0. Within each matroid, every eligible pair receives weight `1 / eligible_pair_count`, so each matroid contributes total weight one regardless of how many eligible pairs it has. Zero ratios cannot be shown on the logarithmic axis; their probability mass is reported in the legend. The vertical reference lines have the same meanings as in the $\overline{\alpha}$ histogram after taking logarithms. The four panels use the same field-pair/replacement split as the matroid-level histogram.

![Pair log-ratio probability histogram](../figures/n9_census/r3/pair_logratio_histogram.png)

The next scatterplot compares the maximum odds ratio $\overline{\alpha}$ with the largest Pearson correlation among eligible pairs. It shows whether a large odds ratio is also a large standardized effect. It uses the same filtered population and deterministic rendering sample as the other scatterplots, again separated into the four field-pair/replacement panels.

![Odds ratio versus Pearson correlation](../figures/n9_census/r3/odds_ratio_vs_pearson.png)

## Upper-tail observations

The table lists the ten largest connected, positive-$\overline{\alpha}$ observations in this rank scope. PolyDB rows are isomorphism-class representatives.

| Source | Rank | Field | Identifier | Bases | $\overline{\alpha}$ | Maximizing pair | Positive-pair fraction |
|---|---:|---:|---|---:|---:|---|---:|
| polyDB | 3 | — | n9r3_00000494 | 63 | 1 | {0, 6} | 0.00% |
| polyDB | 3 | — | n9r3_00000684 | 60 | 1 | {0, 8} | 0.00% |
| polyDB | 3 | — | n9r3_00000751 | 50 | 1 | {0, 8} | 0.00% |
| polyDB | 3 | — | n9r3_00000828 | 48 | 1 | {0, 3} | 0.00% |
| polyDB | 3 | — | n9r3_00000949 | 49 | 1 | {0, 8} | 0.00% |
| polyDB | 3 | — | n9r3_00001037 | 40 | 1 | {0, 8} | 0.00% |
| polyDB | 3 | — | n9r3_00000749 | 51 | 120/121 | {2, 5} | 0.00% |
| polyDB | 3 | — | n9r3_00000985 | 46 | 119/120 | {5, 6} | 0.00% |
| polyDB | 3 | — | n9r3_00000990 | 39 | 80/81 | {3, 6} | 0.00% |
| polyDB | 3 | — | n9r3_00000989 | 41 | 76/77 | {0, 6} | 0.00% |

For the maximum in each primary ensemble, the following 2×2 panel shows the raw basis counts and, in parentheses, their normalized cell probabilities. Rows and columns indicate exclusion or inclusion of the maximizing elements.

![Maximizing-pair contingency tables](../figures/n9_census/r3/maximizing_pair_profiles.png)

The final heatmap shows `log Rᵢⱼ` for every eligible element pair of the same selected matroid. Red indicates positive association, blue negative association, and light gray marks the diagonal or an ineligible pair. Exact zero ratios are displayed at the plotting floor -3. Element labels match the stored zero-based basis encoding.

![Pair heatmaps for ensemble maxima](../figures/n9_census/r3/top_pair_heatmaps.png)

## Data exports

- [`runs.csv`](../data/n9_census/exports/r3/runs.csv)
- [`selected_matroids.csv`](../data/n9_census/exports/r3/selected_matroids.csv)
- [`selected_pairs.csv`](../data/n9_census/exports/r3/selected_pairs.csv)

The SQLite tables are authoritative. Bulk `matroids` and `pair_ratio_aggregates` CSV files duplicate SQLite and are generated only on demand with `scripts/export_bulk_tables.jl`. Exact $\overline{\alpha}$ values, aggregate ratio keys, and selected pair ratios use reduced integer numerators and denominators; floating-point columns are supplied for summaries and visualization.
