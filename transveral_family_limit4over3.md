## A transversal family approaching $4/3$

For each integer $r\geq 2$, define a transversal matroid $M_r$ using the following $2r+1$ presentation rows:

$$
A=\{a_1,\ldots,a_r\},\qquad
B=\{b_1,\ldots,b_r\},\qquad
\{g\}.
$$

Its ground set consists of:

- $2r$ elements of type $X$, each adjacent to every row in $A\cup\{g\}$;
- $2r$ elements of type $Y$, each adjacent to every row in $B\cup\{g\}$;
- an element $e$ adjacent only to $g$;
- an element $f$ adjacent to $a_1$ and $b_1$.

Thus $M_r$ has rank $2r+1$ on $4r+2$ elements.

Set

$$
c=\binom{2r}{r},
\qquad
q=\binom{2r}{r-1}=\binom{2r}{r+1}
=\frac{r}{r+1}c.
$$

For the pair $e,f$, the four basis counts are

| Status of $e,f$ | Count |
|---|---:|
| neither | $2qc$ |
| $e$ only | $c^2$ |
| $f$ only | $c^2+2q^2$ |
| both | $2qc$ |

Indeed, the ordinary $X,Y$ occupancies are respectively

- $(r+1,r)$ or $(r,r+1)$ when neither is present;
- $(r,r)$ when only $e$ is present;
- $(r,r)$, $(r+1,r-1)$, or $(r-1,r+1)$ when only $f$ is present;
- $(r-1,r)$ or $(r,r-1)$ when both are present.

Consequently,

$$
\alpha_{e,f}(M_r)
=
\frac{(2qc)^2}{c^2(c^2+2q^2)}
=
\frac{4r^2}{3r^2+2r+1}.
$$

Therefore

$$
\lim_{r\to\infty}\alpha_{e,f}(M_r)=\frac43,
$$

although every finite member remains strictly below $4/3$.

The first balanced member beating $100/81$ occurs at $r=9$:

$$
\overline{\alpha}(M_9)
=
\alpha_{e,f}(M_9)
=
\frac{162}{131}
\approx1.236641
>
\frac{100}{81}
\approx1.234568.
$$

Here $M_9$ has rank $19$ on $38$ elements, and the exact counts are

$$
(A,B,C,D)
=
(4\,255\,027\,920,\,
 2\,363\,904\,400,\,
 6\,193\,429\,528,\,
 4\,255\,027\,920).
$$

An exact check of all pair orbits confirms that $(e,f)$ is the maximizing pair for this member.

## Free-extension/free-coextension description

Yes. The matroid in `transveral_family_limit4over3.md` has exactly this form.

Define

$$
N_r
=
U_{r,2r}(X)\oplus U_{r,2r}(Y).
$$

Let $P_r$ be the free extension of $N_r$ by $f$, and then let $M_r$ be the free coextension of $P_r$ by $e$:

$$
P_r=N_r+f,
\qquad
M_r=P_r\times e.
$$

Here $+$ denotes free extension and $\times$ denotes free coextension. Equivalently,

$$
M_r
=
\left(
U_{r,2r}(X)\oplus U_{r,2r}(Y)+f
\right)\times e.
$$

### Why $f$ is a free-extension element

Contracting $e$ forces it to be matched to its unique presentation row $g$. After removing $e$ and $g$, the remaining presentation has:

- every element of $X$ adjacent to all rows in $A$;
- every element of $Y$ adjacent to all rows in $B$;
- $f$ adjacent to $a_1$ and $b_1$.

Deleting $f$ therefore gives

$$
(M_r/e)\setminus f
=
U_{r,2r}(X)\oplus U_{r,2r}(Y)
=
N_r.
$$

Every basis of $N_r$ contains $r$ elements of $X$ and $r$ elements of $Y$. If one element is removed from such a basis, then $f$ can be matched into the newly available side. Consequently, for every basis $B$ of $N_r$,

$$
B\cup\{f\}
$$

is a circuit, while $f$ can be added to every nonspanning independent set. This is precisely the defining property of a free extension. Hence

$$
M_r/e=P_r=N_r+f.
$$

### Why $e$ is a free-coextension element

The bases of $M_r$ containing $e$ are exactly the sets

$$
B\cup\{e\},
$$

where $B$ is a basis of $P_r$.

The bases of $M_r$ avoiding $e$ are exactly the $(2r+1)$-element spanning subsets of $P_r$. This is the standard basis characterization of the free coextension of $P_r$ by $e$. Therefore,

$$
M_r=P_r\times e.
$$

### Interpretation of the four basis counts

Let

$$
c=\binom{2r}{r},
\qquad
q=\binom{2r}{r-1}
=\binom{2r}{r+1}.
$$

The four basis counts now follow directly from the two free operations:

| Status of $e,f$ | Interpretation | Count |
|---|---|---:|
| $e$ only | Bases of $N_r$ | $c^2$ |
| Both $e$ and $f$ | Independent $(2r-1)$-subsets of $N_r$ together with $e,f$ | $2qc$ |
| Neither $e$ nor $f$ | $(2r+1)$-element spanning subsets of $N_r$ | $2qc$ |
| $f$ only | Bases of $N_r$, or rank-$(2r-1)$ subsets with occupancies $(r+1,r-1)$ or $(r-1,r+1)$ | $c^2+2q^2$ |

Thus the family can be written succinctly as

$$
\boxed{
M_r
=
\left(
U_{r,2r}\oplus U_{r,2r}+f
\right)\times e
}.
$$

The special element $f$ is the free-extension element, and $e$ is the subsequent free-coextension element.