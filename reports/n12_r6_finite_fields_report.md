# Unweighted correlation ratios for rank-6 matroids on 12 elements

This report studies rank 6. For every distributional table and matroid-level distribution figure, the analysis population excludes disconnected matroids and all matroids with zero correlation ratio; equivalently, it uses `connected = 1` and `alpha_num > 0`.

## Reproducibility and validation

- SQLite database: [`results.sqlite`](../data/n12_finite_fields/r6/results.sqlite)
- Stored matroid observations in this rank scope: 900000
- Eligible pairs represented in aggregate tables: 59122696
- Eligible pairs expected from matroid summaries: 59122696
- Matroids selected for detailed pair profiles: 12
- Detailed selected-pair rows: 792
- Selected matroids whose $\overline{\alpha}$ disagrees with their recomputed pair maximum: 0
- Selected pairs with a nonpositive mixed cell or denominator: 0
- Element labels and maximizing pairs are zero-based.

Every matroid is stored losslessly as a packed hexadecimal form of its polyDB-compatible `REVLEX_BASIS_ENCODING`. Decoding gives one character for each rank-sized subset in reverse-lexicographic/colex order, with `*` for a basis and `0` for a nonbasis. Complete pair profiles are reproducible derived data and are retained only for selected examples.

## Runs

| Run | Rank | Ensemble | Field | Accepted | Rejected | Seed |
|---|---:|---|---:|---:|---:|---:|
| n12_r6_johnson_p0010_rep1 | 6 | johnson_random_greedy_p0.01 | — | 5000 | 0 | 315070001 |
| n12_r6_johnson_p0010_rep2 | 6 | johnson_random_greedy_p0.01 | — | 5000 | 0 | 315070002 |
| n12_r6_johnson_p0010_rep3 | 6 | johnson_random_greedy_p0.01 | — | 5000 | 0 | 315070003 |
| n12_r6_johnson_p0010_rep4 | 6 | johnson_random_greedy_p0.01 | — | 5000 | 0 | 315070004 |
| n12_r6_johnson_p0010_rep5 | 6 | johnson_random_greedy_p0.01 | — | 5000 | 0 | 315070005 |
| n12_r6_johnson_p0050_rep1 | 6 | johnson_random_greedy_p0.05 | — | 5000 | 0 | 315110001 |
| n12_r6_johnson_p0050_rep2 | 6 | johnson_random_greedy_p0.05 | — | 5000 | 0 | 315110002 |
| n12_r6_johnson_p0050_rep3 | 6 | johnson_random_greedy_p0.05 | — | 5000 | 0 | 315110003 |
| n12_r6_johnson_p0050_rep4 | 6 | johnson_random_greedy_p0.05 | — | 5000 | 0 | 315110004 |
| n12_r6_johnson_p0050_rep5 | 6 | johnson_random_greedy_p0.05 | — | 5000 | 0 | 315110005 |
| n12_r6_johnson_p0200_rep1 | 6 | johnson_random_greedy_p0.2 | — | 5000 | 0 | 315260001 |
| n12_r6_johnson_p0200_rep2 | 6 | johnson_random_greedy_p0.2 | — | 5000 | 0 | 315260002 |
| n12_r6_johnson_p0200_rep3 | 6 | johnson_random_greedy_p0.2 | — | 5000 | 0 | 315260003 |
| n12_r6_johnson_p0200_rep4 | 6 | johnson_random_greedy_p0.2 | — | 5000 | 0 | 315260004 |
| n12_r6_johnson_p0200_rep5 | 6 | johnson_random_greedy_p0.2 | — | 5000 | 0 | 315260005 |
| n12_r6_johnson_p1000_rep1 | 6 | johnson_random_greedy_p1.0 | — | 5000 | 0 | 316060001 |
| n12_r6_johnson_p1000_rep2 | 6 | johnson_random_greedy_p1.0 | — | 5000 | 0 | 316060002 |
| n12_r6_johnson_p1000_rep3 | 6 | johnson_random_greedy_p1.0 | — | 5000 | 0 | 316060003 |
| n12_r6_johnson_p1000_rep4 | 6 | johnson_random_greedy_p1.0 | — | 5000 | 0 | 316060004 |
| n12_r6_johnson_p1000_rep5 | 6 | johnson_random_greedy_p1.0 | — | 5000 | 0 | 316060005 |
| n12_r6_q2_random_rep1 | 6 | projective_subsets_random | 2 | 20000 | 70 | 214660231 |
| n12_r6_q2_random_rep2 | 6 | projective_subsets_random | 2 | 20000 | 68 | 214660232 |
| n12_r6_q2_random_rep3 | 6 | projective_subsets_random | 2 | 20000 | 68 | 214660233 |
| n12_r6_q2_random_rep4 | 6 | projective_subsets_random | 2 | 20000 | 72 | 214660234 |
| n12_r6_q2_random_rep5 | 6 | projective_subsets_random | 2 | 20000 | 72 | 214660235 |
| n12_r6_q2_replacement_rep1 | 6 | projective_points_with_replacement_random | 2 | 20000 | 255 | 214660271 |
| n12_r6_q2_replacement_rep2 | 6 | projective_points_with_replacement_random | 2 | 20000 | 251 | 214660272 |
| n12_r6_q2_replacement_rep3 | 6 | projective_points_with_replacement_random | 2 | 20000 | 290 | 214660273 |
| n12_r6_q2_replacement_rep4 | 6 | projective_points_with_replacement_random | 2 | 20000 | 232 | 214660274 |
| n12_r6_q2_replacement_rep5 | 6 | projective_points_with_replacement_random | 2 | 20000 | 281 | 214660275 |
| n12_r6_q3_random_rep1 | 6 | projective_subsets_random | 3 | 20000 | 12 | 214660331 |
| n12_r6_q3_random_rep2 | 6 | projective_subsets_random | 3 | 20000 | 8 | 214660332 |
| n12_r6_q3_random_rep3 | 6 | projective_subsets_random | 3 | 20000 | 4 | 214660333 |
| n12_r6_q3_random_rep4 | 6 | projective_subsets_random | 3 | 20000 | 13 | 214660334 |
| n12_r6_q3_random_rep5 | 6 | projective_subsets_random | 3 | 20000 | 5 | 214660335 |
| n12_r6_q3_replacement_rep1 | 6 | projective_points_with_replacement_random | 3 | 20000 | 15 | 214660371 |
| n12_r6_q3_replacement_rep2 | 6 | projective_points_with_replacement_random | 3 | 20000 | 16 | 214660372 |
| n12_r6_q3_replacement_rep3 | 6 | projective_points_with_replacement_random | 3 | 20000 | 14 | 214660373 |
| n12_r6_q3_replacement_rep4 | 6 | projective_points_with_replacement_random | 3 | 20000 | 12 | 214660374 |
| n12_r6_q3_replacement_rep5 | 6 | projective_points_with_replacement_random | 3 | 20000 | 14 | 214660375 |
| n12_r6_q5_random_rep1 | 6 | projective_subsets_random | 5 | 20000 | 0 | 214660531 |
| n12_r6_q5_random_rep2 | 6 | projective_subsets_random | 5 | 20000 | 0 | 214660532 |
| n12_r6_q5_random_rep3 | 6 | projective_subsets_random | 5 | 20000 | 0 | 214660533 |
| n12_r6_q5_random_rep4 | 6 | projective_subsets_random | 5 | 20000 | 0 | 214660534 |
| n12_r6_q5_random_rep5 | 6 | projective_subsets_random | 5 | 20000 | 1 | 214660535 |
| n12_r6_q5_replacement_rep1 | 6 | projective_points_with_replacement_random | 5 | 20000 | 0 | 214660571 |
| n12_r6_q5_replacement_rep2 | 6 | projective_points_with_replacement_random | 5 | 20000 | 1 | 214660572 |
| n12_r6_q5_replacement_rep3 | 6 | projective_points_with_replacement_random | 5 | 20000 | 0 | 214660573 |
| n12_r6_q5_replacement_rep4 | 6 | projective_points_with_replacement_random | 5 | 20000 | 0 | 214660574 |
| n12_r6_q5_replacement_rep5 | 6 | projective_points_with_replacement_random | 5 | 20000 | 1 | 214660575 |
| n12_r6_q7_random_rep1 | 6 | projective_subsets_random | 7 | 20000 | 0 | 214660731 |
| n12_r6_q7_random_rep2 | 6 | projective_subsets_random | 7 | 20000 | 0 | 214660732 |
| n12_r6_q7_random_rep3 | 6 | projective_subsets_random | 7 | 20000 | 0 | 214660733 |
| n12_r6_q7_random_rep4 | 6 | projective_subsets_random | 7 | 20000 | 0 | 214660734 |
| n12_r6_q7_random_rep5 | 6 | projective_subsets_random | 7 | 20000 | 0 | 214660735 |
| n12_r6_q7_replacement_rep1 | 6 | projective_points_with_replacement_random | 7 | 20000 | 0 | 214660771 |
| n12_r6_q7_replacement_rep2 | 6 | projective_points_with_replacement_random | 7 | 20000 | 0 | 214660772 |
| n12_r6_q7_replacement_rep3 | 6 | projective_points_with_replacement_random | 7 | 20000 | 0 | 214660773 |
| n12_r6_q7_replacement_rep4 | 6 | projective_points_with_replacement_random | 7 | 20000 | 0 | 214660774 |
| n12_r6_q7_replacement_rep5 | 6 | projective_points_with_replacement_random | 7 | 20000 | 0 | 214660775 |

## Distribution summary

`Included N` is the number remaining after removing disconnected and $\overline{\alpha}$ = 0 matroids. `Excluded` reports how many stored observations were removed. For polyDB, these are counts of matroids up to isomorphism. For finite-field runs, they are counts of accepted projective configurations or draws, not deduplicated isomorphism classes. For Johnson-graph runs, they are independent labeled stable-set outputs of the stated random-priority greedy activity, not uniform independent sets or matroid isomorphism classes.

| Ensemble | Included N | Excluded | Distinct encodings | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) | $\overline{\alpha}$ ≥ 8/7 | $\overline{\alpha}$ ≥ 100/81 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 25000 | 0 | 24999 | 0.711290 | 0.719449 | 36/49 (0.734694) | 0 (0.00%) [95% CI 0.00%–0.02%] | 0 | 0 |
| Johnson greedy p = 0.05 | 25000 | 0 | 25000 | 0.722678 | 0.734182 | 169/225 (0.751111) | 0 (0.00%) [95% CI 0.00%–0.02%] | 0 | 0 |
| Johnson greedy p = 0.2 | 25000 | 0 | 25000 | 0.724447 | 0.736260 | 1394/1833 (0.760502) | 0 (0.00%) [95% CI 0.00%–0.02%] | 0 | 0 |
| Johnson greedy p = 1 | 25000 | 0 | 25000 | 0.720508 | 0.730960 | 39601/52670 (0.751870) | 0 (0.00%) [95% CI 0.00%–0.02%] | 0 | 0 |
| GF(2) random, no replacement | 93645 | 6355 | 93644 | 1.013781 | 1.065217 | 57/50 (1.140000) | 55308 (59.06%) [95% CI 58.75%–59.38%] | 0 | 0 |
| GF(2) random, with replacement | 82408 | 17592 | 82408 | 1.000000 | 1.065217 | 57/50 (1.140000) | 35705 (43.33%) [95% CI 42.99%–43.67%] | 0 | 0 |
| GF(3) random, no replacement | 98732 | 1268 | 98732 | 0.956598 | 1.019185 | 3600/3247 (1.108716) | 13064 (13.23%) [95% CI 13.02%–13.44%] | 0 | 0 |
| GF(3) random, with replacement | 98368 | 1632 | 98368 | 0.959808 | 1.019608 | 42/37 (1.135135) | 13240 (13.46%) [95% CI 13.25%–13.67%] | 0 | 0 |
| GF(5) random, no replacement | 99927 | 73 | 99927 | 0.868075 | 0.940669 | 12635/11972 (1.055379) | 139 (0.14%) [95% CI 0.12%–0.16%] | 0 | 0 |
| GF(5) random, with replacement | 99915 | 85 | 99915 | 0.868861 | 0.942529 | 961/918 (1.046841) | 155 (0.16%) [95% CI 0.13%–0.18%] | 0 | 0 |
| GF(7) random, no replacement | 99992 | 8 | 99992 | 0.821937 | 0.890251 | 17689/17056 (1.037113) | 9 (0.01%) [95% CI 0.00%–0.02%] | 0 | 0 |
| GF(7) random, with replacement | 99990 | 10 | 99990 | 0.822396 | 0.890909 | 7791/7600 (1.025132) | 4 (0.00%) [95% CI 0.00%–0.01%] | 0 | 0 |

The normalized histogram below uses every included observation and 45 equal-width bins; each curve's bin masses sum to one. The staircase traces the bin heights and is not a CDF. Since $\overline{\alpha}$ is an exact rational statistic on a finite matroid population, many classes can share the same value. Thus some jaggedness is genuine atomic mass, while its precise placement also depends on the bin edges. The black dashed line is $\overline{\alpha}$ = 1, the gray dotted line is 8/7, and the red dash-dot line is 100/81. To avoid overplotting, the finite-field curves are split into four panels: GF(2)/GF(3) with replacement, GF(5)/GF(7) with replacement, GF(2)/GF(3) without replacement, and GF(5)/GF(7) without replacement. An exhaustive subset population, when present, belongs to the corresponding without-replacement panel. Johnson random-greedy populations are placed in separate panels with at most two activity values each. Common bin edges make all panels directly comparable.

![Probability histogram of $\overline{\alpha}$](../figures/n12_finite_fields/r6/alpha_histogram.png)

## Distribution after excluding sparse paving matroids

Sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, so they cannot contribute to the positive tail beyond 1. The table and companion histogram therefore condition the usual connected, positive-$\overline{\alpha}$ population further on `sparse_paving = 0`. Each histogram curve is renormalized within this smaller population; `N` in its legend and the retained-percentage column below prevent that conditional normalization from hiding the amount of data removed. The companion figure uses exactly the same bin edges, panels, and reference lines as the preceding figure.

| Ensemble | Non-sparse-paving N | Retained | Median $\overline{\alpha}$ | 95th percentile | Maximum | $\overline{\alpha}$ > 1, count (%) |
|---|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 0 | 0.00% | — | — | — | 0 (—) |
| Johnson greedy p = 0.05 | 0 | 0.00% | — | — | — | 0 (—) |
| Johnson greedy p = 0.2 | 0 | 0.00% | — | — | — | 0 (—) |
| Johnson greedy p = 1 | 0 | 0.00% | — | — | — | 0 (—) |
| GF(2) random, no replacement | 93645 | 100.00% | 1.013781 | 1.065217 | 57/50 (1.140000) | 55308 (59.06%) |
| GF(2) random, with replacement | 82408 | 100.00% | 1.000000 | 1.065217 | 57/50 (1.140000) | 35705 (43.33%) |
| GF(3) random, no replacement | 98732 | 100.00% | 0.956598 | 1.019185 | 3600/3247 (1.108716) | 13064 (13.23%) |
| GF(3) random, with replacement | 98368 | 100.00% | 0.959808 | 1.019608 | 42/37 (1.135135) | 13240 (13.46%) |
| GF(5) random, no replacement | 99927 | 100.00% | 0.868075 | 0.940669 | 12635/11972 (1.055379) | 139 (0.14%) |
| GF(5) random, with replacement | 99915 | 100.00% | 0.868861 | 0.942529 | 961/918 (1.046841) | 155 (0.16%) |
| GF(7) random, no replacement | 99992 | 100.00% | 0.821937 | 0.890251 | 17689/17056 (1.037113) | 9 (0.01%) |
| GF(7) random, with replacement | 99990 | 100.00% | 0.822396 | 0.890909 | 7791/7600 (1.025132) | 4 (0.00%) |

As a consistency check, the primary ensembles in this report contain 0 stored sparse paving observations with $\overline{\alpha}$ > 1.

![Probability histogram of $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n12_finite_fields/r6/alpha_histogram_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ after excluding sparse paving matroids

This analysis uses the same connected, positive-$\overline{\alpha}$, non-sparse-paving population as the preceding conditional histogram. Pearson's `r` measures linear association, while Spearman's `ρ` uses weighted midranks and measures monotone association. The final column is the fitted change in $\overline{\alpha}$ associated with a 0.1 increase in basis density.

For random finite-field and Johnson-graph ensembles, the table gives two-sided tests of zero association. Pearson intervals and tests use the Fisher transformation; the Spearman test uses the usual large-sample normal approximation after assigning midranks to ties. A `census` entry means the row is polyDB or exhaustive, so its coefficient is an exact population description and an inferential p-value would be inappropriate. With the very large random samples here, effect sizes are more informative than tiny p-values.

| Ensemble | N | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 0 | — | — | — | — | — | — |
| Johnson greedy p = 0.05 | 0 | — | — | — | — | — | — |
| Johnson greedy p = 0.2 | 0 | — | — | — | — | — | — |
| Johnson greedy p = 1 | 0 | — | — | — | — | — | — |
| GF(2) random, no replacement | 93645 | -0.1145 | [-0.1208, -0.1081] | < 1e-15 | +0.0110 | 0.000758 | -0.0068 |
| GF(2) random, with replacement | 82408 | +0.1133 | [+0.1066, +0.1201] | < 1e-15 | +0.2516 | < 1e-15 | +0.0045 |
| GF(3) random, no replacement | 98732 | -0.6310 | [-0.6348, -0.6273] | < 1e-15 | -0.6613 | < 1e-15 | -0.0385 |
| GF(3) random, with replacement | 98368 | -0.5727 | [-0.5768, -0.5684] | < 1e-15 | -0.6059 | < 1e-15 | -0.0275 |
| GF(5) random, no replacement | 99927 | -0.7994 | [-0.8016, -0.7972] | < 1e-15 | -0.8409 | < 1e-15 | -0.0646 |
| GF(5) random, with replacement | 99915 | -0.7818 | [-0.7842, -0.7794] | < 1e-15 | -0.8416 | < 1e-15 | -0.0588 |
| GF(7) random, no replacement | 99992 | -0.8432 | [-0.8449, -0.8414] | < 1e-15 | -0.8677 | < 1e-15 | -0.0810 |
| GF(7) random, with replacement | 99990 | -0.8328 | [-0.8347, -0.8309] | < 1e-15 | -0.8703 | < 1e-15 | -0.0763 |

The scatterplots show the filtered observations and the weighted least-squares lines used for the final table column. Legend values of `r` and all fitted lines use every observation. Only the point clouds are thinned, at deterministic evenly spaced indices, when a group exceeds 15,000 observations.

![Basis density versus $\overline{\alpha}$ for non-sparse-paving matroids](../figures/n12_finite_fields/r6/basis_density_vs_alpha_non_sparse_paving.png)

## Basis density versus $\overline{\alpha}$ for sparse paving matroids

This companion instead conditions on `sparse_paving = 1`, while retaining the report's connected and positive-$\overline{\alpha}$ filters. `Retained` is the percentage of that main analysis population which is sparse paving. The number of distinct basis-density levels is included because sparse paving samples often have many ties or only a few possible basis counts.

The coefficients, intervals, tests, and fitted effect use the same definitions as in the preceding non-sparse-paving analysis. A dash means that the ensemble has no retained sparse paving observations or that a coefficient is undefined because one variable is constant. Census and exhaustive rows again receive no inferential p-value.

| Ensemble | N | Retained | Density levels | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δ$\overline{\alpha}$ per +0.1 density |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 25000 | 100.00% | 21 | -0.7076 | [-0.7137, -0.7014] | < 1e-15 | -0.6239 | < 1e-15 | -0.1226 |
| Johnson greedy p = 0.05 | 25000 | 100.00% | 25 | -0.1768 | [-0.1888, -0.1648] | < 1e-15 | -0.1430 | < 1e-15 | -0.0312 |
| Johnson greedy p = 0.2 | 25000 | 100.00% | 22 | -0.0397 | [-0.0520, -0.0273] | 3.56e-10 | +0.0015 | 0.808 | -0.0082 |
| Johnson greedy p = 1 | 25000 | 100.00% | 21 | -0.0613 | [-0.0737, -0.0490] | < 1e-15 | +0.0016 | 0.803 | -0.0130 |
| GF(2) random, no replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(2) random, with replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(3) random, no replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(3) random, with replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(5) random, no replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(5) random, with replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(7) random, no replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |
| GF(7) random, with replacement | 0 | 0.00% | 0 | — | — | — | — | — | — |

The sparse-paving plots use all observations for correlations and fitted lines and the same deterministic 15,000-point rendering cap. Empty panels explicitly say that no observations survived the filter. Because sparse paving matroids satisfy $\overline{\alpha}$ ≤ 1, only the black $\overline{\alpha}$ = 1 reference line is drawn.

![Basis density versus $\overline{\alpha}$ for sparse paving matroids](../figures/n12_finite_fields/r6/basis_density_vs_alpha_sparse_paving.png)

## Johnson-graph sampling diagnostics

For a stable set $H$ of the Johnson graph $J(n,r)$, the corresponding sparse paving matroid has $H$ as its circuit-hyperplanes and therefore $\lvert\mathcal B(M)\rvert=\binom nr-\lvert H\rvert$. For each draw, the sampler traverses a fresh uniform random vertex order and selects an available vertex with probability p. At p = 1 the resulting stable set is maximal, which does not mean maximum. The table uses all labeled draws; duplicate encodings remain part of the sampling distribution.

| Ensemble | Draws | Distinct encodings | Minimum $\lvert H\rvert$ | Median $\lvert H\rvert$ | Mean $\lvert H\rvert$ | Maximum $\lvert H\rvert$ | Basis-density range |
|---|---:|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 25000 | 24999 | 0 | 8.0 | 7.884 | 20 | 0.978355–1.000000 |
| Johnson greedy p = 0.05 | 25000 | 25000 | 14 | 25.0 | 25.188 | 38 | 0.958874–0.984848 |
| Johnson greedy p = 0.2 | 25000 | 25000 | 36 | 46.0 | 46.281 | 57 | 0.938312–0.961039 |
| Johnson greedy p = 1 | 25000 | 25000 | 58 | 68.0 | 67.933 | 78 | 0.915584–0.937229 |

## Structural prevalence

This table uses the complete stored rank scope before the distribution filter, so the connected column also documents how much of the original population is retained for distributional analysis.

| Ensemble | N | Simple | Cosimple | Connected | 3-connected | Paving | Sparse paving |
|---|---:|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 25000 | 100.00% | 100.00% | 100.00% | 100.00% | 100.00% | 100.00% |
| Johnson greedy p = 0.05 | 25000 | 100.00% | 100.00% | 100.00% | 100.00% | 100.00% | 100.00% |
| Johnson greedy p = 0.2 | 25000 | 100.00% | 100.00% | 100.00% | 100.00% | 100.00% | 100.00% |
| Johnson greedy p = 1 | 25000 | 100.00% | 100.00% | 100.00% | 100.00% | 100.00% | 100.00% |
| GF(2) random, no replacement | 100000 | 100.00% | 50.62% | 93.64% | 50.30% | 0.00% | 0.00% |
| GF(2) random, with replacement | 100000 | 33.21% | 31.08% | 82.41% | 16.76% | 0.00% | 0.00% |
| GF(3) random, no replacement | 100000 | 100.00% | 85.17% | 98.73% | 84.80% | 0.00% | 0.00% |
| GF(3) random, with replacement | 100000 | 83.28% | 82.36% | 98.37% | 70.71% | 0.00% | 0.00% |
| GF(5) random, no replacement | 100000 | 100.00% | 98.29% | 99.93% | 98.27% | 0.00% | 0.00% |
| GF(5) random, with replacement | 100000 | 98.35% | 98.25% | 99.91% | 96.67% | 0.00% | 0.00% |
| GF(7) random, no replacement | 100000 | 100.00% | 99.65% | 99.99% | 99.65% | 0.00% | 0.00% |
| GF(7) random, with replacement | 100000 | 99.64% | 99.61% | 99.99% | 99.24% | 0.00% | 0.00% |

Each row uses the same field-pair/replacement or Johnson-activity comparison panels as the distribution figure. The left column relates $\overline{\alpha}$ to the fraction of rank-sized subsets that are bases; the right column compares $\overline{\alpha}$ with the fraction of eligible element pairs having positive association. Every panel uses the connected, positive-$\overline{\alpha}$ population. For rendering only, groups larger than 15,000 are thinned at deterministic evenly spaced indices; summary tables and histograms remain exact.

![Matroid-level scatterplots](../figures/n12_finite_fields/r6/matroid_scatterplots.png)

## Pair-association distribution

The pair histogram also uses only connected matroids with $\overline{\alpha}$ > 0. Within each matroid, every eligible pair receives weight `1 / eligible_pair_count`, so each matroid contributes total weight one regardless of how many eligible pairs it has. Zero ratios cannot be shown on the logarithmic axis; their probability mass is reported in the legend. The vertical reference lines have the same meanings as in the $\overline{\alpha}$ histogram after taking logarithms. The panels use the same field-pair/replacement and Johnson-activity split as the matroid-level histogram.

![Pair log-ratio probability histogram](../figures/n12_finite_fields/r6/pair_logratio_histogram.png)

The next scatterplot compares the maximum odds ratio $\overline{\alpha}$ with the largest Pearson correlation among eligible pairs. It shows whether a large odds ratio is also a large standardized effect. It uses the same filtered population and deterministic rendering sample as the other scatterplots, again separated into the same comparison panels.

![Odds ratio versus Pearson correlation](../figures/n12_finite_fields/r6/odds_ratio_vs_pearson.png)

## Upper-tail observations

The table lists the ten largest connected, positive-$\overline{\alpha}$ observations in this rank scope. PolyDB rows are isomorphism-class representatives.

| Source | Rank | Field | Identifier | Bases | $\overline{\alpha}$ | Maximizing pair | Positive-pair fraction |
|---|---:|---:|---|---:|---:|---|---:|
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660271_draw_00009196 | 340 | 57/50 | {1, 2} | 1.52% |
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660271_draw_00010932 | 340 | 57/50 | {4, 5} | 1.52% |
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660272_draw_00003107 | 340 | 57/50 | {6, 10} | 1.52% |
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660272_draw_00009639 | 340 | 57/50 | {3, 4} | 1.52% |
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660272_draw_00010909 | 340 | 57/50 | {5, 6} | 1.52% |
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660272_draw_00013669 | 340 | 57/50 | {3, 5} | 1.52% |
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660272_draw_00014483 | 340 | 57/50 | {5, 6} | 1.52% |
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660273_draw_00004879 | 340 | 57/50 | {0, 1} | 1.52% |
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660274_draw_00010382 | 340 | 57/50 | {2, 11} | 1.52% |
| projective points with replacement random | 6 | 2 | pg2_replacement_seed214660275_draw_00006227 | 340 | 57/50 | {3, 7} | 1.52% |

For the maximum in each primary ensemble, the following 2×2 panel shows the raw basis counts and, in parentheses, their normalized cell probabilities. Rows and columns indicate exclusion or inclusion of the maximizing elements.

![Maximizing-pair contingency tables](../figures/n12_finite_fields/r6/maximizing_pair_profiles.png)

The final heatmap shows `log Rᵢⱼ` for every eligible element pair of the same selected matroid. Red indicates positive association, blue negative association, and light gray marks the diagonal or an ineligible pair. Exact zero ratios are displayed at the plotting floor -3. Element labels match the stored zero-based basis encoding.

![Pair heatmaps for ensemble maxima](../figures/n12_finite_fields/r6/top_pair_heatmaps.png)

## Data exports

- [`runs.csv`](../data/n12_finite_fields/r6/exports/runs.csv)
- [`selected_matroids.csv`](../data/n12_finite_fields/r6/exports/selected_matroids.csv)
- [`selected_pairs.csv`](../data/n12_finite_fields/r6/exports/selected_pairs.csv)

The SQLite tables are authoritative. Bulk `matroids` and `pair_ratio_aggregates` CSV files duplicate SQLite and are generated only on demand with `scripts/export_bulk_tables.jl`. Exact $\overline{\alpha}$ values, aggregate ratio keys, and selected pair ratios use reduced integer numerators and denominators; floating-point columns are supplied for summaries and visualization.
