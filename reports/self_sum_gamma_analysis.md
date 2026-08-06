# $\overline{\alpha}(M)$ and $\gamma_*(M\oplus M)$

_Generated on 2026-08-03._

Here $\gamma_*$ is the critical density-penalty exponent already used in the
project. Let $M$ have rank $r$, corank $c=n-r$, $b$ bases, and basis density

$$
D=\frac{b}{\binom nr}.
$$

For a connected nontrivial matroid,

$$
\overline{\alpha}(M\oplus M)=\max\{1,\overline{\alpha}(M)\}.
$$

Also

$$
D_\oplus
=\frac{b^2}{\binom{2n}{2r}}
=K_{r,n}D^2,
\qquad
K_{r,n}=\frac{\binom nr^2}{\binom{2n}{2r}},
$$

and

$$
c_{2r,2n}=\overline{\alpha}(U_{2r,2n})
=\frac{(2r-1)(2c-1)}{4rc}.
$$

Consequently the exact self-sum formula is

$$
\boxed{
\gamma_*(M\oplus M)
=
\frac{
\log\!\left(\max\{1,\overline{\alpha}(M)\}/c_{2r,2n}\right)
}{
\log\!\left(1/(K_{r,n}D^2)\right)
}.
}
$$

This immediately separates direct from indirect effects:

- On the whole region $\overline{\alpha}(M)\leq1$, the numerator is constant, so
  $\gamma_*(M\oplus M)$ has no direct dependence on $\overline{\alpha}(M)$ at all.
  It is strictly increasing in the basis density $D$.
- When $\overline{\alpha}(M)>1$, it is increasing in both $\overline{\alpha}(M)$ and $D$.

Thus a low-$\overline{\alpha}$/high-$\gamma_*$ pattern can occur only indirectly,
because low $\overline{\alpha}$ happens to be associated with high basis density in a
particular population. It cannot be a universal inverse law.


## Database pattern

The within-cell Spearman correlation is negative in **30 of 38** cells. The median cell correlation is **-0.5558**. Among finite-field cells it is negative in **22 of 28** cells, with median **-0.5950**.

| Scope | Ensemble | $N$ | Median $\gamma_*$ | $\rho_S(\overline{\alpha},\gamma_{*,\oplus2})$ | $\rho_S(D,\gamma_{*,\oplus2})$ | $\rho_S(\overline{\alpha},D)$ | $N(\overline{\alpha}\leq1)$ |
|---|---|---:|---:|---:|---:|---:|---:|
| n8_r4 | GF(2) exhaustive, no replacement | 6315 | 0.144411 | -0.1197 | 0.9997 | -0.1238 | 5475 |
| n8_r4 | GF(3) random, no replacement | 4889 | 0.159059 | -0.1311 | 0.9339 | -0.2959 | 4564 |
| n8_r4 | GF(5) random, no replacement | 4965 | 0.194009 | -0.7086 | 0.9947 | -0.7178 | 4945 |
| n8_r4 | GF(7) random, no replacement | 4991 | 0.209631 | -0.8158 | 0.9997 | -0.8164 | 4987 |
| n8_r4 | polyDB isomorphism classes | 731 | 0.204242 | -0.7907 | 0.9972 | -0.7976 | 727 |
| n9_r2 | polyDB isomorphism classes | 25 | 0.280115 | -0.8971 | 1.0000 | -0.8971 | 25 |
| n9_r3 | polyDB isomorphism classes | 901 | 0.197927 | -0.8482 | 1.0000 | -0.8482 | 901 |
| n9_r4 | polyDB isomorphism classes | 188961 | 0.199648 | -0.6492 | 1.0000 | -0.6492 | 188911 |
| n10_r4_finite_fields | GF(2) random, with replacement | 84481 | 0.081020 | 0.4627 | 0.9826 | 0.4097 | 75483 |
| n10_r4_finite_fields | GF(2) exhaustive, no replacement | 3003 | 0.110636 | 0.1532 | -0.1532 | -1.0000 | 2163 |
| n10_r4_finite_fields | GF(3) random, with replacement | 98439 | 0.108954 | -0.3247 | 0.9607 | -0.4523 | 90633 |
| n10_r4_finite_fields | GF(3) random, no replacement | 99904 | 0.126069 | -0.4386 | 0.8776 | -0.6593 | 91177 |
| n10_r4_finite_fields | GF(5) random, with replacement | 99941 | 0.143966 | -0.7382 | 0.9990 | -0.7413 | 99368 |
| n10_r4_finite_fields | GF(5) random, no replacement | 99980 | 0.148614 | -0.7992 | 0.9984 | -0.8022 | 99474 |
| n10_r4_finite_fields | GF(7) random, with replacement | 99987 | 0.161094 | -0.8305 | 1.0000 | -0.8305 | 99943 |
| n10_r4_finite_fields | GF(7) random, no replacement | 99994 | 0.162416 | -0.8402 | 1.0000 | -0.8402 | 99962 |
| n10_r5_finite_fields | GF(2) random, with replacement | 72231 | 0.073247 | 0.3952 | 0.9718 | 0.2853 | 62246 |
| n10_r5_finite_fields | GF(2) random, no replacement | 94375 | 0.088104 | 0.5799 | 0.7892 | 0.1713 | 66993 |
| n10_r5_finite_fields | GF(3) random, with replacement | 95722 | 0.101999 | -0.2551 | 0.9427 | -0.4310 | 84639 |
| n10_r5_finite_fields | GF(3) random, no replacement | 97880 | 0.109349 | -0.3015 | 0.8908 | -0.5529 | 84831 |
| n10_r5_finite_fields | GF(5) random, with replacement | 99700 | 0.134169 | -0.7967 | 0.9986 | -0.8005 | 98920 |
| n10_r5_finite_fields | GF(5) random, no replacement | 99743 | 0.135044 | -0.8049 | 0.9981 | -0.8093 | 98914 |
| n10_r5_finite_fields | GF(7) random, with replacement | 99946 | 0.151072 | -0.8618 | 1.0000 | -0.8618 | 99895 |
| n10_r5_finite_fields | GF(7) random, no replacement | 99946 | 0.152089 | -0.8588 | 1.0000 | -0.8588 | 99907 |
| n12_r6 | GF(2) random, with replacement | 82408 | 0.058016 | 0.6356 | 0.8523 | 0.2516 | 46703 |
| n12_r6 | GF(2) random, no replacement | 93645 | 0.069021 | 0.7107 | 0.6462 | 0.0110 | 38337 |
| n12_r6 | GF(3) random, with replacement | 98368 | 0.079314 | -0.4494 | 0.9395 | -0.6059 | 85128 |
| n12_r6 | GF(3) random, no replacement | 98732 | 0.081312 | -0.4814 | 0.9153 | -0.6613 | 85668 |
| n12_r6 | GF(5) random, with replacement | 99915 | 0.104297 | -0.8414 | 0.9999 | -0.8416 | 99760 |
| n12_r6 | GF(5) random, no replacement | 99927 | 0.104472 | -0.8407 | 0.9999 | -0.8409 | 99788 |
| n12_r6 | GF(7) random, with replacement | 99990 | 0.116860 | -0.8703 | 1.0000 | -0.8703 | 99986 |
| n12_r6 | GF(7) random, no replacement | 99992 | 0.116860 | -0.8677 | 1.0000 | -0.8677 | 99983 |
| n12_r6 | Johnson greedy p = 0.01 | 25000 | 0.148703 | -0.6239 | 1.0000 | -0.6239 | 25000 |
| n12_r6 | Johnson greedy p = 0.05 | 25000 | 0.144090 | -0.1430 | 1.0000 | -0.1430 | 25000 |
| n12_r6 | Johnson greedy p = 0.2 | 25000 | 0.138663 | 0.0015 | 1.0000 | 0.0015 | 25000 |
| n12_r6 | Johnson greedy p = 1 | 25000 | 0.133273 | 0.0016 | 1.0000 | 0.0016 | 25000 |
| n10_r4_icarm | ICARM simple random sample | 99991 | 0.182556 | -0.4878 | 1.0000 | -0.4878 | 99991 |
| n10_r5_icarm | ICARM two-stage sample | 12800 | 0.173269 | -0.3049 | 1.0000 | -0.3049 | 12800 |

![Self-sum critical exponent versus alpha and density](../figures/epsilon_analysis/self_sum_gamma_vs_alpha.png)

## Reproduction

- [Compact summary](../data/epsilon_analysis/self_sum_gamma_summary.csv)

```bash
julia --project=. scripts/make_self_sum_gamma_report.jl
```
