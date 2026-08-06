Yes. The cleanest way to combine the two quantities is to regard this as a **two-objective extremal problem**:

$$
\text{maximize }\alpha_0(M)
\qquad\text{and}\qquad
\text{maximize }d_B(M).
$$

There is no completely canonical way to collapse two objectives to one number without choosing an exchange rate between them. Nevertheless, there is a particularly natural family of joint invariants, and it has both a probabilistic interpretation and a useful extremal theory.

Throughout, put

$$
\delta(M):=d_B(M)=\frac{|\mathcal B(M)|}{\binom nr},
\qquad
s:=n-r,
$$

and, in the nondegenerate range $2\le r\le n-2$, let

$$
\lambda_{r,n}
:=
\alpha_0(U_{r,n})
=
\frac{(r-1)(s-1)}{rs}.
$$

Since the uniform matroid is the natural reference point, I would usually normalize

$$
\rho(M):=\frac{\alpha_0(M)}{\lambda_{r,n}}.
$$

For a fixed pair $(r,n)$, replacing $\rho$ by $\alpha_0$ only multiplies every score below by the same constant. The normalization matters mainly when comparing different ranks and ground-set sizes.

## 1. The natural coordinates are logarithmic

There is a useful information-theoretic interpretation of density.

Let

$$
\Omega_{r,n}=\binom{[n]}r,
$$

let $\nu$ be the uniform probability measure on $\Omega_{r,n}$, and let $\mu_M$ be the uniform probability measure on $\mathcal B(M)$. Then

$$
\mu_M=\nu(\,\cdot\,\mid \mathcal B(M)).
$$

Consequently,

$$
\begin{aligned}
D_{\mathrm{KL}}(\mu_M\Vert\nu)
&=
\sum_{B\in\mathcal B(M)}
\frac1{|\mathcal B(M)|}
\log\frac{\binom nr}{|\mathcal B(M)|}\\
&=
\log\frac{\binom nr}{|\mathcal B(M)|}\\
&=
-\log\delta(M).
\end{aligned}
$$

Thus

$$
\boxed{C(M):=-\log d_B(M)}
$$

is exactly the relative-entropy cost of restricting the uniform distribution on all $r$-sets to the basis set. Equivalently,

$$
C(M)
=
\log\binom nr-\log|\mathcal B(M)|
$$

is the loss of support entropy.

There is also a milder density cost:

$$
\lVert\mu_M-\nu\rVert_{\mathrm{TV}}=1-\delta(M).
$$

So the two most natural density penalties are

$$
C_{\mathrm{KL}}=-\log\delta
\qquad\text{and}\qquad
C_{\mathrm{TV}}=1-\delta.
$$

Meanwhile, since $\alpha_0$ is an odds ratio, its statistically natural transform is its logarithm. Relative to the uniform benchmark, put

$$
R(M):=\log\rho(M)
=
\log\frac{\alpha_0(M)}{\lambda_{r,n}}.
$$

The problem then becomes:

$$
\text{maximize reward }R(M)
\qquad\text{while minimizing cost }C(M).
$$

This is the coordinate system I would use for both theory and data analysis.

---

## 2. Primary proposal: the density-discounted correlation invariant

For a parameter $\gamma>0$, define

$$
\boxed{
\mathcal J_\gamma(M)
:=
\frac{\alpha_0(M)}{\lambda_{r,n}}\,
d_B(M)^\gamma
=
\rho(M)\,\delta(M)^\gamma.
}
$$

Equivalently,

$$
\log \mathcal J_\gamma(M)
=
R(M)-\gamma C(M).
$$

For fixed $(r,n)$, this ranks matroids in exactly the same order as

$$
\alpha_0(M)\,d_B(M)^\gamma
$$

or, since $\binom nr$ is constant, as

$$
\alpha_0(M)\,|\mathcal B(M)|^\gamma.
$$

Thus this is not merely an arbitrary product: it is the exponential of

$$
\log\alpha_0(M)+\gamma\log|\mathcal B(M)|,
$$

a weighted sum of the maximum log-odds ratio and the basis entropy.

### Interpretation of $\gamma$

The parameter $\gamma$ is an elasticity. Infinitesimally,

$$
d\log\mathcal J_\gamma
=
d\log\alpha_0+\gamma\,d\log\delta.
$$

So a $1\%$ loss in density must be offset by approximately a $\gamma\%$ increase in $\alpha_0$.

* $\gamma=1$ gives the simplest product:
  $$
  \mathcal J_1=\rho\,\delta.
  $$
* $0<\gamma<1$ is forgiving of low density.
* $\gamma>1$ penalizes density loss more severely.

The weighted geometric mean

$$
\left(\rho\,\delta^\gamma\right)^{1/(1+\gamma)}
$$

has exactly the same ordering and sometimes looks more balanced numerically.

### Desirable formal properties

The score is duality invariant:

$$
\mathcal J_\gamma(M^*)=\mathcal J_\gamma(M).
$$

Indeed, $\alpha_0$, basis density, and $\lambda_{r,n}$ are all unchanged by duality.

It is also normalized so that

$$
\mathcal J_\gamma(U_{r,n})=1.
$$

Therefore:

* a matroid with the same $\alpha_0$ as $U_{r,n}$ but lower density scores below $1$;
* a lower-density matroid beats $U_{r,n}$ exactly when its increase in $\alpha_0$ is large enough to compensate.

For example, for the free extension $F_7+\infty$ discussed earlier,

$$
\alpha_0(F_7+\infty)=\lambda_{3,8}=\frac8{15},
\qquad
d_B(F_7+\infty)=\frac{49}{56}=\frac78.
$$

Hence

$$
\mathcal J_\gamma(F_7+\infty)
=
\left(\frac78\right)^\gamma<1.
$$

So the joint invariant distinguishes $F_7+\infty$ from the uniform matroid even though their unweighted $\alpha_0$'s agree.

### Main drawback

The choice of $\gamma$ is substantive. There is no universal mathematical reason that the exchange rate between a percentage loss in density and a percentage gain in $\alpha_0$ must equal $1$.

That is not necessarily a defect: the entire family $\{\mathcal J_\gamma\}_{\gamma>0}$ contains more information than one arbitrarily selected member.

---

## 3. A parameter-free derivative: the critical penalty exponent

For a nonuniform matroid with $\delta(M)<1$, define

$$
\boxed{
\gamma_*(M)
:=
\frac{\log\bigl(\alpha_0(M)/\lambda_{r,n}\bigr)}
{\log\bigl(1/d_B(M)\bigr)}.
}
$$

This has a precise interpretation:

$$
\mathcal J_\gamma(M)>1
\quad\Longleftrightarrow\quad
\gamma<\gamma_*(M),
$$

provided $\alpha_0(M)>\lambda_{r,n}$.

Thus $\gamma_*(M)$ is the **largest density-penalty exponent that the matroid can withstand while still outperforming the uniform matroid**.

This is a particularly attractive parameter-free joint invariant:

* $\gamma_*=0$ when $\alpha_0=\lambda_{r,n}$ and $d_B<1$;
* a large $\gamma_*$ means that the correlation increase is substantial relative to the entropy cost;
* it is duality invariant;
* it is the slope from the uniform point $(C,R)=(0,0)$ to the point representing $M$ in the $(C,R)$-plane.

Its weakness is that it measures **efficiency**, not absolute quality. A very small correlation improvement obtained from a very tiny density loss can have a large ratio. It should therefore be reported alongside either $R$, $C$, or $\mathcal J_1$, rather than used alone.

There is also a natural class invariant. For a class $\mathcal C_{r,n}$ of rank-$r$, $n$-element matroids, define

$$
\boxed{
\Gamma(\mathcal C_{r,n})
=
\sup_{\substack{M\in\mathcal C_{r,n}\\ d_B(M)<1}}
\frac{
\bigl[\log(\alpha_0(M)/\lambda_{r,n})\bigr]_+
}{
\log(1/d_B(M))
}.
}
$$

Then $\Gamma(\mathcal C_{r,n})$ is the smallest exponent such that

$$
\mathcal J_\gamma(M)\le1
$$

for every $M\in\mathcal C_{r,n}$ whenever $\gamma\ge\Gamma(\mathcal C_{r,n})$.

This creates concrete new extremal problems:

$$
\Gamma_{r,n}^{\mathrm{conn}},
\qquad
\Gamma_{r,n}^{\mathrm{paving}},
\qquad
\Gamma_{r,n}^{\mathrm{sparse\ paving}},
$$

together with classification of the maximizing matroids.

---

## 4. The Pareto frontier is mathematically more fundamental than any scalar score

Before choosing $\gamma$, I would define the density-correlation frontier

$$
\boxed{
A_{r,n}(\delta_0)
:=
\sup\left\{
\alpha_0(M):
\begin{array}{l}
M\text{ connected of rank }r\text{ on }n\text{ elements},\\
d_B(M)\ge\delta_0
\end{array}
\right\}.
}
$$

Equivalently, in logarithmic coordinates,

$$
F_{r,n}(c)
:=
\sup\{R(M):C(M)\le c\}.
$$

A matroid is Pareto efficient if there is no other matroid of the same $(r,n)$ having both at least as high an $\alpha_0$ and at least as high a density, with one strict.

This avoids assigning an arbitrary conversion rate between the two quantities. It is likely the best object for proving structural theorems:

* determine or bound $A_{r,n}(\delta)$;
* classify matroids on the frontier;
* compare the frontiers for paving, sparse-paving, representable, and arbitrary matroids;
* determine whether the frontier has phase transitions.

The product family is related to the frontier by

$$
\Phi_{r,n}(\gamma)
:=
\sup_M\bigl(R(M)-\gamma C(M)\bigr)
=
\log\sup_M\mathcal J_\gamma(M).
$$

As a function of $\gamma$, $\Phi_{r,n}$ is convex and nonincreasing, being a supremum of affine functions. Its breakpoints correspond to changes in the extremal matroid.

One caveat is that linear scalarization in the $(C,R)$-plane detects only points on the exposed upper convex hull. Because the set of matroids is discrete, there may be Pareto-optimal matroids that maximize no $\mathcal J_\gamma$. The constrained frontier $A_{r,n}(\delta_0)$ sees all of them.

---

## 5. A deterministic reason that high density constrains $\alpha_0$

Part of the observed anti-correlation has a simple set-system explanation; it does not even require basis exchange.

Let $\mathcal F\subseteq\binom{[n]}r$ be any family of $r$-subsets, with density

$$
\delta=\frac{|\mathcal F|}{\binom nr}.
$$

Define $\alpha_0(\mathcal F)$ from the same pairwise odds ratios. Put

$$
v_{r,n}:=\frac{r(n-r)}{n(n-1)}.
$$

### Proposition

If

$$
1-\delta<v_{r,n},
$$

then

$$
\boxed{
\frac{\alpha_0(\mathcal F)}{\lambda_{r,n}}
\le
\frac{1}{
1-\dfrac{1-\delta}{v_{r,n}}
}.
}
\tag{1}
$$

### Proof

Fix $(i,j)$. Among all $r$-subsets, the four cell sizes are

$$
A_0=\binom{n-2}{r-2},\qquad
B_0=\binom{n-2}{r-1},\qquad
B_0,\qquad
D_0=\binom{n-2}{r}.
$$

Let

$$
Q=(1-\delta)\binom nr
$$

be the total number of omitted $r$-subsets. Suppose $x$ and $y$ of the omitted sets lie in the two mixed cells. Then $x+y\le Q$, and the two remaining mixed-cell sizes satisfy

$$
\begin{aligned}
(B_0-x)(B_0-y)
&=
B_0(B_0-x-y)+xy\\
&\ge B_0(B_0-Q).
\end{aligned}
$$

The two numerator cells are at most $A_0$ and $D_0$. Therefore

$$
R_{ij}
\le
\frac{A_0D_0}{B_0(B_0-Q)}.
$$

Now

$$
\frac{A_0D_0}{B_0^2}
=
\lambda_{r,n},
$$

and

$$
\frac{B_0}{\binom nr}
=
v_{r,n}.
$$

Substitution gives (1). $\square$

Thus, near density $1$,

$$
\frac{\alpha_0}{\lambda_{r,n}}
\le
1+\frac{1-\delta}{v_{r,n}}
+O((1-\delta)^2).
$$

Equivalently, achieving an inflation factor $\rho>1$ requires

$$
\boxed{
1-\delta
\ge
v_{r,n}\left(1-\frac1\rho\right).
}
\tag{2}
$$

So at least in the high-density regime, the observed tradeoff is a theorem: a large pairwise odds ratio requires deleting a definite fraction of all $r$-subsets.

This also suggests a rank-sensitive density cost

$$
C_{\mathrm{cap}}(M)
=
-\log\left(
1-\frac{1-d_B(M)}{v_{r,n}}
\right),
$$

defined when $1-d_B<v_{r,n}$. By (1),

$$
\log\rho(M)\le C_{\mathrm{cap}}(M).
$$

One can therefore define the **deletion-efficiency statistic**

$$
\boxed{
\Theta(M)
=
\frac{\log\rho(M)}
{
-\log\left(1-\dfrac{1-d_B(M)}{v_{r,n}}\right)
}.
}
$$

When $\rho\ge1$, this lies in $[0,1]$ in the high-density regime. It measures how much of the maximum correlation inflation permitted by the mere deletion budget is actually realized.

This is an excellent diagnostic, although it is more a density-adjusted efficiency than a welfare score: it does not by itself favor high density.

---

## 6. Other reasonable scalarizations

Let $R=\log\rho$, $C=-\log\delta$, and $q=1-\delta$.

| Joint quantity | Interpretation | Advantages | Main drawback |
| --- | --- | --- | --- |
| $\rho\delta^\gamma$ | Multiplicative reward minus entropy cost | Natural for odds ratios; elasticity interpretation; dual invariant; uniform score $1$ | Requires choosing $\gamma$ |
| $R-\eta q$ | Log-correlation premium minus missing-basis fraction | Mild penalty; transparent near $\delta=1$ | Barely penalizes extremely low densities |
| $\delta^\gamma(\rho-1)$ or $\delta^\gamma R$ | Density-discounted excess over uniform | Uniform and all lower-bound achievers receive $0$; isolates genuinely increased correlation | Does not reward density when $\rho=1$; can be negative if $\rho<1$ |
| $t\rho+(1-t)\delta$ | Linear compromise | Simple and visually interpretable | The two scales are not intrinsically comparable; the weight is coordinate-dependent |
| $\gamma_* = R/C$ | Correlation gain per unit entropy loss | Parameter-free; clear break-even meaning | Can be unstable near $(R,C)=(0,0)$; measures efficiency rather than absolute quality |

### Additive scores

A raw score such as

$$
\alpha_0+d_B
$$

implicitly declares that one unit of odds ratio is worth one unit of basis density. That has no natural statistical justification. It is especially problematic across different $(r,n)$, because the uniform benchmark $\lambda_{r,n}$ changes.

A better additive version would be

$$
S_t(M)
=
t\,\widetilde\alpha(M)+(1-t)\,\delta(M),
$$

where $\widetilde\alpha$ has first been normalized to a common scale.

For example, Huh–Schröter–Wang, Theorem 5, together with duality, gives

$$
\alpha_0(M)
\le
\Upsilon_{r,n}
:=
2\left(1-\frac1{\min\{r,n-r\}}\right).
$$

Thus one could take $\widetilde\alpha=\alpha_0/\Upsilon_{r,n}$. The universal bound comes from their weighted correlation inequality, of which $\alpha_0$ is the constant-weight specialization. ([arXiv][1])

The drawback is that $\Upsilon_{r,n}$ is often a loose upper bound, so normalization can compress the $\alpha_0$-values.

### Harmonic or bottleneck scores

Once $\widetilde\alpha,\delta\in[0,1]$, one could use

$$
H_t(M)
=
\left(
\frac{t}{\widetilde\alpha(M)}
+
\frac{1-t}{\delta(M)}
\right)^{-1}.
$$

This punishes an imbalance more strongly than an arithmetic or geometric mean. It is appropriate when a very poor value in either coordinate should be nearly disqualifying.

Its weakness is that the result depends heavily on how $\alpha_0$ is normalized. I would regard it as a presentation or ranking statistic, not the primary mathematical invariant.

---

## 7. What the proposed scores do on known examples

Consider three examples.

$$
\begin{array}{c|c|c|c|c}
M & d_B(M) & \rho(M) & \mathcal J_1(M) & \gamma_*(M)\\
\hline
U_{3,8} & 1 & 1 & 1 & \text{special}\\
F_7+\infty & 7/8 & 1 & 7/8 & 0
\end{array}
$$

Thus $\mathcal J_1$ ranks the uniform matroid above the free extension, although they have the same $\alpha_0$.

For Jerrum's rank-$6$, $24$-element paving example, the displayed pair has the four cell counts

$$
7315,\quad22638,\quad22638,\quad72149.
$$

Their sum is $124740$, so

$$
d_B(M)
=
\frac{124740}{\binom{24}{6}}
=
\frac{405}{437}
\approx0.926773.
$$

The displayed pair ratio is

$$
\frac{89015}{86436}
\approx1.029837,
$$

whereas

$$
\lambda_{6,24}=\frac{85}{108}\approx0.787037.
$$

Therefore

$$
\rho(M)\ge
\frac{53409}{40817}
\approx1.308499,
$$

and

$$
\mathcal J_1(M)
\ge
1.308499\cdot0.926773
\approx1.212682.
$$

So under the $\gamma=1$ product, the correlation premium more than compensates for the roughly $7.3\%$ density loss. Its break-even exponent satisfies

$$
\gamma_*(M)\ge3.536.
$$

Thus this example would continue to outperform the uniform matroid under any density exponent below approximately $3.536$. The counts and paving construction are Huh–Schröter–Wang, Example 4. ([arXiv][1])

This comparison illustrates why $\gamma_*$ is informative: $F_7+\infty$ gains no correlation from its missing bases, while the Jerrum matroid gains correlation efficiently enough to survive a fairly severe density penalty.

---

## 8. Statistical treatment of catalogue data

For actual data analysis, I would not begin by computing a single composite score. I would first analyze

$$
X(M)=-\log d_B(M),
\qquad
Y(M)=\log\frac{\alpha_0(M)}{\lambda_{r,n}}.
$$

### Stratify by $(r,n)$

Raw $\alpha_0$-values should not be pooled indiscriminately across ranks and ground-set sizes. Both the uniform benchmark and the number of element pairs vary with $(r,n)$.

At minimum, one should either:

* analyze each $(r,n)$ separately, or
* use $Y=\log(\alpha_0/\lambda_{r,n})$ and include $(r,n)$ as covariates.

For asymptotic comparisons across growing $n$, the entropy cost may also be normalized as

$$
\frac{-\log d_B(M)}{n}
$$

or

$$
\frac{-\log d_B(M)}{\log\binom nr}.
$$

The second quantity is the proportion of the maximal possible support-entropy deficit.

### Use the frontier or upper quantiles

Because $\alpha_0$ is an extremal statistic, the upper envelope is more relevant than the conditional mean. I would estimate:

$$
\sup\left\{
Y(M):X(M)\le x
\right\},
$$

or a high conditional quantile of $Y$ given $X$, rather than only fitting least squares.

If the observed relationship is approximately

$$
Y\approx a+\beta X,
$$

then $\beta$ gives a data-driven choice of penalty exponent:

$$
Y-\beta X=\log\mathcal J_\beta.
$$

* $\gamma=\beta$ removes the typical density trend;
* $\gamma>\beta$ penalizes low density more strongly than the observed trend;
* $\gamma<\beta$ emphasizes correlation gain.

The resulting residual is statistically useful but is not an intrinsic matroid invariant, because it depends on the sampled population.

### Be careful about how matroids are sampled

A statistical statement about "random matroids in a catalogue" depends on whether one weights:

* each isomorphism class equally, or
* each labeled matroid equally.

An isomorphism class $M$ represents

$$
\frac{n!}{|\operatorname{Aut}(M)|}
$$

labeled matroids. The two weighting schemes can produce noticeably different correlations between density and $\alpha_0$.

It is also worth stratifying by structural class—paving, sparse paving, representable, binary, and so forth—because an aggregate trend may reflect differing mixtures of classes rather than a within-class phenomenon.

### The maximum-over-pairs issue

The invariant $\alpha_0$ is determined by one worst pair. As $n$ increases, there are more pairs over which to maximize, and a single exceptional pair can dominate.

For statistical robustness, let $R_{ef}$ be the unweighted odds ratio for the pair $e,f$, and define

$$
\alpha_p(M)
=
\left(
\frac1{\binom n2}
\sum_{e<f}R_{ef}^{\,p}
\right)^{1/p}.
$$

Then

$$
\lim_{p\to\infty}\alpha_p(M)=\alpha_0(M).
$$

The quantities $\alpha_4,\alpha_8$, or the average of the largest $5\%$ of the $R_{ef}$'s, reveal whether high correlation is widespread or concentrated in one pair. One can form

$$
\mathcal J_{\gamma,p}(M)
=
\frac{\alpha_p(M)}{\lambda_{r,n}}\,
d_B(M)^\gamma
$$

as a robust companion to $\mathcal J_\gamma$.

---

## Recommendation

For the mathematical theory, I would use the following three-level package.

The primary two-dimensional object should be the **density-correlation Pareto frontier**

$$
A_{r,n}(\delta_0)
=
\sup\{\alpha_0(M):d_B(M)\ge\delta_0\}.
$$

The primary scalar family should be

$$
\boxed{
\mathcal J_\gamma(M)
=
\frac{\alpha_0(M)}{\alpha_0(U_{r,n})}\,
d_B(M)^\gamma.
}
$$

The parameter-free secondary invariant should be

$$
\boxed{
\gamma_*(M)
=
\frac{
\log\!\left(\alpha_0(M)/\alpha_0(U_{r,n})\right)
}{
\log\!\left(1/d_B(M)\right)
}.
}
$$

For an initial computational study, I would report $\mathcal J_\gamma$ at

$$
\gamma=\frac12,\quad1,\quad2,
$$

together with $\gamma_*$ and Pareto status. This would reveal whether any conclusions are robust to the choice of density penalty, rather than being artifacts of one scalarization.

[1]: https://arxiv.org/pdf/1806.02675 "https://arxiv.org/pdf/1806.02675"
