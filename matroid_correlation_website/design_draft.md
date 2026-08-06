# Leaderboard-style website for correlation ratios of matroids (draft)

## Definitions
Let $M$ be a matroid on $[n] = \{1, \dotsc, n\}$.  For elements $i,j\in [n]$, let us denote:

$$
\begin{align*}
B^{ij}(M) &:=  \{ B \text{ a basis of } M : B \not\ni i \text{ and } B \not\ni j \}, \\
B_{ij}(M) &:= \{ B \text{ a basis of } M : B \ni i \text{ and } B \ni j \}, \text{ and}\\
B^i_j(M) &:=  \{ B \text{ a basis of } M : B \not\ni i \text{ and } B \ni j \} .
\end{align*}
$$
and define
$$
R_{ij}(M) := \frac{|B^{ij}(M)| \cdot |B_{ij}(M)|}{|B^i_j(M)| \cdot |B^j_i(M)|}.
$$

The *(unweighted) correlation ratio* of the matroid $M$, which we denote $\overline{\alpha}(M)$, is defined as

$$
\overline{\alpha}(M) := \max_{i\neq j} R_{ij}(M)
$$

where $i\neq j\in [n]$ ranges over all non-loop and non-coloop elements of $M$.
More generally, by replacing $|B^{ij}(M)|$ by $B^{ij}(M,w) := \sum_{B\in B^{ij}(M)} \prod_{i\in B} w_i$ (and likewise for the other quantities), one can define the *weighted correlation ratio* of $M$, denoted $\alpha(M)$ to be

$$

\alpha(M) := \max_{i\neq j, w\in \mathbb{R}_{> 0}^n} R_{ij}(M,w)

$$

where $i\neq j\in [n]$ ranges over all non-loop and non-coloop elements of $M$ and $w$ is a positive weight vector.  If $M$ consists only of loops and coloops, we set $\overline{\alpha}(M) = \alpha(M) = 0$ by definition.

We point to [HSW18](https://arxiv.org/abs/1806.02675) and references therein for background literature on correlation ratios of matroids.

**Questions:** How big can $\overline{\alpha}(M)$ be, and more generally how big can $\alpha(M)$ be?  Are there common features of matroids with property $\overline{\alpha}(M) >1$?

## Known results and records so far:

* [HSW18](https://arxiv.org/abs/1806.02675) showed $\alpha(M) \leq 2$.
* Graphical matroids are known to satisfy $\alpha(M) \leq 1$.
* Sparse paving matroids are known to satisfy $\overline{\alpha}(M) \leq 1$.
* Section 5 of the paper [HSW18](https://arxiv.org/abs/1806.02675) gives a family of matroids that achieve $\overline{\alpha}(M) = 8/7$.
* AlphaEvolve found the following example via prompting by Chris Eur and David Renshaw, which achieves $\overline{\alpha}(M) = 100/81$.
  * This example was also independently found with the help of ChatGPT by June Huh, who noted the additional structure of the matroid $M$ in that: contraction of $M$ by two elements gives a matroid corresponding to the Steiner system $S(3,4,10)$, and the linear subclasses arising in the co-extension from $S(3,4,10)$ to $M$ have a structure arising from the permutation group on 6 elements known as synthemes and duads.
  * The matroid $M$ here is the matroid of the following matrix over $GF(3)$:
$$
A = \begin{bmatrix}
1 & 2 & 1 & 2 & 2 & 2 & 1 & 1 & 0 & 0 & 1 & 2 \\
0 & 0 & 2 & 0 & 0 & 0 & 0 & 0 & 2 & 1 & 1 & 1 \\
0 & 1 & 1 & 1 & 0 & 1 & 1 & 2 & 1 & 1 & 1 & 2 \\
1 & 1 & 1 & 2 & 2 & 1 & 1 & 2 & 1 & 1 & 0 & 1 \\
0 & 1 & 0 & 1 & 2 & 1 & 1 & 0 & 2 & 0 & 1 & 0 \\
0 & 1 & 1 & 1 & 1 & 0 & 2 & 0 & 0 & 1 & 0 & 0
\end{bmatrix}
$$
* Let $N+e\times f$ be the free coextension by $f$ of the free extension by $e$ of a matroid $N$.  By considering 2-designs, like uniform matroids and affine/projective geometries, one can construct a family of matroids such that $R_{ef}((M \oplus M)+e\times f)$ approaches 4/3 from below.
  * When $M=U_{r,2r}$,

    $$
    \boxed{
    R_{ef}((M\oplus M)+e\times f)
    =
    \frac{4r^2}{3r^2+2r+1}
    }
    \longrightarrow \frac43
    \qquad (r\to\infty).
    $$

  * Use the standard convention that $\operatorname{AG}(r,q)$ has affine
    dimension $r$, rank $r+1$, and $q^r$ points.  If
    $A_r=\operatorname{AG}(r,q)$ and $q$ is fixed, then

    $$
    \boxed{
    \lim_{r\to\infty}
    R_{ef}((A_r\oplus A_r)+e\times f)
    =
    \frac{4q^2}{3q^2+1}.
    }
    $$

    Consequently,

    $$
    \lim_{q\to\infty}\lim_{r\to\infty}
    R_{ef}((A_r\oplus A_r)+e\times f)
    =
    \frac43.
    $$

    In the other order, for fixed affine dimension $r$,

    $$
    \boxed{
    \lim_{q\to\infty}
    R_{ef}((\operatorname{AG}(r,q)\oplus
    \operatorname{AG}(r,q))+e\times f)
    =
    \frac{4(r+1)}{3r+4},
    }
    $$

    and this also approaches $4/3$ as $r\to\infty$.

### Proof

Let $M$ have rank $m$, and write

$$
\begin{aligned}
i&=\#\{I\subseteq E(M):|I|=m-1,\ I\text{ is independent}\},\\
b&=|\mathcal B(M)|,\\
a&=\#\{A\subseteq E(M):|A|=m,\ \operatorname{rk}_M(A)\geq m-1\},\\
s&=\#\{S\subseteq E(M):|S|=m+1,\ \operatorname{rk}_M(S)=m\}.
\end{aligned}
$$

The standard descriptions of bases under free extension and free
coextension give

$$
R_{ef}(M+e\times f)=\frac{is}{ab}.
$$

Indeed, the four classes of bases according to whether they contain $e$ and
$f$ correspond, respectively, to independent $(m-1)$-sets, bases,
rank-$m$ sets of rank at least $m-1$, and spanning $(m+1)$-sets of $M$.

For $N=M\oplus M$, its four adjacent-rank counts are

$$
b_N=b^2,
\qquad
i_N=2ib,
\qquad
s_N=2sb,
\qquad
a_N=2ab-b^2+2is.
$$

For example, an almost-basis of $N$ either has $m$ elements in each copy,
with at least one of the two parts a basis, or has sizes $m-1$ and $m+1$,
with the smaller part independent and the larger part spanning.  It follows
that

$$
\boxed{
R_{ef}((M\oplus M)+e\times f)
=
\frac{4is}{2ab-b^2+2is}.
}
\tag{1}
$$

Equivalently, if

$$
Q(M)=\frac{is}{b^2},
\qquad
Z(M)=\frac{a}{b},
$$

then

$$
R_{ef}((M\oplus M)+e\times f)
=
\frac{4Q(M)}{2Z(M)-1+2Q(M)}.
\tag{2}
$$

For $M=U_{r,2r}$, every $r$-set is a basis and every
$(r+1)$-set is spanning, so

$$
a=b=\binom{2r}{r},
\qquad
i=s=\binom{2r}{r-1}.
$$

Therefore

$$
Q(M)
=
\left(
\frac{\binom{2r}{r-1}}{\binom{2r}{r}}
\right)^2
=
\frac{r^2}{(r+1)^2},
\qquad
Z(M)=1.
$$

Substitution into (2) gives

$$
R_{ef}((M\oplus M)+e\times f)
=
\frac{4r^2}{(r+1)^2+2r^2}
=
\frac{4r^2}{3r^2+2r+1}.
$$

Now let $A_r=\operatorname{AG}(r,q)$.  Translating one selected point to
the origin turns affine spanning into ordinary linear spanning in
$\mathbb F_q^r$.  Let

* $p_0(r)$ be the probability that a random $r\times r$ matrix is
  nonsingular;
* $p_-(r)$ be the probability that a random $r\times(r-1)$ matrix has full
  column rank;
* $p_+(r)$ be the probability that a random $r\times(r+1)$ matrix has full
  row rank; and
* $p_1(r)$ be the probability that a random $r\times r$ matrix has rank
  $r-1$.

The standard finite-field matrix counts give

$$
\frac{p_-(r)}{p_0(r)}
=
\frac{1}{1-q^{-1}},
\qquad
\frac{p_+(r)}{p_0(r)}
=
\frac{1-q^{-(r+1)}}{1-q^{-1}},
$$

and

$$
\frac{p_1(r)}{p_0(r)}
=
\frac{q(1-q^{-r})}{(q-1)^2}.
$$

Choosing $r+O(1)$ distinct affine points instead of independent random
points changes these probabilities by $o(1)$, since the collision
probability is $O(r^2/q^r)$.  The adjacent binomial-coefficient factor also
satisfies

$$
\frac{\binom{q^r}{r}\binom{q^r}{r+2}}
     {\binom{q^r}{r+1}^2}
\longrightarrow 1.
$$

Consequently,

$$
Q(A_r)
\longrightarrow
\frac{q^2}{(q-1)^2},
\qquad
Z(A_r)
\longrightarrow
1+\frac{q}{(q-1)^2}
=
\frac{q^2-q+1}{(q-1)^2}.
$$

Substituting these limits into (2) yields

$$
\lim_{r\to\infty}
R_{ef}((A_r\oplus A_r)+e\times f)
=
\frac{
4q^2
}{
2(q^2-q+1)-(q-1)^2+2q^2
}
=
\frac{4q^2}{3q^2+1}.
$$

Finally, fix $r$ and let $q\to\infty$.  Among subsets of each relevant
size, the affine geometry is then asymptotically uniform: almost every set
of size at most $r+1$ is independent, and almost every set of size at least
$r+1$ is spanning.  With $m=r+1$, this gives

$$
Q(\operatorname{AG}(r,q))
\longrightarrow
\frac{m}{m+1},
\qquad
Z(\operatorname{AG}(r,q))
\longrightarrow1.
$$

Equation (2) therefore gives

$$
\lim_{q\to\infty}
R_{ef}((\operatorname{AG}(r,q)\oplus
\operatorname{AG}(r,q))+e\times f)
=
\frac{4m}{3m+1}
=
\frac{4(r+1)}{3r+4}.
$$

## Website design

A leaderboard-style website, modeled in spirit on
[https://elliptic-rank.icarm.cloud](https://elliptic-rank.icarm.cloud), should
serve simultaneously as:

1. a public record table for large correlation ratios;
2. a reproducible registry of the underlying matroids and constructions;
3. a place to propose and discuss infinite families;
4. a collection of open computational and mathematical challenges; and
5. a credit-preserving record of who found, verified, and explained each
   construction.

The working title can be **Matroid Correlation Atlas**.  Browsing the website
requires no account.  For the first version, all submissions are mediated by
GitHub and therefore require a GitHub account.

### Scope of the first release

The first release should concern the exact unweighted invariant
$\overline{\alpha}$.  The weighted invariant $\alpha$ should be reserved for
a later, separate part of the website.  A weighted pair and a positive
rational weight vector automatically certify only a lower bound

$$
\alpha(M)\geq R_{ij}(M,w),
$$

unless an additional mathematical argument proves optimality over all pairs
and all positive weights.  When weighted submissions are introduced, they
should therefore have their own tab and their own verification language.

The first release has two submission types:

1. **A concrete matroid.**  This is automatically verifiable from finite
   combinatorial data.
2. **An infinite family.**  Its finite examples can often be checked
   automatically, but its general formula and supremum require mathematical
   review.

### Exact curves versus lower-bound curves

This distinction is essential for family submissions.  Suppose a submitted
family is a parameterized collection

$$
\mathcal F=\{M_t:t\in T\}.
$$

A submitter may prove either:

1. an exact formula

   $$
   v(t)=\overline{\alpha}(M_t),
   $$

   including a proof that no element pair gives a larger ratio; or

2. a certified lower bound from a specified pair,

   $$
   v(t)=R_{i(t)j(t)}(M_t)
   \leq \overline{\alpha}(M_t).
   $$

The second situation includes constructions for which one distinguished pair
has been analyzed but has not been proved to be maximizing.  It is still
valuable and should appear on the website, but it must not be presented as an
exact $\overline{\alpha}$ curve.

The chart should use the following visual language:

| Curve style | Meaning |
|---|---|
| Solid curve | $\overline{\alpha}(M_t)$ is proved exactly for every displayed parameter |
| Dashed curve | A proved lower bound $R_{i(t)j(t)}(M_t)\leq\overline{\alpha}(M_t)$ |
| Dotted horizontal line | A proved supremum or limiting value |
| Faint or gray curve | A computationally checked proposal whose proof is still under review |

The family page must also state whether its claimed supremum is:

- attained by a member;
- approached but not attained;
- an exact supremum; or
- only a proved lower bound on the supremum.

A proof that values approach $L$ proves

$$
\sup_{t\in T}\overline{\alpha}(M_t)\geq L.
$$

To claim equality, the submission must additionally prove the corresponding
upper bound.

### Public information architecture

The first version should have the following pages:

- **Explore:** the main interactive plot and synchronized record table;
- **Matroids:** searchable concrete-matroid records;
- **Families:** a catalog of all accepted families and their curves;
- **Challenges:** specific targets on which collaborators can work;
- **Submit:** instructions and a guided GitHub submission workflow;
- **Methods:** definitions, verification rules, file formats, and source code;
- **Activity:** recently submitted, verified, corrected, or superseded results.

Every plotted object should have a stable, shareable URL.

### Main Explore page

The main page should have two synchronized views:

1. an interactive plot; and
2. a sortable table of the currently visible points and families.

A possible desktop layout is:

    ┌───────────────────────────────────────────────────────────────┐
    │ Matroid Correlation Atlas       Explore  Families  Submit     │
    ├───────────────────────────────────────────────────────────────┤
    │ Global verified record: value, matroid, contributors          │
    ├───────────────────────────────────────────────────────────────┤
    │ Filters                 │ Interactive point-and-curve plot     │
    │                         │                                      │
    │ Ground-set size         │       exact family curve ─────       │
    │ Rank                    │       lower-bound curve - - -        │
    │ Verified field          │       concrete matroid       ●       │
    │ Structural properties   │                                      │
    │ Verification status     │                                      │
    ├───────────────────────────────────────────────────────────────┤
    │ Records and visible constructions table                       │
    ├───────────────────────────────────────────────────────────────┤
    │ Open challenges                 Recent activity                │
    └───────────────────────────────────────────────────────────────┘

#### Plot axes and points

- The horizontal axis is the ground-set size $|E(M)|$.
- The vertical axis is the correlation-ratio value.
- The default lower endpoint is $1$, since the initial purpose is to study
  positive correlation, but a toggle should reveal values below $1$.
- The initial upper endpoint may be $2$, but it should automatically expand
  if a verified construction exceeds the current range.
- A point represents one concrete matroid.
- Point color represents rank, with a colorblind-safe palette.
- Point shape or outline indicates whether the point is a global record, a
  record at its ground-set size, or an ordinary verified construction.
- Multiple points at the same coordinates should be grouped or slightly
  jittered for display without changing their exact tooltip values.
- Hovering over a point shows its name, exact fraction, decimal value, rank,
  field certificates, construction or family, and contributors.
- Clicking a point opens its matroid detail page.

The user should be able to switch between:

- record holders only;
- all curated verified constructions;
- concrete members of selected families; and
- an aggregated heatmap of the current database.

The complete research database should not be sent to the browser.  Large
populations should be pre-aggregated into a heatmap or binned background
layer, while individually interesting matroids are sent as clickable points.

#### Family curves

Every accepted family has at least one curve on the main chart.  A curve is
the set of discrete points

$$
\bigl\{(|E(M_t)|,v(t)):t\in T\bigr\},
$$

where $v(t)$ is either the exact value or the certified lower bound declared
by the curve style.  A connecting line is a visual guide; it must not imply
that nonexistent intermediate ground-set sizes are admissible.

Requirements for curve rendering:

- admissible parameter values are marked explicitly;
- gaps in the parameter domain remain gaps on the chart;
- hovering identifies the family, parameter, exact displayed value, and
  verification status;
- clicking any segment or point opens the family page at that parameter;
- a proved limit or supremum appears as a labeled dotted line;
- the legend can hide or reveal any family;
- all accepted families are available on the chart, even if some are hidden
  temporarily by a user's legend choices;
- the current URL records which families and filters are visible.

A family with several natural one-parameter subfamilies may define several
named series on the same family page.  For example, a two-parameter geometry
family may use one series for each fixed field size.  The submission must say
which parameter path each curve represents.

#### Filters

The initial filters should include:

- minimum and maximum ground-set size;
- rank and corank;
- connected and $3$-connected;
- simple and cosimple;
- paving, copaving, and sparse paving;
- concrete points, exact family curves, or lower-bound family curves;
- named family;
- verification status;
- source or contributor;
- verified representation over $\operatorname{GF}(2)$,
  $\operatorname{GF}(3)$, or $\operatorname{GF}(5)$.

Additional fields can be added later.

The representability filter must be phrased as **has a verified
$\operatorname{GF}(q)$ representation**.  A supplied matrix proves
representability over that field, but the absence of such a certificate does
not prove nonrepresentability.  A matroid may carry several verified field
badges.

All filter states should be encoded in the URL so that a user can send
another researcher exactly the same view.

### Concrete-matroid detail page

Each concrete matroid receives a permanent page containing:

- stable identifier and descriptive name;
- exact value of $\overline{\alpha}(M)$ and a decimal approximation;
- ground-set size, rank, corank, and number of bases;
- all maximizing pairs, or at least the number of maximizing pairs and one
  representative;
- for a displayed maximizing pair, the exact counts
  $b_{00},b_{01},b_{10},b_{11}$;
- basis density and relevant structural invariants;
- connectedness, simplicity, cosimplicity, paving, and related flags;
- verified finite-field representations;
- the submitted matrix, bases, circuits, or hyperplanes;
- a normalized downloadable representation;
- short OSCAR/Julia reconstruction code generated by the verifier;
- family memberships and links to related constructions;
- the dual matroid when it has a separate useful description;
- submitters, mathematical contributors, and verifiers;
- citation, DOI, arXiv, repository, or other provenance;
- submission date, verification date, and verifier version;
- links to the GitHub pull request and public discussion;
- a machine-readable verification certificate.

Exact fractions should always be displayed alongside decimals.  The exact
fraction is authoritative.

### Family detail page

Each family page should contain:

- family name and stable identifier;
- submitters, proof authors, reviewers, and citations;
- precise definition of $M_t$ and its parameter domain $T$;
- formulas for $|E(M_t)|$, rank, and any field of representation;
- the exact or lower-bound formula $v(t)$ plotted by each series;
- the claimed supremum and whether it is attained;
- a clear indication of which assertions are proved and which are
  computational observations;
- the complete mathematical proof or a stable link to a paper or preprint;
- a proof-review history;
- a table of automatically verified small parameter values;
- downloadable construction data for those finite examples;
- a declarative curve-data file;
- optional generator code;
- links to concrete record-holding members;
- open questions specific to the family.

Supremum alone is not enough to draw a curve.  A family submission must also
provide an exact formula, a proved lower-bound formula, or another
machine-checkable rule for evaluating the displayed value at admissible
parameters.

### GitHub-mediated submission workflow

The **Submit** button should offer exactly two paths:

1. **Submit a concrete matroid**
2. **Propose an infinite family**

The website may provide a client-side wizard that validates basic fields and
produces the required files, but the final submission is a GitHub pull
request.  GitHub provides identity, public discussion, revision history, and
moderation without requiring a separate account system.

The repository should contain submission templates and worked examples for
both paths.

### Concrete-matroid submissions

#### Required information

A concrete submission contains:

- proposed name;
- contributor GitHub handles and preferred display names;
- ground-set labels;
- one explicit matroid description;
- claimed exact value of $\overline{\alpha}(M)$;
- optional claimed maximizing pair;
- optional construction notes and family membership;
- optional field-representability claims;
- citation or provenance;
- a license permitting the website to redistribute the submitted data.

The accepted input descriptions are:

1. **Matrix representation.**

   The submission specifies the field and a matrix whose columns represent
   the ground-set elements.  The first release should support prime fields
   $\operatorname{GF}(2)$, $\operatorname{GF}(3)$, and
   $\operatorname{GF}(5)$ directly.  Later releases may support arbitrary
   finite fields by additionally specifying an irreducible polynomial and a
   fixed element encoding.

2. **Bases.**

   The submission lists all bases as subsets of a declared ground set.

3. **Circuits.**

   The submission lists all circuits as subsets of a declared ground set.

4. **Hyperplanes.**

   The submission lists all hyperplanes as subsets of a declared ground set.

JSON should be the canonical interchange format.  Small matrices may also be
entered through a table in the submission wizard, and CSV may be accepted as
an import format.  The verifier converts every accepted input to the
project's canonical basis encoding.

#### Automatic verification

No contributor-supplied code is executed.  The trusted Julia/OSCAR verifier
performs the following steps:

1. validate the submission schema and ground-set labels;
2. construct the proposed matroid;
3. verify the relevant basis, circuit, or hyperplane axioms when the input is
   combinatorial;
4. enumerate or otherwise determine the bases;
5. identify loops and coloops and the eligible element pairs;
6. compute every pair ratio exactly;
7. recompute $\overline{\alpha}(M)$ as an exact reduced fraction;
8. compare it with the submitted claim;
9. record all maximizing pairs and their four basis counts;
10. compute the structural metadata used by the website filters;
11. verify each field badge for which a matrix certificate was supplied;
12. search for an identical encoding and, where feasible, an isomorphic or
    dual entry;
13. generate a deterministic verification certificate and page preview.

The GitHub check reports one of:

- **verified as claimed**;
- **valid matroid, but the exact value differs from the claim**;
- **invalid or incomplete matroid description**;
- **duplicate or apparently isomorphic to an existing entry**; or
- **verification exceeds the automatic resource limit and requires manual
  review**.

A differing claimed value need not close the submission automatically.  The
bot should report the recomputed value and let the contributor correct the
description or accept the verified value.

After all checks pass, a maintainer reviews attribution and presentation and
merges the pull request.  Merging publishes the point and its detail page.

#### Resource limits

Automatic verification may be exponential in ground-set size.  The
submission guide should state limits on matrix size, number of listed sets,
and verification time.  A large submission may enter a manual queue, but it
must ultimately produce the same kind of independently reproducible
certificate before receiving a verified badge.

### Infinite-family submissions

#### Required information

A family pull request must provide:

- a precise parameter space $T$;
- an unambiguous construction of $M_t$ for every $t\in T$;
- a proof that the construction defines a matroid;
- formulas for ground-set size and rank;
- any claimed field representations;
- the exact or lower-bound value $v(t)$ to be plotted;
- a declaration of whether $v(t)=\overline{\alpha}(M_t)$ or merely
  $v(t)\leq\overline{\alpha}(M_t)$;
- the supremum of the displayed values;
- the claimed supremum of $\overline{\alpha}$ for the family, if different;
- whether each supremum is attained;
- a complete mathematical proof or a stable paper/preprint reference;
- a declarative list or rule for the admissible curve parameters;
- enough explicit finite members for computational checking;
- optional generator code;
- contributors, citations, and license.

If an exact curve is claimed, the proof must show both:

1. that a specified pair attains the displayed value; and
2. that every other eligible pair has ratio at most that value.

If an exact family supremum is claimed, the proof must establish both the
lower and upper bounds.  A limiting witness pair establishes only the lower
bound unless a matching upper bound is supplied.

#### What can be checked automatically

The family CI can:

- validate the metadata and parameter schema;
- evaluate safe declarative formulas;
- verify that declared parameter values produce integral ground-set sizes
  and ranks;
- construct submitted small members;
- recompute their exact $\overline{\alpha}$ values;
- compare those values with the proposed curve;
- check internal consistency between the plotted values, supremum, and
  asymptotic expressions;
- render a preview of the proposed curve and family page.

These checks can find errors but cannot prove an arbitrary theorem about an
infinite family.  Contributor-supplied generator code should not run in the
ordinary untrusted pull-request workflow.  It may run only after inspection,
in a restricted maintainer-approved workflow.

#### Mathematical review

Family submissions require human mathematical review.  The proposed default
policy is:

1. the proof and all revisions are public in the pull request;
2. at least one maintainer checks the website and data requirements;
3. at least one named mathematical reviewer checks the general argument;
4. an exact-supremum claim receives a second mathematical approval unless it
   is already established in a cited peer-reviewed source;
5. reviewers disclose substantial contributions and receive credit on the
   family page;
6. accepted results remain versioned and can later be corrected,
   strengthened, or withdrawn without erasing their history.

This is community review, not a claim of formal proof verification.  The
badge must describe exactly what was reviewed.

### Verification statuses

The site should use a small, explicit vocabulary:

| Status | Concrete matroid | Infinite family |
|---|---|---|
| Submitted | GitHub proposal received | GitHub proposal received |
| Computationally checked | Input is a valid matroid and the exact value was recomputed | Displayed finite examples agree with the proposed rule |
| Proof reviewed | Usually unnecessary for the finite computation | General formula or bound reviewed by named mathematicians |
| Literature verified | Data reproduce a cited published result | The theorem appears in a cited published source |
| Superseded | A better description or duplicate canonical entry exists | A stronger version of the family is available |
| Withdrawn | A material error was found | A material error was found |

Only computationally verified concrete matroids appear as ordinary points on
the default chart.  Solid family curves require proof-reviewed exact formulas.
Proof-reviewed lower bounds appear as dashed curves.  Proposals still under
review are visible only when the user enables the pending layer.

### Records, leaderboards, and challenges

The website should maintain several record views:

- largest verified $\overline{\alpha}$ overall;
- largest verified value at each ground-set size;
- largest verified value at each $(n,r)$;
- largest value with a verified representation over each supported field;
- newest verified constructions;
- family suprema and proved lower bounds;
- historical progression of the global record.

The default table should not imply that sampled database observations form a
uniform population of matroids.  Provenance labels must distinguish exact
censuses, random constructions, database representatives, and individual
community submissions.

The **Challenges** page should contain concrete, shareable targets, such as:

- beat the current global record;
- improve the record at a specified $(n,r)$;
- find the best known binary or ternary example;
- prove that a distinguished pair is maximizing in a lower-bound family;
- turn a computational family curve into a theorem;
- determine representability or structural properties of a record holder;
- find a simpler description of an existing example.

Each challenge links to a GitHub Discussion.  A submission can cite the
challenge it addresses, and solved challenges remain visible with credit and
links to the resolution.

### Attribution and discussion

Every entry should distinguish, when applicable:

- discoverers of the matroid or family;
- submitters who entered it into the website;
- authors of the proof;
- computational verifiers;
- mathematical reviewers;
- earlier literature sources.

Credit should be additive rather than assigning a single owner.  Each entry
has a GitHub discussion link, but the website itself need not implement
native comments in the first release.

### Canonical data and provenance

The Git repository should be the source of truth for curated website
entries.  A possible organization is:

    website/data/matroids/<stable-id>/submission.json
    website/data/matroids/<stable-id>/input.json
    website/data/matroids/<stable-id>/certificate.json
    website/data/families/<stable-id>/family.json
    website/data/families/<stable-id>/proof.md
    website/data/families/<stable-id>/curve.json

The submitter edits the submission and input files.  The trusted verifier
generates the certificate and normalized curve data.  Generated files state
the verifier version and a hash of every input.

Stable identifiers should never be recycled.  Corrections create new
versions while preserving old URLs and explaining what changed.

Dual matroids have the same correlation ratio and should be cross-linked.
Exact duplicate encodings should be merged automatically.  Isomorphic
duplicates should be merged when isomorphism can be certified, while
potential duplicates may be flagged for human review.

### Suggested technical architecture

The first version can be static-first:

- **Astro with TypeScript** for pages and routing;
- **KaTeX** for mathematical notation;
- **Plotly or Vega-Lite** for the interactive plot;
- static JSON files for curated points, families, filters, and leaderboards;
- the existing Julia/OSCAR project as the authoritative verifier;
- GitHub pull requests and GitHub Actions for submissions;
- GitHub Discussions for challenges and mathematical discussion;
- GitHub Pages or Cloudflare Pages for deployment.

A build script should export only curated records and aggregate database
layers from the existing SQLite files.  The browser should never need direct
access to the research databases.

The static data should also be published as a documented read-only JSON API,
so other researchers can build visualizations or analyses without scraping
the website.

This architecture avoids a production user database, password management,
and a privileged web backend in the first release.  GitHub supplies identity,
review history, moderation, and notifications.

### Implementation stages

#### Stage 1: read-only atlas

- finalize the concrete-matroid and family schemas;
- export the current record examples;
- enter the known $8/7$ and $100/81$ constructions;
- enter the uniform, affine/projective, and other proved family curves with
  their correct exact or lower-bound status;
- build the plot, filters, tables, and detail pages;
- deploy a public preview.

#### Stage 2: automatic concrete submissions

- add submission templates and the client-side file builder;
- implement trusted reconstruction from matrices, bases, circuits, and
  hyperplanes;
- run exact $\overline{\alpha}$ verification in GitHub Actions;
- generate certificates and preview pages;
- document resource limits and duplicate handling.

#### Stage 3: family proposals

- add the family schema and proof template;
- add curve-preview checks;
- establish the mathematical reviewer workflow;
- publish proof-review and lower-bound badges;
- connect accepted families to concrete checked members.

#### Stage 4: collaboration features

- add challenges, activity feeds, and record history;
- add RSS or email notification options;
- improve cross-linking among constructions, families, and discussions;
- expose the public JSON API.

#### Stage 5: weighted correlation

- add a separate weighted-$\alpha$ tab;
- accept rational positive weight vectors as exact lower-bound certificates;
- distinguish computed lower bounds, theorem-backed exact values, and upper
  bounds;
- develop a separate review policy for optimization claims.

### First-release acceptance criteria

The first public version is ready when:

- every point and curve has a stable detail page;
- every concrete point is independently recomputable from downloadable data;
- exact and lower-bound family curves are visually unmistakable;
- every curve identifies its admissible parameter values and supremum status;
- every verified claim links to its GitHub review and certificate;
- filters have shareable URLs;
- finite-field badges are backed by explicit representations;
- no untrusted submission code is executed;
- the site works on mobile and is keyboard accessible;
- the complete curated dataset is downloadable in a documented format.


