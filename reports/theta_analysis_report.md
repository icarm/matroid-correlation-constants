# Statistical analysis of the density-adjusted correlation excess Θ

This is a standalone report. The existing $\overline{\alpha}$ reports are unchanged and do not include Θ.

## Executive summary

- No primary census, finite-field, or Johnson-graph ensemble contains an observed Θ < 0. Equivalently, every connected positive-$\overline{\alpha}$ observation satisfies the uniform-baseline inequality $\overline{\alpha}$(M) ≥ $\overline{\alpha}$(U_{r,n}). This is evidence, not a proof, for the conjectured general inequality.
- The largest distinct observed profile has n = 10, rank 5, basis density 0.738095, $\overline{\alpha}$ = 256/225, and Θ = 248/243 ≈ 1.020576.
- Θ > 1 occurs in 2 primary ensemble cells. Every such observation is automatically non-sparse-paving and has $\overline{\alpha}$ > 1.
- In the exact n = 9, rank 4 census, the median is 0.280506 and the 95th percentile is 0.477667. Sparse paving and non-sparse-paving medians are 0.247642 and 0.359324, respectively.
- Across primary ensemble cells, Spearman correlation with $\overline{\alpha}$ ranges from 0.489 to 1.000, whereas correlation with the raw product d_B $\overline{\alpha}$ ranges from 0.124 to 0.963. Thus baseline correction can materially change rankings.
- In the GF(5) and GF(7) cells, Spearman ρ(d_B, Θ₁) ranges from -0.823 to -0.449. After changing to λ = 2, the range becomes -0.740 to -0.039. The second density factor shifts the association upward but need not eliminate it.
- The largest observed Θ₂ value in the current n ≤ 12 data is 0.753282, and the primary cells contain 0 observations with Θ₂ > 1.
- Where both sparse-paving statuses occur, the non-sparse-paving versus sparse-paving ordinal-superiority statistic ranges from 87.57% to 100.00%.

## Definition and calibration

For a rank-r matroid M on n elements, let

$$
d_{\mathcal B}(M)=\frac{|\mathcal B(M)|}{\binom nr},
\qquad
c_{r,n}=\overline{\alpha}(U_{r,n})=\frac{(r-1)(n-r-1)}{r(n-r)}.
$$

The chosen invariant is

$$
\Theta(M)=d_{\mathcal B}(M)\frac{\overline{\alpha}(M)-c_{r,n}}{1-c_{r,n}}.
$$

It is zero at the uniform-matroid baseline, equals d_B at $\overline{\alpha}$ = 1, lies above the diagonal Θ = d_B exactly when $\overline{\alpha}$ > 1, and satisfies Θ ≤ d_B ≤ 1 for sparse paving matroids. Hence Θ > 1 is a structural certificate.

More generally, consider

$$
\Theta_\lambda(M)
=
d_{\mathcal B}(M)^\lambda
\frac{\overline{\alpha}(M)-c_{r,n}}{1-c_{r,n}}.
$$

For λ = 2,

$$
\Theta_2(M)=d_{\mathcal B}(M)\Theta_1(M).
$$

Because every currently observed Θ₁ is nonnegative and 0 < d_B ≤ 1, the second factor can only lower observed scores. It preserves the sign and the sparse-paving certificate Θ₂ > 1, but makes that certificate harder to attain. At $\overline{\alpha}$ = 1 the calibration changes from Θ₁ = d_B to Θ₂ = d_B².

For the rank-6, 12-element matroid attaining $\overline{\alpha}$ = 100/81, d_B = 57/77 and

$$
\Theta_1=\frac{475}{363}\approx1.30854,
\qquad
\Theta_2=\frac{57}{77}\Theta_1
=\frac{9025}{9317}\approx0.96867.
$$

Thus λ = 2 no longer places the benchmark above 1. This is an important cost of the stronger density penalty.

## Why a negative Θ₁–density correlation is not automatic

Write

$$
D=d_{\mathcal B}(M),
\qquad
Z=\frac{\overline{\alpha}(M)-c_{r,n}}{1-c_{r,n}},
\qquad
\Theta_1=DZ.
$$

At fixed Z, multiplying by D pushes Θ₁ upward. Moreover, the covariance has the exact decomposition

$$
\operatorname{Cov}(D,DZ)
=
\mathbb E[D]\operatorname{Cov}(D,Z)
+\mathbb E[Z]\operatorname{Var}(D)
+\mathbb E[(D-\mathbb E[D])^2(Z-\mathbb E[Z])].
$$

The middle term is nonnegative when the average normalized excess is nonnegative, while the other terms can be negative. Consequently, a negative correlation between $\overline{\alpha}$ and density does not determine the sign of the Θ₁–density correlation. Its observed persistence says that the decline in normalized excess is strong enough to overcome one explicit density factor. Using λ = 2 tests whether a second factor compensates for that decline.

## Populations and statistical conventions

Every table and figure uses connected matroids with $\overline{\alpha}$ > 0. PolyDB rows are isomorphism classes, so census coefficients and percentages are exact descriptions of those finite populations. Finite-field rows are configurations or representations sampled from the stated field and replacement model; they are not uniform samples of matroid isomorphism classes. Johnson-graph rows are independent labeled outputs of a one-pass random-priority greedy law at the displayed activation probability p; they are neither uniform independent sets nor uniform matroid isomorphism classes.

The mean and SD describe the empirical distribution. A 95% Monte Carlo interval for the mean and a Wilson interval for P(Θ > 1) are given only for random finite-field and Johnson-graph cells. Correlations involving Θ are algebraically coupled and are therefore reported descriptively without independence p-values. Weighted midranks handle ties. The sparse-paving probability-of-superiority statistic gives half credit to ties; 50% means no ordinal separation. Upper-decile sets include all ties at the empirical 90th percentile and can therefore contain more than exactly 10% of a population.

Data sources:

- n = 8, rank 4 validation data: [`results.sqlite`](../data/n8_r4_compact/results.sqlite)
- n = 9, rank 3 exact census: [`results.sqlite`](../data/n9_census/results.sqlite)
- n = 9, rank 4 exact census: [`results.sqlite`](../data/n9_census/results.sqlite)
- n = 10, rank 4 finite-field data: [`results.sqlite.zst`](../data/n10_finite_fields/r4/results.sqlite.zst) (temporarily materialized by the report script)
- n = 10, rank 5 finite-field data: [`results.sqlite`](../data/n10_finite_fields/r5/results.sqlite)
- n = 12, rank 6 finite-field and Johnson-graph data: [`results.sqlite`](../data/n12_finite_fields/r6/results.sqlite)

## n = 8, rank 4 validation data

Here c_{r,n} = 9/16 ≈ 0.562500.

### Distribution and thresholds

| Ensemble | N | Mean Θ | 95% MC CI for mean | SD | Minimum | Median | 95th percentile | Maximum |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 731 | 0.383144 | census | 0.148718 | 0.000000 | 0.390306 | 0.614332 | 216/245 (0.881633) |
| polyDB simple | 592 | 0.374186 | census | 0.158835 | 0.000000 | 0.366747 | 0.640561 | 216/245 (0.881633) |
| GF(2) exhaustive, no replacement | 6315 | 0.579155 | exhaustive | 0.141242 | 0.000000 | 0.571429 | 0.881633 | 216/245 (0.881633) |
| GF(3) random, no replacement | 4889 | 0.569127 | [0.565024, 0.573229] | 0.146353 | 0.043641 | 0.600471 | 0.794118 | 1027/1225 (0.838367) |
| GF(5) random, no replacement | 4965 | 0.500704 | [0.497046, 0.504363] | 0.131529 | 0.088687 | 0.521315 | 0.665986 | 1027/1225 (0.838367) |
| GF(7) random, no replacement | 4991 | 0.434764 | [0.431368, 0.438161] | 0.122439 | 0.073255 | 0.446473 | 0.614332 | 1027/1225 (0.838367) |

| Ensemble | Θ < 0 | Θ = 0 | Θ > d_B (equiv. $\overline{\alpha}$ > 1) | Θ > 1 |
|---|---:|---:|---:|---:|
| polyDB | 0 (0.00%) | 4 (0.55%) | 4 (0.55%) | 0 (0.00%) |
| polyDB simple | 0 (0.00%) | 4 (0.68%) | 4 (0.68%) | 0 (0.00%) |
| GF(2) exhaustive, no replacement | 0 (0.00%) | 15 (0.24%) | 840 (13.30%) | 0 (0.00%) |
| GF(3) random, no replacement | 0 (0.00%) | 0 (0.00%) | 325 (6.65%) | 0 (0.00%) [95% MC 0.000%–0.079%] |
| GF(5) random, no replacement | 0 (0.00%) | 0 (0.00%) | 20 (0.40%) | 0 (0.00%) [95% MC 0.000%–0.077%] |
| GF(7) random, no replacement | 0 (0.00%) | 0 (0.00%) | 4 (0.08%) | 0 (0.00%) [95% MC 0.000%–0.077%] |

The histogram uses every retained observation and 45 common equal-width bins within this rank scope. Curves are probability masses, not CDFs. The black dashed line is Θ = 0 and the red dash-dot line is Θ = 1.

![Θ probability histogram for n8_r4](../figures/theta_analysis/n8_r4_theta_histogram.png)

### Relationship with $\overline{\alpha}$, basis density, and d_B $\overline{\alpha}$

| Ensemble | Pearson r(Θ, $\overline{\alpha}$) | Spearman ρ(Θ, $\overline{\alpha}$) | Pearson r(Θ, d_B) | Spearman ρ(Θ, d_B) | Spearman ρ(Θ, d_B $\overline{\alpha}$) | Θ top decile also $\overline{\alpha}$ top decile | Θ top decile also d_B $\overline{\alpha}$ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | +0.8785 | +0.8813 | -0.3491 | -0.5283 | +0.4859 | 55.41% | 58.11% |
| polyDB simple | +0.9642 | +0.9769 | -0.5366 | -0.6318 | +0.7003 | 65.00% | 63.33% |
| GF(2) exhaustive, no replacement | +0.9497 | +1.0000 | +0.3370 | -0.1238 | +0.1238 | 100.00% | 100.00% |
| GF(3) random, no replacement | +0.9376 | +0.8122 | -0.0871 | +0.0590 | +0.8812 | 44.16% | 79.48% |
| GF(5) random, no replacement | +0.9553 | +0.9336 | -0.4210 | -0.4776 | +0.7826 | 80.35% | 30.09% |
| GF(7) random, no replacement | +0.9750 | +0.9729 | -0.6151 | -0.7057 | +0.7749 | 96.03% | 64.29% |

The point clouds are deterministically thinned to at most 15,000 rows per ensemble for rendering only; all coefficients and tables use the complete population. Circles are non-sparse-paving and triangles are sparse paving. The black diagonal is Θ = d_B, equivalently $\overline{\alpha}$ = 1.

![Basis density versus Θ for n8_r4](../figures/theta_analysis/n8_r4_density_vs_theta.png)

### Effect of changing from λ = 1 to λ = 2

| Ensemble | Pearson r(d_B, Θ₁) | Pearson r(d_B, Θ₂) | Spearman ρ(d_B, Θ₁) | Spearman ρ(d_B, Θ₂) | Change in Spearman ρ | Spearman ρ(Θ₁, Θ₂) | Θ₂ top decile also Θ₁ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | -0.3491 | +0.0747 | -0.5283 | -0.1228 | +0.4055 | +0.8755 | 64.63% |
| polyDB simple | -0.5366 | -0.2945 | -0.6318 | -0.4297 | +0.2021 | +0.9536 | 74.63% |
| GF(2) exhaustive, no replacement | +0.3370 | +0.5370 | -0.1238 | +0.8985 | +1.0223 | +0.1238 | 100.00% |
| GF(3) random, no replacement | -0.0871 | +0.2043 | +0.0590 | +0.1538 | +0.0947 | +0.9805 | 100.00% |
| GF(5) random, no replacement | -0.4210 | -0.1241 | -0.4776 | -0.2100 | +0.2676 | +0.9384 | 87.46% |
| GF(7) random, no replacement | -0.6151 | -0.4033 | -0.7057 | -0.5214 | +0.1843 | +0.9528 | 81.20% |

| Ensemble | Median Θ₁ | Median Θ₂ | 95th percentile Θ₂ | Maximum Θ₂ | Θ₂ > 1 |
|---|---:|---:|---:|---:|---:|
| polyDB | 0.390306 | 0.299569 | 0.493190 | 352/525 (0.670476) | 0 (0.00%) |
| polyDB simple | 0.366747 | 0.308571 | 0.509018 | 352/525 (0.670476) | 0 (0.00%) |
| GF(2) exhaustive, no replacement | 0.571429 | 0.347869 | 0.604548 | 5184/8575 (0.604548) | 0 (0.00%) |
| GF(3) random, no replacement | 0.600471 | 0.389650 | 0.565558 | 26702/42875 (0.622787) | 0 (0.00%) |
| GF(5) random, no replacement | 0.521315 | 0.395608 | 0.524781 | 352/525 (0.670476) | 0 (0.00%) |
| GF(7) random, no replacement | 0.446473 | 0.378892 | 0.509018 | 352/525 (0.670476) | 0 (0.00%) |

The companion scatterplot uses Θ₂ = d_B Θ₁. Its black dashed curve is Θ₂ = d_B², the $\overline{\alpha}$ = 1 boundary. Points above the curve have $\overline{\alpha}$ > 1. The same deterministic rendering cap and sparse-paving markers are used.

![Basis density versus Θ₂ for n8_r4](../figures/theta_analysis/n8_r4_density_vs_theta_lambda2.png)

### Sparse-paving comparison

| Ensemble | Sparse paving N | Median Θ | 95th percentile | Maximum | Non-sparse-paving N | Median Θ | 95th percentile | Maximum | Mean difference (non-SP − SP) | Ordinal superiority (ties half) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 270 | 0.258663 | 0.457143 | 0.640561 | 461 | 0.446473 | 0.653212 | 0.881633 | +0.190279 | 87.57% |
| polyDB simple | 270 | 0.258663 | 0.457143 | 0.640561 | 322 | 0.458585 | 0.665986 | 0.881633 | +0.204148 | 88.38% |
| GF(2) exhaustive, no replacement | 15 | 0.000000 | 0.000000 | 0.000000 | 6300 | 0.571429 | 0.881633 | 0.881633 | +0.580534 | 100.00% |
| GF(3) random, no replacement | 66 | 0.113325 | 0.184949 | 0.184949 | 4823 | 0.600471 | 0.794118 | 0.838367 | +0.478925 | 100.00% |
| GF(5) random, no replacement | 578 | 0.239002 | 0.457143 | 0.640561 | 4387 | 0.530002 | 0.665986 | 0.838367 | +0.229275 | 90.78% |
| GF(7) random, no replacement | 1409 | 0.284354 | 0.457143 | 0.544538 | 3582 | 0.502419 | 0.653212 | 0.838367 | +0.179329 | 89.79% |

## n = 9, rank 3 exact census

Here c_{r,n} = 5/9 ≈ 0.555556.

### Distribution and thresholds

| Ensemble | N | Mean Θ | 95% MC CI for mean | SD | Minimum | Median | 95th percentile | Maximum |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 901 | 0.398183 | census | 0.113141 | 0.000000 | 0.401786 | 0.574306 | 3/4 (0.750000) |
| polyDB simple | 382 | 0.344233 | census | 0.117776 | 0.000000 | 0.338579 | 0.544085 | 335/448 (0.747768) |

| Ensemble | Θ < 0 | Θ = 0 | Θ > d_B (equiv. $\overline{\alpha}$ > 1) | Θ > 1 |
|---|---:|---:|---:|---:|
| polyDB | 0 (0.00%) | 2 (0.22%) | 0 (0.00%) | 0 (0.00%) |
| polyDB simple | 0 (0.00%) | 2 (0.52%) | 0 (0.00%) | 0 (0.00%) |

The histogram uses every retained observation and 45 common equal-width bins within this rank scope. Curves are probability masses, not CDFs. The black dashed line is Θ = 0 and the red dash-dot line is Θ = 1.

![Θ probability histogram for n9_r3](../figures/theta_analysis/n9_r3_theta_histogram.png)

### Relationship with $\overline{\alpha}$, basis density, and d_B $\overline{\alpha}$

| Ensemble | Pearson r(Θ, $\overline{\alpha}$) | Spearman ρ(Θ, $\overline{\alpha}$) | Pearson r(Θ, d_B) | Spearman ρ(Θ, d_B) | Spearman ρ(Θ, d_B $\overline{\alpha}$) | Θ top decile also $\overline{\alpha}$ top decile | Θ top decile also d_B $\overline{\alpha}$ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | +0.8279 | +0.8478 | -0.3539 | -0.5342 | +0.3584 | 36.96% | 45.65% |
| polyDB simple | +0.9865 | +0.9928 | -0.5986 | -0.7052 | +0.8830 | 80.00% | 80.00% |

The point clouds are deterministically thinned to at most 15,000 rows per ensemble for rendering only; all coefficients and tables use the complete population. Circles are non-sparse-paving and triangles are sparse paving. The black diagonal is Θ = d_B, equivalently $\overline{\alpha}$ = 1.

![Basis density versus Θ for n9_r3](../figures/theta_analysis/n9_r3_density_vs_theta.png)

### Effect of changing from λ = 1 to λ = 2

| Ensemble | Pearson r(d_B, Θ₁) | Pearson r(d_B, Θ₂) | Spearman ρ(d_B, Θ₁) | Spearman ρ(d_B, Θ₂) | Change in Spearman ρ | Spearman ρ(Θ₁, Θ₂) | Θ₂ top decile also Θ₁ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | -0.3539 | +0.1972 | -0.5342 | -0.0277 | +0.5065 | +0.8136 | 66.30% |
| polyDB simple | -0.5986 | -0.4747 | -0.7052 | -0.6192 | +0.0860 | +0.9855 | 95.00% |

| Ensemble | Median Θ₁ | Median Θ₂ | 95th percentile Θ₂ | Maximum Θ₂ | Θ₂ > 1 |
|---|---:|---:|---:|---:|---:|
| polyDB | 0.401786 | 0.312107 | 0.443242 | 22445/37632 (0.596434) | 0 (0.00%) |
| polyDB simple | 0.338579 | 0.306333 | 0.456407 | 22445/37632 (0.596434) | 0 (0.00%) |

The companion scatterplot uses Θ₂ = d_B Θ₁. Its black dashed curve is Θ₂ = d_B², the $\overline{\alpha}$ = 1 boundary. Points above the curve have $\overline{\alpha}$ > 1. The same deterministic rendering cap and sparse-paving markers are used.

![Basis density versus Θ₂ for n9_r3](../figures/theta_analysis/n9_r3_density_vs_theta_lambda2.png)

### Sparse-paving comparison

| Ensemble | Sparse paving N | Median Θ | 95th percentile | Maximum | Non-sparse-paving N | Median Θ | 95th percentile | Maximum | Mean difference (non-SP − SP) | Ordinal superiority (ties half) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 163 | 0.247259 | 0.369213 | 0.419147 | 738 | 0.424405 | 0.586607 | 0.750000 | +0.178354 | 93.92% |
| polyDB simple | 163 | 0.247259 | 0.369213 | 0.419147 | 219 | 0.400473 | 0.586607 | 0.747768 | +0.160716 | 92.28% |

## n = 9, rank 4 exact census

Here c_{r,n} = 3/5 ≈ 0.600000.

### Distribution and thresholds

| Ensemble | N | Mean Θ | 95% MC CI for mean | SD | Minimum | Median | 95th percentile | Maximum |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 188961 | 0.299482 | census | 0.094894 | 0.000000 | 0.280506 | 0.477667 | 517/588 (0.879252) |
| polyDB simple | 185911 | 0.297227 | census | 0.093495 | 0.000000 | 0.280413 | 0.476720 | 517/588 (0.879252) |

| Ensemble | Θ < 0 | Θ = 0 | Θ > d_B (equiv. $\overline{\alpha}$ > 1) | Θ > 1 |
|---|---:|---:|---:|---:|
| polyDB | 0 (0.00%) | 3 (0.00%) | 50 (0.03%) | 0 (0.00%) |
| polyDB simple | 0 (0.00%) | 3 (0.00%) | 33 (0.02%) | 0 (0.00%) |

The histogram uses every retained observation and 45 common equal-width bins within this rank scope. Curves are probability masses, not CDFs. The black dashed line is Θ = 0 and the red dash-dot line is Θ = 1.

![Θ probability histogram for n9_r4](../figures/theta_analysis/n9_r4_theta_histogram.png)

### Relationship with $\overline{\alpha}$, basis density, and d_B $\overline{\alpha}$

| Ensemble | Pearson r(Θ, $\overline{\alpha}$) | Spearman ρ(Θ, $\overline{\alpha}$) | Pearson r(Θ, d_B) | Spearman ρ(Θ, d_B) | Spearman ρ(Θ, d_B $\overline{\alpha}$) | Θ top decile also $\overline{\alpha}$ top decile | Θ top decile also d_B $\overline{\alpha}$ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | +0.9719 | +0.9911 | -0.5556 | -0.5749 | +0.8210 | 85.66% | 65.96% |
| polyDB simple | +0.9900 | +0.9924 | -0.6268 | -0.5591 | +0.8782 | 90.99% | 65.65% |

The point clouds are deterministically thinned to at most 15,000 rows per ensemble for rendering only; all coefficients and tables use the complete population. Circles are non-sparse-paving and triangles are sparse paving. The black diagonal is Θ = d_B, equivalently $\overline{\alpha}$ = 1.

![Basis density versus Θ for n9_r4](../figures/theta_analysis/n9_r4_density_vs_theta.png)

### Effect of changing from λ = 1 to λ = 2

| Ensemble | Pearson r(d_B, Θ₁) | Pearson r(d_B, Θ₂) | Spearman ρ(d_B, Θ₁) | Spearman ρ(d_B, Θ₂) | Change in Spearman ρ | Spearman ρ(Θ₁, Θ₂) | Θ₂ top decile also Θ₁ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB | -0.5556 | -0.3805 | -0.5749 | -0.4952 | +0.0797 | +0.9851 | 88.69% |
| polyDB simple | -0.6268 | -0.5169 | -0.5591 | -0.4966 | +0.0625 | +0.9933 | 94.35% |

| Ensemble | Median Θ₁ | Median Θ₂ | 95th percentile Θ₂ | Maximum Θ₂ | Θ₂ > 1 |
|---|---:|---:|---:|---:|---:|
| polyDB | 0.280506 | 0.258244 | 0.409306 | 2/3 (0.666667) | 0 (0.00%) |
| polyDB simple | 0.280413 | 0.258244 | 0.409306 | 2/3 (0.666667) | 0 (0.00%) |

The companion scatterplot uses Θ₂ = d_B Θ₁. Its black dashed curve is Θ₂ = d_B², the $\overline{\alpha}$ = 1 boundary. Points above the curve have $\overline{\alpha}$ > 1. The same deterministic rendering cap and sparse-paving markers are used.

![Basis density versus Θ₂ for n9_r4](../figures/theta_analysis/n9_r4_density_vs_theta_lambda2.png)

### Sparse-paving comparison

| Ensemble | Sparse paving N | Median Θ | 95th percentile | Maximum | Non-sparse-paving N | Median Θ | 95th percentile | Maximum | Mean difference (non-SP − SP) | Ordinal superiority (ties half) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB | 113063 | 0.247642 | 0.353753 | 0.750000 | 75898 | 0.359324 | 0.535714 | 0.879252 | +0.120427 | 87.64% |
| polyDB simple | 113063 | 0.247642 | 0.353753 | 0.750000 | 72848 | 0.356375 | 0.532357 | 0.879252 | +0.117688 | 87.26% |

## n = 10, rank 4 finite-field data

Here c_{r,n} = 5/8 ≈ 0.625000.

### Distribution and thresholds

| Ensemble | N | Mean Θ | 95% MC CI for mean | SD | Minimum | Median | 95th percentile | Maximum |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 84481 | 0.420979 | [0.420353, 0.421605] | 0.092839 | 0.099206 | 0.419048 | 0.571429 | 2033/3150 (0.645397) |
| GF(2) exhaustive, no replacement | 3003 | 0.507835 | exhaustive | 0.077140 | 0.431746 | 0.457460 | 0.619636 | 1054/1701 (0.619636) |
| GF(3) random, with replacement | 98439 | 0.510021 | [0.509438, 0.510604] | 0.093296 | 0.170975 | 0.506349 | 0.676861 | 26/27 (0.962963) |
| GF(3) random, no replacement | 99904 | 0.557754 | [0.557163, 0.558345] | 0.095297 | 0.187075 | 0.568833 | 0.688502 | 26/27 (0.962963) |
| GF(5) random, with replacement | 99941 | 0.481577 | [0.480969, 0.482185] | 0.098067 | 0.097956 | 0.478289 | 0.643810 | 26/27 (0.962963) |
| GF(5) random, no replacement | 99980 | 0.481335 | [0.480677, 0.481993] | 0.106163 | 0.066817 | 0.478461 | 0.652144 | 21/25 (0.840000) |
| GF(7) random, with replacement | 99987 | 0.416718 | [0.416078, 0.417357] | 0.103118 | 0.086222 | 0.417234 | 0.583069 | 11/14 (0.785714) |
| GF(7) random, no replacement | 99994 | 0.411358 | [0.410701, 0.412015] | 0.106016 | 0.085597 | 0.411519 | 0.583610 | 2542/3087 (0.823453) |

| Ensemble | Θ < 0 | Θ = 0 | Θ > d_B (equiv. $\overline{\alpha}$ > 1) | Θ > 1 |
|---|---:|---:|---:|---:|
| GF(2) random, with replacement | 0 (0.00%) | 0 (0.00%) | 8998 (10.65%) | 0 (0.00%) [95% MC 0.000%–0.005%] |
| GF(2) exhaustive, no replacement | 0 (0.00%) | 0 (0.00%) | 840 (27.97%) | 0 (0.00%) |
| GF(3) random, with replacement | 0 (0.00%) | 0 (0.00%) | 7806 (7.93%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(3) random, no replacement | 0 (0.00%) | 0 (0.00%) | 8727 (8.74%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(5) random, with replacement | 0 (0.00%) | 0 (0.00%) | 573 (0.57%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(5) random, no replacement | 0 (0.00%) | 0 (0.00%) | 506 (0.51%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(7) random, with replacement | 0 (0.00%) | 0 (0.00%) | 44 (0.04%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(7) random, no replacement | 0 (0.00%) | 0 (0.00%) | 32 (0.03%) | 0 (0.00%) [95% MC 0.000%–0.004%] |

The histogram uses every retained observation and 45 common equal-width bins within this rank scope. Curves are probability masses, not CDFs. The black dashed line is Θ = 0 and the red dash-dot line is Θ = 1.

![Θ probability histogram for n10_r4](../figures/theta_analysis/n10_r4_theta_histogram.png)

### Relationship with $\overline{\alpha}$, basis density, and d_B $\overline{\alpha}$

| Ensemble | Pearson r(Θ, $\overline{\alpha}$) | Spearman ρ(Θ, $\overline{\alpha}$) | Pearson r(Θ, d_B) | Spearman ρ(Θ, d_B) | Spearman ρ(Θ, d_B $\overline{\alpha}$) | Θ top decile also $\overline{\alpha}$ top decile | Θ top decile also d_B $\overline{\alpha}$ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | +0.5624 | +0.6640 | +0.8415 | +0.8972 | +0.9565 | 82.39% | 90.47% |
| GF(2) exhaustive, no replacement | +0.9995 | +1.0000 | -0.9577 | -1.0000 | +0.7082 | 100.00% | 100.00% |
| GF(3) random, with replacement | +0.5986 | +0.5622 | +0.4428 | +0.3889 | +0.7298 | 64.73% | 49.99% |
| GF(3) random, no replacement | +0.9387 | +0.9285 | -0.2914 | -0.4013 | +0.6951 | 64.69% | 71.45% |
| GF(5) random, with replacement | +0.9062 | +0.9021 | -0.3299 | -0.4489 | +0.4863 | 57.51% | 57.31% |
| GF(5) random, no replacement | +0.9729 | +0.9767 | -0.6023 | -0.6851 | +0.6854 | 75.37% | 57.77% |
| GF(7) random, with replacement | +0.9690 | +0.9767 | -0.5950 | -0.7212 | +0.5846 | 74.17% | 51.16% |
| GF(7) random, no replacement | +0.9865 | +0.9921 | -0.7155 | -0.7793 | +0.7610 | 83.91% | 53.92% |

The point clouds are deterministically thinned to at most 15,000 rows per ensemble for rendering only; all coefficients and tables use the complete population. Circles are non-sparse-paving and triangles are sparse paving. The black diagonal is Θ = d_B, equivalently $\overline{\alpha}$ = 1.

![Basis density versus Θ for n10_r4](../figures/theta_analysis/n10_r4_density_vs_theta.png)

### Effect of changing from λ = 1 to λ = 2

| Ensemble | Pearson r(d_B, Θ₁) | Pearson r(d_B, Θ₂) | Spearman ρ(d_B, Θ₁) | Spearman ρ(d_B, Θ₂) | Change in Spearman ρ | Spearman ρ(Θ₁, Θ₂) | Θ₂ top decile also Θ₁ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | +0.8415 | +0.9340 | +0.8972 | +0.9651 | +0.0679 | +0.9778 | 100.00% |
| GF(2) exhaustive, no replacement | -0.9577 | -0.9409 | -1.0000 | -1.0000 | +0.0000 | +1.0000 | 100.00% |
| GF(3) random, with replacement | +0.4428 | +0.7863 | +0.3889 | +0.7570 | +0.3681 | +0.8820 | 64.48% |
| GF(3) random, no replacement | -0.2914 | +0.0801 | -0.4013 | -0.0652 | +0.3361 | +0.9219 | 80.01% |
| GF(5) random, with replacement | -0.3299 | +0.1180 | -0.4489 | -0.0388 | +0.4101 | +0.8828 | 76.11% |
| GF(5) random, no replacement | -0.6023 | -0.3711 | -0.6851 | -0.4910 | +0.1941 | +0.9603 | 76.75% |
| GF(7) random, with replacement | -0.5950 | -0.3536 | -0.7212 | -0.5255 | +0.1957 | +0.9527 | 76.55% |
| GF(7) random, no replacement | -0.7155 | -0.5802 | -0.7793 | -0.6760 | +0.1032 | +0.9831 | 81.18% |

| Ensemble | Median Θ₁ | Median Θ₂ | 95th percentile Θ₂ | Maximum Θ₂ | Θ₂ > 1 |
|---|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 0.419048 | 0.175601 | 0.326531 | 65348/178605 (0.365880) | 0 (0.00%) |
| GF(2) exhaustive, no replacement | 0.457460 | 0.285368 | 0.365880 | 65348/178605 (0.365880) | 0 (0.00%) |
| GF(3) random, with replacement | 0.506349 | 0.312989 | 0.443303 | 676/945 (0.715344) | 0 (0.00%) |
| GF(3) random, no replacement | 0.568833 | 0.387776 | 0.484075 | 676/945 (0.715344) | 0 (0.00%) |
| GF(5) random, with replacement | 0.478289 | 0.362805 | 0.488350 | 676/945 (0.715344) | 0 (0.00%) |
| GF(5) random, no replacement | 0.478461 | 0.380761 | 0.498213 | 5184596/7942725 (0.652748) | 0 (0.00%) |
| GF(7) random, with replacement | 0.417234 | 0.347695 | 0.470143 | 71260949/113116500 (0.629978) | 0 (0.00%) |
| GF(7) random, no replacement | 0.411519 | 0.350762 | 0.475464 | 5184596/7942725 (0.652748) | 0 (0.00%) |

The companion scatterplot uses Θ₂ = d_B Θ₁. Its black dashed curve is Θ₂ = d_B², the $\overline{\alpha}$ = 1 boundary. Points above the curve have $\overline{\alpha}$ > 1. The same deterministic rendering cap and sparse-paving markers are used.

![Basis density versus Θ₂ for n10_r4](../figures/theta_analysis/n10_r4_density_vs_theta_lambda2.png)

### Sparse-paving comparison

| Ensemble | Sparse paving N | Median Θ | 95th percentile | Maximum | Non-sparse-paving N | Median Θ | 95th percentile | Maximum | Mean difference (non-SP − SP) | Ordinal superiority (ties half) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 0 | — | — | — | 84481 | 0.419048 | 0.571429 | 0.645397 | — | — |
| GF(2) exhaustive, no replacement | 0 | — | — | — | 3003 | 0.457460 | 0.619636 | 0.619636 | — | — |
| GF(3) random, with replacement | 0 | — | — | — | 98439 | 0.506349 | 0.676861 | 0.962963 | — | — |
| GF(3) random, no replacement | 0 | — | — | — | 99904 | 0.568833 | 0.688502 | 0.962963 | — | — |
| GF(5) random, with replacement | 66 | 0.135865 | 0.216424 | 0.216424 | 99875 | 0.478373 | 0.643810 | 0.962963 | +0.334463 | 99.94% |
| GF(5) random, no replacement | 102 | 0.135865 | 0.162443 | 0.216424 | 99878 | 0.478461 | 0.652144 | 0.840000 | +0.346638 | 99.97% |
| GF(7) random, with replacement | 1649 | 0.187733 | 0.253146 | 0.352742 | 98338 | 0.419193 | 0.583610 | 0.785714 | +0.230134 | 98.83% |
| GF(7) random, no replacement | 1930 | 0.187733 | 0.253146 | 0.383160 | 98064 | 0.413441 | 0.585034 | 0.823453 | +0.225434 | 98.59% |

## n = 10, rank 5 finite-field data

Here c_{r,n} = 16/25 ≈ 0.640000.

### Distribution and thresholds

| Ensemble | N | Mean Θ | 95% MC CI for mean | SD | Minimum | Median | 95th percentile | Maximum |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 72231 | 0.407672 | [0.406942, 0.408402] | 0.100064 | 0.000000 | 0.396825 | 0.632586 | 2992/3969 (0.753842) |
| GF(2) random, no replacement | 94375 | 0.506225 | [0.505657, 0.506793] | 0.089036 | 0.000000 | 0.510435 | 0.632586 | 2992/3969 (0.753842) |
| GF(3) random, with replacement | 95722 | 0.507741 | [0.507140, 0.508343] | 0.094955 | 0.152415 | 0.502221 | 0.671138 | 248/243 (1.020576) |
| GF(3) random, no replacement | 97880 | 0.537841 | [0.537296, 0.538385] | 0.086898 | 0.152415 | 0.535714 | 0.678348 | 248/243 (1.020576) |
| GF(5) random, with replacement | 99700 | 0.474367 | [0.473755, 0.474979] | 0.098591 | 0.084559 | 0.475474 | 0.634733 | 159445/173502 (0.918981) |
| GF(5) random, no replacement | 99743 | 0.475424 | [0.474800, 0.476049] | 0.100684 | 0.064804 | 0.478628 | 0.637501 | 159445/173502 (0.918981) |
| GF(7) random, with replacement | 99946 | 0.403727 | [0.403074, 0.404379] | 0.105199 | 0.071554 | 0.404692 | 0.575726 | 21808/27027 (0.806897) |
| GF(7) random, no replacement | 99946 | 0.402218 | [0.401563, 0.402872] | 0.105530 | 0.071554 | 0.402384 | 0.576249 | 1160591/1444716 (0.803335) |

| Ensemble | Θ < 0 | Θ = 0 | Θ > d_B (equiv. $\overline{\alpha}$ > 1) | Θ > 1 |
|---|---:|---:|---:|---:|
| GF(2) random, with replacement | 0 (0.00%) | 4 (0.01%) | 9985 (13.82%) | 0 (0.00%) [95% MC 0.000%–0.005%] |
| GF(2) random, no replacement | 0 (0.00%) | 31 (0.03%) | 27382 (29.01%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(3) random, with replacement | 0 (0.00%) | 0 (0.00%) | 11083 (11.58%) | 12 (0.01%) [95% MC 0.007%–0.022%] |
| GF(3) random, no replacement | 0 (0.00%) | 0 (0.00%) | 13049 (13.33%) | 4 (0.00%) [95% MC 0.002%–0.011%] |
| GF(5) random, with replacement | 0 (0.00%) | 0 (0.00%) | 780 (0.78%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(5) random, no replacement | 0 (0.00%) | 0 (0.00%) | 829 (0.83%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(7) random, with replacement | 0 (0.00%) | 0 (0.00%) | 51 (0.05%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(7) random, no replacement | 0 (0.00%) | 0 (0.00%) | 39 (0.04%) | 0 (0.00%) [95% MC 0.000%–0.004%] |

The histogram uses every retained observation and 45 common equal-width bins within this rank scope. Curves are probability masses, not CDFs. The black dashed line is Θ = 0 and the red dash-dot line is Θ = 1.

![Θ probability histogram for n10_r5](../figures/theta_analysis/n10_r5_theta_histogram.png)

### Relationship with $\overline{\alpha}$, basis density, and d_B $\overline{\alpha}$

| Ensemble | Pearson r(Θ, $\overline{\alpha}$) | Spearman ρ(Θ, $\overline{\alpha}$) | Pearson r(Θ, d_B) | Spearman ρ(Θ, d_B) | Spearman ρ(Θ, d_B $\overline{\alpha}$) | Θ top decile also $\overline{\alpha}$ top decile | Θ top decile also d_B $\overline{\alpha}$ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | +0.6164 | +0.5286 | +0.8654 | +0.9172 | +0.9625 | 81.64% | 94.72% |
| GF(2) random, no replacement | +0.8020 | +0.7838 | +0.5328 | +0.5901 | +0.8826 | 19.77% | 81.02% |
| GF(3) random, with replacement | +0.5685 | +0.5325 | +0.4821 | +0.4409 | +0.7457 | 59.94% | 55.75% |
| GF(3) random, no replacement | +0.7860 | +0.7454 | +0.0879 | +0.0465 | +0.6184 | 63.84% | 61.32% |
| GF(5) random, with replacement | +0.9120 | +0.9058 | -0.3862 | -0.5390 | +0.4420 | 61.59% | 46.29% |
| GF(5) random, no replacement | +0.9479 | +0.9483 | -0.5191 | -0.6235 | +0.4612 | 68.98% | 46.60% |
| GF(7) random, with replacement | +0.9726 | +0.9822 | -0.6419 | -0.7799 | +0.5722 | 76.73% | 46.32% |
| GF(7) random, no replacement | +0.9804 | +0.9880 | -0.6909 | -0.7891 | +0.6083 | 81.03% | 47.54% |

The point clouds are deterministically thinned to at most 15,000 rows per ensemble for rendering only; all coefficients and tables use the complete population. Circles are non-sparse-paving and triangles are sparse paving. The black diagonal is Θ = d_B, equivalently $\overline{\alpha}$ = 1.

![Basis density versus Θ for n10_r5](../figures/theta_analysis/n10_r5_density_vs_theta.png)

### Effect of changing from λ = 1 to λ = 2

| Ensemble | Pearson r(d_B, Θ₁) | Pearson r(d_B, Θ₂) | Spearman ρ(d_B, Θ₁) | Spearman ρ(d_B, Θ₂) | Change in Spearman ρ | Spearman ρ(Θ₁, Θ₂) | Θ₂ top decile also Θ₁ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | +0.8654 | +0.9370 | +0.9172 | +0.9740 | +0.0568 | +0.9810 | 90.69% |
| GF(2) random, no replacement | +0.5328 | +0.7753 | +0.5901 | +0.7993 | +0.2091 | +0.9453 | 100.00% |
| GF(3) random, with replacement | +0.4821 | +0.8059 | +0.4409 | +0.7837 | +0.3428 | +0.8903 | 74.67% |
| GF(3) random, no replacement | +0.0879 | +0.5742 | +0.0465 | +0.5111 | +0.4647 | +0.8630 | 73.53% |
| GF(5) random, with replacement | -0.3862 | +0.0576 | -0.5390 | -0.1522 | +0.3868 | +0.8870 | 71.77% |
| GF(5) random, no replacement | -0.5191 | -0.1641 | -0.6235 | -0.3079 | +0.3156 | +0.9140 | 71.46% |
| GF(7) random, with replacement | -0.6419 | -0.4261 | -0.7799 | -0.6181 | +0.1618 | +0.9595 | 77.35% |
| GF(7) random, no replacement | -0.6909 | -0.5152 | -0.7891 | -0.6564 | +0.1327 | +0.9714 | 78.63% |

| Ensemble | Median Θ₁ | Median Θ₂ | 95th percentile Θ₂ | Maximum Θ₂ | Θ₂ > 1 |
|---|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 0.396825 | 0.159903 | 0.325187 | 48200/107163 (0.449782) | 0 (0.00%) |
| GF(2) random, no replacement | 0.510435 | 0.252489 | 0.353947 | 48200/107163 (0.449782) | 0 (0.00%) |
| GF(3) random, with replacement | 0.502221 | 0.307121 | 0.436576 | 3844/5103 (0.753282) | 0 (0.00%) |
| GF(3) random, no replacement | 0.535714 | 0.341217 | 0.448641 | 3844/5103 (0.753282) | 0 (0.00%) |
| GF(5) random, with replacement | 0.475474 | 0.360184 | 0.474148 | 10363925/14574168 (0.711116) | 0 (0.00%) |
| GF(5) random, no replacement | 0.478628 | 0.364585 | 0.476769 | 10363925/14574168 (0.711116) | 0 (0.00%) |
| GF(7) random, with replacement | 0.404692 | 0.335629 | 0.457714 | 613111/950796 (0.644840) | 0 (0.00%) |
| GF(7) random, no replacement | 0.402384 | 0.336600 | 0.457973 | 117219691/182034216 (0.643943) | 0 (0.00%) |

The companion scatterplot uses Θ₂ = d_B Θ₁. Its black dashed curve is Θ₂ = d_B², the $\overline{\alpha}$ = 1 boundary. Points above the curve have $\overline{\alpha}$ > 1. The same deterministic rendering cap and sparse-paving markers are used.

![Basis density versus Θ₂ for n10_r5](../figures/theta_analysis/n10_r5_density_vs_theta_lambda2.png)

### Sparse-paving comparison

| Ensemble | Sparse paving N | Median Θ | 95th percentile | Maximum | Non-sparse-paving N | Median Θ | 95th percentile | Maximum | Mean difference (non-SP − SP) | Ordinal superiority (ties half) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 0 | — | — | — | 72231 | 0.396825 | 0.632586 | 0.753842 | — | — |
| GF(2) random, no replacement | 0 | — | — | — | 94375 | 0.510435 | 0.632586 | 0.753842 | — | — |
| GF(3) random, with replacement | 0 | — | — | — | 95722 | 0.502221 | 0.671138 | 1.020576 | — | — |
| GF(3) random, no replacement | 0 | — | — | — | 97880 | 0.535714 | 0.678348 | 1.020576 | — | — |
| GF(5) random, with replacement | 63 | 0.118381 | 0.216438 | 0.245034 | 99637 | 0.475539 | 0.634736 | 0.918981 | +0.338510 | 99.90% |
| GF(5) random, no replacement | 69 | 0.118381 | 0.215952 | 0.245034 | 99674 | 0.478628 | 0.637560 | 0.918981 | +0.343175 | 99.92% |
| GF(7) random, with replacement | 1257 | 0.166266 | 0.237112 | 0.326524 | 98689 | 0.406360 | 0.576319 | 0.806897 | +0.240962 | 98.98% |
| GF(7) random, no replacement | 1253 | 0.166266 | 0.237112 | 0.395604 | 98693 | 0.404678 | 0.576937 | 0.803335 | +0.240671 | 98.97% |

## n = 12, rank 6 finite-field and Johnson-graph data

Here c_{r,n} = 25/36 ≈ 0.694444.

The Johnson-graph rows use independent stable sets from the labeled random-priority greedy ensemble described above. Separate fixed-p cells show how the conclusions vary with the sampling activity; pooling across those cells would induce an additional between-activity association and is therefore avoided in the reported correlations.

### Distribution and thresholds

| Ensemble | N | Mean Θ | 95% MC CI for mean | SD | Minimum | Median | 95th percentile | Maximum |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 25000 | 0.056709 | [0.056530, 0.056887] | 0.014389 | 0.000000 | 0.054774 | 0.080860 | 4615/35574 (0.129730) |
| Johnson greedy p = 0.05 | 25000 | 0.092337 | [0.092114, 0.092561] | 0.018031 | 0.040121 | 0.090099 | 0.125967 | 544/3025 (0.179835) |
| Johnson greedy p = 0.2 | 25000 | 0.095565 | [0.095332, 0.095798] | 0.018804 | 0.040325 | 0.093834 | 0.129890 | 637867/3105102 (0.205425) |
| Johnson greedy p = 1 | 25000 | 0.081002 | [0.080798, 0.081207] | 0.016500 | 0.032732 | 0.079020 | 0.110839 | 46657651/267668940 (0.174311) |
| GF(2) random, with replacement | 82408 | 0.370382 | [0.369738, 0.371025] | 0.094207 | 0.086202 | 0.365214 | 0.536009 | 19256/27951 (0.688920) |
| GF(2) random, no replacement | 93645 | 0.444933 | [0.444468, 0.445399] | 0.072665 | 0.127236 | 0.443611 | 0.551827 | 19256/27951 (0.688920) |
| GF(3) random, with replacement | 98368 | 0.484262 | [0.483804, 0.484720] | 0.073300 | 0.159110 | 0.485262 | 0.602731 | 8395/10164 (0.825954) |
| GF(3) random, no replacement | 98732 | 0.499148 | [0.498732, 0.499564] | 0.066686 | 0.157152 | 0.499082 | 0.609082 | 601417/719950 (0.835359) |
| GF(5) random, with replacement | 99915 | 0.433342 | [0.432839, 0.433846] | 0.081166 | 0.140689 | 0.433808 | 0.565918 | 750/1001 (0.749251) |
| GF(5) random, no replacement | 99927 | 0.432985 | [0.432481, 0.433488] | 0.081141 | 0.145777 | 0.434191 | 0.565202 | 15895977/20690516 (0.768274) |
| GF(7) random, with replacement | 99990 | 0.356792 | [0.356280, 0.357304] | 0.082630 | 0.109459 | 0.353036 | 0.498834 | 1212313/1575420 (0.769517) |
| GF(7) random, no replacement | 99992 | 0.356312 | [0.355798, 0.356826] | 0.082887 | 0.089140 | 0.352042 | 0.498513 | 303503/408496 (0.742977) |

| Ensemble | Θ < 0 | Θ = 0 | Θ > d_B (equiv. $\overline{\alpha}$ > 1) | Θ > 1 |
|---|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 0 (0.00%) | 1 (0.00%) | 0 (0.00%) | 0 (0.00%) [95% MC 0.000%–0.015%] |
| Johnson greedy p = 0.05 | 0 (0.00%) | 0 (0.00%) | 0 (0.00%) | 0 (0.00%) [95% MC 0.000%–0.015%] |
| Johnson greedy p = 0.2 | 0 (0.00%) | 0 (0.00%) | 0 (0.00%) | 0 (0.00%) [95% MC 0.000%–0.015%] |
| Johnson greedy p = 1 | 0 (0.00%) | 0 (0.00%) | 0 (0.00%) | 0 (0.00%) [95% MC 0.000%–0.015%] |
| GF(2) random, with replacement | 0 (0.00%) | 0 (0.00%) | 35705 (43.33%) | 0 (0.00%) [95% MC 0.000%–0.005%] |
| GF(2) random, no replacement | 0 (0.00%) | 0 (0.00%) | 55308 (59.06%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(3) random, with replacement | 0 (0.00%) | 0 (0.00%) | 13240 (13.46%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(3) random, no replacement | 0 (0.00%) | 0 (0.00%) | 13064 (13.23%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(5) random, with replacement | 0 (0.00%) | 0 (0.00%) | 155 (0.16%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(5) random, no replacement | 0 (0.00%) | 0 (0.00%) | 139 (0.14%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(7) random, with replacement | 0 (0.00%) | 0 (0.00%) | 4 (0.00%) | 0 (0.00%) [95% MC 0.000%–0.004%] |
| GF(7) random, no replacement | 0 (0.00%) | 0 (0.00%) | 9 (0.01%) | 0 (0.00%) [95% MC 0.000%–0.004%] |

The histogram uses every retained observation and 45 common equal-width bins within this rank scope. Curves are probability masses, not CDFs. The black dashed line is Θ = 0 and the red dash-dot line is Θ = 1.

![Θ probability histogram for n12_r6](../figures/theta_analysis/n12_r6_theta_histogram.png)

### Relationship with $\overline{\alpha}$, basis density, and d_B $\overline{\alpha}$

| Ensemble | Pearson r(Θ, $\overline{\alpha}$) | Spearman ρ(Θ, $\overline{\alpha}$) | Pearson r(Θ, d_B) | Spearman ρ(Θ, d_B) | Spearman ρ(Θ, d_B $\overline{\alpha}$) | Θ top decile also $\overline{\alpha}$ top decile | Θ top decile also d_B $\overline{\alpha}$ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | +1.0000 | +1.0000 | -0.7026 | -0.6238 | +0.9436 | 100.00% | 89.75% |
| Johnson greedy p = 0.05 | +0.9999 | +1.0000 | -0.1606 | -0.1387 | +0.9344 | 100.00% | 88.79% |
| Johnson greedy p = 0.2 | +0.9999 | +1.0000 | -0.0242 | +0.0040 | +0.9598 | 100.00% | 95.13% |
| Johnson greedy p = 1 | +0.9999 | +1.0000 | -0.0478 | +0.0025 | +0.9632 | 100.00% | 87.37% |
| GF(2) random, with replacement | +0.5257 | +0.5846 | +0.9008 | +0.9146 | +0.9595 | 28.21% | 65.39% |
| GF(2) random, no replacement | +0.5977 | +0.6578 | +0.7223 | +0.7234 | +0.8577 | 23.26% | 54.97% |
| GF(3) random, with replacement | +0.5112 | +0.4886 | +0.4009 | +0.3009 | +0.5665 | 45.45% | 35.45% |
| GF(3) random, no replacement | +0.6947 | +0.6630 | +0.1085 | +0.0303 | +0.4092 | 50.29% | 33.69% |
| GF(5) random, with replacement | +0.9470 | +0.9545 | -0.5503 | -0.6850 | +0.1641 | 69.60% | 30.93% |
| GF(5) random, no replacement | +0.9590 | +0.9671 | -0.6067 | -0.7065 | +0.1646 | 72.39% | 30.44% |
| GF(7) random, with replacement | +0.9850 | +0.9940 | -0.7326 | -0.8227 | +0.3941 | 84.75% | 36.35% |
| GF(7) random, no replacement | +0.9877 | +0.9950 | -0.7569 | -0.8218 | +0.4088 | 86.22% | 35.99% |

The point clouds are deterministically thinned to at most 15,000 rows per ensemble for rendering only; all coefficients and tables use the complete population. Circles are non-sparse-paving and triangles are sparse paving. The black diagonal is Θ = d_B, equivalently $\overline{\alpha}$ = 1.

![Basis density versus Θ for n12_r6](../figures/theta_analysis/n12_r6_density_vs_theta.png)

### Effect of changing from λ = 1 to λ = 2

| Ensemble | Pearson r(d_B, Θ₁) | Pearson r(d_B, Θ₂) | Spearman ρ(d_B, Θ₁) | Spearman ρ(d_B, Θ₂) | Change in Spearman ρ | Spearman ρ(Θ₁, Θ₂) | Θ₂ top decile also Θ₁ top decile |
|---|---:|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | -0.7026 | -0.6976 | -0.6238 | -0.6238 | +0.0000 | +1.0000 | 100.00% |
| Johnson greedy p = 0.05 | -0.1606 | -0.1442 | -0.1387 | -0.1325 | +0.0062 | +0.9999 | 99.88% |
| Johnson greedy p = 0.2 | -0.0242 | -0.0087 | +0.0040 | +0.0072 | +0.0032 | +1.0000 | 100.00% |
| Johnson greedy p = 1 | -0.0478 | -0.0343 | +0.0025 | +0.0040 | +0.0015 | +1.0000 | 100.00% |
| GF(2) random, with replacement | +0.9008 | +0.9592 | +0.9146 | +0.9756 | +0.0610 | +0.9797 | 78.19% |
| GF(2) random, no replacement | +0.7223 | +0.9025 | +0.7234 | +0.9149 | +0.1914 | +0.9331 | 79.46% |
| GF(3) random, with replacement | +0.4009 | +0.8051 | +0.3009 | +0.7318 | +0.4309 | +0.8442 | 65.92% |
| GF(3) random, no replacement | +0.1085 | +0.6627 | +0.0303 | +0.5686 | +0.5383 | +0.8059 | 63.89% |
| GF(5) random, with replacement | -0.5503 | -0.1835 | -0.6850 | -0.3859 | +0.2991 | +0.9138 | 71.72% |
| GF(5) random, no replacement | -0.6067 | -0.2868 | -0.7065 | -0.4387 | +0.2678 | +0.9263 | 71.98% |
| GF(7) random, with replacement | -0.7326 | -0.5876 | -0.8227 | -0.7318 | +0.0908 | +0.9821 | 81.33% |
| GF(7) random, no replacement | -0.7569 | -0.6296 | -0.8218 | -0.7398 | +0.0819 | +0.9865 | 81.83% |

| Ensemble | Median Θ₁ | Median Θ₂ | 95th percentile Θ₂ | Maximum Θ₂ | Θ₂ > 1 |
|---|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 0.054774 | 0.054418 | 0.079897 | 299975/2347884 (0.127764) | 0 (0.00%) |
| Johnson greedy p = 0.05 | 0.090099 | 0.087857 | 0.122014 | 17408/99825 (0.174385) | 0 (0.00%) |
| Johnson greedy p = 0.2 | 0.093834 | 0.088615 | 0.123283 | 280023613/1434557124 (0.195199) | 0 (0.00%) |
| Johnson greedy p = 1 | 0.079020 | 0.073205 | 0.102802 | 39985606907/247326100560 (0.161672) | 0 (0.00%) |
| GF(2) random, with replacement | 0.365214 | 0.131125 | 0.252237 | 1097728/2934855 (0.374031) | 0 (0.00%) |
| GF(2) random, no replacement | 0.443611 | 0.190564 | 0.270136 | 1097728/2934855 (0.374031) | 0 (0.00%) |
| GF(3) random, with replacement | 0.485262 | 0.288611 | 0.372894 | 612835/1043504 (0.587286) | 0 (0.00%) |
| GF(3) random, no replacement | 0.499082 | 0.300668 | 0.377697 | 612835/1043504 (0.587286) | 0 (0.00%) |
| GF(5) random, with replacement | 0.433808 | 0.327684 | 0.414902 | 748526263/1364120604 (0.548724) | 0 (0.00%) |
| GF(5) random, no replacement | 0.434191 | 0.328598 | 0.414278 | 42010089053/74756626560 (0.561958) | 0 (0.00%) |
| GF(7) random, with replacement | 0.353036 | 0.295797 | 0.394972 | 166086881/291137616 (0.570476) | 0 (0.00%) |
| GF(7) random, no replacement | 0.352042 | 0.295559 | 0.395100 | 5463841225/9915114132 (0.551062) | 0 (0.00%) |

The companion scatterplot uses Θ₂ = d_B Θ₁. Its black dashed curve is Θ₂ = d_B², the $\overline{\alpha}$ = 1 boundary. Points above the curve have $\overline{\alpha}$ > 1. The same deterministic rendering cap and sparse-paving markers are used.

![Basis density versus Θ₂ for n12_r6](../figures/theta_analysis/n12_r6_density_vs_theta_lambda2.png)

### Sparse-paving comparison

| Ensemble | Sparse paving N | Median Θ | 95th percentile | Maximum | Non-sparse-paving N | Median Θ | 95th percentile | Maximum | Mean difference (non-SP − SP) | Ordinal superiority (ties half) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Johnson greedy p = 0.01 | 25000 | 0.054774 | 0.080860 | 0.129730 | 0 | — | — | — | — | — |
| Johnson greedy p = 0.05 | 25000 | 0.090099 | 0.125967 | 0.179835 | 0 | — | — | — | — | — |
| Johnson greedy p = 0.2 | 25000 | 0.093834 | 0.129890 | 0.205425 | 0 | — | — | — | — | — |
| Johnson greedy p = 1 | 25000 | 0.079020 | 0.110839 | 0.174311 | 0 | — | — | — | — | — |
| GF(2) random, with replacement | 0 | — | — | — | 82408 | 0.365214 | 0.536009 | 0.688920 | — | — |
| GF(2) random, no replacement | 0 | — | — | — | 93645 | 0.443611 | 0.551827 | 0.688920 | — | — |
| GF(3) random, with replacement | 0 | — | — | — | 98368 | 0.485262 | 0.602731 | 0.825954 | — | — |
| GF(3) random, no replacement | 0 | — | — | — | 98732 | 0.499082 | 0.609082 | 0.835359 | — | — |
| GF(5) random, with replacement | 0 | — | — | — | 99915 | 0.433808 | 0.565918 | 0.749251 | — | — |
| GF(5) random, no replacement | 0 | — | — | — | 99927 | 0.434191 | 0.565202 | 0.768274 | — | — |
| GF(7) random, with replacement | 0 | — | — | — | 99990 | 0.353036 | 0.498834 | 0.769517 | — | — |
| GF(7) random, no replacement | 0 | — | — | — | 99992 | 0.352042 | 0.498513 | 0.742977 | — | — |

## Largest distinct observed profiles

Profiles are deduplicated by `(n, rank, number of bases, $\overline{\alpha}$, sparse-paving status)`. The identifier is one representative observation. Multiple origins are combined when the same profile occurs in several ensembles.

| n | Rank | Representative | Bases | d_B | $\overline{\alpha}$ | Θ | Sparse paving | Observed in |
|---:|---:|---|---:|---:|---:|---:|---:|---|
| 10 | 5 | pg3_replacement_seed202650372_draw_00006662 | 186 | 0.738095 | 256/225 | 248/243 (1.020576) | no | n10_r5: GF(3) random, no replacement<br>n10_r5: GF(3) random, with replacement |
| 10 | 4 | pg3_replacement_seed202640371_draw_00003486 | 156 | 0.742857 | 10/9 | 26/27 (0.962963) | no | n10_r4: GF(3) random, no replacement<br>n10_r4: GF(3) random, with replacement<br>n10_r4: GF(5) random, with replacement |
| 10 | 5 | pg5_replacement_seed202650575_draw_00002578 | 195 | 0.773810 | 490/459 | 159445/173502 (0.918981) | no | n10_r5: GF(5) random, no replacement<br>n10_r5: GF(5) random, with replacement |
| 10 | 5 | pg5_seed202650532_draw_00014210 | 193 | 0.765873 | 49/46 | 31459/34776 (0.904618) | no | n10_r5: GF(5) random, no replacement |
| 10 | 5 | pg5_seed202650534_draw_00011751 | 198 | 0.785714 | 500/477 | 26774/30051 (0.890952) | no | n10_r5: GF(5) random, no replacement |
| 8 | 4 | pg2_subset_017f | 48 | 0.685714 | 9/8 | 216/245 (0.881633) | no | n8_r4: GF(2) exhaustive, no replacement<br>n8_r4: polyDB |
| 9 | 4 | n9r4_00185140 | 94 | 0.746032 | 15/14 | 517/588 (0.879252) | no | n9_r4: polyDB |
| 10 | 5 | pg5_seed202650535_draw_00000005 | 186 | 0.738095 | 529/496 | 1763/2016 (0.874504) | no | n10_r5: GF(5) random, no replacement |
| 9 | 4 | n9r4_00182475 | 93 | 0.738095 | 15/14 | 341/392 (0.869898) | no | n9_r4: polyDB |
| 10 | 5 | pg5_seed202650534_draw_00015663 | 178 | 0.706349 | 242/225 | 623/729 (0.854595) | no | n10_r5: GF(5) random, no replacement |
| 10 | 5 | pg5_seed202650532_draw_00019165 | 190 | 0.753968 | 2209/2108 | 291745/341496 (0.854315) | no | n10_r5: GF(5) random, no replacement |
| 10 | 5 | pg5_replacement_seed202650572_draw_00005032 | 203 | 0.805556 | 2601/2548 | 703453/825552 (0.852100) | no | n10_r5: GF(5) random, with replacement |
| 10 | 5 | pg5_replacement_seed202650572_draw_00012552 | 190 | 0.753968 | 256/245 | 23560/27783 (0.848001) | no | n10_r5: GF(5) random, with replacement |
| 10 | 5 | pg5_replacement_seed202650571_draw_00015963 | 199 | 0.789683 | 1250/1219 | 166961/197478 (0.845466) | no | n10_r5: GF(5) random, no replacement<br>n10_r5: GF(5) random, with replacement |
| 10 | 4 | pg5_replacement_seed202640575_draw_00016982 | 162 | 0.771429 | 31/30 | 21/25 (0.840000) | no | n10_r4: GF(5) random, no replacement<br>n10_r4: GF(5) random, with replacement |

## Reproducibility exports

- [`theta_summary.csv`](../data/theta_analysis/theta_summary.csv)
- [`theta_extremal_profiles.csv`](../data/theta_analysis/theta_extremal_profiles.csv)

These compact exports contain only derived summaries and extremal profiles. No per-matroid Θ table is stored. Exact Θ is reconstructed from `n`, rank, number of bases, and the exact $\overline{\alpha}$ numerator and denominator by the shared Julia helper `density_adjusted_correlation_excess`.
