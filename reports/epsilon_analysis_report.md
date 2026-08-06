# The free-extension/free-coextension invariant $\epsilon(M)$

_Generated deterministically from the project databases on 2026-08-02._

## Executive summary

The exhaustive single-matroid pass evaluated **2642818** stored observations or census classes in **38** ensemble cells. This is a bookkeeping total across distinct sampling laws, not a uniform sample from a universal population of matroids.

- $\epsilon(M)\geq\overline{\alpha}(M)$ for **970769** of **2642818** observations (36.73%).
- Among **209591** observations with $\overline{\alpha}(M)>1$, **72117** have $\epsilon(M)>1$ (34.41%).
- The converse occurs **61775** times: $\epsilon(M)>1$ while $\overline{\alpha}(M)\leq1$.
- Among **296858** sparse-paving observations, **0** have $\epsilon(M)>1$ (0.00%).
- In the observation-weighted direct-sum experiment, 499362 of 500000 draws satisfy $\epsilon\geq\overline{\alpha}$ (99.87%), and all 500000 draws have $\epsilon>1$. The conditional implication holds in 75644/75644 (100.00%).
- For the exhaustive self-sum calculation, **2642818** of **2642818** observations have $\epsilon(M\oplus M)>1$ (100.00%), and **2642818** exceed $\epsilon(M)$.

The fully specified finite-field spike family with $\overline{\alpha}=8/7$ is computed exactly; its $p=2$ and $p=3$ members already disprove $\overline{\alpha}>1\Rightarrow\epsilon>1$. The supplied $\operatorname{GF}(3)$ matrix closes the former $100/81$ reproducibility gap and is checked directly from all $\binom{12}{6}=924$ column subsets.

## Definition and exact formula

Let $M$ have rank $r$. Define

$$
i=i_{r-1}(M),
\qquad
b=|\mathcal B(M)|,
$$

$$
a=
\#\left\{
A\in\binom{E(M)}r:
\operatorname{rk}_M(A)\geq r-1
\right\},
$$

and

$$
s=
\#\left\{
S\in\binom{E(M)}{r+1}:
\operatorname{rk}_M(S)=r
\right\}.
$$

For $Q=(M+e)\mathbin{\times}f$, the new pair has table

| Membership of $e,f$ | Basis count |
|---|---:|
| neither | $s$ |
| $e$ only | $a$ |
| $f$ only | $b$ |
| both | $i$ |

Therefore

$$
\boxed{
\epsilon(M)=\frac{s\,i}{a\,b}.
}
$$

All threshold decisions below use exact integer cross multiplication.
Floating-point values are used only for descriptive statistics and plots.


The implementation is checked against

$$
\epsilon(M^*)=\epsilon(M)
$$

and

$$
\epsilon(U_{r,n})
=
\frac{r(n-r)}{(r+1)(n-r+1)}.
$$


## Population and methods

The single-matroid population follows the project convention: connected rows with positive stored $\overline{\alpha}$. polyDB rows are isomorphism classes; finite-field rows are accepted configurations or draws; Johnson rows are labeled random-greedy outputs; and ICARM rows are probability samples. The nonredundant stored ranks are used, including ranks 2, 3, and 4 in the $n=9$ census.

The packed basis encoding is scanned directly. For paving matroids $i=\binom n{r-1}$ and $a=\binom nr$; for copaving matroids $s=\binom n{r+1}$. These are exact shortcuts.

## Exhaustive results by ensemble cell

| Scope | Ensemble | $N$ | Median $\epsilon$ | 95% | Maximum | $\epsilon\geq\overline{\alpha}$ | $N(\overline{\alpha}>1)$ | $\overline{\alpha}>1\Rightarrow\epsilon>1$ | $N(\epsilon>1,\overline{\alpha}\leq1)$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| n8_r4 | GF(2) exhaustive, no replacement | 6315 | 0.858413 | 0.874286 | 153/175 (0.874286) | 435 (6.89%) | 840 | 0/840 (0.00%) | 0 |
| n8_r4 | GF(3) random, no replacement | 4889 | 0.805471 | 0.858413 | 153/175 (0.874286) | 962 (19.68%) | 325 | 0/325 (0.00%) | 0 |
| n8_r4 | GF(5) random, no replacement | 4965 | 0.757653 | 0.806522 | 153/175 (0.874286) | 465 (9.37%) | 20 | 0/20 (0.00%) | 0 |
| n8_r4 | GF(7) random, no replacement | 4991 | 0.721311 | 0.785984 | 153/175 (0.874286) | 751 (15.05%) | 4 | 0/4 (0.00%) | 0 |
| n8_r4 | polyDB isomorphism classes | 731 | 0.734426 | 0.860963 | 46/51 (0.901961) | 219 (29.96%) | 4 | 0/4 (0.00%) | 0 |
| n9_r2 | polyDB isomorphism classes | 25 | 0.706897 | 0.800000 | 49/60 (0.816667) | 11 (44.00%) | 0 | — | 0 |
| n9_r3 | polyDB isomorphism classes | 901 | 0.744048 | 0.863186 | 3100/3403 (0.910961) | 197 (21.86%) | 0 | — | 0 |
| n9_r4 | polyDB isomorphism classes | 188961 | 0.730435 | 0.770590 | 39/41 (0.951220) | 106850 (56.55%) | 50 | 0/50 (0.00%) | 0 |
| n10_r4_finite_fields | GF(2) random, with replacement | 84481 | 0.946410 | 0.975564 | 5192/5293 (0.980918) | 8548 (10.12%) | 8998 | 0/8998 (0.00%) | 0 |
| n10_r4_finite_fields | GF(2) exhaustive, no replacement | 3003 | 0.919956 | 0.930286 | 814/875 (0.930286) | 1995 (66.43%) | 840 | 0/840 (0.00%) | 0 |
| n10_r4_finite_fields | GF(3) random, with replacement | 98439 | 0.889760 | 0.934522 | 5192/5293 (0.980918) | 8610 (8.75%) | 7806 | 0/7806 (0.00%) | 0 |
| n10_r4_finite_fields | GF(3) random, no replacement | 99904 | 0.866553 | 0.894862 | 814/875 (0.930286) | 10252 (10.26%) | 8727 | 0/8727 (0.00%) | 0 |
| n10_r4_finite_fields | GF(5) random, with replacement | 99941 | 0.815577 | 0.866298 | 2512/2613 (0.961347) | 14227 (14.24%) | 573 | 0/573 (0.00%) | 0 |
| n10_r4_finite_fields | GF(5) random, no replacement | 99980 | 0.808583 | 0.846429 | 11663/12792 (0.911742) | 16270 (16.27%) | 506 | 0/506 (0.00%) | 0 |
| n10_r4_finite_fields | GF(7) random, with replacement | 99987 | 0.779374 | 0.825440 | 5370/5713 (0.939961) | 21877 (21.88%) | 44 | 0/44 (0.00%) | 0 |
| n10_r4_finite_fields | GF(7) random, no replacement | 99994 | 0.776565 | 0.813036 | 184/205 (0.897561) | 24056 (24.06%) | 32 | 0/32 (0.00%) | 0 |
| n10_r5_finite_fields | GF(2) random, with replacement | 72231 | 0.956705 | 0.982415 | 21025/21182 (0.992588) | 6043 (8.37%) | 9985 | 0/9985 (0.00%) | 0 |
| n10_r5_finite_fields | GF(2) random, no replacement | 94375 | 0.947791 | 0.968000 | 51/52 (0.980769) | 9295 (9.85%) | 27382 | 0/27382 (0.00%) | 0 |
| n10_r5_finite_fields | GF(3) random, with replacement | 95722 | 0.899969 | 0.942436 | 21025/21182 (0.992588) | 9635 (10.07%) | 11083 | 0/11083 (0.00%) | 0 |
| n10_r5_finite_fields | GF(3) random, no replacement | 97880 | 0.893025 | 0.931569 | 51/52 (0.980769) | 10731 (10.96%) | 13049 | 0/13049 (0.00%) | 0 |
| n10_r5_finite_fields | GF(5) random, with replacement | 99700 | 0.825961 | 0.875558 | 1292/1331 (0.970699) | 18394 (18.45%) | 780 | 0/780 (0.00%) | 0 |
| n10_r5_finite_fields | GF(5) random, no replacement | 99743 | 0.825714 | 0.868712 | 2093/2166 (0.966297) | 19283 (19.33%) | 829 | 0/829 (0.00%) | 0 |
| n10_r5_finite_fields | GF(7) random, with replacement | 99946 | 0.790284 | 0.834925 | 3388/3615 (0.937206) | 28820 (28.84%) | 51 | 0/51 (0.00%) | 0 |
| n10_r5_finite_fields | GF(7) random, no replacement | 99946 | 0.789765 | 0.830603 | 704/747 (0.942436) | 29237 (29.25%) | 39 | 0/39 (0.00%) | 0 |
| n12_r6 | GF(2) random, with replacement | 82408 | 1.005949 | 1.024344 | 197136/188497 (1.045831) | 45146 (54.78%) | 35705 | 25348/35705 (70.99%) | 34897 |
| n12_r6 | GF(2) random, no replacement | 93645 | 1.005392 | 1.022457 | 47405/45424 (1.043611) | 41456 (44.27%) | 55308 | 46691/55308 (84.42%) | 26350 |
| n12_r6 | GF(3) random, with replacement | 98368 | 0.950157 | 0.978944 | 197136/188497 (1.045831) | 41037 (41.72%) | 13240 | 53/13240 (0.40%) | 380 |
| n12_r6 | GF(3) random, no replacement | 98732 | 0.947773 | 0.974117 | 65500/63261 (1.035393) | 41436 (41.97%) | 13064 | 25/13064 (0.19%) | 148 |
| n12_r6 | GF(5) random, with replacement | 99915 | 0.874007 | 0.907080 | 67034/67791 (0.988833) | 58411 (58.46%) | 155 | 0/155 (0.00%) | 0 |
| n12_r6 | GF(5) random, no replacement | 99927 | 0.873793 | 0.904895 | 84309/85870 (0.981821) | 58930 (58.97%) | 139 | 0/139 (0.00%) | 0 |
| n12_r6 | GF(7) random, with replacement | 99990 | 0.835547 | 0.864477 | 38931/41587 (0.936134) | 70322 (70.33%) | 4 | 0/4 (0.00%) | 0 |
| n12_r6 | GF(7) random, no replacement | 99992 | 0.835546 | 0.863845 | 92344/98271 (0.939687) | 70444 (70.45%) | 9 | 0/9 (0.00%) | 0 |
| n12_r6 | Johnson greedy p = 0.01 | 25000 | 0.741110 | 0.744361 | 594/791 (0.750948) | 25000 (100.00%) | 0 | — | 0 |
| n12_r6 | Johnson greedy p = 0.05 | 25000 | 0.755125 | 0.759348 | 2376/3101 (0.766204) | 25000 (100.00%) | 0 | — | 0 |
| n12_r6 | Johnson greedy p = 0.2 | 25000 | 0.773186 | 0.777614 | 1584/2023 (0.782996) | 25000 (100.00%) | 0 | — | 0 |
| n12_r6 | Johnson greedy p = 1 | 25000 | 0.793057 | 0.796781 | 264/329 (0.802432) | 25000 (100.00%) | 0 | — | 0 |
| n10_r4_icarm | ICARM simple random sample | 99991 | 0.742268 | 0.758881 | 21809/25080 (0.869577) | 84445 (84.45%) | 0 | — | 0 |
| n10_r5_icarm | ICARM two-stage sample | 12800 | 0.747863 | 0.763889 | 4761/5908 (0.805856) | 11979 (93.59%) | 0 | — | 0 |

![Stored matroids: $\epsilon$ versus $\overline{\alpha}$](../figures/epsilon_analysis/epsilon_vs_alpha.png)

The point cloud uses deterministic display reservoirs. Every table entry uses the full eligible stored population.

### Associations and the uniform reference

| Scope | Ensemble | $\rho_S(\epsilon,\overline{\alpha})$ | $\rho_S(\epsilon,d_B)$ | Median $\epsilon/\epsilon(U_{r,n})$ | Sparse-paving median | Other median |
|---|---|---:|---:|---:|---:|---:|
| n8_r4 | GF(2) exhaustive, no replacement | 0.2090 | -0.9148 | 1.3413 | 0.800000 | 0.858413 |
| n8_r4 | GF(3) random, no replacement | 0.3143 | -0.9703 | 1.2585 | 0.759322 | 0.818950 |
| n8_r4 | GF(5) random, no replacement | 0.7050 | -0.9636 | 1.1838 | 0.722581 | 0.757653 |
| n8_r4 | GF(7) random, no replacement | 0.7777 | -0.9653 | 1.1270 | 0.700000 | 0.732446 |
| n8_r4 | polyDB isomorphism classes | 0.7622 | -0.9745 | 1.1475 | 0.711111 | 0.771429 |
| n9_r2 | polyDB isomorphism classes | 0.8846 | -0.9803 | 1.2118 | 0.617647 | 0.714286 |
| n9_r3 | polyDB isomorphism classes | 0.8546 | -0.9839 | 1.1574 | 0.701299 | 0.757576 |
| n9_r4 | polyDB isomorphism classes | 0.6078 | -0.9883 | 1.0957 | 0.724138 | 0.744048 |
| n10_r4_finite_fields | GF(2) random, with replacement | -0.2797 | -0.6355 | 1.3802 | — | 0.946410 |
| n10_r4_finite_fields | GF(2) exhaustive, no replacement | 0.9607 | -0.9607 | 1.3416 | — | 0.919956 |
| n10_r4_finite_fields | GF(3) random, with replacement | 0.5454 | -0.9333 | 1.2976 | — | 0.889760 |
| n10_r4_finite_fields | GF(3) random, no replacement | 0.6604 | -0.9543 | 1.2637 | — | 0.866553 |
| n10_r4_finite_fields | GF(5) random, with replacement | 0.7761 | -0.9770 | 1.1894 | 0.765957 | 0.815577 |
| n10_r4_finite_fields | GF(5) random, no replacement | 0.7984 | -0.9810 | 1.1792 | 0.765957 | 0.808583 |
| n10_r4_finite_fields | GF(7) random, with replacement | 0.8299 | -0.9865 | 1.1366 | 0.746114 | 0.779963 |
| n10_r4_finite_fields | GF(7) random, no replacement | 0.8257 | -0.9872 | 1.1325 | 0.746114 | 0.777302 |
| n10_r5_finite_fields | GF(2) random, with replacement | -0.2004 | -0.5899 | 1.3777 | — | 0.956705 |
| n10_r5_finite_fields | GF(2) random, no replacement | -0.1422 | -0.7761 | 1.3648 | — | 0.947791 |
| n10_r5_finite_fields | GF(3) random, with replacement | 0.5614 | -0.9189 | 1.2960 | — | 0.899969 |
| n10_r5_finite_fields | GF(3) random, no replacement | 0.6493 | -0.9293 | 1.2860 | — | 0.893025 |
| n10_r5_finite_fields | GF(5) random, with replacement | 0.8246 | -0.9793 | 1.1894 | 0.777778 | 0.825961 |
| n10_r5_finite_fields | GF(5) random, no replacement | 0.8269 | -0.9786 | 1.1890 | 0.774336 | 0.825714 |
| n10_r5_finite_fields | GF(7) random, with replacement | 0.8488 | -0.9795 | 1.1380 | 0.757576 | 0.790577 |
| n10_r5_finite_fields | GF(7) random, no replacement | 0.8440 | -0.9783 | 1.1373 | 0.757576 | 0.790136 |
| n12_r6 | GF(2) random, with replacement | -0.0704 | -0.2221 | 1.3692 | — | 1.005949 |
| n12_r6 | GF(2) random, no replacement | 0.0129 | -0.5086 | 1.3685 | — | 1.005392 |
| n12_r6 | GF(3) random, with replacement | 0.7341 | -0.8950 | 1.2933 | — | 0.950157 |
| n12_r6 | GF(3) random, no replacement | 0.7513 | -0.9090 | 1.2900 | — | 0.947773 |
| n12_r6 | GF(5) random, with replacement | 0.8496 | -0.9789 | 1.1896 | — | 0.874007 |
| n12_r6 | GF(5) random, no replacement | 0.8470 | -0.9782 | 1.1893 | — | 0.873793 |
| n12_r6 | GF(7) random, with replacement | 0.8593 | -0.9849 | 1.1373 | — | 0.835547 |
| n12_r6 | GF(7) random, no replacement | 0.8560 | -0.9848 | 1.1373 | — | 0.835546 |
| n12_r6 | Johnson greedy p = 0.01 | 0.6239 | -1.0000 | 1.0087 | 0.741110 | — |
| n12_r6 | Johnson greedy p = 0.05 | 0.1430 | -1.0000 | 1.0278 | 0.755125 | — |
| n12_r6 | Johnson greedy p = 0.2 | -0.0015 | -1.0000 | 1.0524 | 0.773186 | — |
| n12_r6 | Johnson greedy p = 1 | -0.0016 | -1.0000 | 1.0794 | 0.793057 | — |
| n10_r4_icarm | ICARM simple random sample | 0.4472 | -0.9934 | 1.0825 | 0.738462 | 0.747024 |
| n10_r5_icarm | ICARM two-stage sample | 0.2601 | -0.9875 | 1.0769 | 0.747863 | 0.759947 |

### Does $\overline{\alpha}>1$ imply $\epsilon>1$?

No: the implication fails in the stored data. The lowest-$\epsilon$ retained counterexamples are:

| Scope | Ensemble | Source ID | $\overline{\alpha}$ | $\epsilon$ | Bases |
|---|---|---|---:|---:|---:|
| n8_r4 | GF(5) random, no replacement | pg5_draw_00000726 | 49/48 | 605/784 | 56 |
| n8_r4 | GF(5) random, no replacement | pg5_draw_00001149 | 49/48 | 605/784 | 56 |
| n8_r4 | GF(5) random, no replacement | pg5_draw_00002260 | 49/48 | 605/784 | 56 |
| n8_r4 | GF(5) random, no replacement | pg5_draw_00003497 | 49/48 | 605/784 | 56 |
| n8_r4 | GF(5) random, no replacement | pg5_draw_00003695 | 49/48 | 605/784 | 56 |
| n8_r4 | GF(5) random, no replacement | pg5_draw_00003984 | 49/48 | 605/784 | 56 |
| n8_r4 | GF(7) random, no replacement | pg7_draw_00001840 | 49/48 | 605/784 | 56 |
| n8_r4 | GF(7) random, no replacement | pg7_draw_00003992 | 49/48 | 605/784 | 56 |
| n8_r4 | polyDB isomorphism classes | n8r4_00000376 | 49/48 | 605/784 | 56 |
| n8_r4 | GF(3) random, no replacement | pg3_draw_00000032 | 169/160 | 729/910 | 52 |
| n8_r4 | GF(3) random, no replacement | pg3_draw_00000067 | 169/160 | 729/910 | 52 |
| n8_r4 | GF(3) random, no replacement | pg3_draw_00000115 | 169/160 | 729/910 | 52 |

### When is $\epsilon\geq\overline{\alpha}$?

1672049 stored observations have $\epsilon<\overline{\alpha}$. The strongest retained discrepancies are:

| Scope | Ensemble | Source ID | $\overline{\alpha}$ | $\epsilon$ | $\epsilon-\overline{\alpha}$ |
|---|---|---|---:|---:|---:|
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_017f | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_01bf | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_01df | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_01ef | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_01f7 | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_01fb | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_01fd | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_01fe | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_027f | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_02bf | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_02df | 9/8 | 2809/3360 | -0.288988 |
| n8_r4 | GF(2) exhaustive, no replacement | pg2_subset_02ef | 9/8 | 2809/3360 | -0.288988 |

### Sparse-paving identity

For a sparse-paving matroid,

$$
\epsilon(M)
=
\frac{\binom n{r+1}\binom n{r-1}}
{\binom nr\,|\mathcal B(M)|}
=
\frac{\epsilon(U_{r,n})}{d_B(M)}.
$$

Thus $\epsilon>1$ is exactly a basis-density threshold in this class, while
$\overline{\alpha}\leq1$. None of the stored sparse-paving observations crosses that
threshold, so the observed cases with $\epsilon>1$ and $\overline{\alpha}\leq1$ arise
outside the stored sparse-paving population.


## Direct sums

For profiles $(i_j,b_j,a_j,s_j)$,

$$
\begin{aligned}
b&=b_1b_2,\\
i&=i_1b_2+b_1i_2,\\
s&=s_1b_2+b_1s_2,\\
a&=a_1b_2+b_1a_2-b_1b_2+s_1i_2+i_1s_2.
\end{aligned}
$$

No direct-sum matroid needs to be materialized. If
$x_j=i_j/b_j$, $y_j=s_j/b_j$, and $z_j=a_j/b_j$, then

$$
\epsilon(M_1\oplus M_2)
=
\frac{(x_1+x_2)(y_1+y_2)}
{z_1+z_2-1+y_1x_2+x_1y_2}.
$$

Also,

$$
\epsilon(M_1\oplus M_2)>1
\iff
z_1(\epsilon(M_1)-1)+z_2(\epsilon(M_2)-1)+1>0.
$$

For the loopless, coloopless summands analyzed here,

$$
\overline{\alpha}(M_1\oplus M_2)
=
\max\{1,\overline{\alpha}(M_1),\overline{\alpha}(M_2)\}.
$$

The last identity is recorded by [Huh–Schröter–Wang](https://arxiv.org/abs/1806.02675). Each scenario draws from deterministic uniform reservoirs of at most 2000 rows per ensemble cell. The formulas and comparisons inside each draw are exact; the percentages are two-stage empirical Monte Carlo estimates, not Cartesian-product enumerations.

| Scenario | Draws | Median $\epsilon$ | 95% | $\epsilon\geq\overline{\alpha}$ | $N(\overline{\alpha}>1)$ | $\overline{\alpha}>1\Rightarrow\epsilon>1$ | $N(\epsilon>1,\overline{\alpha}\leq1)$ | $\epsilon$ exceeds both summands |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| All cells, stored-observation weighted | 500000 | 1.145037 | 1.172379 | 499362 (99.87%) | 75644 | 75644/75644 (100.00%) | 424356 | 500000 (100.00%) |
| All cells, ensemble-cell balanced | 250000 | 1.139356 | 1.176083 | 249152 (99.66%) | 34654 | 34654/34654 (100.00%) | 215346 | 250000 (100.00%) |
| Within the same ensemble cell | 300000 | 1.146966 | 1.185764 | 298729 (99.58%) | 40056 | 40056/40056 (100.00%) | 259944 | 300000 (100.00%) |
| polyDB only | 200000 | 1.145000 | 1.146825 | 200000 (100.00%) | 568 | 568/568 (100.00%) | 199432 | 200000 (100.00%) |
| Finite-field cells only | 300000 | 1.141881 | 1.170736 | 299456 (99.82%) | 53030 | 53030/53030 (100.00%) | 246970 | 300000 (100.00%) |
| Johnson-graph cells only | 100000 | 1.191131 | 1.192587 | 100000 (100.00%) | 0 | — | 100000 | 100000 (100.00%) |
| ICARM samples only | 100000 | 1.158499 | 1.159650 | 100000 (100.00%) | 0 | — | 100000 | 100000 (100.00%) |

![Direct sums: $\epsilon$ versus $\overline{\alpha}$](../figures/epsilon_analysis/direct_sum_epsilon_vs_alpha.png)

## What makes a self-direct sum large?

Put

$$
q(M)=\frac{i(M)s(M)}{b(M)^2},
\qquad
z(M)=\frac{a(M)}{b(M)},
$$

It is also useful to write

$$
\beta(M)=\frac{b(M)}{a(M)}=\frac1{z(M)}.
$$

Here $\beta$ is the fraction of rank-$r$ almost-bases that are actual bases;
call it the basis purity among almost-bases. Since every basis is an
almost-basis, $0<\beta\leq1$.

Define also the normalized near-basis defect

$$
\Delta(M)=z(M)-q(M)
=\frac{a(M)b(M)-i(M)s(M)}{b(M)^2}
=z(M)\bigl(1-\epsilon(M)\bigr).
$$

Specializing the direct-sum formulas to two identical summands gives

$$
\boxed{
\epsilon(M\oplus M)
=
\frac{4q(M)}{2z(M)-1+2q(M)}
=
\frac{4\epsilon(M)}
{2\bigl(1+\epsilon(M)\bigr)-\beta(M)}
}
$$

and, since the denominator is positive,

$$
\boxed{
\epsilon(M\oplus M)>1
\iff
\Delta(M)<\frac12.
}
$$

Equivalently,

$$
\boxed{
\epsilon(M\oplus M)>1
\iff
\epsilon(M)>1-\frac{\beta(M)}2.
}
$$

More precisely,

$$
\epsilon(M\oplus M)-1
=
\frac{1-2\Delta(M)}
{4q(M)+2\Delta(M)-1}.
$$

Thus crossing $1$ is controlled exactly by $\Delta$, not by $\epsilon(M)$
or $\overline{\alpha}(M)$ alone. Numerical magnitude has a particularly simple
two-coordinate interpretation: the displayed formula is strictly increasing
in each of $\epsilon(M)$ and $\beta(M)$ when the other is held fixed. A large
self-sum therefore comes from the combination of high original $\epsilon$
and high basis purity. These two coordinates can move in opposite directions,
which is why either one alone can have a misleading empirical association.

Combinatorially, $z=a/b$ measures rank-$r$ almost-bases per basis, while
$q=(i/b)(s/b)$ measures the product of the two adjacent near-basis
reservoirs. In a self-direct sum, the one-unit size deficit and one-unit size
excess can be assigned to opposite copies in two ways. Those cross-copy terms
are the source of the boost.


Across all **2642818** eligible database observations, **2642818** have $\epsilon(M\oplus M)>1$ and **2642818** have $\epsilon(M\oplus M)>\epsilon(M)$. The exact observed range is $2112/2081$ to $23232/19465$.

| Scope | Ensemble | $N$ | 5% | Median $\epsilon(M\oplus M)$ | 95% | Minimum | Maximum | $N(>1)$ | Median $\Delta$ | Median $\beta$ | $\rho_S(\epsilon_{\oplus2},\beta)$ | $\rho_S(\epsilon_{\oplus2},\epsilon)$ | $\rho_S(\epsilon_{\oplus2},\overline{\alpha})$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| n8_r4 | GF(2) exhaustive, no replacement | 6315 | 1.100719 | 1.117009 | 1.119793 | 153/139 | 8/7 | 6315 | 0.220247 | 0.642857 | 1.0000 | -0.9148 | -0.1238 |
| n8_r4 | GF(3) random, no replacement | 4889 | 1.090302 | 1.115014 | 1.125163 | 2150/1993 | 3136/2757 | 4889 | 0.272203 | 0.700000 | 0.9082 | -0.8188 | -0.2598 |
| n8_r4 | GF(5) random, no replacement | 4965 | 1.090984 | 1.117370 | 1.129276 | 272/253 | 196/173 | 4965 | 0.304757 | 0.814286 | 0.8792 | -0.7368 | -0.5984 |
| n8_r4 | GF(7) random, no replacement | 4991 | 1.097054 | 1.120407 | 1.127753 | 272/253 | 196/173 | 4991 | 0.319807 | 0.857143 | 0.8475 | -0.6904 | -0.7162 |
| n8_r4 | polyDB isomorphism classes | 731 | 1.070034 | 1.119748 | 1.131007 | 3136/3081 | 8/7 | 731 | 0.313943 | 0.842857 | 0.8040 | -0.6794 | -0.7419 |
| n9_r2 | polyDB isomorphism classes | 25 | 1.036437 | 1.077307 | 1.086325 | 196/193 | 12/11 | 25 | 0.383975 | 0.805556 | 0.3441 | -0.1908 | -0.2592 |
| n9_r3 | polyDB isomorphism classes | 901 | 1.068826 | 1.117456 | 1.129482 | 4284/4213 | 42/37 | 901 | 0.313004 | 0.821429 | 0.8665 | -0.7792 | -0.7065 |
| n9_r4 | polyDB isomorphism classes | 188961 | 1.137010 | 1.145362 | 1.147317 | 680/669 | 98/85 | 188961 | 0.295350 | 0.912698 | 0.3772 | -0.2827 | -0.5505 |
| n10_r4_finite_fields | GF(2) random, with replacement | 84481 | 1.069784 | 1.100448 | 1.128985 | 2112/2081 | 3248/2831 | 84481 | 0.121088 | 0.443902 | 0.9491 | -0.4275 | 0.3814 |
| n10_r4_finite_fields | GF(2) exhaustive, no replacement | 3003 | 1.135196 | 1.144188 | 1.147298 | 24090/21221 | 3248/2831 | 3003 | 0.128314 | 0.623810 | 1.0000 | -0.9607 | -1.0000 |
| n10_r4_finite_fields | GF(3) random, with replacement | 98439 | 1.085682 | 1.123657 | 1.148726 | 29184/28165 | 29028/25055 | 98439 | 0.184874 | 0.612440 | 0.9696 | -0.8333 | -0.3722 |
| n10_r4_finite_fields | GF(3) random, no replacement | 99904 | 1.127580 | 1.144072 | 1.152709 | 6976/6357 | 29028/25055 | 99904 | 0.190650 | 0.700000 | 0.9596 | -0.8539 | -0.6259 |
| n10_r4_finite_fields | GF(5) random, with replacement | 99941 | 1.115442 | 1.146498 | 1.156761 | 1558/1489 | 120960/104051 | 99941 | 0.237553 | 0.785714 | 0.9707 | -0.9036 | -0.6822 |
| n10_r4_finite_fields | GF(5) random, no replacement | 99980 | 1.130621 | 1.149220 | 1.157407 | 25344/23347 | 1120/963 | 99980 | 0.239377 | 0.804762 | 0.9504 | -0.8787 | -0.7562 |
| n10_r4_finite_fields | GF(7) random, with replacement | 99987 | 1.127926 | 1.151976 | 1.158696 | 17856/16753 | 640/551 | 99987 | 0.259815 | 0.852381 | 0.9509 | -0.8935 | -0.7931 |
| n10_r4_finite_fields | GF(7) random, no replacement | 99994 | 1.140489 | 1.152642 | 1.158696 | 27032/24943 | 10040/8647 | 99994 | 0.259879 | 0.857143 | 0.9342 | -0.8692 | -0.8042 |
| n10_r5_finite_fields | GF(2) random, with replacement | 72231 | 1.068793 | 1.097688 | 1.133733 | 11534/11201 | 625/538 | 72231 | 0.101928 | 0.422764 | 0.9437 | -0.3791 | 0.2458 |
| n10_r5_finite_fields | GF(2) random, no replacement | 94375 | 1.099408 | 1.121051 | 1.141160 | 4658/4281 | 625/538 | 94375 | 0.101010 | 0.512000 | 0.9563 | -0.6331 | 0.1027 |
| n10_r5_finite_fields | GF(3) random, with replacement | 95722 | 1.088980 | 1.128430 | 1.153163 | 35308/33925 | 169744/145775 | 95722 | 0.167148 | 0.600000 | 0.9751 | -0.8239 | -0.3480 |
| n10_r5_finite_fields | GF(3) random, no replacement | 97880 | 1.108555 | 1.136779 | 1.153367 | 80936/75217 | 169744/145775 | 97880 | 0.167368 | 0.641434 | 0.9679 | -0.8242 | -0.4702 |
| n10_r5_finite_fields | GF(5) random, with replacement | 99700 | 1.115059 | 1.150471 | 1.162325 | 7874/7457 | 90/77 | 99700 | 0.224390 | 0.777778 | 0.9754 | -0.9171 | -0.7535 |
| n10_r5_finite_fields | GF(5) random, no replacement | 99743 | 1.123078 | 1.150933 | 1.162325 | 36250/34011 | 4900/4189 | 99743 | 0.224581 | 0.781746 | 0.9713 | -0.9083 | -0.7608 |
| n10_r5_finite_fields | GF(7) random, with replacement | 99946 | 1.136086 | 1.158250 | 1.163764 | 45602/42835 | 176400/151079 | 99946 | 0.248264 | 0.849206 | 0.9627 | -0.8946 | -0.8407 |
| n10_r5_finite_fields | GF(7) random, no replacement | 99946 | 1.139461 | 1.158261 | 1.163764 | 85408/79559 | 176400/151079 | 99946 | 0.248285 | 0.853175 | 0.9602 | -0.8882 | -0.8376 |
| n12_r6 | GF(2) random, with replacement | 82408 | 1.077552 | 1.108876 | 1.144453 | 4256/4117 | 13924/11907 | 82408 | -0.015378 | 0.380623 | 0.9717 | -0.0466 | 0.2324 |
| n12_r6 | GF(2) random, no replacement | 93645 | 1.103238 | 1.128856 | 1.150556 | 764/707 | 13924/11907 | 93645 | -0.012397 | 0.444194 | 0.9702 | -0.3358 | -0.0029 |
| n12_r6 | GF(3) random, with replacement | 98368 | 1.107938 | 1.149407 | 1.172742 | 402784/383923 | 1164338/983065 | 98368 | 0.085994 | 0.591009 | 0.9875 | -0.8256 | -0.5425 |
| n12_r6 | GF(3) random, no replacement | 98732 | 1.121209 | 1.153832 | 1.173092 | 12958/12041 | 2359296/1986335 | 98732 | 0.086876 | 0.607415 | 0.9848 | -0.8365 | -0.6013 |
| n12_r6 | GF(5) random, with replacement | 99915 | 1.149727 | 1.176066 | 1.185509 | 76167/69694 | 310078/260079 | 99915 | 0.163118 | 0.773810 | 0.9857 | -0.9345 | -0.8150 |
| n12_r6 | GF(5) random, no replacement | 99927 | 1.153623 | 1.176204 | 1.185512 | 1178832/1077947 | 20567/17266 | 99927 | 0.163272 | 0.774892 | 0.9849 | -0.9315 | -0.8139 |
| n12_r6 | GF(7) random, with replacement | 99990 | 1.166342 | 1.182835 | 1.188788 | 1288104/1178585 | 1251362/1049369 | 99990 | 0.194334 | 0.845238 | 0.9795 | -0.9328 | -0.8548 |
| n12_r6 | GF(7) random, no replacement | 99992 | 1.166794 | 1.182835 | 1.188788 | 1400256/1266917 | 1251362/1049207 | 99992 | 0.194337 | 0.845238 | 0.9793 | -0.9322 | -0.8529 |
| n12_r6 | Johnson greedy p = 0.01 | 25000 | 1.190092 | 1.190119 | 1.190164 | 144/121 | 9801/8234 | 25000 | 0.261151 | 0.991342 | -1.0000 | 1.0000 | 0.6239 |
| n12_r6 | Johnson greedy p = 0.05 | 25000 | 1.190308 | 1.190436 | 1.190591 | 627264/527027 | 627264/526715 | 25000 | 0.251685 | 0.972944 | -1.0000 | 1.0000 | 0.1430 |
| n12_r6 | Johnson greedy p = 0.2 | 25000 | 1.191079 | 1.191278 | 1.191553 | 2178/1829 | 92928/77965 | 25000 | 0.238697 | 0.950216 | -1.0000 | 1.0000 | -0.0015 |
| n12_r6 | Johnson greedy p = 1 | 25000 | 1.192399 | 1.192699 | 1.193016 | 627264/526235 | 23232/19465 | 25000 | 0.223382 | 0.926407 | -1.0000 | 1.0000 | -0.0016 |
| n10_r4_icarm | ICARM simple random sample | 99991 | 1.155620 | 1.158798 | 1.159832 | 43618/39689 | 120960/104051 | 99991 | 0.279471 | 0.923810 | 0.0132 | 0.0708 | -0.4124 |
| n10_r5_icarm | ICARM two-stage sample | 12800 | 1.162204 | 1.165010 | 1.166181 | 85698/74023 | 176400/151079 | 12800 | 0.271532 | 0.928571 | -0.1987 | 0.2995 | -0.3132 |

Within every finite-field cell the self-sum is positively associated with basis purity: the within-cell Spearman correlations range from 0.8475 to 1.0000. Ordinary basis density has the same direction in these cells, with correlations from 0.8475 to 1.0000. By contrast, its association with the original $\epsilon(M)$ is negative in every finite-field cell, ranging from -0.9607 to -0.0466. Its within-cell association with $\overline{\alpha}(M)$ ranges from -1.0000 to 0.3814. These directions reverse in the Johnson sparse-paving cells, where $\epsilon(M\oplus M)$ and $\epsilon(M)$ are comonotone and basis density is antimonotone. Therefore density and the original invariant are ensemble-dependent proxies, not structural substitutes for $(q,\Delta)$.

![Self-direct sums: $\epsilon$ versus the normalized defect](../figures/epsilon_analysis/self_sum_epsilon_vs_defect.png)

### The supplied $100/81$ example is not exceptional for its size

For the supplied rank-$6$ matroid on $12$ elements,

$$
q(M)=\frac{16129}{12996},
\qquad
z(M)=\frac{77}{57},
\qquad
\beta(M)=\frac{57}{77},
\qquad
\Delta(M)=\frac{1427}{12996}\approx0.109802.
$$

This small defect explains why its self-sum crosses $1$. Nevertheless, the
uniform matroid of the same rank and size has

$$
\epsilon(U_{6,12}\oplus U_{6,12})
=\frac{144}{121}
\approx1.190083,
$$

which is slightly larger than

$$
\epsilon(M\oplus M)
=\frac{32258}{27187}
\approx1.186523.
$$

The supplied matroid combines the high value
$\epsilon(M)=16129/17556$ with moderate basis purity $\beta=57/77$.
The uniform matroid has the smaller value $\epsilon(U_{6,12})=36/49$ but
maximal purity $\beta=1$, which more than compensates. Therefore the large
$\overline{\alpha}(M)=100/81$ is not the cause of the self-sum value.


### Ground-set size: uniform controls

Let $c=n-r$. For a uniform matroid,

$$
\epsilon(U_{r,n}\oplus U_{r,n})
=
\frac{4rc}{(r+1)(c+1)+2rc},
$$

so

$$
\epsilon(U_{r,n}\oplus U_{r,n})>1
\iff
(r-1)(c-1)>2.
$$

In the balanced family this becomes

$$
\epsilon(U_{m,2m}\oplus U_{m,2m})
=
\frac{4m^2}{3m^2+2m+1}
\longrightarrow \frac43.
$$

For $m=2,3,4,5,6,10$ the exact values are, respectively,

$$
\frac{16}{17},\quad
\frac{18}{17},\quad
\frac{64}{57},\quad
\frac{50}{43},\quad
\frac{144}{121},\quad
\frac{400}{321}.
$$

Consequently a database restricted to $n\leq12$ cannot display the approach
to $4/3$ even in the most elementary family.


### Nonuniform rank-$2$ controls

A loopless rank-$2$ matroid is determined by its parallel-class sizes
$c_1,\ldots,c_k$. It is connected exactly when $k\geq3$, and its profile is

$$
i=n,\qquad
b=\frac{n^2-\sum_j c_j^2}{2},\qquad
a=\binom n2,\qquad
s=\binom n3-\sum_j\binom{c_j}{3}.
$$

The following table comes from an exact enumeration of every integer
partition with at least three parts for each $3\leq n\leq30$; selected rows
are displayed.


| $n$ | Minimizing class sizes | Minimum self-sum | Maximizing class sizes | Maximum self-sum |
|---:|---|---:|---|---:|
| 4 | $(1,1,1,1)$ | 16/17 | $(2,1,1)$ | 64/67 |
| 5 | $(3,1,1)$ | 180/181 | $(2,2,1)$ | 50/49 |
| 6 | $(4,1,1)$ | 128/127 | $(2,2,2)$ | 20/19 |
| 9 | $(7,1,1)$ | 196/193 | $(3,3,3)$ | 12/11 |
| 12 | $(10,1,1)$ | 1600/1577 | $(4,4,4)$ | 52/47 |
| 20 | $(18,1,1)$ | 25920/25651 | $(7,7,6)$ | 12000/10693 |
| 30 | $(28,1,1)$ | 31360/31127 | $(10,10,10)$ | 148/131 |

The small cases genuinely differ: connected examples below, equal to, and
above $1$ all occur at $n\leq5$. Every enumerated connected rank-$2$ type for
$6\leq n\leq30$ is above $1$. Highly unbalanced types $(n-2,1,1)$ approach
$1$ from above, whereas balanced three-class types stay farther above $1$.
This shows that size alone is not enough: balance of the near-basis counts
also matters.


## Known $\overline{\alpha}=8/7$ family

[Huh, Schröter, and Wang](https://doi.org/10.4171/JEMS/1119) define the rank-$d$ finite-field spike $M_p^d$ over $\operatorname{GF}(p)$ using $e_1$, $e_2+\cdots+e_d$, and $ke_1+e_m$. Its distinguished ratio is $(d-1)^2/(d^2-3d+4)$, equal to $8/7$ at $d=5$. Here the full unweighted $\overline{\alpha}$ is independently recomputed from all bases before evaluating $\epsilon$.

| $p$ | $n$ | Bases | $i_4$ | $a_5$ | $s_6$ | $\overline{\alpha}$ | $\epsilon$ | $\epsilon(M\oplus M)$ | $\epsilon\geq\overline{\alpha}$ |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 | 10 | 136 | 176 | 246 | 176 | 8/7 | 1936/2091 (0.925873) | 3872/3449 (1.122644) | no |
| 3 | 14 | 891 | 783 | 1872 | 2079 | 8/7 | 203/208 (0.975962) | 812/723 (1.123098) | no |
| 5 | 22 | 9625 | 5375 | 23550 | 42625 | 8/7 | 6665/6594 (1.010767) | 26660/23823 (1.119087) | no |
| 7 | 30 | 46991 | 19551 | 124656 | 307671 | 8/7 | 119301/116176 (1.026899) | 1431612/1281479 (1.117156) | no |

This family cleanly separates the invariants: for the tested primes, $\epsilon$ increases from $1936/2091<1$ at $p=2$ to $119301/116176>1$ at $p=7$, crossing $1$ between $p=3$ and $p=5$, while remaining strictly below the fixed value $\overline{\alpha}=8/7$.

## The supplied $\overline{\alpha}=100/81$ benchmark

The supplied matrix over $\operatorname{GF}(3)$ defines a rank-$6$ matroid on
$12$ elements. Enumerating all $924$ six-column subsets reproduces $684$
bases and the maximizing pair table

$$
(b_{00},b_{01},b_{10},b_{11})=(180,162,162,180),
$$

so

$$
\overline{\alpha}(M)=\frac{180^2}{162^2}=\frac{100}{81}.
$$

The exact near-basis profile is

$$
(i_5,b_6,a_6,s_7)=(762,684,924,762).
$$

Consequently

$$
\boxed{
\epsilon(M)
=
\frac{762^2}{924\cdot684}
=
\frac{16129}{17556}
\approx0.918717
}
$$

and

$$
\boxed{
\epsilon(M\oplus M)
=
\frac{32258}{27187}
\approx1.186523.
}
$$

The matrix is stored literally in the report generator, so both values are
recomputed from the representation rather than from the aggregate pair
table.


## Artifacts and reproduction

- [Individual-cell summary](../data/epsilon_analysis/epsilon_summary.csv)
- [Direct-sum summary](../data/epsilon_analysis/direct_sum_summary.csv)
- [Known-family values](../data/epsilon_analysis/known_family_summary.csv)
- [Extrema and implication failures](../data/epsilon_analysis/epsilon_extrema.csv)

Run:

```bash
julia --project=. scripts/make_epsilon_report.jl
```

Unit tests cover $\epsilon(U_{4,8})=16/25$, dual invariance, and $\epsilon(U_{2,4}\oplus U_{2,4})=16/17$.
