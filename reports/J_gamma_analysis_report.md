# Analysis of the density-discounted score $\mathcal J_\gamma$

## Reader's guide: no statistics background is assumed

The report asks a two-objective question about a matroid: can it have both many bases and a large unweighted correlation ratio? Everything needed to read the answer is explained below. The information-theoretic interpretation is optional; none of the conclusions requires prior knowledge of probability, statistics, optimization, or information theory.

There are two unrelated uses of the word *correlation* in this report. $\overline{\alpha}(M)$ is the matroid invariant being studied. A *Spearman correlation coefficient* is only a number used later to summarize how two matroid invariants vary across a collection of matroids. To reduce confusion, the latter is usually called an *association* below.

### The two matroid quantities

Let $M$ have rank $r$ on an $n$-element ground set $E$. Its **basis density** is the fraction of all $r$-subsets that are bases:

$$
D=d_B(M)=\frac{|\mathcal B(M)|}{\binom nr}.
$$

Thus $0<D\le1$. The value $D=1$ occurs exactly for the uniform matroid. For example, a rank-4 matroid on 8 elements with 48 bases has $D=48/\binom84=48/70$.

To define $\overline{\alpha}$, choose a basis uniformly from $\mathcal B(M)$. For distinct elements $i,j$, let $b_{ab}$ be the number of bases for which the indicator of $i$ is $a$ and the indicator of $j$ is $b$, where $a,b\in\{0,1\}$. The pair ratio is

$$
Q_{ij}=\frac{b_{00}b_{11}}{b_{01}b_{10}}.
$$

The unweighted correlation ratio is the worst, meaning largest, eligible pair ratio:

$$
\overline{\alpha}(M)=\max_{i\ne j}Q_{ij}.
$$

The implementation excludes loops and coloops from pair eligibility. This qualification is immaterial for the actual report population because every analyzed matroid is connected and therefore has neither loops nor coloops. The maximum matters: a single exceptional element pair can determine $\overline{\alpha}$ even if most pair ratios are much smaller.

For the uniform matroid the pair ratio is the same for every pair, namely

$$
c_{r,n}=\overline{\alpha}(U_{r,n})
=\frac{(r-1)(n-r-1)}{r(n-r)}.
$$

### Exactly which matroids are included?

Only **connected matroids with $\overline{\alpha}>0$** are used in every table, coefficient, frontier, and figure. The database query also redundantly requires `loops_count = 0` and `coloops_count = 0`, even though connectedness already implies both conditions.

Here connected has its usual matroid meaning. If $A$ is a nonempty proper subset of $E$, put

$$
\lambda_M(A)
=r_M(A)+r_M(E\setminus A)-r(M).
$$

The matroid is connected exactly when $\lambda_M(A)>0$ for every such $A$. The code checks this condition directly from the rank function.

This proves that loops and coloops cannot occur in the analyzed population. If $e$ is a loop, then $r(\{e\})=0$ and $r(E\setminus\{e\})=r(M)$, so $\lambda_M(\{e\})=0$. If $e$ is a coloop, then $r(\{e\})=1$ and $r(E\setminus\{e\})=r(M)-1$, again giving zero. The converse is false: having no loops or coloops does not by itself imply connectedness, so the filter is stronger than merely deleting those elements.

Connected matroids may still have parallel or series elements; the report does not impose simplicity or cosimplicity. Disconnected matroids are excluded because adjoining direct-sum components—especially loops or coloops—can change basis density without representing the density–correlation tradeoff we want to study. The extra condition $\overline{\alpha}>0$ is needed because the logarithms used later are not defined at zero.

Whenever a table says **all**, it therefore means all connected, positive-$\overline{\alpha}$ observations in that particular source ensemble, not every matroid stored in the database.

### What the score $\mathcal J_\gamma$ means

The joint score is

$$
\mathcal J_\gamma(M)
=
\frac{\overline{\alpha}(M)}{c_{r,n}}D^\gamma.
$$

The first factor compares $M$ with the uniform matroid's correlation ratio. The second factor penalizes missing bases. Their product equals 1 for the uniform matroid.

- $\gamma=1/2$ is relatively forgiving of missing bases.
- With $\gamma=1$, a 1% density loss requires approximately a 1% increase in $\overline{\alpha}$ to compensate.
- $\gamma=2$ penalizes missing bases more severely.

A value $\mathcal J_\gamma>1$ means that, under this chosen exchange rate, the increase in relative correlation more than pays for the missing bases. It does **not** mean $\overline{\alpha}>1$, and it does not declare one choice of $\gamma$ to be canonical.

### A short reading path

For the main mathematical message, read this guide, the next summary, the sections on Pareto geometry and the high-density cap, and then the cross-source findings. The long rank-by-rank tables are supporting evidence. Their repeated column names are decoded in the statistics glossary before the figures.

### Conclusions in plain language

- Among matroids extremely close to uniform, larger correlation ratios often come with more missing bases. Much of the striking large-field pattern lies in this region, where the high-density theorem already predicts a tradeoff.
- After that region is removed, the direction and strength of the pattern depend on the finite field and generation rule. Binary samples sometimes behave in the opposite direction. The data therefore do not suggest one universal monotonicity statement for all matroids.
- In the moderate-density region, one full power of density usually penalizes missing bases more strongly than is needed merely to remove the observed trend. Two powers are extremely severe: almost nothing there beats the uniform score.
- No single choice of $\gamma$ records every reasonable compromise between density and $\overline{\alpha}$. Many observed profiles are not worse in both quantities than any competitor, yet they never maximize $\mathcal J_\gamma$ for any $\gamma$.
- Large $\mathcal J_1$ values are more often controlled by an exceptional element pair than by uniformly large pair ratios. This is a warning to inspect the pair distribution as well as its maximum $\overline{\alpha}$.

## Main findings, with the technical numbers

- The outside-cap sensitivity population contains 1143112 observations. 31 ensemble cells retain at least 30 observations, so no additional sampling was needed. The ICARM rank-5 and Johnson cells contribute no moderate-density observations under their present sampling laws.
- The strong large-field tradeoff is largely a high-density effect. For **n12_r6 / GF(7) random, with replacement**, Spearman $\rho_{\mathrm S}(C,R)$ falls from +0.870 to +0.028. Across adequately populated cells, 26 of 31 remain positive; the five negative cells are all low-field finite-field ensembles.
- Outside the cap, $\mathcal J_1$ is positively associated with density in 30 of 31 adequately populated cells, and 6 cells switch from a negative full-data association to a positive one. Thus a unit density exponent usually overcompensates the residual moderate-density reward trend.
- Among the 1143112 outside-cap observations, exactly 1 has $\mathcal J_2>1$: one exact rank-3, 9-element class at the cap boundary with $d_B=3/4$ and $\overline{\alpha}=1$. The stronger penalty is therefore extremely selective away from high density.
- The deletion inequality has 0 numerical violations and is exactly sharp: observed one-deletion sparse-paving profiles attain $E_{\mathrm{del}}=1$. Typical efficiencies are much smaller, so sharpness is an extremal rather than a typical phenomenon.
- Only 200 of 566 observed Pareto profiles (35.3%) are supported hull vertices. Also, the top-$\mathcal J_1$ decile has a lower median $Q_{0.9}/\overline{\alpha}$ than its full cell in all 37 cells, showing systematic worst-pair localization (partly expected because $\overline{\alpha}$ itself is the selected maximum).

## Definitions and mathematical calibration

For a rank-$r$ matroid on $n$ elements, set

$$
D=d_B(M),
\qquad
c_{r,n}=\overline{\alpha}(U_{r,n})
=\frac{(r-1)(n-r-1)}{r(n-r)}.
$$

The score studied here is

$$
\mathcal J_\gamma(M)
=
\frac{\overline{\alpha}(M)}{c_{r,n}}D^\gamma,
\qquad \gamma\ge0.
$$

In logarithmic coordinates

$$
C=-\log D,
\qquad
R=\log\frac{\overline{\alpha}}{c_{r,n}},
\qquad
\log\mathcal J_\gamma=R-\gamma C.
$$

### Why logarithms are used

No information theory is needed to use these coordinates. The natural logarithm is an order-preserving change of scale: it turns products into sums. The only facts needed to read the plots are:

- $C=0$ for the uniform matroid, and $C$ becomes larger as basis density becomes smaller. For example, $D=1,1/2,1/4$ give $C=0,\log2,2\log2$.
- $R=0$ when $\overline{\alpha}$ equals the uniform value $c_{r,n}$; $R>0$ means larger than the uniform value and $R<0$ means smaller.
- Maximizing $\mathcal J_\gamma$ is exactly the same as maximizing $\log\mathcal J_\gamma=R-\gamma C$.

For readers interested in the optional information-theoretic interpretation, if $\nu$ is uniform on all $r$-subsets and $\mu_M$ is uniform on the bases of $M$, then

$$
D_{\mathrm{KL}}(\mu_M\Vert\nu)
=\log\frac{\binom nr}{|\mathcal B(M)|}
=-\log D=C.
$$

Thus $C$ is exactly the support-entropy cost of restricting the uniform law to the basis set, rather than an ad hoc transformation. In elementary terms, there are $\binom nr$ possible $r$-sets but only $|\mathcal B(M)|$ allowed bases, and $C$ is the logarithm of the ratio of those two numbers. The symbol $D_{\mathrm{KL}}$ is just the standard name for this measure of discrepancy between the two uniform choices. Basis density, $\overline{\alpha}$, and $c_{r,n}$ are invariant under matroid duality, so $\mathcal J_\gamma$ and $\gamma_*$ are duality invariant as well.

A $1\%$ density loss therefore requires approximately a $\gamma\%$ increase in $\overline{\alpha}$ to hold the score fixed. The normalization changes comparisons across ranks but, within a fixed $(r,n)$, it leaves the ordering identical to $d_B^\gamma\overline{\alpha}$.

The relationship with the previously adopted excess score is exact:

$$
\Theta_\gamma
=D^\gamma\frac{\overline{\alpha}-c_{r,n}}{1-c_{r,n}},
\qquad
\mathcal J_\gamma
=D^\gamma+\frac{1-c_{r,n}}{c_{r,n}}\Theta_\gamma.
$$

Thus $\mathcal J_\gamma$ deliberately rewards baseline density, whereas $\Theta_\gamma$ isolates excess correlation. A score above one means that a matroid beats the uniform matroid under the chosen exchange rate; it does not imply $\overline{\alpha}>1$.

For the rank-6, 12-element $100/81$ benchmark, $D=57/77$ and $\overline{\alpha}/c_{6,12}=16/9$. Hence

$$
\mathcal J_1=\frac{304}{231}\approx1.3160,
\qquad
\mathcal J_2=\frac{5776}{5929}\approx0.9742,
\qquad
\gamma_*
=\frac{\log(16/9)}{\log(77/57)}\approx1.9131.
$$

It therefore beats the uniform reference at $\gamma=1$ but not at $\gamma=2$, a concrete reminder that the density exchange rate is substantive.

### Pareto geometry

**Pareto** terminology is just a way to discuss two goals without first deciding how much one goal is worth relative to the other. Here the goals are to make both $D$ and $\overline{\alpha}$ large.

| Toy profile | Density $D$ | $\overline{\alpha}$ |
|---|---:|---:|
| A | 0.80 | 1.05 |
| B | 0.70 | 1.20 |
| C | 0.60 | 1.00 |

Profile A is unambiguously preferable to C for these two objectives: it has both higher density and higher $\overline{\alpha}$. We say that A **dominates** C. Neither A nor B dominates the other, because A has higher density while B has higher $\overline{\alpha}$. The **Pareto frontier** consists of the profiles that are not dominated by any observed profile; in this toy example it is $\{A,B\}$. Calling a profile Pareto efficient does not say that it is best. It says only that improving one objective requires sacrificing the other among the profiles observed.

The report applies this comparison to exact profiles $(D,\overline{\alpha})$. Combining identical profiles first prevents repeated samples from changing which profiles are on the frontier. In $(C,R)$ coordinates, the preferred direction is up and to the left: smaller $C$ means greater density, while larger $R$ means greater relative correlation.

Fixing $\gamma$ converts the two goals into the single score $R-\gamma C$. Geometrically, draw a line of slope $\gamma$ and slide it upward until it last touches an observed point. A touched profile maximizes $\mathcal J_\gamma$ for that exponent and is called **supported**. Some Pareto points sit in an inward bend below the straight segment joining two other frontier points. They are still nondominated, but no choice of $\gamma$ makes them the maximizer. The boundary formed by the supported points is what the technical phrase **upper concave hull** means here.

Consequently, the Pareto count answers “how many observed tradeoffs are unambiguously viable?”, while the supported count answers “how many can be selected by some score $\mathcal J_\gamma$?” Lines in the figures merely connect discrete observed frontier points; they do not claim that intermediate matroids exist.

### The high-density deletion cap

The very-high-density region is treated separately because there is already an elementary theorem forcing density and correlation to trade off there. Removing that region lets us ask whether the empirical pattern persists where this theorem gives no finite restriction.

Put

$$
v_{r,n}=\frac{r(n-r)}{n(n-1)},
\qquad
D_{\mathrm{cap}}=1-v_{r,n}.
$$

For a fixed ordered choice of two elements, $v_{r,n}$ is the fraction of all $r$-subsets in one of the two mixed cells (containing exactly the specified one of the two elements). If the omitted fraction $1-D$ is smaller than this cell, simple counting prevents the pair ratio from growing arbitrarily. The condition $1-D<v_{r,n}$ is exactly $D>D_{\mathrm{cap}}$, which this report calls **high density**.

When $D>D_{\mathrm{cap}}$, the set-system argument gives

$$
R
\le
C_{\mathrm{cap}}(D)
:=-\log\left(1-\frac{1-D}{v_{r,n}}\right).
$$

The ratio $E_{\mathrm{del}}=R/C_{\mathrm{cap}}$ compares the observed relative-correlation increase with this rigorous allowance. The value 1 means equality in the bound, 0 means no increase over the uniform baseline, and a negative value means $\overline{\alpha}<c_{r,n}$. Whenever $R\ge0$, the theorem forces $0\le E_{\mathrm{del}}\le1$.

This bound is exactly sharp even within matroids. Fix an $r$-set $H$ and let $M_H$ have every $r$-set except $H$ as a basis; $H$ is its single circuit-hyperplane, so $M_H$ is sparse paving. Put

$$
B_0=\binom{n-2}{r-1}.
$$

For $i\in H$ and $j\notin H$, deleting $H$ removes one set from exactly one mixed cell of the pair table and leaves both numerator cells unchanged. Therefore

$$
\frac{\overline{\alpha}(M_H)}{c_{r,n}}
=\frac{B_0}{B_0-1}
=\frac{1}{1-(1-D)/v_{r,n}},
$$

where $1-D=1/\binom nr$ and $v_{r,n}=B_0/\binom nr$. Hence $E_{\mathrm{del}}(M_H)=1$. The observed equality cases are not numerical accidents, although most sampled high-density matroids lie well below the envelope.

The diagnostic $E_{\mathrm{del}}=R/C_{\mathrm{cap}}$ is computed only for nonuniform observations in that domain. The separate sensitivity population uses $D\le D_{\mathrm{cap}}$, precisely where this finite bound no longer applies. This cutoff is mathematical rather than a fitted quantile. The theorem constrains the feasible upper envelope; it does not determine a sampling correlation.

### The critical exponent

Rather than selecting $\gamma$ first, one can ask how severe a density penalty a particular matroid can survive. This break-even value is $\gamma_*$.

For $D<1$ and $\overline{\alpha}>c_{r,n}$,

$$
\gamma_*
=
\frac{\log(\overline{\alpha}/c_{r,n})}{\log(1/D)},
\qquad
\mathcal J_\gamma>1
\Longleftrightarrow
\gamma<\gamma_*.
$$

For example, $\gamma_*=1.5$ means that the matroid beats the uniform score for $\gamma<1.5$, ties it at $1.5$, and loses for $\gamma>1.5$. The tables include $\gamma_*$ only when $D<1$ and $\overline{\alpha}>c_{r,n}$; the uniform matroid needs no break-even exponent.

The all-data maximum is reported but should not be treated as robust: near the uniform point both the numerator and denominator are close to zero, so a very small change can produce a large quotient. This is the sense in which the maximum is numerically unstable. The outside-cap percentiles are safer summaries.

## Statistics glossary and table-reading guide

This analysis is mainly **descriptive**: it records patterns in the matroids that were enumerated or generated. A descriptive pattern is not automatically a theorem about all matroids. The exact PolyDB censuses describe their complete finite populations; the random finite-field, Johnson, and ICARM data describe their stated sampling procedures.

### Basic words

- An **observation** is one retained database row, representing one matroid or one generated configuration.
- An **ensemble** or **cell** is one source and generation rule at fixed $(n,r)$, such as rank 6 over $\mathrm{GF}(7)$ with replacement.
- A **population** is the collection about which a row of a table speaks. Here **all** and **outside cap** are two populations within each ensemble.
- A **distribution** is simply the list of possible observed values together with how often they occur.
- The **median** is a middle value after sorting: at least half the observations are no larger and at least half are no smaller.
- The **90th percentile** is a value at or above roughly 90% of the observations; only roughly the largest 10% lie above it. The 95th percentile is analogous. With many ties, the percentages need not split exactly.
- A **proportion** $P(A)$ is the fraction of observations satisfying condition $A$. For example, $P(\mathcal J_1>1)=0.20$ means 20%.
- A **range** $[a,b]$ reports the smallest and largest displayed values.
- The **top decile** means the observations in the largest 10% according to the stated score.

### Measuring association across matroids

A scatter plot places one point for each observation, with one invariant on the horizontal axis and another on the vertical axis. An upward overall ordering means that larger values of one tend to accompany larger values of the other; a downward ordering means that larger values of one tend to accompany smaller values of the other.

The report mainly summarizes this ordering with **Spearman's rank association** $\rho_{\mathrm S}$. First replace the numerical values by their positions after sorting, and then compare the two sets of positions. Its value lies between $-1$ and $1$:

- $+1$ means the two orderings agree perfectly.
- $-1$ means one ordering is exactly the reverse of the other.
- A value near 0 means there is little overall increasing or decreasing ordering. It does not rule out a curved or subgroup-dependent pattern.

Only the ordering matters, not the numerical distances between consecutive values. Equal values are ties and receive the same average rank. The word *weighted* means that a row with stored multiplicity $m$ is treated as occurring $m$ times.

A **Pearson correlation** instead measures closeness to a straight-line relationship using the actual numerical distances. Pearson values are retained in the CSV but Spearman values are emphasized in the report because these matroid distributions are discrete, tied, and often curved.

An **ordinary least-squares (OLS) line** is the straight line chosen to make the sum of the squared vertical discrepancies from the points as small as possible. The table's slope $\widehat\beta$ comes from fitting

$$
R\approx a+\widehat\beta C.
$$

For example, $\widehat\beta=0.4$ says that the fitted line rises by about 0.4 units of $R$ for one unit of $C$. It describes that ensemble; it is not a matroid invariant, a causal claim, or a proof that every point follows the line.

### Random samples and repeated seeds

A **census** contains every member of a stated finite catalogue, whereas a **sample** contains only selected or generated members. Repeating a random generator with five independent seeds gives five separate replicates. A narrow replicate range means the reported pattern did not change much when the random seed changed; it does not make the generator uniform over all matroids.

No inferential p-values are used here. Roughly, a p-value addresses how surprising a statistic would be under a chosen random null model. The data sources do not share one such model, many rows are dependent or repeated, and the variables are algebraically related. Reporting a tiny p-value from the very large row counts would therefore give a misleading impression of a theorem.

### Worst-pair robustness

Because $\overline{\alpha}$ is the maximum over pairs, it can be controlled by one unusual pair. For each matroid, $Q_{0.9}$ is the 90th percentile of all its eligible pair ratios: about 90% of the pair ratios are at most $Q_{0.9}$. Thus $Q_{0.9}/\overline{\alpha}$ is near 1 if many pairs are close to the maximum and is small if the maximizing pair is exceptional. Here **robust** means less dependent on that single maximum; it is not a claim of a formal robustness theorem.

The **empirical survival curve** of $\gamma_*$ answers a direct counting question. At horizontal value $g$, its height is the fraction of observed matroids for which $\gamma_*\ge g$, equivalently the fraction that still beats the uniform benchmark at penalty exponent $g$.

### Repeated table columns

| Column | Plain-language meaning |
|---|---|
| Primary N | Number of connected, positive-$\overline{\alpha}$ observations before the density-cap split. |
| all | The entire primary population for that ensemble. |
| outside cap | The subset with $D\le D_{\mathrm{cap}}$; the very-high-density region is removed. |
| High-density N (%) | Count and percentage with $D>D_{\mathrm{cap}}$. |
| Median / 90% / 95% / Maximum | Middle value, percentile, or largest value as defined above. |
| $P(\mathcal J_\gamma>1)$ | Fraction beating the uniform benchmark for that $\gamma$. |
| $\rho(X,Y)$ | Spearman rank association between the displayed quantities. |
| OLS slope $R$ on $C$ | Slope of the descriptive best-fit line $R\approx a+\widehat\beta C$. |
| Distinct profiles | Number of different observed pairs $(D,\overline{\alpha})$ after exact ties are combined. |
| Pareto | Number of profiles not unambiguously beaten in both density and $\overline{\alpha}$. |
| Supported vertices | Pareto profiles that maximize $\mathcal J_\gamma$ for at least one $\gamma\ge0$. |
| $E_{\mathrm{del}}$ | Observed log-reward divided by the rigorous high-density allowance: 1 saturates the bound, 0 equals the uniform baseline, and negative values are below it. |
| $\gamma_*\ N$ | Number for which the positive break-even exponent is defined and used. |
| $Q_{0.9}/\overline{\alpha}$ | Whether large pair ratios are widespread (near 1) or localized (smaller). |
| Relative alpha gap | Relative gap between the largest and second-largest eligible pair ratios. |
| Sparse-only Pareto | Pareto profiles observed only among sparse-paving matroids in that ensemble. |
| Bound violations | Number exceeding the rigorous deletion bound; it is 0 in every reported cell. |
| Replicate range | Smallest and largest result across independent random seeds. |

## Populations and statistical conventions

Every distributional calculation uses connected matroids with $\overline{\alpha}>0$, so there are no loops or coloops; the proof was given in the reader's guide. PolyDB rows are isomorphism classes and give exact finite-population descriptions, with one vote per isomorphism class. Finite-field rows are accepted labeled configurations from the stated field and replacement model, not uniform samples of matroid isomorphism classes. Johnson rows are labeled random-greedy stable sets, not uniform samples of sparse-paving matroids. ICARM rank 4 is a class-uniform simple random sample, meaning every class had the same chance to be chosen. Rank 5 is a two-stage cluster pilot: chunks were selected first and rows within chunks second, so its 12,800 rows cannot be treated as independent draws.

Associations, OLS slopes, frontiers, and score distributions are descriptive. No p-values are reported: the variables are algebraically coupled and the large row counts do not cure ensemble dependence. For finite-field and Johnson cells with multiple independent seeds, ranges across seed replicates are reported. Spearman coefficients use weighted midranks for exact ties. The OLS slope of $R$ on $C$ is a sample-dependent detrending exponent, not an intrinsic matroid invariant and not an estimate of the frontier slope.

Outside-cap rows with fewer than 30 observations are retained in coverage tables but excluded from the cross-source sign counts and substantive correlation comparisons. In particular, the current ICARM rank-4 sample has only four such rows, while ICARM rank 5 and all four Johnson samples have none. Targeting additional low-density ICARM or Johnson observations would change the sampling law and could not be interpreted as an extension of the present probability sample. The existing sources already supply 1143112 outside-cap observations across 31 adequately populated cells, so no new data were generated for this report.

No synthetic weight combines the class-uniform catalogues, labeled finite-field configurations, Johnson samples, and the clustered ICARM pilot; every coefficient and proportion is computed within its displayed ensemble. Consequently, the cross-source total of 1143112 rows is an audit count, not the denominator of a pooled prevalence estimate.

The robust companion uses the stored 90th percentile $Q_{0.9}$ of eligible pair ratios:

$$
\mathcal J_{1,q90}=D\frac{Q_{0.9}}{c_{r,n}}.
$$

The ratio $Q_{0.9}/\overline{\alpha}$ is near one when large pair ratios are widespread and small when the maximum is exceptional. It is a robustness diagnostic, not a replacement definition of $\overline{\alpha}$.

## Reading the figures

Read a cost–reward frontier plot as follows. The horizontal coordinate is $C=-\log D$: moving right means fewer bases. The vertical coordinate is $R=\log(\overline{\alpha}/c_{r,n})$: moving upward means a larger correlation ratio relative to the uniform matroid. Thus up and left is preferable, but the observed points generally force a tradeoff.

Circles are non-sparse-paving observations and triangles are sparse paving. Colored lines and larger points show the exact observed Pareto frontiers. The black star at $(0,0)$ is the uniform matroid. For a gray line $R=\gamma C$, a point above the line has $\mathcal J_\gamma>1$, a point on it ties the uniform score, and a point below it has score below 1.

The vertical red line marks $D=D_{\mathrm{cap}}$. The rigorous high-density region lies to its **left**, because higher density means smaller $C$. The outside-cap sensitivity population lies on or to its right. In an all-data plot, the solid red curve is the theorem's upper bound on $R$ in the high-density region.

For legibility, at most 12,000 ordinary scatter points per ensemble are drawn. This thinning changes only the ink in the picture: every retained row is still used to compute frontiers, coefficients, and tables. In a $\gamma_*$ survival plot, the curve's height at $g$ is the observed fraction with $\gamma_*\ge g$. Solid curves use the primary population; dashed curves use the outside-cap subset when it has at least 30 observations.

## Cross-source findings

### The strong large-field tradeoff is concentrated near uniformity

In the full finite-field samples, the visually striking positive association between density cost $C$ and relative-correlation reward $R$ becomes stronger with the field size. Much of it disappears after imposing $D\le D_{\mathrm{cap}}$. The clearest case is rank 6 on 12 elements over $\mathrm{GF}(7)$ with replacement: Spearman's coefficient changes from $+0.870$ to $+0.028$. Across its five seeds, the outside-cap coefficient ranges only from $+0.007$ to $+0.085$, so this collapse is not an artifact of pooling the replicates.

The residual behavior is nevertheless not universal. Of the 31 adequately populated cells, 26 retain a positive coefficient. The five negative cases are all $\mathrm{GF}(2)$ finite-field ensembles; four are stably negative across seeds, while rank 6 without replacement straddles zero. Thus the data suggest an ensemble- and field-dependent crossover, not a distribution-free monotonicity theorem for matroids.

### A unit density penalty usually over-corrects outside the cap

There is a simple way to interpret the fitted slope. If the moderate-density conditional trend is approximated by $R\approx a+\beta C$, then

$$
\log\mathcal J_1
\approx a+(\beta-1)C.
$$

Because $D=e^{-C}$, a slope $\beta<1$ predicts that $\mathcal J_1$ increases, rather than decreases, with density. This is exactly the dominant pattern: 30 of 31 outside-cap cells have $\widehat\beta<1$, and 30 of 31 have positive Spearman association between $D$ and $\mathcal J_1$. Six cells even reverse from a negative full-data association to a positive outside-cap association.

The sole exception to both counts is the exhaustive rank-4, 10-element $\mathrm{GF}(2)$ no-replacement ensemble: it has $\widehat\beta=1.921$ and Spearman $\rho(D,\mathcal J_1)=-0.708$. It contains 3,003 labeled configurations but only four distinct $ (D,\overline{\alpha}) $ profiles, so its coefficient describes a very small discrete support. More broadly, neither the OLS identity nor a Spearman sign is a causal statement; their agreement here is a useful diagnostic of the chosen exchange rate.

### Observed scalar maximizers

| Population | $\gamma$ | $n$ | Rank | Representative | $d_B$ | $\overline{\alpha}$ | $\mathcal J_\gamma$ | Sparse paving | Observed in |
|---|---:|---:|---:|---|---:|---:|---:|---:|---|
| all | 0.5 | 8 | 4 | n8r4_00000520 | 0.685714 | 9/8 | 1.656157 | no | n8_r4: GF(2) exhaustive, no replacement<br>n8_r4: polyDB isomorphism classes |
| all | 1.0 | 8 | 4 | n8r4_00000376 | 0.800000 | 49/48 | 1.451852 | no | n8_r4: GF(5) random, no replacement<br>n8_r4: GF(7) random, no replacement<br>n8_r4: polyDB isomorphism classes |
| all | 2.0 | 9 | 4 | n9r4_00027567 | 0.888889 | 15/16 | 1.234568 | yes | n9_r4: polyDB isomorphism classes |
| outside cap | 0.5 | 8 | 4 | n8r4_00000520 | 0.685714 | 9/8 | 1.656157 | no | n8_r4: GF(2) exhaustive, no replacement<br>n8_r4: polyDB isomorphism classes |
| outside cap | 1.0 | 8 | 4 | n8r4_00000520 | 0.685714 | 9/8 | 1.371429 | no | n8_r4: GF(2) exhaustive, no replacement<br>n8_r4: polyDB isomorphism classes |
| outside cap | 2.0 | 9 | 3 | n9r3_00000494 | 0.750000 | 1/1 | 1.012500 | no | n9_r3: polyDB isomorphism classes |

As $\gamma$ increases, the global all-data maximizer moves from a moderately dense matroid with $\overline{\alpha}=9/8$, through a denser profile with $\overline{\alpha}=49/48$, to a sparse-paving profile with density $8/9$ but $\overline{\alpha}=15/16<1$. This is correct scalarization geometry—density is being rewarded more heavily—but it is a useful warning that a large $\mathcal J_\gamma$ need not mean unusually large raw correlation.

Away from the cap, $\gamma=2$ is far more selective. Exactly one of 1143112 observations has $\mathcal J_2>1$: the class `n9r3_00000494`, with $D=3/4=D_{\mathrm{cap}}$ and $\overline{\alpha}=1$. Thus the observed rank-6 $100/81$ example, although strong at $\gamma=1$, is already below the uniform benchmark at $\gamma=2$.

### Scalarization misses much of the discrete frontier

Across the all-data cells there are 566 distinct Pareto-efficient profiles but only 200 supported upper-hull vertices. Hence a scan over all exponents $\gamma\ge0$ can recover only 35.3% of the observed nondominated profiles. The remaining profiles are genuine density–correlation compromises, but no linear log-space exchange rate makes one of them optimal. This is a substantive limitation of any single $\mathcal J_\gamma$ ranking, not a computational omission.

The robust companion $\mathcal J_{1,q90}$ is positively rank-correlated with $\mathcal J_1$ in 35 of 37 cells. Nevertheless, in every cell the top $\mathcal J_1$ decile has a lower median $Q_{0.9}/\overline{\alpha}$ than the cell as a whole. High scores are therefore disproportionately supported by an exceptional worst pair. Part of this effect is mechanical—selection uses the maximum $\overline{\alpha}$ in the denominator—so it should be read as a localization diagnostic rather than evidence of a separate theorem.

## n = 8, rank 4 validation data

Here $c_{r,n}=9/16\approx0.562500$ and $D_{\mathrm{cap}}=5/7\approx0.714286$.

### Coverage and the deletion bound

| Ensemble | Primary N | $d_B$ range | High-density N (%) | Outside-cap N (%) | Median $E_{\mathrm{del}}$ | 95% $E_{\mathrm{del}}$ | Maximum $E_{\mathrm{del}}$ | Bound violations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | 731 | [0.2429, 1.0000] | 532 (72.8%) | 199 (27.2%) | 0.4431 | 0.9312 | 1.0000 | 0 |
| GF(2) exhaustive, no replacement | 6315 | [0.5714, 0.8000] | 15 (0.2%) | 6300 (99.8%) | 0.0000 | 0.0000 | 0.0000 | 0 |
| GF(3) random, no replacement | 4889 | [0.5143, 0.8571] | 2112 (43.2%) | 2777 (56.8%) | 0.2499 | 0.3002 | 0.3002 | 0 |
| GF(5) random, no replacement | 4965 | [0.5143, 0.9143] | 4180 (84.2%) | 785 (15.8%) | 0.3662 | 0.6199 | 0.9210 | 0 |
| GF(7) random, no replacement | 4991 | [0.5571, 0.9571] | 4773 (95.6%) | 218 (4.4%) | 0.4986 | 0.9312 | 1.0000 | 0 |

### Log-coordinate association and observed frontiers

| Ensemble | Population | N | Spearman $\rho_{\mathrm S}(C,R)$ | OLS slope $R$ on $C$ | Distinct profiles | Pareto | Supported vertices | Sparse-only Pareto |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | all | 731 | +0.798 | +0.450 | 238 | 15 | 5 | 9 |
| polyDB isomorphism classes | outside cap | 199 | +0.364 | +0.117 | 103 | 3 | 2 | 0 |
| GF(2) exhaustive, no replacement | all | 6315 | +0.124 | +0.038 | 5 | 2 | 2 | 1 |
| GF(2) exhaustive, no replacement | outside cap | 6300 | +0.117 | -0.035 | 4 | 1 | 1 | 0 |
| GF(3) random, no replacement | all | 4889 | +0.296 | +0.460 | 34 | 8 | 4 | 3 |
| GF(3) random, no replacement | outside cap | 2777 | +0.175 | +0.031 | 23 | 2 | 2 | 0 |
| GF(5) random, no replacement | all | 4965 | +0.718 | +0.717 | 127 | 8 | 5 | 3 |
| GF(5) random, no replacement | outside cap | 785 | +0.331 | +0.352 | 48 | 2 | 2 | 0 |
| GF(7) random, no replacement | all | 4991 | +0.816 | +0.946 | 146 | 11 | 6 | 5 |
| GF(7) random, no replacement | outside cap | 218 | +0.564 | +0.528 | 38 | 2 | 2 | 0 |

![Observed cost-reward frontier for n8_r4](../figures/j_gamma_analysis/n8_r4_frontier.png)

The next plot discards $D>D_{\mathrm{cap}}$. An empty panel means that the source law supplied no observations in the sensitivity region.

![Outside-cap cost-reward frontier for n8_r4](../figures/j_gamma_analysis/n8_r4_frontier_outside_cap.png)

### Scalarization and penalty sensitivity

| Ensemble | Population | Median $\mathcal J_{1/2}$ | Median $\mathcal J_1$ | Median $\mathcal J_2$ | $P(\mathcal J_{1/2}>1)$ | $P(\mathcal J_1>1)$ | $P(\mathcal J_2>1)$ | 95% $\mathcal J_1$ | Max $\mathcal J_1$ | $\rho_{\mathrm S}(d_B,\mathcal J_1)$ | $\rho_{\mathrm S}(\overline{\alpha},\mathcal J_1)$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | all | 1.2271 | 1.1155 | 0.9491 | 97.3% | 78.8% | 33.8% | 1.2876 | 1.4519 | +0.412 | +0.096 |
| polyDB isomorphism classes | outside cap | 1.2268 | 0.9752 | 0.6163 | 96.0% | 43.2% | 0.0% | 1.1235 | 1.3714 | +0.838 | +0.116 |
| GF(2) exhaustive, no replacement | all | 1.3439 | 1.0637 | 0.6838 | 99.8% | 93.1% | 0.0% | 1.3714 | 1.3714 | +0.898 | +0.124 |
| GF(2) exhaustive, no replacement | outside cap | 1.3439 | 1.0637 | 0.6838 | 100.0% | 93.3% | 0.0% | 1.3714 | 1.3714 | +0.914 | +0.117 |
| GF(3) random, no replacement | all | 1.3898 | 1.1143 | 0.8305 | 99.5% | 91.8% | 12.0% | 1.3381 | 1.3949 | +0.436 | +0.566 |
| GF(3) random, no replacement | outside cap | 1.3524 | 1.0637 | 0.6895 | 100.0% | 87.9% | 0.0% | 1.3176 | 1.3176 | +0.761 | +0.386 |
| GF(5) random, no replacement | all | 1.3428 | 1.1864 | 0.9762 | 100.0% | 97.4% | 36.8% | 1.3206 | 1.4519 | +0.115 | +0.529 |
| GF(5) random, no replacement | outside cap | 1.3236 | 1.0679 | 0.7174 | 100.0% | 85.0% | 0.0% | 1.1951 | 1.3176 | +0.563 | +0.492 |
| GF(7) random, no replacement | all | 1.3013 | 1.2092 | 1.0199 | 100.0% | 99.1% | 62.0% | 1.3064 | 1.4519 | -0.174 | +0.636 |
| GF(7) random, no replacement | outside cap | 1.2881 | 1.0860 | 0.7314 | 100.0% | 87.6% | 0.0% | 1.1349 | 1.3176 | +0.476 | +0.393 |

![Penalty sensitivity for n8_r4](../figures/j_gamma_analysis/n8_r4_gamma_sensitivity.png)

### Critical exponent and worst-pair robustness

| Ensemble | Population | $\gamma_*$ N | Median $\gamma_*$ | 90% $\gamma_*$ | 95% $\gamma_*$ | Maximum $\gamma_*$ | Median $Q_{0.9}/\overline{\alpha}$ | Top-$\mathcal J_1$ median $Q_{0.9}/\overline{\alpha}$ | $\rho_{\mathrm S}(\mathcal J_1,\mathcal J_{1,q90})$ | Top-$\mathcal J_1$ median relative alpha gap |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | all | 727 | 1.6561 | 2.7415 | 3.6147 | 3.7923 | 0.9949 | 0.8265 | +0.665 | 0.1185 |
| polyDB isomorphism classes | outside cap | 199 | 0.9509 | 1.2539 | 1.3264 | 1.8372 | 1.0000 | 0.9122 | +0.886 | 0.0000 |
| GF(2) exhaustive, no replacement | all | 6300 | 1.1398 | 1.8372 | 1.8372 | 1.8372 | 0.9930 | 0.6364 | +0.318 | 0.3636 |
| GF(2) exhaustive, no replacement | outside cap | 6300 | 1.1398 | 1.8372 | 1.8372 | 1.8372 | 0.9930 | 0.6364 | +0.313 | 0.3636 |
| GF(3) random, no replacement | all | 4889 | 1.3762 | 2.0469 | 2.0469 | 2.1197 | 0.9636 | 0.8047 | +0.418 | 0.1953 |
| GF(3) random, no replacement | outside cap | 2777 | 1.1398 | 1.5250 | 1.7734 | 1.7734 | 0.9636 | 0.7377 | +0.699 | 0.2623 |
| GF(5) random, no replacement | all | 4965 | 1.8555 | 2.4212 | 2.6093 | 3.6774 | 0.9006 | 0.8047 | +0.367 | 0.1230 |
| GF(5) random, no replacement | outside cap | 785 | 1.1564 | 1.4791 | 1.5298 | 1.7734 | 0.9636 | 0.9636 | +0.593 | 0.0000 |
| GF(7) random, no replacement | all | 4991 | 2.2194 | 2.7700 | 3.6272 | 3.7923 | 0.9000 | 0.8730 | +0.317 | 0.1185 |
| GF(7) random, no replacement | outside cap | 218 | 1.2167 | 1.3761 | 1.3761 | 1.7734 | 0.9244 | 0.9544 | +0.349 | 0.0000 |

## n = 9, rank 3 exact census

Here $c_{r,n}=5/9\approx0.555556$ and $D_{\mathrm{cap}}=3/4\approx0.750000$.

### Coverage and the deletion bound

| Ensemble | Primary N | $d_B$ range | High-density N (%) | Outside-cap N (%) | Median $E_{\mathrm{del}}$ | 95% $E_{\mathrm{del}}$ | Maximum $E_{\mathrm{del}}$ | Bound violations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | 901 | [0.2262, 1.0000] | 614 (68.1%) | 287 (31.9%) | 0.3908 | 0.7016 | 1.0000 | 0 |

### Log-coordinate association and observed frontiers

| Ensemble | Population | N | Spearman $\rho_{\mathrm S}(C,R)$ | OLS slope $R$ on $C$ | Distinct profiles | Pareto | Supported vertices | Sparse-only Pareto |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | all | 901 | +0.848 | +0.426 | 456 | 14 | 8 | 7 |
| polyDB isomorphism classes | outside cap | 287 | +0.522 | +0.181 | 245 | 1 | 1 | 0 |

![Observed cost-reward frontier for n9_r3](../figures/j_gamma_analysis/n9_r3_frontier.png)

The next plot discards $D>D_{\mathrm{cap}}$. An empty panel means that the source law supplied no observations in the sensitivity region.

![Outside-cap cost-reward frontier for n9_r3](../figures/j_gamma_analysis/n9_r3_frontier_outside_cap.png)

### Scalarization and penalty sensitivity

| Ensemble | Population | Median $\mathcal J_{1/2}$ | Median $\mathcal J_1$ | Median $\mathcal J_2$ | $P(\mathcal J_{1/2}>1)$ | $P(\mathcal J_1>1)$ | $P(\mathcal J_2>1)$ | 95% $\mathcal J_1$ | Max $\mathcal J_1$ | $\rho_{\mathrm S}(d_B,\mathcal J_1)$ | $\rho_{\mathrm S}(\overline{\alpha},\mathcal J_1)$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | all | 1.2505 | 1.1335 | 0.9623 | 99.1% | 84.9% | 36.8% | 1.2706 | 1.4000 | +0.521 | -0.090 |
| polyDB isomorphism classes | outside cap | 1.2479 | 1.0200 | 0.6677 | 98.3% | 56.1% | 0.3% | 1.1751 | 1.3500 | +0.822 | -0.029 |

![Penalty sensitivity for n9_r3](../figures/j_gamma_analysis/n9_r3_gamma_sensitivity.png)

### Critical exponent and worst-pair robustness

| Ensemble | Population | $\gamma_*$ N | Median $\gamma_*$ | 90% $\gamma_*$ | 95% $\gamma_*$ | Maximum $\gamma_*$ | Median $Q_{0.9}/\overline{\alpha}$ | Top-$\mathcal J_1$ median $Q_{0.9}/\overline{\alpha}$ | $\rho_{\mathrm S}(\mathcal J_1,\mathcal J_{1,q90})$ | Top-$\mathcal J_1$ median relative alpha gap |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | all | 899 | 1.7576 | 2.8973 | 3.2101 | 4.2387 | 0.9630 | 0.9032 | +0.738 | 0.0000 |
| polyDB isomorphism classes | outside cap | 287 | 1.0444 | 1.4356 | 1.4958 | 2.0432 | 1.0000 | 0.9308 | +0.949 | 0.0000 |

## n = 9, rank 4 exact census

Here $c_{r,n}=3/5\approx0.600000$ and $D_{\mathrm{cap}}=13/18\approx0.722222$.

### Coverage and the deletion bound

| Ensemble | Primary N | $d_B$ range | High-density N (%) | Outside-cap N (%) | Median $E_{\mathrm{del}}$ | 95% $E_{\mathrm{del}}$ | Maximum $E_{\mathrm{del}}$ | Bound violations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | 188961 | [0.1667, 1.0000] | 186658 (98.8%) | 2303 (1.2%) | 0.4637 | 0.7190 | 1.0000 | 0 |

### Log-coordinate association and observed frontiers

| Ensemble | Population | N | Spearman $\rho_{\mathrm S}(C,R)$ | OLS slope $R$ on $C$ | Distinct profiles | Pareto | Supported vertices | Sparse-only Pareto |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | all | 188961 | +0.649 | +0.744 | 3123 | 24 | 5 | 15 |
| polyDB isomorphism classes | outside cap | 2303 | +0.443 | +0.142 | 1307 | 6 | 3 | 0 |

![Observed cost-reward frontier for n9_r4](../figures/j_gamma_analysis/n9_r4_frontier.png)

The next plot discards $D>D_{\mathrm{cap}}$. An empty panel means that the source law supplied no observations in the sensitivity region.

![Outside-cap cost-reward frontier for n9_r4](../figures/j_gamma_analysis/n9_r4_frontier_outside_cap.png)

### Scalarization and penalty sensitivity

| Ensemble | Population | Median $\mathcal J_{1/2}$ | Median $\mathcal J_1$ | Median $\mathcal J_2$ | $P(\mathcal J_{1/2}>1)$ | $P(\mathcal J_1>1)$ | $P(\mathcal J_2>1)$ | 95% $\mathcal J_1$ | Max $\mathcal J_1$ | $\rho_{\mathrm S}(d_B,\mathcal J_1)$ | $\rho_{\mathrm S}(\overline{\alpha},\mathcal J_1)$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | all | 1.1532 | 1.0967 | 0.9990 | 99.9% | 98.5% | 46.9% | 1.1906 | 1.3889 | -0.126 | +0.766 |
| polyDB isomorphism classes | outside cap | 1.1859 | 0.9626 | 0.6387 | 95.9% | 32.6% | 0.0% | 1.1095 | 1.2282 | +0.801 | +0.081 |

![Penalty sensitivity for n9_r4](../figures/j_gamma_analysis/n9_r4_gamma_sensitivity.png)

### Critical exponent and worst-pair robustness

| Ensemble | Population | $\gamma_*$ N | Median $\gamma_*$ | 90% $\gamma_*$ | 95% $\gamma_*$ | Maximum $\gamma_*$ | Median $Q_{0.9}/\overline{\alpha}$ | Top-$\mathcal J_1$ median $Q_{0.9}/\overline{\alpha}$ | $\rho_{\mathrm S}(\mathcal J_1,\mathcal J_{1,q90})$ | Top-$\mathcal J_1$ median relative alpha gap |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| polyDB isomorphism classes | all | 188958 | 1.9916 | 2.6455 | 2.8841 | 3.9039 | 0.9315 | 0.8676 | +0.427 | 0.0640 |
| polyDB isomorphism classes | outside cap | 2303 | 0.9095 | 1.1929 | 1.2875 | 1.5727 | 0.9633 | 0.8845 | +0.852 | 0.0000 |

## n = 10, rank 4 finite-field data

Here $c_{r,n}=5/8\approx0.625000$ and $D_{\mathrm{cap}}=11/15\approx0.733333$.

### Coverage and the deletion bound

| Ensemble | Primary N | $d_B$ range | High-density N (%) | Outside-cap N (%) | Median $E_{\mathrm{del}}$ | 95% $E_{\mathrm{del}}$ | Maximum $E_{\mathrm{del}}$ | Bound violations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 84481 | [0.1190, 0.6476] | 0 (0.0%) | 84481 (100.0%) | — | — | — | 0 |
| GF(2) exhaustive, no replacement | 3003 | [0.5905, 0.6476] | 0 (0.0%) | 3003 (100.0%) | — | — | — | 0 |
| GF(3) random, with replacement | 98439 | [0.1857, 0.8000] | 4314 (4.4%) | 94125 (95.6%) | 0.1086 | 0.1555 | 0.2075 | 0 |
| GF(3) random, no replacement | 99904 | [0.5000, 0.8000] | 14562 (14.6%) | 85342 (85.4%) | 0.1086 | 0.1555 | 0.2075 | 0 |
| GF(5) random, with replacement | 99941 | [0.2810, 0.9048] | 70575 (70.6%) | 29366 (29.4%) | 0.2278 | 0.3206 | 0.4392 | 0 |
| GF(5) random, no replacement | 99980 | [0.4714, 0.9095] | 89070 (89.1%) | 10910 (10.9%) | 0.2327 | 0.3223 | 0.4381 | 0 |
| GF(7) random, with replacement | 99987 | [0.3571, 0.9333] | 93796 (93.8%) | 6191 (6.2%) | 0.3132 | 0.4354 | 0.7269 | 0 |
| GF(7) random, no replacement | 99994 | [0.5000, 0.9381] | 98244 (98.2%) | 1750 (1.8%) | 0.3204 | 0.4376 | 0.6988 | 0 |

### Log-coordinate association and observed frontiers

| Ensemble | Population | N | Spearman $\rho_{\mathrm S}(C,R)$ | OLS slope $R$ on $C$ | Distinct profiles | Pareto | Supported vertices | Sparse-only Pareto |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | all | 84481 | -0.410 | -0.008 | 151 | 8 | 4 | 0 |
| GF(2) random, with replacement | outside cap | 84481 | -0.410 | -0.008 | 151 | 8 | 4 | 0 |
| GF(2) exhaustive, no replacement | all | 3003 | +1.000 | +1.921 | 4 | 4 | 2 | 0 |
| GF(2) exhaustive, no replacement | outside cap | 3003 | +1.000 | +1.921 | 4 | 4 | 2 | 0 |
| GF(3) random, with replacement | all | 98439 | +0.452 | +0.141 | 1304 | 4 | 2 | 0 |
| GF(3) random, with replacement | outside cap | 94125 | +0.381 | +0.107 | 1278 | 8 | 5 | 0 |
| GF(3) random, no replacement | all | 99904 | +0.659 | +0.524 | 176 | 4 | 2 | 0 |
| GF(3) random, no replacement | outside cap | 85342 | +0.493 | +0.324 | 151 | 8 | 5 | 0 |
| GF(5) random, with replacement | all | 99941 | +0.741 | +0.439 | 9481 | 17 | 5 | 1 |
| GF(5) random, with replacement | outside cap | 29366 | +0.404 | +0.181 | 5724 | 6 | 3 | 0 |
| GF(5) random, no replacement | all | 99980 | +0.802 | +0.811 | 5078 | 23 | 7 | 2 |
| GF(5) random, no replacement | outside cap | 10910 | +0.321 | +0.141 | 1523 | 5 | 3 | 0 |
| GF(7) random, with replacement | all | 99987 | +0.830 | +0.703 | 8442 | 26 | 9 | 2 |
| GF(7) random, with replacement | outside cap | 6191 | +0.318 | +0.170 | 2672 | 6 | 5 | 0 |
| GF(7) random, no replacement | all | 99994 | +0.840 | +1.030 | 5820 | 23 | 8 | 4 |
| GF(7) random, no replacement | outside cap | 1750 | +0.175 | +0.049 | 749 | 3 | 2 | 0 |

![Observed cost-reward frontier for n10_r4_finite_fields](../figures/j_gamma_analysis/n10_r4_finite_fields_frontier.png)

The next plot discards $D>D_{\mathrm{cap}}$. An empty panel means that the source law supplied no observations in the sensitivity region.

![Outside-cap cost-reward frontier for n10_r4_finite_fields](../figures/j_gamma_analysis/n10_r4_finite_fields_frontier_outside_cap.png)

### Scalarization and penalty sensitivity

| Ensemble | Population | Median $\mathcal J_{1/2}$ | Median $\mathcal J_1$ | Median $\mathcal J_2$ | $P(\mathcal J_{1/2}>1)$ | $P(\mathcal J_1>1)$ | $P(\mathcal J_2>1)$ | 95% $\mathcal J_1$ | Max $\mathcal J_1$ | $\rho_{\mathrm S}(d_B,\mathcal J_1)$ | $\rho_{\mathrm S}(\overline{\alpha},\mathcal J_1)$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | all | 1.0357 | 0.6765 | 0.2867 | 62.1% | 0.0% | 0.0% | 0.8983 | 0.9623 | +0.984 | +0.515 |
| GF(2) random, with replacement | outside cap | 1.0357 | 0.6765 | 0.2867 | 62.1% | 0.0% | 0.0% | 0.8983 | 0.9623 | +0.984 | +0.515 |
| GF(2) exhaustive, no replacement | all | 1.1373 | 0.8983 | 0.5604 | 100.0% | 0.0% | 0.0% | 0.9623 | 0.9623 | -0.708 | +0.708 |
| GF(2) exhaustive, no replacement | outside cap | 1.1373 | 0.8983 | 0.5604 | 100.0% | 0.0% | 0.0% | 0.9623 | 0.9623 | -0.708 | +0.708 |
| GF(3) random, with replacement | all | 1.1756 | 0.9222 | 0.5644 | 95.1% | 24.1% | 0.0% | 1.0760 | 1.3206 | +0.899 | -0.059 |
| GF(3) random, with replacement | outside cap | 1.1756 | 0.9175 | 0.5547 | 94.9% | 21.6% | 0.0% | 1.0760 | 1.1657 | +0.904 | +0.007 |
| GF(3) random, no replacement | all | 1.2376 | 1.0286 | 0.7317 | 100.0% | 70.8% | 0.0% | 1.1215 | 1.3206 | +0.316 | +0.435 |
| GF(3) random, no replacement | outside cap | 1.2542 | 1.0357 | 0.7166 | 100.0% | 69.1% | 0.0% | 1.1333 | 1.1657 | +0.486 | +0.452 |
| GF(5) random, with replacement | all | 1.2023 | 1.0651 | 0.8502 | 99.8% | 80.4% | 0.3% | 1.1622 | 1.3206 | +0.505 | +0.122 |
| GF(5) random, with replacement | outside cap | 1.1937 | 0.9891 | 0.6878 | 99.5% | 42.9% | 0.0% | 1.0927 | 1.2070 | +0.681 | +0.298 |
| GF(5) random, no replacement | all | 1.2159 | 1.0832 | 0.8763 | 100.0% | 96.4% | 0.3% | 1.1695 | 1.2972 | -0.008 | +0.537 |
| GF(5) random, no replacement | outside cap | 1.2465 | 1.0464 | 0.7382 | 100.0% | 80.5% | 0.0% | 1.1282 | 1.2070 | +0.478 | +0.599 |
| GF(7) random, with replacement | all | 1.1887 | 1.0895 | 0.9351 | 100.0% | 95.1% | 6.3% | 1.1707 | 1.2847 | +0.058 | +0.421 |
| GF(7) random, with replacement | outside cap | 1.1940 | 0.9995 | 0.7088 | 99.9% | 49.3% | 0.0% | 1.0842 | 1.1815 | +0.640 | +0.427 |
| GF(7) random, no replacement | all | 1.1904 | 1.0958 | 0.9417 | 100.0% | 99.2% | 7.2% | 1.1724 | 1.2972 | -0.251 | +0.684 |
| GF(7) random, no replacement | outside cap | 1.2336 | 1.0409 | 0.7418 | 100.0% | 78.3% | 0.0% | 1.1144 | 1.1907 | +0.540 | +0.656 |

![Penalty sensitivity for n10_r4_finite_fields](../figures/j_gamma_analysis/n10_r4_finite_fields_gamma_sensitivity.png)

### Critical exponent and worst-pair robustness

| Ensemble | Population | $\gamma_*$ N | Median $\gamma_*$ | 90% $\gamma_*$ | 95% $\gamma_*$ | Maximum $\gamma_*$ | Median $Q_{0.9}/\overline{\alpha}$ | Top-$\mathcal J_1$ median $Q_{0.9}/\overline{\alpha}$ | $\rho_{\mathrm S}(\mathcal J_1,\mathcal J_{1,q90})$ | Top-$\mathcal J_1$ median relative alpha gap |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | all | 84481 | 0.5404 | 0.7955 | 0.8384 | 0.9270 | 0.9871 | 0.8749 | +0.960 | 0.0000 |
| GF(2) random, with replacement | outside cap | 84481 | 0.5404 | 0.7955 | 0.8384 | 0.9270 | 0.9871 | 0.8749 | +0.960 | 0.0000 |
| GF(2) exhaustive, no replacement | all | 3003 | 0.7727 | 0.9270 | 0.9270 | 0.9270 | 1.0000 | 0.8416 | -0.691 | 0.0000 |
| GF(2) exhaustive, no replacement | outside cap | 3003 | 0.7727 | 0.9270 | 0.9270 | 0.9270 | 1.0000 | 0.8416 | -0.691 | 0.0000 |
| GF(3) random, with replacement | all | 98439 | 0.8371 | 1.1667 | 1.2143 | 1.9356 | 0.9353 | 0.8722 | +0.902 | 0.0496 |
| GF(3) random, with replacement | outside cap | 94125 | 0.8293 | 1.1554 | 1.2037 | 1.4064 | 0.9366 | 0.8722 | +0.903 | 0.0594 |
| GF(3) random, no replacement | all | 99904 | 1.0806 | 1.2604 | 1.3548 | 1.9356 | 0.9083 | 0.8354 | +0.433 | 0.1228 |
| GF(3) random, no replacement | outside cap | 85342 | 1.0916 | 1.2795 | 1.3548 | 1.4064 | 0.9014 | 0.8354 | +0.458 | 0.1228 |
| GF(5) random, with replacement | all | 99941 | 1.2795 | 1.6085 | 1.7094 | 2.3037 | 0.9205 | 0.8563 | +0.674 | 0.0673 |
| GF(5) random, with replacement | outside cap | 29366 | 0.9705 | 1.1964 | 1.2604 | 1.5768 | 0.9346 | 0.8841 | +0.764 | 0.0400 |
| GF(5) random, no replacement | all | 99980 | 1.3672 | 1.6493 | 1.7327 | 2.3037 | 0.9140 | 0.8499 | +0.382 | 0.0749 |
| GF(5) random, no replacement | outside cap | 10910 | 1.1263 | 1.3165 | 1.3758 | 1.5768 | 0.9197 | 0.8730 | +0.582 | 0.0616 |
| GF(7) random, with replacement | all | 99987 | 1.5532 | 1.9316 | 2.0369 | 3.1766 | 0.9271 | 0.8703 | +0.530 | 0.0607 |
| GF(7) random, with replacement | outside cap | 6191 | 0.9987 | 1.1856 | 1.2479 | 1.5302 | 0.9401 | 0.8922 | +0.739 | 0.0283 |
| GF(7) random, no replacement | all | 99994 | 1.5867 | 1.9491 | 2.0597 | 2.9399 | 0.9249 | 0.8682 | +0.406 | 0.0618 |
| GF(7) random, no replacement | outside cap | 1750 | 1.1145 | 1.3031 | 1.3365 | 1.5302 | 0.9285 | 0.8772 | +0.579 | 0.0586 |

### Independent-seed stability

| Ensemble | Replicates | $\rho_{\mathrm S}(C,R)$ range | OLS slope range | $P(\mathcal J_1>1)$ range | Outside-cap $\rho_{\mathrm S}(C,R)$ range |
|---|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 5 | [-0.417, -0.406] | [-0.009, -0.007] | [0.0000, 0.0000] | [-0.417, -0.406] |
| GF(3) random, with replacement | 5 | [0.445, 0.460] | [0.140, 0.145] | [0.2386, 0.2441] | [0.374, 0.389] |
| GF(3) random, no replacement | 5 | [0.654, 0.662] | [0.508, 0.535] | [0.7034, 0.7107] | [0.484, 0.500] |
| GF(5) random, with replacement | 5 | [0.736, 0.746] | [0.430, 0.445] | [0.8016, 0.8077] | [0.387, 0.422] |
| GF(5) random, no replacement | 5 | [0.798, 0.805] | [0.807, 0.816] | [0.9620, 0.9648] | [0.307, 0.347] |
| GF(7) random, with replacement | 5 | [0.827, 0.832] | [0.694, 0.711] | [0.9487, 0.9530] | [0.268, 0.364] |
| GF(7) random, no replacement | 5 | [0.837, 0.843] | [1.018, 1.037] | [0.9917, 0.9928] | [0.046, 0.261] |

## n = 10, rank 4 ICARM class-uniform sample

Here $c_{r,n}=5/8\approx0.625000$ and $D_{\mathrm{cap}}=11/15\approx0.733333$.

### Coverage and the deletion bound

| Ensemble | Primary N | $d_B$ range | High-density N (%) | Outside-cap N (%) | Median $E_{\mathrm{del}}$ | 95% $E_{\mathrm{del}}$ | Maximum $E_{\mathrm{del}}$ | Bound violations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| ICARM class SRS | 99991 | [0.5714, 0.9667] | 99987 (100.0%) | 4 (0.0%) | 0.4016 | 0.5695 | 0.9673 | 0 |

### Log-coordinate association and observed frontiers

| Ensemble | Population | N | Spearman $\rho_{\mathrm S}(C,R)$ | OLS slope $R$ on $C$ | Distinct profiles | Pareto | Supported vertices | Sparse-only Pareto |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| ICARM class SRS | all | 99991 | +0.488 | +1.269 | 1463 | 17 | 9 | 6 |
| ICARM class SRS | outside cap | 4 | +0.949 | +0.343 | 4 | 3 | 3 | 0 |

![Observed cost-reward frontier for n10_r4_icarm](../figures/j_gamma_analysis/n10_r4_icarm_frontier.png)

The next plot discards $D>D_{\mathrm{cap}}$. An empty panel means that the source law supplied no observations in the sensitivity region.

![Outside-cap cost-reward frontier for n10_r4_icarm](../figures/j_gamma_analysis/n10_r4_icarm_frontier_outside_cap.png)

### Scalarization and penalty sensitivity

| Ensemble | Population | Median $\mathcal J_{1/2}$ | Median $\mathcal J_1$ | Median $\mathcal J_2$ | $P(\mathcal J_{1/2}>1)$ | $P(\mathcal J_1>1)$ | $P(\mathcal J_2>1)$ | 95% $\mathcal J_1$ | Max $\mathcal J_1$ | $\rho_{\mathrm S}(d_B,\mathcal J_1)$ | $\rho_{\mathrm S}(\overline{\alpha},\mathcal J_1)$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ICARM class SRS | all | 1.0976 | 1.0565 | 0.9785 | 100.0% | 99.0% | 21.7% | 1.1153 | 1.2382 | -0.088 | +0.892 |
| ICARM class SRS | outside cap | 1.1706 | 0.9992 | 0.7280 | 100.0% | 50.0% | 0.0% | 1.0486 | 1.0486 | +0.316 | -0.200 |

![Penalty sensitivity for n10_r4_icarm](../figures/j_gamma_analysis/n10_r4_icarm_gamma_sensitivity.png)

### Critical exponent and worst-pair robustness

| Ensemble | Population | $\gamma_*$ N | Median $\gamma_*$ | 90% $\gamma_*$ | 95% $\gamma_*$ | Maximum $\gamma_*$ | Median $Q_{0.9}/\overline{\alpha}$ | Top-$\mathcal J_1$ median $Q_{0.9}/\overline{\alpha}$ | $\rho_{\mathrm S}(\mathcal J_1,\mathcal J_{1,q90})$ | Top-$\mathcal J_1$ median relative alpha gap |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ICARM class SRS | all | 99991 | 1.7095 | 2.2416 | 2.3943 | 3.8593 | 0.9454 | 0.9044 | +0.420 | 0.0543 |
| ICARM class SRS | outside cap | 4 | 0.9974 | 1.1469 | 1.1469 | 1.1469 | 0.9530 | 1.0000 | +1.000 | 0.0000 |

## n = 10, rank 5 finite-field data

Here $c_{r,n}=16/25\approx0.640000$ and $D_{\mathrm{cap}}=13/18\approx0.722222$.

### Coverage and the deletion bound

| Ensemble | Primary N | $d_B$ range | High-density N (%) | Outside-cap N (%) | Median $E_{\mathrm{del}}$ | 95% $E_{\mathrm{del}}$ | Maximum $E_{\mathrm{del}}$ | Bound violations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 72231 | [0.1508, 0.6984] | 0 (0.0%) | 72231 (100.0%) | — | — | — | 0 |
| GF(2) random, no replacement | 94375 | [0.3810, 0.6984] | 0 (0.0%) | 94375 (100.0%) | — | — | — | 0 |
| GF(3) random, with replacement | 95722 | [0.1944, 0.7976] | 5511 (5.8%) | 90211 (94.2%) | 0.1016 | 0.1675 | 0.2206 | 0 |
| GF(3) random, no replacement | 97880 | [0.3492, 0.7976] | 8004 (8.2%) | 89876 (91.8%) | 0.1016 | 0.1675 | 0.2206 | 0 |
| GF(5) random, with replacement | 99700 | [0.2738, 0.9048] | 76221 (76.5%) | 23479 (23.5%) | 0.2103 | 0.3035 | 0.4700 | 0 |
| GF(5) random, no replacement | 99743 | [0.3492, 0.9048] | 80782 (81.0%) | 18961 (19.0%) | 0.2103 | 0.3035 | 0.4421 | 0 |
| GF(7) random, with replacement | 99946 | [0.3611, 0.9365] | 95158 (95.2%) | 4788 (4.8%) | 0.2943 | 0.4026 | 0.6076 | 0 |
| GF(7) random, no replacement | 99946 | [0.4167, 0.9325] | 96776 (96.8%) | 3170 (3.2%) | 0.2946 | 0.4042 | 0.5947 | 0 |

### Log-coordinate association and observed frontiers

| Ensemble | Population | N | Spearman $\rho_{\mathrm S}(C,R)$ | OLS slope $R$ on $C$ | Distinct profiles | Pareto | Supported vertices | Sparse-only Pareto |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | all | 72231 | -0.285 | -0.026 | 134 | 4 | 3 | 0 |
| GF(2) random, with replacement | outside cap | 72231 | -0.285 | -0.026 | 134 | 4 | 3 | 0 |
| GF(2) random, no replacement | all | 94375 | -0.171 | +0.032 | 37 | 4 | 3 | 0 |
| GF(2) random, no replacement | outside cap | 94375 | -0.171 | +0.032 | 37 | 4 | 3 | 0 |
| GF(3) random, with replacement | all | 95722 | +0.431 | +0.125 | 1382 | 4 | 2 | 0 |
| GF(3) random, with replacement | outside cap | 90211 | +0.336 | +0.087 | 1336 | 7 | 4 | 0 |
| GF(3) random, no replacement | all | 97880 | +0.553 | +0.258 | 853 | 4 | 2 | 0 |
| GF(3) random, no replacement | outside cap | 89876 | +0.449 | +0.185 | 806 | 7 | 4 | 0 |
| GF(5) random, with replacement | all | 99700 | +0.801 | +0.443 | 12371 | 17 | 3 | 2 |
| GF(5) random, with replacement | outside cap | 23479 | +0.148 | +0.082 | 6448 | 5 | 5 | 0 |
| GF(5) random, no replacement | all | 99743 | +0.809 | +0.578 | 11318 | 25 | 6 | 3 |
| GF(5) random, no replacement | outside cap | 18961 | +0.170 | +0.103 | 5266 | 4 | 4 | 0 |
| GF(7) random, with replacement | all | 99946 | +0.862 | +0.715 | 10004 | 25 | 8 | 2 |
| GF(7) random, with replacement | outside cap | 4788 | +0.191 | +0.151 | 2533 | 2 | 2 | 0 |
| GF(7) random, no replacement | all | 99946 | +0.859 | +0.828 | 9365 | 26 | 8 | 2 |
| GF(7) random, no replacement | outside cap | 3170 | +0.099 | +0.128 | 1908 | 2 | 2 | 0 |

![Observed cost-reward frontier for n10_r5_finite_fields](../figures/j_gamma_analysis/n10_r5_finite_fields_frontier.png)

The next plot discards $D>D_{\mathrm{cap}}$. An empty panel means that the source law supplied no observations in the sensitivity region.

![Outside-cap cost-reward frontier for n10_r5_finite_fields](../figures/j_gamma_analysis/n10_r5_finite_fields_frontier_outside_cap.png)

### Scalarization and penalty sensitivity

| Ensemble | Population | Median $\mathcal J_{1/2}$ | Median $\mathcal J_1$ | Median $\mathcal J_2$ | $P(\mathcal J_{1/2}>1)$ | $P(\mathcal J_1>1)$ | $P(\mathcal J_2>1)$ | 95% $\mathcal J_1$ | Max $\mathcal J_1$ | $\rho_{\mathrm S}(d_B,\mathcal J_1)$ | $\rho_{\mathrm S}(\overline{\alpha},\mathcal J_1)$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | all | 0.9876 | 0.6252 | 0.2535 | 43.3% | 0.3% | 0.0% | 0.8730 | 1.0334 | +0.988 | +0.390 |
| GF(2) random, with replacement | outside cap | 0.9876 | 0.6252 | 0.2535 | 43.3% | 0.3% | 0.0% | 0.8730 | 1.0334 | +0.988 | +0.390 |
| GF(2) random, no replacement | all | 1.1180 | 0.8030 | 0.4031 | 93.1% | 1.0% | 0.0% | 0.9154 | 1.0334 | +0.890 | +0.540 |
| GF(2) random, no replacement | outside cap | 1.1180 | 0.8030 | 0.4031 | 93.1% | 1.0% | 0.0% | 0.9154 | 1.0334 | +0.890 | +0.540 |
| GF(3) random, with replacement | all | 1.1449 | 0.8984 | 0.5335 | 92.0% | 15.9% | 0.0% | 1.0402 | 1.3122 | +0.911 | -0.066 |
| GF(3) random, with replacement | outside cap | 1.1421 | 0.8865 | 0.5196 | 91.5% | 14.4% | 0.0% | 1.0364 | 1.1153 | +0.920 | +0.018 |
| GF(3) random, no replacement | all | 1.1764 | 0.9493 | 0.6139 | 99.1% | 22.7% | 0.0% | 1.0582 | 1.3122 | +0.779 | +0.029 |
| GF(3) random, no replacement | outside cap | 1.1801 | 0.9433 | 0.6047 | 99.0% | 21.1% | 0.0% | 1.0529 | 1.1153 | +0.799 | +0.116 |
| GF(5) random, with replacement | all | 1.1798 | 1.0409 | 0.8206 | 99.8% | 78.1% | 0.0% | 1.1225 | 1.2978 | +0.443 | +0.096 |
| GF(5) random, with replacement | outside cap | 1.1693 | 0.9566 | 0.6381 | 99.1% | 31.9% | 0.0% | 1.0696 | 1.1742 | +0.843 | +0.348 |
| GF(5) random, no replacement | all | 1.1826 | 1.0451 | 0.8270 | 100.0% | 82.7% | 0.0% | 1.1240 | 1.2907 | +0.335 | +0.205 |
| GF(5) random, no replacement | outside cap | 1.1940 | 0.9888 | 0.6824 | 99.9% | 42.8% | 0.0% | 1.0796 | 1.1871 | +0.747 | +0.453 |
| GF(7) random, with replacement | all | 1.1630 | 1.0652 | 0.9106 | 100.0% | 93.9% | 1.2% | 1.1378 | 1.2642 | -0.012 | +0.437 |
| GF(7) random, with replacement | outside cap | 1.1450 | 0.9402 | 0.6435 | 99.7% | 20.6% | 0.0% | 1.0502 | 1.1588 | +0.762 | +0.402 |
| GF(7) random, no replacement | all | 1.1634 | 1.0665 | 0.9119 | 100.0% | 95.4% | 1.3% | 1.1378 | 1.2680 | -0.069 | +0.498 |
| GF(7) random, no replacement | outside cap | 1.1638 | 0.9613 | 0.6654 | 99.9% | 30.2% | 0.0% | 1.0627 | 1.1611 | +0.708 | +0.569 |

![Penalty sensitivity for n10_r5_finite_fields](../figures/j_gamma_analysis/n10_r5_finite_fields_gamma_sensitivity.png)

### Critical exponent and worst-pair robustness

| Ensemble | Population | $\gamma_*$ N | Median $\gamma_*$ | 90% $\gamma_*$ | 95% $\gamma_*$ | Maximum $\gamma_*$ | Median $Q_{0.9}/\overline{\alpha}$ | Top-$\mathcal J_1$ median $Q_{0.9}/\overline{\alpha}$ | $\rho_{\mathrm S}(\mathcal J_1,\mathcal J_{1,q90})$ | Top-$\mathcal J_1$ median relative alpha gap |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | all | 72227 | 0.4863 | 0.7150 | 0.7900 | 1.0723 | 0.9877 | 0.8656 | +0.965 | 0.0000 |
| GF(2) random, with replacement | outside cap | 72227 | 0.4863 | 0.7150 | 0.7900 | 1.0723 | 0.9877 | 0.8656 | +0.965 | 0.0000 |
| GF(2) random, no replacement | all | 94344 | 0.6505 | 0.8477 | 0.8477 | 1.0723 | 0.9671 | 0.8656 | +0.823 | 0.0000 |
| GF(2) random, no replacement | outside cap | 94344 | 0.6505 | 0.8477 | 0.8477 | 1.0723 | 0.9671 | 0.8656 | +0.823 | 0.0000 |
| GF(3) random, with replacement | all | 95722 | 0.7908 | 1.0437 | 1.1007 | 1.8946 | 0.9349 | 0.8819 | +0.919 | 0.0649 |
| GF(3) random, with replacement | outside cap | 90211 | 0.7672 | 1.0327 | 1.0786 | 1.3100 | 0.9367 | 0.8867 | +0.928 | 0.0595 |
| GF(3) random, no replacement | all | 97880 | 0.8775 | 1.0694 | 1.1577 | 1.8946 | 0.9261 | 0.8736 | +0.799 | 0.0778 |
| GF(3) random, no replacement | outside cap | 89876 | 0.8657 | 1.0665 | 1.1273 | 1.3100 | 0.9261 | 0.8840 | +0.818 | 0.0654 |
| GF(5) random, with replacement | all | 99700 | 1.1708 | 1.4445 | 1.5304 | 2.3933 | 0.9261 | 0.8742 | +0.645 | 0.0704 |
| GF(5) random, with replacement | outside cap | 23479 | 0.8916 | 1.1360 | 1.1982 | 1.4813 | 0.9358 | 0.8845 | +0.882 | 0.0523 |
| GF(5) random, no replacement | all | 99743 | 1.1862 | 1.4541 | 1.5376 | 2.2630 | 0.9253 | 0.8741 | +0.576 | 0.0711 |
| GF(5) random, no replacement | outside cap | 18961 | 0.9689 | 1.1639 | 1.2182 | 1.4933 | 0.9290 | 0.8792 | +0.798 | 0.0593 |
| GF(7) random, with replacement | all | 99946 | 1.3887 | 1.7173 | 1.8206 | 2.5105 | 0.9312 | 0.8848 | +0.501 | 0.0650 |
| GF(7) random, with replacement | outside cap | 4788 | 0.8399 | 1.0828 | 1.1401 | 1.4529 | 0.9475 | 0.9026 | +0.855 | 0.0424 |
| GF(7) random, no replacement | all | 99946 | 1.3963 | 1.7284 | 1.8223 | 2.5571 | 0.9309 | 0.8845 | +0.472 | 0.0658 |
| GF(7) random, no replacement | outside cap | 3170 | 0.8972 | 1.1216 | 1.1763 | 1.4529 | 0.9414 | 0.8919 | +0.819 | 0.0497 |

### Independent-seed stability

| Ensemble | Replicates | $\rho_{\mathrm S}(C,R)$ range | OLS slope range | $P(\mathcal J_1>1)$ range | Outside-cap $\rho_{\mathrm S}(C,R)$ range |
|---|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 5 | [-0.298, -0.276] | [-0.028, -0.025] | [0.0024, 0.0030] | [-0.298, -0.276] |
| GF(2) random, no replacement | 5 | [-0.180, -0.162] | [0.027, 0.037] | [0.0084, 0.0108] | [-0.180, -0.162] |
| GF(3) random, with replacement | 5 | [0.424, 0.445] | [0.122, 0.129] | [0.1566, 0.1609] | [0.326, 0.351] |
| GF(3) random, no replacement | 5 | [0.546, 0.566] | [0.254, 0.265] | [0.2252, 0.2281] | [0.444, 0.462] |
| GF(5) random, with replacement | 5 | [0.799, 0.804] | [0.438, 0.452] | [0.7781, 0.7845] | [0.123, 0.175] |
| GF(5) random, no replacement | 5 | [0.808, 0.812] | [0.573, 0.583] | [0.8223, 0.8331] | [0.158, 0.185] |
| GF(7) random, with replacement | 5 | [0.860, 0.863] | [0.705, 0.719] | [0.9374, 0.9416] | [0.150, 0.217] |
| GF(7) random, no replacement | 5 | [0.857, 0.863] | [0.818, 0.837] | [0.9522, 0.9563] | [0.078, 0.123] |

## n = 10, rank 5 ICARM cluster pilot

Here $c_{r,n}=16/25\approx0.640000$ and $D_{\mathrm{cap}}=13/18\approx0.722222$.

### Coverage and the deletion bound

| Ensemble | Primary N | $d_B$ range | High-density N (%) | Outside-cap N (%) | Median $E_{\mathrm{del}}$ | 95% $E_{\mathrm{del}}$ | Maximum $E_{\mathrm{del}}$ | Bound violations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| ICARM cluster pilot | 12800 | [0.8373, 0.9603] | 12800 (100.0%) | 0 (0.0%) | 0.3500 | 0.5411 | 0.8152 | 0 |

### Log-coordinate association and observed frontiers

| Ensemble | Population | N | Spearman $\rho_{\mathrm S}(C,R)$ | OLS slope $R$ on $C$ | Distinct profiles | Pareto | Supported vertices | Sparse-only Pareto |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| ICARM cluster pilot | all | 12800 | +0.305 | +1.131 | 703 | 10 | 3 | 8 |
| ICARM cluster pilot | outside cap | 0 | — | — | 0 | 0 | 0 | 0 |

![Observed cost-reward frontier for n10_r5_icarm](../figures/j_gamma_analysis/n10_r5_icarm_frontier.png)

The next plot discards $D>D_{\mathrm{cap}}$. An empty panel means that the source law supplied no observations in the sensitivity region.

![Outside-cap cost-reward frontier for n10_r5_icarm](../figures/j_gamma_analysis/n10_r5_icarm_frontier_outside_cap.png)

### Scalarization and penalty sensitivity

| Ensemble | Population | Median $\mathcal J_{1/2}$ | Median $\mathcal J_1$ | Median $\mathcal J_2$ | $P(\mathcal J_{1/2}>1)$ | $P(\mathcal J_1>1)$ | $P(\mathcal J_2>1)$ | 95% $\mathcal J_1$ | Max $\mathcal J_1$ | $\rho_{\mathrm S}(d_B,\mathcal J_1)$ | $\rho_{\mathrm S}(\overline{\alpha},\mathcal J_1)$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ICARM cluster pilot | all | 1.0758 | 1.0306 | 0.9568 | 100.0% | 92.6% | 8.7% | 1.0828 | 1.2112 | +0.030 | +0.918 |
| ICARM cluster pilot | outside cap | — | — | — | — | — | — | — | — | — | — |

![Penalty sensitivity for n10_r5_icarm](../figures/j_gamma_analysis/n10_r5_icarm_gamma_sensitivity.png)

### Critical exponent and worst-pair robustness

| Ensemble | Population | $\gamma_*$ N | Median $\gamma_*$ | 90% $\gamma_*$ | 95% $\gamma_*$ | Maximum $\gamma_*$ | Median $Q_{0.9}/\overline{\alpha}$ | Top-$\mathcal J_1$ median $Q_{0.9}/\overline{\alpha}$ | $\rho_{\mathrm S}(\mathcal J_1,\mathcal J_{1,q90})$ | Top-$\mathcal J_1$ median relative alpha gap |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ICARM cluster pilot | all | 12800 | 1.4505 | 1.9468 | 2.1432 | 3.3171 | 0.9648 | 0.9031 | +0.335 | 0.0438 |
| ICARM cluster pilot | outside cap | 0 | — | — | — | — | — | — | — | — |

## n = 12, rank 6 finite-field and Johnson-graph data

Here $c_{r,n}=25/36\approx0.694444$ and $D_{\mathrm{cap}}=8/11\approx0.727273$.

### Coverage and the deletion bound

| Ensemble | Primary N | $d_B$ range | High-density N (%) | Outside-cap N (%) | Median $E_{\mathrm{del}}$ | 95% $E_{\mathrm{del}}$ | Maximum $E_{\mathrm{del}}$ | Bound violations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 82408 | [0.0920, 0.5974] | 0 (0.0%) | 82408 (100.0%) | — | — | — | 0 |
| GF(2) random, no replacement | 93645 | [0.2424, 0.5974] | 0 (0.0%) | 93645 (100.0%) | — | — | — | 0 |
| GF(3) random, with replacement | 98368 | [0.1807, 0.7532] | 176 (0.2%) | 98192 (99.8%) | 0.0484 | 0.0707 | 0.0801 | 0 |
| GF(3) random, no replacement | 98732 | [0.2522, 0.7652] | 211 (0.2%) | 98521 (99.8%) | 0.0481 | 0.0673 | 0.0871 | 0 |
| GF(5) random, with replacement | 99915 | [0.3777, 0.8745] | 78242 (78.3%) | 21673 (21.7%) | 0.1322 | 0.1781 | 0.2588 | 0 |
| GF(5) random, no replacement | 99927 | [0.3355, 0.8658] | 79731 (79.8%) | 20196 (20.2%) | 0.1320 | 0.1779 | 0.2981 | 0 |
| GF(7) random, with replacement | 99990 | [0.4340, 0.9134] | 98085 (98.1%) | 1905 (1.9%) | 0.1929 | 0.2449 | 0.3427 | 0 |
| GF(7) random, no replacement | 99992 | [0.4729, 0.9134] | 98552 (98.6%) | 1440 (1.4%) | 0.1926 | 0.2448 | 0.3483 | 0 |
| Johnson greedy p = 0.01 | 25000 | [0.9784, 1.0000] | 25000 (100.0%) | 0 (0.0%) | 0.7722 | 0.9970 | 1.0000 | 0 |
| Johnson greedy p = 0.05 | 25000 | [0.9589, 0.9848] | 25000 (100.0%) | 0 (0.0%) | 0.3819 | 0.5455 | 0.8742 | 0 |
| Johnson greedy p = 0.2 | 25000 | [0.9383, 0.9610] | 25000 (100.0%) | 0 (0.0%) | 0.2095 | 0.2894 | 0.4508 | 0 |
| Johnson greedy p = 1 | 25000 | [0.9156, 0.9372] | 25000 (100.0%) | 0 (0.0%) | 0.1172 | 0.1657 | 0.2587 | 0 |

### Log-coordinate association and observed frontiers

| Ensemble | Population | N | Spearman $\rho_{\mathrm S}(C,R)$ | OLS slope $R$ on $C$ | Distinct profiles | Pareto | Supported vertices | Sparse-only Pareto |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | all | 82408 | -0.252 | -0.018 | 1670 | 6 | 5 | 0 |
| GF(2) random, with replacement | outside cap | 82408 | -0.252 | -0.018 | 1670 | 6 | 5 | 0 |
| GF(2) random, no replacement | all | 93645 | -0.011 | +0.022 | 500 | 6 | 4 | 0 |
| GF(2) random, no replacement | outside cap | 93645 | -0.011 | +0.022 | 500 | 6 | 4 | 0 |
| GF(3) random, with replacement | all | 98368 | +0.606 | +0.143 | 61850 | 16 | 5 | 0 |
| GF(3) random, with replacement | outside cap | 98192 | +0.604 | +0.141 | 61753 | 11 | 5 | 0 |
| GF(3) random, no replacement | all | 98732 | +0.661 | +0.218 | 56598 | 13 | 6 | 0 |
| GF(3) random, no replacement | outside cap | 98521 | +0.659 | +0.215 | 56488 | 7 | 4 | 0 |
| GF(5) random, with replacement | all | 99915 | +0.842 | +0.465 | 83195 | 40 | 11 | 0 |
| GF(5) random, with replacement | outside cap | 21673 | +0.372 | +0.143 | 21157 | 11 | 6 | 0 |
| GF(5) random, no replacement | all | 99927 | +0.841 | +0.523 | 82524 | 31 | 9 | 0 |
| GF(5) random, no replacement | outside cap | 20196 | +0.417 | +0.192 | 19704 | 12 | 6 | 0 |
| GF(7) random, with replacement | all | 99990 | +0.870 | +0.712 | 62700 | 42 | 9 | 0 |
| GF(7) random, with replacement | outside cap | 1905 | +0.028 | +0.062 | 1894 | 7 | 5 | 0 |
| GF(7) random, no replacement | all | 99992 | +0.868 | +0.768 | 62545 | 50 | 11 | 0 |
| GF(7) random, no replacement | outside cap | 1440 | +0.124 | +0.092 | 1433 | 7 | 4 | 0 |
| Johnson greedy p = 0.01 | all | 25000 | +0.624 | +1.707 | 222 | 15 | 5 | 15 |
| Johnson greedy p = 0.01 | outside cap | 0 | — | — | 0 | 0 | 0 | 0 |
| Johnson greedy p = 0.05 | all | 25000 | +0.143 | +0.419 | 979 | 9 | 5 | 9 |
| Johnson greedy p = 0.05 | outside cap | 0 | — | — | 0 | 0 | 0 | 0 |
| Johnson greedy p = 0.2 | all | 25000 | -0.002 | +0.108 | 944 | 5 | 4 | 5 |
| Johnson greedy p = 0.2 | outside cap | 0 | — | — | 0 | 0 | 0 | 0 |
| Johnson greedy p = 1 | all | 25000 | -0.002 | +0.167 | 607 | 6 | 5 | 6 |
| Johnson greedy p = 1 | outside cap | 0 | — | — | 0 | 0 | 0 | 0 |

![Observed cost-reward frontier for n12_r6](../figures/j_gamma_analysis/n12_r6_frontier.png)

The next plot discards $D>D_{\mathrm{cap}}$. An empty panel means that the source law supplied no observations in the sensitivity region.

![Outside-cap cost-reward frontier for n12_r6](../figures/j_gamma_analysis/n12_r6_frontier_outside_cap.png)

### Scalarization and penalty sensitivity

| Ensemble | Population | Median $\mathcal J_{1/2}$ | Median $\mathcal J_1$ | Median $\mathcal J_2$ | $P(\mathcal J_{1/2}>1)$ | $P(\mathcal J_1>1)$ | $P(\mathcal J_2>1)$ | 95% $\mathcal J_1$ | Max $\mathcal J_1$ | $\rho_{\mathrm S}(d_B,\mathcal J_1)$ | $\rho_{\mathrm S}(\overline{\alpha},\mathcal J_1)$ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | all | 0.8684 | 0.5150 | 0.1825 | 10.7% | 0.0% | 0.0% | 0.7133 | 0.8511 | +0.990 | +0.364 |
| GF(2) random, with replacement | outside cap | 0.8684 | 0.5150 | 0.1825 | 10.7% | 0.0% | 0.0% | 0.7133 | 0.8511 | +0.990 | +0.364 |
| GF(2) random, no replacement | all | 0.9554 | 0.6247 | 0.2660 | 28.1% | 0.0% | 0.0% | 0.7487 | 0.8511 | +0.970 | +0.225 |
| GF(2) random, no replacement | outside cap | 0.9554 | 0.6247 | 0.2660 | 28.1% | 0.0% | 0.0% | 0.7487 | 0.8511 | +0.970 | +0.225 |
| GF(3) random, with replacement | all | 1.0506 | 0.8121 | 0.4755 | 74.7% | 0.0% | 0.0% | 0.9051 | 1.0745 | +0.939 | -0.335 |
| GF(3) random, with replacement | outside cap | 1.0507 | 0.8118 | 0.4753 | 74.7% | 0.0% | 0.0% | 0.9050 | 1.0745 | +0.939 | -0.332 |
| GF(3) random, no replacement | all | 1.0611 | 0.8293 | 0.5011 | 86.7% | 0.0% | 0.0% | 0.9091 | 1.0745 | +0.901 | -0.311 |
| GF(3) random, no replacement | outside cap | 1.0612 | 0.8291 | 0.5008 | 86.7% | 0.0% | 0.0% | 0.9090 | 1.0745 | +0.901 | -0.309 |
| GF(5) random, with replacement | all | 1.0910 | 0.9588 | 0.7468 | 99.2% | 8.2% | 0.0% | 1.0077 | 1.0983 | +0.547 | -0.073 |
| GF(5) random, with replacement | outside cap | 1.0929 | 0.9112 | 0.6348 | 96.2% | 0.5% | 0.0% | 0.9697 | 1.0362 | +0.778 | +0.199 |
| GF(5) random, no replacement | all | 1.0916 | 0.9592 | 0.7479 | 99.7% | 8.3% | 0.0% | 1.0080 | 1.1145 | +0.525 | -0.044 |
| GF(5) random, no replacement | outside cap | 1.0961 | 0.9149 | 0.6404 | 98.3% | 0.5% | 0.0% | 0.9701 | 1.0490 | +0.726 | +0.226 |
| GF(7) random, with replacement | all | 1.0853 | 0.9946 | 0.8442 | 100.0% | 40.3% | 0.0% | 1.0339 | 1.1137 | +0.125 | +0.308 |
| GF(7) random, with replacement | outside cap | 1.0760 | 0.8971 | 0.6211 | 97.7% | 0.7% | 0.0% | 0.9657 | 1.0534 | +0.854 | +0.433 |
| GF(7) random, no replacement | all | 1.0852 | 0.9946 | 0.8443 | 100.0% | 40.1% | 0.0% | 1.0337 | 1.1078 | +0.112 | +0.327 |
| GF(7) random, no replacement | outside cap | 1.0907 | 0.9151 | 0.6468 | 99.0% | 1.0% | 0.0% | 0.9700 | 1.0509 | +0.771 | +0.458 |
| Johnson greedy p = 0.01 | all | 1.0209 | 1.0176 | 1.0077 | 100.0% | 100.0% | 95.8% | 1.0237 | 1.0419 | -0.374 | +0.944 |
| Johnson greedy p = 0.01 | outside cap | — | — | — | — | — | — | — | — | — | — |
| Johnson greedy p = 0.05 | all | 1.0274 | 1.0118 | 0.9858 | 100.0% | 95.1% | 6.6% | 1.0270 | 1.0517 | +0.180 | +0.932 |
| Johnson greedy p = 0.05 | outside cap | — | — | — | — | — | — | — | — | — | — |
| Johnson greedy p = 0.2 | all | 1.0178 | 0.9910 | 0.9414 | 99.3% | 19.6% | 0.0% | 1.0063 | 1.0406 | +0.248 | +0.959 |
| Johnson greedy p = 0.2 | outside cap | — | — | — | — | — | — | — | — | — | — |
| Johnson greedy p = 1 | all | 0.9986 | 0.9612 | 0.8904 | 46.2% | 0.0% | 0.0% | 0.9762 | 1.0042 | +0.231 | +0.963 |
| Johnson greedy p = 1 | outside cap | — | — | — | — | — | — | — | — | — | — |

![Penalty sensitivity for n12_r6](../figures/j_gamma_analysis/n12_r6_gamma_sensitivity.png)

### Critical exponent and worst-pair robustness

| Ensemble | Population | $\gamma_*$ N | Median $\gamma_*$ | 90% $\gamma_*$ | 95% $\gamma_*$ | Maximum $\gamma_*$ | Median $Q_{0.9}/\overline{\alpha}$ | Top-$\mathcal J_1$ median $Q_{0.9}/\overline{\alpha}$ | $\rho_{\mathrm S}(\mathcal J_1,\mathcal J_{1,q90})$ | Top-$\mathcal J_1$ median relative alpha gap |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | all | 82408 | 0.3633 | 0.5049 | 0.5340 | 0.7269 | 0.9646 | 0.9176 | +0.985 | 0.0290 |
| GF(2) random, with replacement | outside cap | 82408 | 0.3633 | 0.5049 | 0.5340 | 0.7269 | 0.9646 | 0.9176 | +0.985 | 0.0290 |
| GF(2) random, no replacement | all | 93645 | 0.4473 | 0.5430 | 0.5711 | 0.7269 | 0.9417 | 0.8943 | +0.952 | 0.0340 |
| GF(2) random, no replacement | outside cap | 93645 | 0.4473 | 0.5430 | 0.5711 | 0.7269 | 0.9417 | 0.8943 | +0.952 | 0.0340 |
| GF(3) random, with replacement | all | 98368 | 0.5984 | 0.7249 | 0.7601 | 1.2106 | 0.9299 | 0.8947 | +0.944 | 0.0348 |
| GF(3) random, with replacement | outside cap | 98192 | 0.5984 | 0.7249 | 0.7601 | 1.2106 | 0.9299 | 0.8946 | +0.944 | 0.0348 |
| GF(3) random, no replacement | all | 98732 | 0.6207 | 0.7359 | 0.7700 | 1.2106 | 0.9262 | 0.8922 | +0.908 | 0.0362 |
| GF(3) random, no replacement | outside cap | 98521 | 0.6208 | 0.7360 | 0.7700 | 1.2106 | 0.9262 | 0.8921 | +0.908 | 0.0362 |
| GF(5) random, with replacement | all | 99915 | 0.8324 | 0.9866 | 1.0324 | 1.4273 | 0.9322 | 0.8949 | +0.607 | 0.0428 |
| GF(5) random, with replacement | outside cap | 21673 | 0.7433 | 0.8723 | 0.9092 | 1.1044 | 0.9319 | 0.8957 | +0.815 | 0.0364 |
| GF(5) random, no replacement | all | 99927 | 0.8342 | 0.9869 | 1.0335 | 1.5738 | 0.9317 | 0.8947 | +0.586 | 0.0433 |
| GF(5) random, no replacement | outside cap | 20196 | 0.7524 | 0.8749 | 0.9104 | 1.1423 | 0.9306 | 0.8953 | +0.765 | 0.0368 |
| GF(7) random, with replacement | all | 99990 | 0.9675 | 1.1430 | 1.1949 | 1.6492 | 0.9427 | 0.9078 | +0.320 | 0.0395 |
| GF(7) random, with replacement | outside cap | 1905 | 0.7010 | 0.8569 | 0.8947 | 1.1604 | 0.9455 | 0.9102 | +0.884 | 0.0310 |
| GF(7) random, no replacement | all | 99992 | 0.9674 | 1.1426 | 1.1952 | 1.6349 | 0.9427 | 0.9076 | +0.310 | 0.0392 |
| GF(7) random, no replacement | outside cap | 1440 | 0.7489 | 0.8726 | 0.9087 | 1.1538 | 0.9385 | 0.9080 | +0.821 | 0.0294 |
| Johnson greedy p = 0.01 | all | 24999 | 2.8735 | 3.6832 | 3.6866 | 3.7045 | 0.9912 | 0.9825 | -0.046 | 0.0088 |
| Johnson greedy p = 0.01 | outside cap | 0 | — | — | — | — | — | — | — | — |
| Johnson greedy p = 0.05 | all | 25000 | 1.4636 | 1.9003 | 2.0736 | 3.3035 | 0.9822 | 0.9649 | +0.213 | 0.0177 |
| Johnson greedy p = 0.05 | outside cap | 0 | — | — | — | — | — | — | — | — |
| Johnson greedy p = 0.2 | all | 25000 | 0.8300 | 1.0626 | 1.1324 | 1.7794 | 0.9818 | 0.9640 | +0.278 | 0.0181 |
| Johnson greedy p = 0.2 | outside cap | 0 | — | — | — | — | — | — | — | — |
| Johnson greedy p = 1 | all | 25000 | 0.4820 | 0.6330 | 0.6805 | 1.0561 | 0.9814 | 0.9721 | +0.268 | 0.0186 |
| Johnson greedy p = 1 | outside cap | 0 | — | — | — | — | — | — | — | — |

### Independent-seed stability

| Ensemble | Replicates | $\rho_{\mathrm S}(C,R)$ range | OLS slope range | $P(\mathcal J_1>1)$ range | Outside-cap $\rho_{\mathrm S}(C,R)$ range |
|---|---:|---:|---:|---:|---:|
| GF(2) random, with replacement | 5 | [-0.255, -0.248] | [-0.018, -0.017] | [0.0000, 0.0000] | [-0.255, -0.248] |
| GF(2) random, no replacement | 5 | [-0.020, 0.008] | [0.019, 0.026] | [0.0000, 0.0000] | [-0.020, 0.008] |
| GF(3) random, with replacement | 5 | [0.603, 0.610] | [0.141, 0.144] | [0.0000, 0.0002] | [0.601, 0.608] |
| GF(3) random, no replacement | 5 | [0.656, 0.668] | [0.217, 0.219] | [0.0000, 0.0002] | [0.653, 0.666] |
| GF(5) random, with replacement | 5 | [0.839, 0.845] | [0.456, 0.474] | [0.0802, 0.0839] | [0.342, 0.385] |
| GF(5) random, no replacement | 5 | [0.838, 0.845] | [0.518, 0.533] | [0.0812, 0.0865] | [0.400, 0.434] |
| GF(7) random, with replacement | 5 | [0.870, 0.871] | [0.703, 0.717] | [0.3999, 0.4063] | [0.007, 0.085] |
| GF(7) random, no replacement | 5 | [0.866, 0.870] | [0.752, 0.781] | [0.3986, 0.4056] | [0.098, 0.174] |
| Johnson greedy p = 0.01 | 5 | [0.613, 0.631] | [1.686, 1.718] | [0.9998, 1.0000] | — |
| Johnson greedy p = 0.05 | 5 | [0.136, 0.154] | [0.404, 0.449] | [0.9492, 0.9534] | — |
| Johnson greedy p = 0.2 | 5 | [-0.012, 0.004] | [0.084, 0.134] | [0.1910, 0.2002] | — |
| Johnson greedy p = 1 | 5 | [-0.019, 0.007] | [0.133, 0.192] | [0.0000, 0.0006] | — |

## Optional background references

The report is intended to be readable without these sources. They are listed for readers who want a systematic introduction.

- James Oxley, *Matroid Theory*, second edition, Chapter 4, for matroid connectivity, separations, loops, coloops, and duality.
- [OpenStax, *Introductory Statistics*, Chapter 2](https://openstax.org/books/introductory-statistics/pages/2-introduction), for distributions, medians, percentiles, and histograms.
- [OpenStax, *Introductory Statistics 2e*, Sections 12.2–12.3](https://openstax.org/books/introductory-statistics-2e/pages/12-2-scatter-plots), for scatter plots, association, and least-squares lines.
- [University of Texas at Austin, *Spearman's Rank Correlation*](https://sites.utexas.edu/sos/guided/inferential/numeric/bivariate/rankcor/), for a short worked example based on ranks.
- [Seeing Theory](https://seeing-theory.brown.edu/), an archived interactive visual introduction to probability, distributions, and regression.
- Stephen Boyd and Lieven Vandenberghe, [*Convex Optimization*, Section 4.7](https://web.stanford.edu/~boyd/cvxbook/), for the more advanced general theory of several competing objectives, Pareto optimality, and scalarization.
- Thomas Cover and Joy Thomas, *Elements of Information Theory*, Chapter 2, for entropy and Kullback–Leibler divergence. This is optional here: the elementary identity $C=-\log D$ is all that the analysis uses.

## Reproducibility and compact outputs

- [`j_gamma_summary.csv`](../data/j_gamma_analysis/j_gamma_summary.csv)
- [`j_gamma_frontiers.csv`](../data/j_gamma_analysis/j_gamma_frontiers.csv)
- [`j_gamma_extrema.csv`](../data/j_gamma_analysis/j_gamma_extrema.csv)

The summary export has one row per ensemble and population definition. The frontier export retains only distinct observed Pareto profiles, and the extrema export retains the three requested scalar-score maximizers. No per-matroid score table is stored. All scores can be reconstructed from $n,r,|\mathcal B|,$ and the exact stored numerator and denominator of $\overline{\alpha}$.

Data sources:

- n = 8, rank 4 validation data: [`results.sqlite`](../data/n8_r4_compact/results.sqlite)
- n = 9, rank 3 exact census: [`results.sqlite`](../data/n9_census/results.sqlite)
- n = 9, rank 4 exact census: [`results.sqlite`](../data/n9_census/results.sqlite)
- n = 10, rank 4 finite-field data: [`results.sqlite.zst`](../data/n10_finite_fields/r4/results.sqlite.zst)
- n = 10, rank 4 ICARM class-uniform sample: [`results.sqlite`](../data/icarm_n10/r4/results.sqlite)
- n = 10, rank 5 finite-field data: [`results.sqlite`](../data/n10_finite_fields/r5/results.sqlite)
- n = 10, rank 5 ICARM cluster pilot: [`results.sqlite`](../data/icarm_n10/r5/results.sqlite)
- n = 12, rank 6 finite-field and Johnson-graph data: [`results.sqlite`](../data/n12_finite_fields/r6/results.sqlite)
