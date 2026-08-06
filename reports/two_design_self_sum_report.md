# Base $2$-designs and large self-direct-sum $\epsilon$

_Generated from exact flat-lattice counts on 2026-08-02._

## Why the base $2$-design condition fixes $\overline{\alpha}$

Suppose the bases of a rank-$r$ matroid form a $2$-$(n,r,\lambda)$ design,
and let $b$ be the total number of bases. For every pair of distinct
elements,

$$
\begin{aligned}
b_{11}&=\frac{br(r-1)}{n(n-1)},\\
b_{10}=b_{01}&=\frac{br(n-r)}{n(n-1)},\\
b_{00}&=\frac{b(n-r)(n-r-1)}{n(n-1)}.
\end{aligned}
$$

Therefore every pair has the uniform-matroid ratio

$$
\boxed{
\overline{\alpha}(M)
=
\frac{(r-1)(n-r-1)}{r(n-r)}
=
\overline{\alpha}(U_{r,n}).
}
$$

This condition says nothing by itself about the adjacent-rank counts
$i_{r-1}$, $a_r$, and $s_{r+1}$, so it does not determine $\epsilon$.

For later comparison, recall the exact self-sum identity

$$
\epsilon(M\oplus M)
=\frac{4\epsilon(M)}{2(1+\epsilon(M))-\beta(M)},
\qquad
\beta(M)=\frac{|\mathcal B(M)|}{a_r(M)}.
$$

It gives the sharp threshold

$$
\boxed{
\epsilon(M\oplus M)>\frac43
\quad\Longleftrightarrow\quad
\epsilon(M)+\beta(M)>2.
}
$$


## Affine and projective geometries

The groups $\operatorname{AGL}(r-1,q)$ and $\operatorname{PGL}(r,q)$ are
$2$-transitive on the points of $\operatorname{AG}(r-1,q)$ and
$\operatorname{PG}(r-1,q)$, respectively. Hence their bases form
$2$-designs.

Exact finite-rank values below are obtained by Möbius inversion on the affine
and projective flat lattices. No subsets of the exponentially large ground
sets are materialized.


| Family | $q$ | $r$ | $n$ | $\epsilon(M)$ | $\beta=b/a$ | $\Delta$ | $\epsilon(M\oplus M)$ |
|---|---:|---:|---:|---:|---:|---:|---:|
| PG | 2 | 3 | 7 | 0.750000 | 0.800000 | 0.312500 | 1.111111 |
| PG | 2 | 5 | 31 | 1.093750 | 0.500000 | -0.187500 | 1.186441 |
| PG | 2 | 10 | 1023 | 1.216830 | 0.345946 | -0.626776 | 1.190719 |
| PG | 2 | 20 | 1048575 | 1.269871 | 0.333378 | -0.809505 | 1.207571 |
| PG | 2 | 30 | 1073741823 | 1.290323 | 0.333333 | -0.870968 | 1.215190 |
| PG | 3 | 3 | 13 | 0.818182 | 0.818182 | 0.222222 | 1.161290 |
| PG | 3 | 5 | 121 | 1.059432 | 0.627907 | -0.094650 | 1.213916 |
| PG | 3 | 10 | 29524 | 1.168933 | 0.572263 | -0.295202 | 1.241696 |
| PG | 3 | 20 | 1743392200 | 1.224490 | 0.571429 | -0.392857 | 1.263158 |
| PG | 3 | 30 | 102945566047324 | 1.244240 | 0.571429 | -0.427419 | 1.270588 |
| PG | 5 | 3 | 31 | 0.827586 | 0.862069 | 0.200000 | 1.185185 |
| PG | 5 | 5 | 781 | 0.988875 | 0.772559 | 0.014400 | 1.234092 |
| PG | 5 | 10 | 2441406 | 1.082251 | 0.761919 | -0.107952 | 1.272270 |
| PG | 5 | 20 | 23841857910156 | 1.133787 | 0.761905 | -0.175595 | 1.293661 |
| PG | 5 | 30 | 232830643653869628906 | 1.152074 | 0.761905 | -0.199597 | 1.300954 |
| PG | 7 | 3 | 57 | 0.818182 | 0.890909 | 0.204082 | 1.192053 |
| PG | 7 | 5 | 2801 | 0.948547 | 0.840392 | 0.061224 | 1.241269 |
| PG | 7 | 10 | 47079208 | 1.035941 | 0.837210 | -0.042929 | 1.281046 |
| PG | 7 | 20 | 13298711049602000 | 1.085271 | 0.837209 | -0.101852 | 1.302326 |
| PG | 7 | 30 | 3756556715115376347977208 | 1.102776 | 0.837209 | -0.122760 | 1.309577 |
| AG | 2 | 3 | 4 | 0.375000 | 1.000000 | 0.625000 | 0.857143 |
| AG | 2 | 5 | 16 | 1.025641 | 0.615385 | -0.041667 | 1.194030 |
| AG | 2 | 10 | 512 | 1.218837 | 0.354571 | -0.617188 | 1.194030 |
| AG | 2 | 20 | 524288 | 1.269894 | 0.333414 | -0.809486 | 1.207590 |
| AG | 2 | 30 | 536870912 | 1.290323 | 0.333334 | -0.870968 | 1.215190 |
| AG | 3 | 3 | 9 | 0.750000 | 0.857143 | 0.291667 | 1.135135 |
| AG | 3 | 5 | 81 | 1.051587 | 0.642857 | -0.080247 | 1.215596 |
| AG | 3 | 10 | 19683 | 1.168950 | 0.572563 | -0.295077 | 1.241801 |
| AG | 3 | 20 | 1162261467 | 1.224490 | 0.571429 | -0.392857 | 1.263158 |
| AG | 3 | 30 | 68630377364883 | 1.244240 | 0.571429 | -0.427419 | 1.270588 |
| AG | 5 | 3 | 25 | 0.815217 | 0.869565 | 0.212500 | 1.181102 |
| AG | 5 | 5 | 625 | 0.988132 | 0.773994 | 0.015333 | 1.234289 |
| AG | 5 | 10 | 1953125 | 1.082250 | 0.761922 | -0.107951 | 1.272271 |
| AG | 5 | 20 | 19073486328125 | 1.133787 | 0.761905 | -0.175595 | 1.293661 |
| AG | 5 | 30 | 186264514923095703125 | 1.152074 | 0.761905 | -0.199597 | 1.300954 |
| AG | 7 | 3 | 49 | 0.813830 | 0.893617 | 0.208333 | 1.190661 |
| AG | 7 | 5 | 2401 | 0.948393 | 0.840686 | 0.061386 | 1.241312 |
| AG | 7 | 10 | 40353607 | 1.035941 | 0.837210 | -0.042929 | 1.281046 |
| AG | 7 | 20 | 11398895185373143 | 1.085271 | 0.837209 | -0.101852 | 1.302326 |
| AG | 7 | 30 | 3219905755813179726837607 | 1.102776 | 0.837209 | -0.122760 | 1.309577 |

![Affine and projective self-sum limits](../figures/epsilon_analysis/two_design_self_sum_limits.png)

### Fixed-field, growing-rank limits

For either geometry family, fix the prime power $q$ and let $r\to\infty$.
The rank probabilities converge to those of large square matrices over
$\operatorname{GF}(q)$. After the adjacent binomial factors are included,

$$
\frac{is}{b^2}\longrightarrow\frac{q^2}{(q-1)^2},
\qquad
\frac{a}{b}\longrightarrow
\frac{q^2-q+1}{(q-1)^2}.
$$

Consequently,

$$
\boxed{
\begin{aligned}
\epsilon(M)&\longrightarrow\frac{q^2}{q^2-q+1},\\
\beta(M)&\longrightarrow\frac{(q-1)^2}{q^2-q+1},\\
\Delta(M)&\longrightarrow-\frac1{q-1},\\
\epsilon(M\oplus M)&\longrightarrow\frac{4q^2}{3q^2+1}.
\end{aligned}
}
$$


| $q$ | Limit of $\epsilon(M)$ | Limit of $\beta$ | Limit of $\epsilon(M\oplus M)$ | Decimal self-sum limit |
|---:|---:|---:|---:|---:|
| 2 | 4/3 | 1/3 | 16/13 | 1.230769 |
| 3 | 9/7 | 4/7 | 9/7 | 1.285714 |
| 5 | 25/21 | 16/21 | 25/19 | 1.315789 |
| 7 | 49/43 | 36/43 | 49/37 | 1.324324 |

Thus the ternary geometries tend to $9/7$, the quinary geometries tend to
$25/19$, and the limiting values approach $4/3$ as $q\to\infty$. These are
nonuniform, highly structured matroids with the same $\overline{\alpha}$ as the
corresponding uniform matroid.

In the complementary regime, if $r$ is fixed and $q\to\infty$, both geometry
families satisfy

$$
\epsilon(M)\longrightarrow\frac r{r+1},
\qquad
\beta(M)\longrightarrow1,
\qquad
\epsilon(M\oplus M)\longrightarrow\frac{4r}{3r+1}.
$$

Letting $r\to\infty$ again approaches $4/3$. In the fixed-field limit,
$\epsilon+\beta=2-1/(q^2-q+1)$, so these geometry families approach the
threshold from below rather than cross it.


## Steiner-system sparse-paving families

Let the circuit-hyperplanes of a rank-$r$ sparse-paving matroid be the blocks
of a Steiner system $S(r-1,r,n)$. Two blocks intersect in at most $r-2$
points, so this is a valid sparse-paving matroid. The blocks, and hence their
complement among the $r$-subsets, are $2$-designs.

There are

$$
h=\frac1r\binom n{r-1}
=\frac1{n-r+1}\binom nr
$$

circuit-hyperplanes. Writing $c=n-r$, the exact profile gives

$$
\boxed{
\epsilon(M)=\frac{r}{r+1},
\qquad
\beta(M)=\frac{c}{c+1},
\qquad
\epsilon(M\oplus M)
=
\frac{4r(c+1)}{(3r+1)c+4r+2}.
}
$$

For each fixed $r$, the self-sum therefore tends to

$$
\frac{4r}{3r+1}
$$

as $n\to\infty$. These limits approach $4/3$ as $r\to\infty$.

The first two concrete infinite subfamilies are:

$$
\begin{array}{c|c|c}
\text{systems} & \text{admissible }n & \epsilon(M\oplus M)\\
\hline
S(2,3,n) & n\equiv1,3\pmod6 &
\dfrac{6(n-2)}{5n-8}\longrightarrow\dfrac65\\[6pt]
S(3,4,n) & n\equiv2,4\pmod6 &
\dfrac{16(n-3)}{13n-34}\longrightarrow\dfrac{16}{13}
\end{array}
$$

More generally, for every fixed $r$, Keevash's
[existence theorem](https://arxiv.org/abs/1401.3665) supplies
$S(r-1,r,n)$ for all sufficiently large admissible $n$ satisfying the
standard divisibility conditions. Hence this produces nonuniform infinite
families at every fixed rank.


## More than two uniform summands

For $M=U_{r,n}$, put

$$
u=\epsilon(U_{r,n})
=\frac{r(n-r)}{(r+1)(n-r+1)}.
$$

For $k$ identical copies,

$$
\boxed{
\epsilon\left(M^{\oplus k}\right)
=
\frac{k^2u}{1+k(k-1)u}.
}
$$

For fixed $k$ and $r,n-r\to\infty$,

$$
\epsilon\left(U_{r,n}^{\oplus k}\right)
\longrightarrow
\frac{k^2}{k^2-k+1}.
$$

| $k$ | Limiting value |
|---:|---:|
| $2$ | $4/3$ |
| $3$ | $9/7$ |
| $4$ | $16/13$ |
| $5$ | $25/21$ |
| $6$ | $36/31$ |
| $10$ | $100/91$ |

Thus adding more identical uniform summands does not improve on $4/3$;
the limiting value decreases after $k=2$ and tends to $1$.

The same upper bound holds for arbitrary, nonidentical uniform summands.
For $U_{r_j,r_j+c_j}$ define

$$
x_j=\frac{r_j}{c_j+1},
\qquad
y_j=\frac{c_j}{r_j+1},
\qquad
q_j=x_jy_j<1.
$$

Writing $X=\sum_jx_j$, $Y=\sum_jy_j$, and
$C=XY-\sum_jq_j$, one has

$$
\epsilon\left(\bigoplus_j U_{r_j,r_j+c_j}\right)
=
\frac{C+\sum_jq_j}{1+C}.
$$

Cauchy--Schwarz gives

$$
C\geq2\sum_{i<j}\sqrt{q_iq_j}.
$$

If $t_j=\sqrt{q_j}\in[0,1)$, the elementary cube inequality

$$
4+2\sum_{i<j}t_it_j-3\sum_jt_j^2\geq0
$$

then implies

$$
\boxed{
\epsilon\left(\bigoplus_j U_{r_j,n_j}\right)\leq\frac43.
}
$$

The inequality on the cube can be checked at its vertices because its
left-hand side is concave in each coordinate separately; at a vertex with
$m$ ones it equals $(m-2)^2$. Therefore no finite direct sum of uniform
matroids beats $4/3$.


## Reproduction

- [Exact finite-rank data](../data/epsilon_analysis/two_design_family_summary.csv)
- [Convergence figure](../figures/epsilon_analysis/two_design_self_sum_limits.png)

```bash
julia --project=. scripts/make_two_design_self_sum_report.jl
```
