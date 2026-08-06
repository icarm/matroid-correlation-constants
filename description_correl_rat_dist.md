# Statistical data for correlation ratios of matroids

## Statistical exploration of unweighted correlation ratios

The full $2 \times 2$ basis table should be computed for every eligible pair,
rather than computing only $\overline{\alpha}(M)$. It need not, however, be retained as
a separate database row for every pair of every matroid. Compact summaries and
exact aggregate frequencies are sufficient for the population study, while
complete pair profiles can be regenerated from the stored basis encoding for
selected matroids.

Let $\mathcal B(M)$ denote the set of bases of $M$, and let $\mathbf B$ be a basis chosen uniformly at random from $\mathcal B(M)$. Thus

$$
\Pr(\mathbf B=B)
=
\frac{1}{|\mathcal B(M)|}
\qquad
\text{for every }B\in\mathcal B(M).
$$

For each element $e\in E(M)$, define the basis-inclusion indicator

$$
X_e
=
\mathbf 1_{\{e\in\mathbf B\}}
=
\begin{cases}
1,&e\in\mathbf B,\\
0,&e\notin\mathbf B.
\end{cases}
$$

All probabilities, covariances, and correlations below refer to the randomness of $\mathbf B$ for a fixed matroid $M$. Randomly sampling the matroid itself, discussed later, is a separate level of randomness.

An eligible pair $\{i,j\}$ consists of two distinct elements, neither of which is a loop or a coloop. For every such pair, compute

$$
\begin{array}{c|cc}
 & X_j=0 & X_j=1\\
\hline
X_i=0 & b_{00}=|B^{ij}| & b_{01}=|B^i_j|\\
X_i=1 & b_{10}=|B^j_i| & b_{11}=|B_{ij}|
\end{array}
$$

Equivalently,

$$
b_{ab}
=
\left|
\left\{
B\in\mathcal B(M):
\mathbf 1_{\{i\in B\}}=a,
\quad
\mathbf 1_{\{j\in B\}}=b
\right\}
\right|,
\qquad
a,b\in\{0,1\}.
$$

Then

$$
R_{ij}
=
\frac{b_{00}b_{11}}{b_{01}b_{10}},
$$

and

$$
\overline{\alpha}(M)
=
\max_{i\ne j} R_{ij}.
$$

This preserves enough information to understand why a ratio is large.

## Pair-level statistics

For each eligible pair $\{i,j\}$, compute:

- The correlation ratio $R_{ij}$.
- The log-ratio $\log R_{ij}$.
- The four normalized cell probabilities

  $$
  p_{ab}
  =
  \Pr(X_i=a,X_j=b)
  =
  \frac{b_{ab}}{|\mathcal B(M)|}.
  $$

- The individual inclusion probabilities

  $$
  p_i
  =
  \Pr(X_i=1)
  =
  p_{10}+p_{11},
  \qquad
  p_j
  =
  \Pr(X_j=1)
  =
  p_{01}+p_{11}.
  $$

- The joint inclusion probability

  $$
  p_{ij}
  =
  \Pr(X_i=1,X_j=1)
  =
  p_{11}.
  $$

  Here the subscripts in $p_{11}$ denote the values of the two indicator variables, whereas the subscripts in $p_{ij}$ name the two elements. Thus $p_{11}$ and $p_{ij}$ denote the same probability in this context.

- The covariance of the basis indicators:

  $$
  \operatorname{Cov}(X_i,X_j)
  =
  p_{ij}-p_ip_j
  =
  p_{11}-p_ip_j.
  $$

- The Pearson correlation of $X_i$ and $X_j$:

  $$
  \rho_{ij}
  =
  \frac{p_{ij}-p_ip_j}
  {\sqrt{p_i(1-p_i)p_j(1-p_j)}}.
  $$

- A bounded association score such as Yule's $Q$:

  $$
  Q_{ij}
  =
  \frac{R_{ij}-1}{R_{ij}+1}.
  $$

- The minimum cell count and minimum cell probability.

For an eligible pair, $0<p_i,p_j<1$, so the Pearson correlation is defined. The mixed cell counts $b_{01}$ and $b_{10}$ are positive, so $R_{ij}$ has no zero denominator. Its numerator can be zero, however, in which case $R_{ij}=0$ and $\log R_{ij}=-\infty$.

The additional association statistics matter because two pairs can have the same odds ratio but very different dependence profiles. A large $R_{ij}$ supported on tiny diagonal cells is statistically different from the table

$$
(b_{00},b_{01},b_{10},b_{11})
=
(180,162,162,180)
$$

in the example attaining $100/81$.

For a $2\times2$ table, the following conditions are equivalent:

$$
R_{ij}>1,
$$

$$
p_{00}p_{11}>p_{01}p_{10},
$$

and

$$
p_{ij}-p_ip_j
=
\operatorname{Cov}(X_i,X_j)>0.
$$

Thus $R_{ij}$, covariance, and Pearson correlation detect the same sign of association, but quantify its strength differently.

## Pair-data retention policy

The authoritative reusable data for every matroid are its polyDB-compatible
`REVLEX_BASIS_ENCODING` and its matroid-level summaries. The encoding contains
one character for each $r$-subset in reverse-lexicographic/colex order, with
`*` for a basis and `0` for a nonbasis. Random finite-field matroids are written
in the same convention as polyDB.

During collection, every eligible pair is evaluated in memory. The database
then retains:

- One compact summary row for the matroid.
- Exact aggregate frequencies keyed by the reduced fraction $R_{ij}$.
- Both pair-weighted frequency and equal-matroid-weight frequency, so pooled
  pair plots do not inadvertently overweight matroids with more eligible pairs.
- Complete pair tables only for matroids explicitly selected for heatmaps,
  upper-tail inspection, quantile examples, or deterministic random examples.

Because the basis encoding is retained, a complete pair profile is a
reproducible derived cache rather than irreplaceable primary data.

## Matroid-level summaries

For each matroid, record:

- $\overline{\alpha}(M)$.
- The second-largest pair ratio.
- The gap between the largest and second-largest ratios.
- The number of maximizing pairs.
- The proportion of pairs for which $R_{ij}>1$.
- Quantiles of the pairwise $R_{ij}$ or $\log R_{ij}$ distribution.
- The largest Pearson correlation, in addition to the largest odds ratio.
- Whether positive correlation is concentrated around one special element.
- The graph whose vertices are elements and whose edges are positively correlated pairs.
- Pair orbits under $\operatorname{Aut}(M)$, when feasible.

These statistics distinguish a matroid with one isolated exceptional pair from one having widespread positive dependence.

For example, define the positive-correlation graph by

$$
G_+(M)
=
\left(
E(M),
\left\{
\{i,j\}:R_{ij}>1
\right\}
\right).
$$

Useful summaries of this graph include:

- Number of edges.
- Number and sizes of connected components.
- Maximum degree.
- Weighted degrees using $\log R_{ij}$.
- Whether its vertices or edges form automorphism orbits.

## Structural variables

For every matroid, record at least:

- Ground-set size $n$.
- Rank $r$.
- Corank $n-r$.
- Number of bases $|\mathcal B(M)|$.
- Normalized basis density:

  $$
  d_{\mathcal B}(M)
  =
  \frac{|\mathcal B(M)|}{\binom nr}.
  $$

- Whether the matroid is simple.
- Whether the matroid is cosimple.
- Whether the matroid is connected.
- Whether the matroid is $3$-connected.
- Numbers and sizes of parallel classes.
- Numbers and sizes of series classes.
- Girth and cogirth.
- Number of circuits.
- Number of hyperplanes.
- Number of circuit-hyperplanes.
- Whether it is paving or sparse paving.
- Its representing field.
- Whether it is regular, graphic, or cographic, when known.
- Automorphism-group size.
- Element-orbit and pair-orbit sizes.
- Variation among the element inclusion probabilities $p_i$.

For example, inclusion-probability heterogeneity can be measured by

$$
H_{\mathrm{inc}}(M)
=
\frac{1}{n}
\sum_{i=1}^n
\left(
p_i-\frac{r}{n}
\right)^2.
$$

This statistic vanishes for element-transitive matroids but can also vanish in some less symmetric cases.

## Structure around the maximizing pair

For selected upper-tail or otherwise representative matroids, record the
following information for every pair attaining $\overline{\alpha}(M)$:

- Whether the two elements are clones.
- Whether they lie in the same automorphism orbit.
- The orbit of the unordered pair under $\operatorname{Aut}(M)$.
- The smallest circuit containing both elements.
- The smallest cocircuit containing both elements.
- The number of circuits containing neither, one, or both elements.
- The number of cocircuits containing neither, one, or both elements.
- The number of circuit-hyperplanes containing neither, one, or both elements.
- The four deletion/contraction-related basis counts represented by the contingency table.
- The inclusion probabilities of the two elements.
- The degrees of the two elements in $G_+(M)$.

These features could expose structural mechanisms analogous to the duad–syntheme split in the matroid attaining $100/81$.

## Distinguishing the statistical populations

There are two fundamentally different statistical studies.

### The polyDB census

This measures frequencies among catalogued isomorphism classes.

If a collection is complete for a specified range of $(n,r)$, its proportions are exact population quantities rather than estimates requiring confidence intervals.

The resulting interpretation is:

> Among the isomorphism classes represented in this polyDB collection, what fraction have a given correlation property?

It is important to record the precise polyDB collection and all filters used.

### Random representable matroids

Random generation measures a chosen probability distribution on representations. It does not ordinarily produce a uniform distribution on matroid isomorphism classes.

A clean primary model for simple $\operatorname{GF}(q)$-representable matroids is:

1. Sample $n$ distinct projective points uniformly from

   $$
   \operatorname{PG}(r-1,q).
   $$

2. Condition on the points spanning rank $r$.
3. Optionally condition further on cosimplicity, connectivity, or $3$-connectivity.

The total number of points in this projective space is

$$
\left|
\operatorname{PG}(r-1,q)
\right|
=
\frac{q^r-1}{q-1}.
$$

Sampling iid columns of an $r\times n$ matrix over $\operatorname{GF}(q)$ should be treated as a separate ensemble. That model permits zero columns and parallel columns and therefore gives a substantially different distribution.

For every random sample, retain:

- The generation model.
- $q$, $r$, and $n$.
- The random seed.
- All conditioning criteria.
- The number of rejected samples.
- Whether the resulting matroid is a duplicate of an earlier sample.
- The multiplicity with which its isomorphism class occurred.

If isomorphism testing is computationally practical, report both:

- Results with multiplicity, representing the generator's natural distribution.
- Results after isomorphism deduplication.

## Recommended visualizations

### Rank-size phase diagrams

For every $(n,r)$, first restrict the distributional population to connected
matroids with $\overline{\alpha}(M)>0$, and then show:

- The number and proportion with $\overline{\alpha}(M)>1$.
- The median of $\overline{\alpha}(M)$.
- The $95$th percentile of $\overline{\alpha}(M)$.
- The maximum observed value.
- The number of matroids examined.

Separate plots should be made for different database collections, finite fields, and random-generation models.

Because of duality, the diagrams should be symmetric under

$$
r\longleftrightarrow n-r.
$$

Any failure of this symmetry in a dual-closed dataset would indicate a computational or data-processing problem.

For routine census and sampling work, compute and report only ranks

$$
0\leq r\leq \left\lfloor\frac n2\right\rfloor.
$$

The remaining ranks are determined by duality. Explicitly materialized duals
may be used for a validation audit, but they should not be treated as separate
experimental populations or given redundant reports.

### Empirical distribution plots

Use a normalized histogram (or an estimated probability density when the
sample is large enough to justify smoothing) of $\overline{\alpha}(M)$. Use common bin
edges for populations shown in the same panel, so each population has total
mass one and bin heights are directly comparable. The default distribution
figure should not be a CDF or survival curve.

Because $\overline{\alpha}(M)$ is rational and the population of small matroids is
finite, the empirical distribution can have substantial atoms. State the bin
count, describe the staircase as a histogram outline, and check at least one
coarser binning before interpreting small peaks. Smoothing may be supplied as
a secondary view, but it should not replace the exact histogram or conceal
repeated rational values.

Separate the histograms by:

- Field size $q$.
- Rank and corank.
- Connectivity.
- Paving status.
- Database versus random source.

Mark the reference values

$$
1,
\qquad
\frac87,
\qquad
\frac{100}{81}.
$$

Because sparse paving matroids satisfy

$$
\overline{\alpha}(M)\leq 1,
$$

each report should also show a companion histogram conditioned on $M$ not
being sparse paving. This companion should use exactly the same bin edges,
panels, and reference lines as the main histogram and should report both the
retained sample size and retained percentage. It is a conditional view, not a
replacement for the full distribution: renormalizing after the filter changes
the displayed probability masses even though it removes nothing from the
region $\overline{\alpha}>1$.

### Basis-density plots

Plot $\overline{\alpha}(M)$ against

$$
d_{\mathcal B}(M)
=
\frac{|\mathcal B(M)|}{\binom nr}.
$$

Color or facet the plot by:

- Paving status.
- Field of representation.
- Connectivity.
- Rank.
- Corank.

This may reveal whether positive correlation is associated with moderately sparse basis systems, very sparse systems, or a particular structural regime.

In addition to the full-population plot, make separate companion basis-density
plots for sparse paving and non-sparse-paving matroids. For each ensemble,
report Pearson's $r$, Spearman's $\rho$, and the fitted change in $\overline{\alpha}$
per 0.1 increase in basis density. Confidence intervals and tests are
appropriate for random ensembles, but polyDB and exhaustive populations
should be treated as censuses and described without inferential $p$-values.

### Within-matroid heatmaps

For selected matroids, plot the matrix

$$
\left(\log R_{ij}\right)_{i,j\in E(M)}.
$$

Order elements by automorphism orbit or by hierarchical clustering.

This should make it clear whether an exceptional ratio is isolated, organized into blocks, or distributed across many pairs.

For matroids with zero ratios, display those entries separately rather than treating $\log 0$ as an ordinary numerical value.

### Positive-pair prevalence versus maximum ratio

Plot

$$
\frac{
\left|
\left\{
\{i,j\}:R_{ij}>1
\right\}
\right|
}{
\binom n2
}
$$

against $\overline{\alpha}(M)$.

This distinguishes matroids with one exceptional pair from matroids with many mildly positive pairs.

### Maximizing-pair cell profiles

For every matroid in the upper tail, display the normalized table

$$
\begin{array}{c|cc}
 & j\notin B & j\in B\\
\hline
i\notin B & p_{00} & p_{01}\\
i\in B & p_{10} & p_{11}
\end{array}
$$

as a mosaic plot.

This reveals whether a high ratio is caused by:

- Enhanced diagonal cells.
- Suppressed mixed cells.
- Strongly unequal inclusion probabilities.
- Some combination of these effects.

### Finite-field comparisons

For fixed $(n,r)$, compare distributions across $q$ using violin plots, boxplots, or empirical distribution functions.

For projective-point sampling, also use the projective density

$$
\delta_{\mathrm{PG}}
=
\frac{n}{
\left|\operatorname{PG}(r-1,q)\right|
}
=
\frac{n(q-1)}{q^r-1}.
$$

This is often more meaningful than comparing field sizes alone.

## Controls and possible confounders

### Disconnected matroids

Elements in different direct-sum components are independent under the uniform distribution on bases. Consequently,

$$
R_{ij}=1
$$

when $i$ and $j$ lie in different components.

Disconnected matroids can therefore create a large artificial spike at $1$. Connected matroids should be analyzed separately.

### Series and parallel elements

Parallel pairs can produce

$$
b_{11}=0,
$$

while series pairs can produce

$$
b_{00}=0.
$$

Such pairs have ratio zero and log-ratio $-\infty$. Simple and cosimple matroids should therefore be analyzed separately from the full population.

### Duality

The basis table is transformed under duality by exchanging the diagonal entries and exchanging the off-diagonal entries. Therefore,

$$
R_{ij}(M)
=
R_{ij}(M^*),
$$

and hence

$$
\overline{\alpha}(M)
=
\overline{\alpha}(M^*).
$$

It would be useful to report both:

- Raw statistics over all isomorphism classes.
- Statistics after identifying matroids with their duals.

### Maximum-over-pairs bias

The value $\overline{\alpha}(M)$ is a maximum over as many as

$$
\binom n2
$$

pairs. It therefore has a built-in dependence on ground-set size.

Comparisons across different values of $n$ should include pair-level quantiles and positive-pair proportions, not only the maximum.

### Dependence among pairs

Element pairs from the same matroid are not independent statistical observations.

For random experiments, uncertainty estimates should resample entire matroids rather than individual element pairs. In particular, bootstrap procedures should use the matroid as the sampling unit.

## Suggested data schema

The `matroids` table contains one compact row per census class or random draw:

```text
matroid_id
source
collection
sample_model
seed
field_size
n
rank
corank
num_bases
basis_density
simple
cosimple
connected
three_connected
paving
sparse_paving
automorphism_group_size
alpha1_numerator
alpha1_denominator
alpha1_float
second_ratio
maximizing_pair_count
positive_pair_fraction
pair_ratio_quantiles
positive_pair_graph_summaries
basis_revlex_encoding
```

The `pair_ratio_aggregates` table contains exact population-level frequencies:

```text
run_id
simple
ratio_numerator
ratio_denominator
pair_count
census_weighted_pair_count
equal_matroid_weight
maximizer_count
```

The `selected_matroids` table records why a detailed example was chosen. The
`selected_pairs` table contains the following fields only for those matroids:

```text
matroid_id
element_i
element_j
b00
b01
b10
b11
ratio_numerator
ratio_denominator
ratio_float
log_ratio
yules_q
covariance
pearson_correlation
p_i
p_j
joint_inclusion_probability
minimum_cell_count
pair_orbit
same_element_orbit
clone_pair
smallest_common_circuit
smallest_common_cocircuit
```

Exact ratios should be stored as integer numerators and denominators. Comparisons should use exact integer cross-multiplication, preferably with `BigInt`. Floating-point versions should be used only for numerical summaries and visualization.

## Initial scientific question

A strong initial organizing question would be:

> Across complete small-matroid censuses and several explicitly defined random-representation models, how frequently does positive correlation occur, is it usually localized to a special pair, and which structural features distinguish the positive tail?

This is broader than another record search, while still making every matroid satisfying

$$
\overline{\alpha}(M)
>
\frac{100}{81}
$$

immediately visible.

## basis density vs. $\overline{\alpha}$ ?

Yes—but with an important qualification: the negative relationship is strong overall and within every GF(3), GF(5), and GF(7) ensemble, but it is not universal within GF(2).

I used the report population: connected matroids with $\overline{\alpha}>0$.

## Quantitative results

| Measure | Rank 4 | Rank 5 |
|---|---:|---:|
| Included observations | 685,729 | 759,543 |
| Pooled Pearson correlation | −0.807 | −0.837 |
| Pooled Spearman correlation | −0.882 | −0.882 |
| Pearson correlation of the eight ensemble means | −0.963 | −0.971 |
| Pearson after removing field/mode means | −0.541 | −0.517 |
| Spearman after removing field/mode means | −0.619 | −0.566 |
| Fixed-cell change in $\overline{\alpha}$ per $+0.1$ density | −0.0456 | −0.0396 |

Thus basis density alone explains about 65% and 70% of the raw linear variation in $\overline{\alpha}$ for ranks 4 and 5, respectively. Some of that is the between-field effect: larger fields produce denser matroids and smaller ratios. But the relationship remains moderately strong after controlling for field and replacement mode.

Here are the within-ensemble correlations, reported as Pearson/Spearman:

| Ensemble | Rank 4 | Rank 5 |
|---|---:|---:|
| GF(2), without replacement | −0.966 / −1.000 | −0.071 / +0.171 |
| GF(2), with replacement | +0.034 / +0.410 | +0.146 / +0.285 |
| GF(3), without replacement | −0.598 / −0.659 | −0.539 / −0.553 |
| GF(3), with replacement | −0.445 / −0.452 | −0.437 / −0.431 |
| GF(5), without replacement | −0.763 / −0.802 | −0.755 / −0.809 |
| GF(5), with replacement | −0.689 / −0.741 | −0.721 / −0.801 |
| GF(7), without replacement | −0.813 / −0.840 | −0.812 / −0.859 |
| GF(7), with replacement | −0.767 / −0.830 | −0.795 / −0.862 |

The five-seed Pearson ranges are narrow and preserve these signs, so the pattern is not Monte Carlo noise.

As a more direct effect-size comparison: in every GF(3), GF(5), and GF(7) cell, the highest-density quintile has a mean $\overline{\alpha}$ between 0.065 and 0.135 lower than the lowest-density quintile.

The GF(2) exceptions are real. Their density levels are highly discrete and the dependence is nonmonotone—particularly for rank 5—so the pooled negative trend should not be interpreted as a theorem.

## Why one expects a negative relationship

Let

$$
D(M)=\frac{|\mathcal B(M)|}{\binom nr}
$$

be the basis density. For a pair $i,j$, write $b_{ab}$ for the number of bases in which the inclusion indicators of $i,j$ equal $a,b$. Then

$$
R_{ij}=\frac{b_{11}b_{00}}{b_{10}b_{01}},
\qquad
\overline{\alpha}=\max_{i\ne j}R_{ij}.
$$

For the uniform matroid $U_{r,n}$, every $r$-subset is a basis, and

$$
b_{11}=\binom{n-2}{r-2},
\qquad
b_{10}=b_{01}=\binom{n-2}{r-1},
\qquad
b_{00}=\binom{n-2}{r}.
$$

Consequently,

$$
R_{ij}(U_{r,n})
=
\frac{(r-1)(n-r-1)}{r(n-r)}
<1.
$$

For the present cases, this baseline is

$$
R_{ij}(U_{4,10})=\frac58,
\qquad
R_{ij}(U_{5,10})=\frac{16}{25}.
$$

This is the ordinary negative dependence caused by selecting exactly $r$ elements: including one element leaves fewer available positions for another.

Now regard a nonuniform matroid as deleting nonbases from the four uniform-matroid cells. Write

$$
b_{ab}=u_{ab}-\delta_{ab},
$$

where $u_{ab}$ is the corresponding uniform count. To first order,

$$
\log R_{ij}
\approx
\log R_{ij}(U_{r,n})
-\frac{\delta_{11}}{u_{11}}
-\frac{\delta_{00}}{u_{00}}
+\frac{\delta_{10}}{u_{10}}
+\frac{\delta_{01}}{u_{01}}.
$$

This identifies the mechanism:

- Missing bases in the “both” or “neither” cells lower $R_{ij}$.
- Missing bases in the two “exactly one” cells raise $R_{ij}$.
- Lower basis density permits more missing bases and more uneven cell depletion.
- Because $\overline{\alpha}$ is a maximum, it selects the pair whose missing bases are most concentrated in the two denominator cells.

Dense matroids are therefore close to the negatively associated uniform matroid, while sparser matroids have more circuits, hyperplanes, parallel structure, and near-separations that can deplete the mixed cells asymmetrically.

The GF(2) exceptions also fit this heuristic. Density alone records the total number of missing bases, not where they occur. For example, parallel elements reduce density but have $b_{11}=0$ for their own pair, giving ratio zero rather than a large positive ratio. Binary representability also allows only a comparatively discrete collection of circuit patterns. Thus low density creates the opportunity for large $\overline{\alpha}$, but does not force it.

## Non-sparse-paving sensitivity check

Restricting further to non-sparse-paving matroids does not remove the negative
basis-density association. In the exact $n=9$, rank-$4$ census, the 75,898
connected, positive-$\overline{\alpha}$, non-sparse-paving classes have

$$
r=-0.6749,
\qquad
\rho=-0.6042.
$$

These are somewhat weaker than the full-population values $-0.7232$ and
$-0.6492$, respectively, but remain substantial population-level
associations. No $p$-value is attached to this census statement.

For the $n=10$ finite-field samples, every random $\operatorname{GF}(3)$,
$\operatorname{GF}(5)$, and $\operatorname{GF}(7)$ ensemble remains negative.
The within-ensemble Pearson ranges are

| Field | Rank 4 | Rank 5 |
|---|---:|---:|
| $\operatorname{GF}(3)$ | $-0.598$ to $-0.445$ | $-0.539$ to $-0.437$ |
| $\operatorname{GF}(5)$ | $-0.762$ to $-0.688$ | $-0.755$ to $-0.721$ |
| $\operatorname{GF}(7)$ | $-0.803$ to $-0.758$ | $-0.806$ to $-0.789$ |

All corresponding Spearman correlations are also negative. A 0.1 increase in
basis density is associated with a fitted decrease in $\overline{\alpha}$ between
$0.025$ and $0.102$ in rank 4 and between $0.023$ and $0.085$ in rank 5.
All of these random-sample tests have two-sided $p<10^{-15}$.

The binary exceptions persist. In rank 4, the replacement ensemble has
Pearson $r=0.034$ but Spearman $\rho=0.410$. In rank 5, the no-replacement
ensemble has $r=-0.071$ but $\rho=0.171$, while the replacement ensemble has
$r=0.146$ and $\rho=0.285$. These sign differences are evidence of discrete,
nonlinear, and nonmonotone structure rather than a universal density theorem.
The very small $p$-values in such enormous samples do not make these weak
Pearson effects scientifically large.

## Sparse-paving-only sensitivity check

The prediction that the negative association becomes stronger among sparse
paving matroids is false in the available data. The exact $n=9$, rank-$4$
census contains 113,063 connected, positive-$\overline{\alpha}$ sparse paving classes,
but their coefficients are only

$$
r=-0.1142,
\qquad
\rho=-0.1537.
$$

For comparison, the non-sparse-paving classes have

$$
r=-0.6749,
\qquad
\rho=-0.6042.
$$

Thus the negative association is much weaker, not stronger, in the sparse
paving census.

The $n=10$ finite-field samples give the same qualitative answer. No sparse
paving observations occur in the stored $\operatorname{GF}(2)$ or
$\operatorname{GF}(3)$ cells. In the nonempty cells the Pearson correlations
are:

| Ensemble | Rank 4 | Rank 5 |
|---|---:|---:|
| $\operatorname{GF}(5)$, no replacement | $-0.078$ | $-0.163$ |
| $\operatorname{GF}(5)$, with replacement | $+0.379$ | $-0.190$ |
| $\operatorname{GF}(7)$, no replacement | $+0.076$ | $+0.010$ |
| $\operatorname{GF}(7)$, with replacement | $+0.043$ | $-0.007$ |

Most effects are weak, and several are positive. The rank-$4$
$\operatorname{GF}(5)$ replacement sample is significantly positive, with
$r=0.379$ and a 95% interval from $0.151$ to $0.569$, although it contains
only 66 sparse paving observations. Rank-$5$ $\operatorname{GF}(7)$ Pearson
correlations are essentially zero; their positive Spearman correlations show
that the few discrete density levels can still carry a weak monotone pattern.

There is also a structural explanation. If $M$ is rank $r$ and sparse paving,
let $\mathcal H$ be its circuit-hyperplanes and let

$$
m=|\mathcal H|.
$$

Every rank-sized subset outside $\mathcal H$ is a basis, so

$$
d_{\mathcal B}(M)
=
1-
\frac{m}{\binom nr}.
$$

Basis density therefore remembers only the number of circuit-hyperplanes. For
a pair $i,j$, let $h_{ab}$ be the number of circuit-hyperplanes whose
incidence pattern with $i,j$ is $ab$, and let $u_{ab}$ be the corresponding
uniform-matroid cell count. Then

$$
R_{ij}
=
\frac{(u_{11}-h_{11})(u_{00}-h_{00})}
{(u_{10}-h_{10})(u_{01}-h_{01})}.
$$

The total

$$
m=h_{00}+h_{01}+h_{10}+h_{11}
$$

does not determine this ratio. Circuit-hyperplanes in the mixed cells raise
$R_{ij}$, whereas circuit-hyperplanes in the both-or-neither cells lower it.
The stable-set condition on $\mathcal H$ constrains these placements but does
not reduce them to the single number $m$. Consequently, basis density is a
particularly lossy structural statistic inside the sparse paving class. The
narrow density ranges and many ties further attenuate ordinary correlation.

## density / $\overline{\alpha}$ joint invariant

Your suspicion was not supported: sparse-paving matroids show a much weaker and sometimes positive density–\(\overline{\alpha}\) association. That suggests studying an invariant which rewards simultaneously high correlation and high basis density, rather than treating their empirical correlation as universal.

## Density-adjusted correlation excess

Let \(M\) have rank \(r\) on \(n\) elements, with \(2\leq r\leq n-2\), and define

$$
d_{\mathcal B}(M)
=
\frac{|\mathcal B(M)|}{\binom nr}.
$$

The uniform-matroid correlation ratio is

$$
c_{r,n}
=
\overline{\alpha}(U_{r,n})
=
\frac{(r-1)(n-r-1)}{r(n-r)}.
$$

I propose the invariant

$$
\Theta(M)
=
d_{\mathcal B}(M)
\frac{\overline{\alpha}(M)-c_{r,n}}{1-c_{r,n}}.
$$

Since

$$
1-c_{r,n}
=
\frac{n-1}{r(n-r)},
$$

it can also be written

$$
\Theta(M)
=
\frac{|\mathcal B(M)|}{\binom nr}
\frac{
r(n-r)\overline{\alpha}(M)
-
(r-1)(n-r-1)
}{
n-1
}.
$$

I would call this the density-adjusted correlation excess. The inner factor measures correlation above the uniform-matroid baseline, normalized so that \(\overline{\alpha}=1\) has value \(1\). Multiplication by basis density discounts correlation obtained only after sacrificing many bases.

## First properties

1. Exactness and duality

\(\Theta(M)\) is rational whenever \(\overline{\alpha}(M)\) is stored as an exact rational. It is invariant under isomorphism and matroid duality because

$$
d_{\mathcal B}(M^*)=d_{\mathcal B}(M),
\qquad
\overline{\alpha}(M^*)=\overline{\alpha}(M),
\qquad
c_{n-r,n}=c_{r,n}.
$$

2. Natural calibration

For the uniform matroid,

$$
\Theta(U_{r,n})=0.
$$

More generally,

$$
\operatorname{sign}\Theta(M)
=
\operatorname{sign}\bigl(\overline{\alpha}(M)-c_{r,n}\bigr).
$$

At the positive-correlation threshold,

$$
\overline{\alpha}(M)=1
\quad\Longrightarrow\quad
\Theta(M)=d_{\mathcal B}(M).
$$

Indeed,

$$
\Theta(M)-d_{\mathcal B}(M)
=
d_{\mathcal B}(M)
\frac{\overline{\alpha}(M)-1}{1-c_{r,n}}.
$$

Consequently,

$$
\Theta(M)>d_{\mathcal B}(M)
\quad\Longleftrightarrow\quad
\overline{\alpha}(M)>1.
$$

3. A sparse-paving ceiling

Because sparse paving matroids satisfy \(\overline{\alpha}(M)\leq1\),

$$
\Theta(M)
\leq
d_{\mathcal B}(M)
\leq1.
$$

Thus

$$
\Theta(M)>1
$$

simultaneously certifies that \(M\) is not sparse paving and that \(\overline{\alpha}(M)>1\). This gives the value \(1\) a genuine structural meaning.

4. Pair-design interpretation

If the bases form a \(2\)-design, every element has inclusion probability \(r/n\) and every pair has the uniform joint-inclusion probability. Therefore

$$
\overline{\alpha}(M)=c_{r,n}
\quad\text{and}\quad
\Theta(M)=0.
$$

For an element-transitive matroid one can prove

$$
\overline{\alpha}(M)\geq c_{r,n}.
$$

Indeed, all element marginals equal \(r/n\), while the average pair-inclusion probability is

$$
\frac{\binom r2}{\binom n2}.
$$

Some pair has at least this joint probability, and its odds ratio is at least \(c_{r,n}\). Equality forces all pair-inclusion probabilities to equal their average, giving a \(2\)-design at the basis level.

Every connected observation currently stored in the \(n=8,9,10\) experiments satisfies \(\Theta(M)\geq0\). This suggests the broader question:

$$
\overline{\alpha}(M)
\stackrel{?}{\geq}
\overline{\alpha}(U_{r,n})
$$

for every connected rank-\(r\), \(n\)-element matroid.

5. Sparse paving interpretation

If a sparse paving matroid has \(m\) circuit-hyperplanes, then

$$
d_{\mathcal B}(M)
=
1-\frac{m}{\binom nr}.
$$

Hence

$$
\Theta(M)
=
\left(
1-\frac{m}{\binom nr}
\right)
\frac{\overline{\alpha}(M)-c_{r,n}}{1-c_{r,n}}.
$$

The first factor records how many circuit-hyperplanes there are. The second records how they are arranged around the pair maximizing \(\overline{\alpha}\). Thus \(\Theta\) retains precisely the distinction that basis density alone loses in the sparse-paving analysis.

6. Connectedness matters

For a direct sum, cross-component pairs have ratio \(1\), while the total basis density includes a substantial binomial normalization factor. Therefore \(\Theta\) is neither additive nor multiplicative under direct sums. It is best studied first on connected matroids, matching the reports’ analysis population.

## First observed extremal example

For \(n=10,r=5\),

$$
c_{5,10}=\frac{16}{25}.
$$

The current data contain non-sparse-paving examples with

$$
d_{\mathcal B}(M)=\frac{31}{42},
\qquad
\overline{\alpha}(M)=\frac{256}{225}.
$$

For these,

$$
\Theta(M)
=
\frac{1736}{1701}
\approx1.02058.
$$

They therefore cross the structurally meaningful threshold \(\Theta=1\). By contrast, the largest observed sparse-paving scores are approximately \(0.75\) in the \(n=9,r=4\) census and \(0.40\) in the rank-10 samples.

A useful extension would be the family

$$
\Theta_\lambda(M)
=
d_{\mathcal B}(M)^\lambda
\frac{\overline{\alpha}(M)-c_{r,n}}{1-c_{r,n}},
\qquad
\lambda\geq0.
$$

Here \(\lambda\) controls how strongly high density is rewarded. The choice \(\lambda=1\) is the simplest canonical starting point, while varying \(\lambda\) would trace the density–correlation Pareto frontier.

## why not just density*$\overline{\alpha}$?

“Better” here means better aligned with our scientific question: rewarding unusually large positive correlation while penalizing the loss of bases. If the goal were simply a globally monotone product of two nonnegative numbers, then \(d_{\mathcal B}\overline{\alpha}\) would be simpler and perfectly defensible.

Write

$$
d=d_{\mathcal B}(M),
\qquad
c=c_{r,n}=\overline{\alpha}(U_{r,n}).
$$

Then

$$
\Theta(M)
=
d\frac{\overline{\alpha}-c}{1-c}
=
\frac{d\overline{\alpha}-cd}{1-c}.
$$

Thus \(\Theta\) is precisely the product \(d\overline{\alpha}\), corrected by the uniform-matroid baseline \(cd\), and rescaled by the gap from uniform dependence to independence.

## Why baseline correction matters

The uniform matroid already has a nonzero correlation ratio:

$$
\overline{\alpha}(U_{r,n})
=
c_{r,n}
=
\frac{(r-1)(n-r-1)}{r(n-r)}
<1.
$$

This value represents the unavoidable negative dependence caused by choosing exactly \(r\) elements. It is not an exceptional correlation phenomenon.

For the product

$$
P(M)=d(M)\overline{\alpha}(M),
$$

the uniform matroid has

$$
P(U_{r,n})=c_{r,n}.
$$

Moreover, \(c_{r,n}\) varies with \(n\) and \(r\). For example,

$$
c_{2,10}=\frac{7}{16},
\qquad
c_{50,100}=\frac{2401}{2500}.
$$

Thus large balanced uniform matroids automatically receive product scores near \(1\), despite having no correlation excess beyond the fixed-size sampling baseline.

By contrast,

$$
\Theta(U_{r,n})=0
$$

for every \(n,r\). This makes scores much more comparable across ranks and ground-set sizes.

## The uniform-to-independence scale

The normalized factor

$$
\frac{\overline{\alpha}-c}{1-c}
$$

has a direct interpretation:

- It equals \(0\) at the uniform-matroid baseline.
- It equals \(1\) at the independence threshold \(\overline{\alpha}=1\).
- It exceeds \(1\) exactly when \(\overline{\alpha}>1\).

Multiplying by \(d\) then discounts that correlation excess according to how many bases remain.

The raw product does not distinguish “large because the baseline is large” from “large because the matroid has moved substantially toward positive correlation.”

## A ranking example

Consider \(n=10,r=5\), for which

$$
c_{5,10}=\frac{16}{25}=0.64.
$$

Suppose one matroid has

$$
d=0.95,
\qquad
\overline{\alpha}=0.90.
$$

It has no positively correlated pair, but its product score is

$$
d\overline{\alpha}=0.855.
$$

One of our actual examples has

$$
d=\frac{31}{42}\approx0.7381,
\qquad
\overline{\alpha}=\frac{256}{225}\approx1.1378.
$$

Its product is only

$$
d\overline{\alpha}\approx0.840,
$$

so the raw product ranks the first, negatively correlated matroid higher.

The proposed invariant instead gives

$$
\Theta_{\mathrm{first}}
=
0.95\frac{0.90-0.64}{1-0.64}
\approx0.686,
$$

whereas the actual positively correlated example has

$$
\Theta_{\mathrm{second}}
=
\frac{1736}{1701}
\approx1.021.
$$

That ordering better reflects our interest in strong positive correlation achieved without an excessive loss of bases.

## Structural threshold

Both invariants satisfy

$$
\overline{\alpha}=1
\quad\Longrightarrow\quad
P=\Theta=d.
$$

Both also obey the sparse-paving bound

$$
P\leq d\leq1,
\qquad
\Theta\leq d\leq1.
$$

So either \(P>1\) or \(\Theta>1\) certifies a non-sparse-paving matroid with \(\overline{\alpha}>1\). But the two thresholds have different sensitivity.

For the product,

$$
P>1
\quad\Longleftrightarrow\quad
\overline{\alpha}>\frac1d.
$$

For \(\Theta\),

$$
\Theta>1
\quad\Longleftrightarrow\quad
\overline{\alpha}
>
1+
(1-c)\frac{1-d}{d}.
$$

Since \(1-c<1\), the latter requires less correlation excess. It compensates only for the part of the density loss measured relative to the uniform-to-independence gap. That is why our rank-\(5\) example crosses \(\Theta=1\) even though its raw product is below \(1\).

## Pair-design interpretation

If the bases of \(M\) form a \(2\)-design, then every pair behaves like a pair in the uniform matroid:

$$
\overline{\alpha}(M)=c_{r,n}.
$$

Consequently,

$$
\Theta(M)=0
$$

regardless of the basis density.

The raw product instead gives

$$
P(M)=d(M)c_{r,n},
$$

so it varies among matroids having the same pairwise correlation structure. If the intended quantity is correlation excess, that dependence on density alone is noise rather than signal.

## Honest disadvantages of \(\Theta\)

The product has some genuine advantages:

| Property | \(d\overline{\alpha}\) | \(\Theta\) |
|---|---:|---:|
| Simpler | Yes | No |
| Always nonnegative | Yes | Not necessarily |
| Increasing in both inputs everywhere | Yes | Only automatically when \(\overline{\alpha}\geq c\) |
| Uniform baseline removed | No | Yes |
| Comparable across ranks | Poorly | Better |
| Zero for pair-design behavior | No | Yes |
| Sensitive sparse-paving separator | Weaker | Stronger |

In particular, if examples with

$$
\overline{\alpha}(M)<c_{r,n}
$$

exist, then \(\Theta(M)\) becomes negative. Increasing their density makes the score more negative, so \(\Theta\) is not globally Pareto-monotone. The raw product does not have that problem.

Interestingly, none of the connected observations in the current \(n=8,9,10\) data has \(\overline{\alpha}<c_{r,n}\). Determining whether this is always true is therefore an important preliminary question.

## Recommendation

I would retain the pair

$$
\bigl(d_{\mathcal B}(M),\overline{\alpha}(M)\bigr)
$$

as the primary data and use the Pareto frontier for serious extremal comparisons. No one-dimensional score can completely encode both coordinates.

As a secondary ranking invariant:

- Use \(d\overline{\alpha}\) when one wants the simplest globally monotone score.
- Use \(\Theta\) when one wants density-efficient correlation above the uniform-matroid baseline.

The second objective is much closer to the phenomenon our experiments are trying to isolate.