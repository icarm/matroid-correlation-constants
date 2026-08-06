# ICARM $n=10$ probability samples: $r=4$ and $r=5$

Generated 2026-08-01 15:02.

## Executive summary

The rank-4 result is an exact simple random sample without replacement of 100,000 stored isomorphism classes from a population of 4,886,380,924. The rank-5 result is a two-stage pilot of 12,800 observations in 128 independent chunk draws, with 100 offsets per draw. Every decoded record matched its saved sampling coordinates, and both SQLite files passed integrity checks.

No sampled matroid had $\overline{\alpha}>1$, hence none exceeded $100/81$. The observed maxima were 0.949937 at rank 4 and 0.849307 at rank 5. These are sample findings, not upper bounds for either complete population.

Basis density is negatively associated with $\overline{\alpha}$ in both samples. Spearman correlations are -0.488 at rank 4 and -0.305 at rank 5. Within sparse-paving matroids the association is weak (-0.057 and 0.027), while within non-sparse-paving matroids it remains appreciable (-0.389 and -0.408).

The rank-5 chunk ordering matters statistically. Empirical design effects range from about 47.6 to 100.8 for the four diagnostics below. Thus the pilot is unbiased for population means under its design, but its uncertainty is governed much more by 128 chunk draws than by 12,800 nominal rows.

## Sampling design and target populations

| Rank | Stored population | Realized sample | Design | Unit used for uncertainty |
|---:|---:|---:|---|---|
| 4 | 4,886,380,924 | 100,000 | simple random sample without replacement | individual isomorphism class |
| 5 | 3,222,227,959,444 | 128 × 100 = 12,800 | PPS chunks with replacement; offsets without replacement within draw | chunk draw |

The primary estimand is the distribution over stored isomorphism classes, so every class has equal target weight. For rank 5, selecting a chunk proportional to its record count and then a uniform offset makes every recorded observation marginally uniform over the archive. Observations from the same chunk draw are dependent.

The distribution summaries below retain only connected matroids with $\overline{\alpha}>0$, matching the standing report convention. That removes 9 of 100,000 rank-4 observations and none of the rank-5 observations.

## Sample composition

| Rank | Property | Count | Estimate | 95% interval | Method |
|---:|---|---:|---:|---:|---|
| 4 | connected | 99,991 / 100,000 | 99.991% | [99.983%, 99.995%] | Wilson SRS |
| 4 | simple | 99,955 / 100,000 | 99.955% | [99.940%, 99.966%] | Wilson SRS |
| 4 | cosimple | 99,999 / 100,000 | 99.999% | [99.994%, 100.000%] | Wilson SRS |
| 4 | 3-connected | 99,954 / 100,000 | 99.954% | [99.939%, 99.966%] | Wilson SRS |
| 4 | paving | 92,641 / 100,000 | 92.641% | [92.478%, 92.801%] | Wilson SRS |
| 4 | copaving | 65,331 / 100,000 | 65.331% | [65.035%, 65.625%] | Wilson SRS |
| 4 | sparse paving | 64,500 / 100,000 | 64.500% | [64.203%, 64.796%] | Wilson SRS |
| 4 | alpha1 > 0 | 100,000 / 100,000 | 100.000% | [99.996%, 100.000%] | Wilson SRS |
| 4 | alpha1 > 1 | 0 / 100,000 | 0.000% | [0.000%, 0.004%] | Wilson SRS |
| 5 | connected | 12,800 / 12,800 | 100.000% | not estimable from identical PSU outcomes | cluster-draw normal |
| 5 | simple | 12,800 / 12,800 | 100.000% | not estimable from identical PSU outcomes | cluster-draw normal |
| 5 | cosimple | 12,800 / 12,800 | 100.000% | not estimable from identical PSU outcomes | cluster-draw normal |
| 5 | 3-connected | 12,800 / 12,800 | 100.000% | not estimable from identical PSU outcomes | cluster-draw normal |
| 5 | paving | 11,295 / 12,800 | 88.242% | [82.650%, 93.834%] | cluster-draw normal |
| 5 | copaving | 11,000 / 12,800 | 85.938% | [79.891%, 91.984%] | cluster-draw normal |
| 5 | sparse paving | 10,400 / 12,800 | 81.250% | [74.462%, 88.038%] | cluster-draw normal |
| 5 | alpha1 > 0 | 12,800 / 12,800 | 100.000% | not estimable from identical PSU outcomes | cluster-draw normal |
| 5 | alpha1 > 1 | 0 / 12,800 | 0.000% | not estimable from identical PSU outcomes | cluster-draw normal |

For rank 4, the finite-population correction is numerically negligible. For rank 5, an interval is intentionally omitted when all 128 cluster means agree; a zero cluster variance does not justify claiming a zero-width population interval.

## Distribution of $\overline{\alpha}$

| Rank | Retained $N$ | Mean ± design SE | 5% | 25% | Median | 75% | 95% | Maximum | $N(\overline{\alpha}>1)$ | $N(\overline{\alpha}>100/81)$ |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 4 | 99,991 | 0.718866 ± 0.000082 | 0.6851 | 0.6994 | 0.7137 | 0.7322 | 0.7674 | 0.949937 | 0 | 0 |
| 5 | 12,800 | 0.716813 ± 0.001362 | 0.6865 | 0.6994 | 0.7119 | 0.7272 | 0.7586 | 0.849307 | 0 | 0 |

![Probability-mass histograms](../figures/icarm_n10/alpha_histogram.png)

Each bar is the observed probability mass in a fixed-width $0.005$ bin, not a CDF and not a smoothed density. The panels use identical edges from $0.64$ to $1$. Jaggedness can reflect both bin alignment and the fact that $\overline{\alpha}$ is the maximum of finitely many exact rational pair ratios; it should not be read as fine-scale population structure without a bin-sensitivity check.

![Sparse-paving alpha histograms](../figures/icarm_n10/alpha_histogram_sparse_paving.png)

This companion uses the same bin edges but retains only sparse-paving matroids, so differences in shape are not caused by changing the histogram grid.

![Non-sparse-paving alpha histograms](../figures/icarm_n10/alpha_histogram_non_sparse_paving.png)

This second companion retains only non-sparse-paving matroids and again uses the common bin grid. Its smaller rank-5 sample should be interpreted with the chunk dependence described below.

## Basis density versus $\overline{\alpha}$

| Rank | Stratum | $N$ | Pearson $r$ (95% interval) | Spearman $\rho$ (95% interval) | $\Delta\overline{\alpha}$ per +0.1 density | Interval method |
|---:|---|---:|---:|---:|---:|---|
| 4 | all primary | 99,991 | -0.592 [-0.596, -0.588] | -0.488 [-0.492, -0.483] | -0.1030 | Fisher SRS (Spearman approximate) |
| 4 | sparse paving | 64,500 | -0.031 [-0.039, -0.024] | -0.057 [-0.065, -0.050] | -0.0065 | Fisher SRS (Spearman approximate) |
| 4 | non-sparse-paving | 35,491 | -0.518 [-0.526, -0.511] | -0.389 [-0.398, -0.380] | -0.0889 | Fisher SRS (Spearman approximate) |
| 5 | all primary | 12,800 | -0.527 [-0.635, -0.382] | -0.305 [-0.415, -0.193] | -0.0903 | 400-replicate cluster bootstrap |
| 5 | sparse paving | 10,400 | -0.070 [-0.125, -0.006] | 0.027 [-0.022, 0.083] | -0.0156 | 400-replicate cluster bootstrap |
| 5 | non-sparse-paving | 2,400 | -0.539 [-0.657, -0.292] | -0.408 [-0.578, -0.155] | -0.1003 | 400-replicate cluster bootstrap |

![Basis density and alpha](../figures/icarm_n10/basis_density_vs_alpha.png)

These are two-dimensional count histograms: color records the base-10 logarithm of the number of observations in each density–$\overline{\alpha}$ cell, and the red line is the unweighted least-squares fit. Correlations use every retained observation, not the binned cells. The broad negative association partly reflects the mixture of sparse- and non-sparse-paving classes, so the next two figures condition on that status.

![Sparse-paving basis density and alpha](../figures/icarm_n10/basis_density_vs_alpha_sparse_paving.png)

Sparse-paving observations alone show little monotone density–$\overline{\alpha}$ association in these class-uniform database samples. This does not reproduce the stronger negative association seen in some finite-field random ensembles; the target distributions are different.

![Non-sparse-paving basis density and alpha](../figures/icarm_n10/basis_density_vs_alpha_non_sparse_paving.png)

For non-sparse-paving matroids, the negative association remains visible within each rank. Thus it is not solely a sparse-paving versus non-sparse-paving composition effect.

## Other invariants

| Rank | Invariant | Pearson $r$ | Spearman $\rho$ |
|---:|---|---:|---:|
| 4 | cogirth | -0.605 | -0.605 |
| 4 | basis density | -0.592 | -0.488 |
| 4 | number of circuits | -0.467 | -0.428 |
| 4 | absolute Möbius invariant | -0.527 | -0.421 |
| 4 | beta invariant | -0.504 | -0.415 |
| 4 | circuit-hyperplanes | -0.460 | -0.376 |
| 4 | girth | -0.480 | -0.375 |
| 4 | number of hyperplanes | -0.345 | -0.288 |
| 4 | automorphism-group order | 0.048 | 0.023 |
| 5 | cogirth | -0.531 | -0.443 |
| 5 | girth | -0.505 | -0.407 |
| 5 | basis density | -0.527 | -0.305 |
| 5 | absolute Möbius invariant | -0.494 | -0.292 |
| 5 | beta invariant | -0.454 | -0.276 |
| 5 | circuit-hyperplanes | -0.350 | -0.259 |
| 5 | number of circuits | -0.364 | -0.228 |
| 5 | number of hyperplanes | -0.353 | -0.218 |
| 5 | automorphism-group order | 0.011 | 0.012 |

![Invariant correlations](../figures/icarm_n10/invariant_spearman_correlations.png)

The plot reports Spearman correlations in the primary samples. At rank 4 the strongest absolute association is cogirth ($\rho=-0.605$); at rank 5 it is cogirth ($\rho=-0.443$). These are marginal associations among interdependent invariants, not causal effects or partial correlations.

## The density-adjusted excess $\Theta_\lambda$

We use the previously adopted uniform-matroid baseline:

$$
\Theta_\lambda(M)=d_B(M)^\lambda\,\frac{\overline{\alpha}(M)-\overline{\alpha}(U_{r,n})}{1-\overline{\alpha}(U_{r,n})}.
$$

| Rank | $\lambda$ | Mean | Median | 95% quantile | Maximum | Pearson $r(d_B,\Theta_\lambda)$ | Spearman $\rho(d_B,\Theta_\lambda)$ | Spearman $\rho(\overline{\alpha},\Theta_\lambda)$ |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 4 | 1 | 0.2303 | 0.2180 | 0.3466 | 0.6887 | -0.541 | -0.470 | 0.999 |
| 4 | 2 | 0.2119 | 0.2003 | 0.3173 | 0.5580 | -0.484 | -0.431 | 0.996 |
| 5 | 1 | 0.1971 | 0.1871 | 0.3007 | 0.5166 | -0.481 | -0.298 | 1.000 |
| 5 | 2 | 0.1822 | 0.1752 | 0.2729 | 0.4756 | -0.432 | -0.281 | 0.999 |

![Theta versus density](../figures/icarm_n10/theta_vs_basis_density.png)

Color again shows log observation count per cell. Comparing the two columns measures what changes when the density factor is strengthened from $\lambda=1$ to $\lambda=2$; it does not choose an optimal exponent from these data.

## Rank-5 cluster diagnostics

| Variable | Cluster SE of mean | ICC | Design effect | Effective $N$ | Range of cluster means |
|---|---:|---:|---:|---:|---:|
| alpha1 | 0.001362 | 0.469 | 47.6 | 268.7 | [0.7019, 0.7765] |
| basis density | 0.001048 | 0.823 | 83.0 | 154.1 | [0.8774, 0.9487] |
| paving indicator | 0.028530 | 0.996 | 100.4 | 127.5 | [0.0000, 1.0000] |
| sparse-paving indicator | 0.034635 | 1.000 | 100.8 | 127.0 | [0.0000, 1.0000] |

The near-unit ICCs for paving indicators show that the enumeration order groups structurally similar classes. For future rank-5 work, more chunk draws and fewer offsets per chunk would buy much more precision per analyzed matroid, at the cost of downloading more complete chunks. A design such as 512 chunks × 25 offsets is a sensible next pilot before scaling further.

## Isomorphism-class versus labeled weighting

A class with automorphism group $\operatorname{Aut}(M)$ represents

$$
\frac{10!}{|\operatorname{Aut}(M)|}
$$

labeled matroids. The factor $10!$ cancels in normalized estimates, so labeled point estimates use weight $1/|\operatorname{Aut}(M)|$.

| Rank | Quantity | Uniform over stored classes | Inferred labeled weighting | Kish effective $N$ of weights |
|---:|---|---:|---:|---:|
| 4 | connected proportion | 0.999910 | 0.999915 | 99958.8 |
| 4 | paving proportion | 0.926410 | 0.926673 | 99958.8 |
| 4 | sparse-paving proportion | 0.645000 | 0.645212 | 99958.8 |
| 4 | mean alpha1 | 0.718864 | 0.718840 | 99958.8 |
| 4 | mean basis density | 0.922284 | 0.922317 | 99958.8 |
| 5 | connected proportion | 1.000000 | 1.000000 | 12799.8 |
| 5 | paving proportion | 0.882422 | 0.882456 | 12799.8 |
| 5 | sparse-paving proportion | 0.812500 | 0.812532 | 12799.8 |
| 5 | mean alpha1 | 0.716813 | 0.716812 | 12799.8 |
| 5 | mean basis density | 0.925930 | 0.925930 | 12799.8 |

These labeled-weighted values are secondary ratio estimates from the class-uniform samples. Rank-5 uncertainty would still need to respect chunk clustering; the table intentionally gives point estimates only.

## Selected pair profiles

| Rank | Selection reason | Global index | $\overline{\alpha}$ | $d_B$ | Sparse paving | $\Theta_1$ | $\Theta_2$ | $|\operatorname{Aut}|$ |
|---:|---|---:|---:|---:|---:|---:|---:|---:|
| 4 | maximum alpha1 | 4886375779 | 0.949937 | 0.571429 | no | 0.4951 | 0.2829 | 4 |
| 4 | maximum sparse-paving alpha1 | 681933301 | 0.793003 | 0.923810 | yes | 0.4139 | 0.3823 | 1 |
| 4 | maximum Theta_2 distinct from prior cases | 4879986997 | 0.933333 | 0.823810 | no | 0.6774 | 0.5580 | 1 |
| 5 | maximum alpha1 | 3214592067794 | 0.849307 | 0.869048 | no | 0.5053 | 0.4391 | 1 |
| 5 | maximum sparse-paving alpha1 | 2624276819769 | 0.841990 | 0.920635 | yes | 0.5166 | 0.4756 | 1 |
| 5 | maximum Theta_2 distinct from prior cases | 3191781803422 | 0.848522 | 0.869048 | no | 0.5034 | 0.4375 | 1 |

![Selected pair-ratio heatmaps](../figures/icarm_n10/selected_pair_heatmaps.png)

Each panel contains every eligible element pair for one selected matroid. Entry $(i,j)$ is $\log R_{ij}$; gray diagonal cells are undefined, gray off-diagonal cells would be ineligible, and a zero pair ratio is clipped to $-2$ for display. Only these selected examples have persistent pair rows; routine observations retain compact matroid summaries and exact run-level ratio aggregates.

## Reproducibility and limitations

- The target is the ICARM release as represented by the pinned local manifest, not an abstract distribution over all labeled matroids.

- The database records the manifest, realized-plan, design-file, decoder-source, decoder-binary, and per-downloaded-chunk SHA-256 hashes.

- Canonical sampled basis masks: [rank 4 pack](../data/icarm_n10/r4/sample_basis.tsv.zst) and [rank 5 pack](../data/icarm_n10/r5/sample_basis.tsv.zst). Each adjacent `sample_basis_manifest.toml` records its format and hashes.

- The current ICARM manifest does not publish authoritative chunk hashes; our chunk hashes identify the bytes actually analyzed but cannot prove immutability of the remote release.

- Rank-4 SRS estimates are precise for common properties but a sample maximum is not a population maximum, and zero observed violations is not a proof.

- Rank-5 point estimates are design-unbiased under successful PPS chunk sampling, but the pilot has only 128 independent first-stage draws and strong within-chunk homogeneity.

## Compact tables

- [alpha summaries](../data/icarm_n10/report_tables/alpha_summaries.csv)
- [class versus labeled weighting](../data/icarm_n10/report_tables/labeled_weighting.csv)
- [rank-5 cluster diagnostics](../data/icarm_n10/report_tables/rank5_cluster_diagnostics.csv)
- [invariant correlations](../data/icarm_n10/report_tables/invariant_correlations.csv)
- [selected heatmap cases](../data/icarm_n10/report_tables/selected_heatmap_cases.csv)
- [Theta summaries](../data/icarm_n10/report_tables/theta_summaries.csv)
- [property estimates](../data/icarm_n10/report_tables/property_estimates.csv)
- [density correlations](../data/icarm_n10/report_tables/density_correlations.csv)
