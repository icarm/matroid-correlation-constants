# Area to paste codex answers for readability

## Dump area 8/4/2026




A good main target is about 50,000 usable matroids per rank, preceded by a smaller pilot. Storage will be modest—roughly 150 MiB for the proposed $r=4$ and $r=5$ analyzed samples together. Decoding cost, not storage, is the limiting factor.

## Recommended sampling plan

### Rank 4: exact simple random sample

The ICARM $n=10,r=4$ archive has only 49 chunks totaling 657.09 MiB, although it represents $4{,}886{,}380{,}924$ isomorphism classes. [ICARM rank-4 enumeration](https://matroids.icarm.cloud/enumeration/n10r04).

I recommend:

- benchmark one chunk first;
- preselect 100,000 global indexes uniformly without replacement;
- stream the entire 657-MiB archive once;
- retain only those 100,000 records.

Since 100,000 random indexes will touch essentially every chunk, increasing the sample from 10,000 to 100,000 barely changes the retrieval cost. It does increase the $\overline{\alpha}$ computation, but that is much smaller than computing it for all 4.9 billion records.

This would be an exact simple random sample of stored isomorphism classes.

### Rank 5: pilot cluster sample, then scale

The $n=10,r=5$ archive is very different: 32,223 chunks and 413.58 GiB compressed. [ICARM rank-5 enumeration](https://matroids.icarm.cloud/enumeration/n10r05).

An exact 50,000-record global-index sample would touch most of those chunks, so I recommend:

1. Pilot: 128 randomly selected chunks, with probability proportional to chunk size, and 100 uniformly selected positions per chunk.

   Total raw sample:

   $$
   128\cdot100=12{,}800.
   $$

2. Measure the within-chunk similarity of $\overline{\alpha}$, basis density, and the other invariants.

3. Main run: approximately 50,000 records, using either:

   - 256 chunks $\times$ 200 positions, or
   - 512 chunks $\times$ 100 positions if chunk-order effects are appreciable.

The latter is statistically better but requires twice as many chunks. The pilot lets us estimate the cluster design effect

$$
\operatorname{DEFF}
\approx
1+(s-1)\rho_{\mathrm{chunk}},
$$

and hence the effective sample size

$$
m_{\mathrm{eff}}
\approx
\frac{m}{\operatorname{DEFF}}.
$$

This design gives every stored record equal marginal probability, but it is not an independent simple random sample. The reports must therefore use chunk-level uncertainty estimates.

## What those sample sizes tell us

For an independent sample, the worst-case 95% margin of error for a proportion and the approximate 95% upper bound after observing no events are:

| Sample size | Worst-case proportion margin | Zero-event upper bound |
|---:|---:|---:|
| 12,800 | $\pm0.87$ percentage points | $2.3\times10^{-4}$ |
| 50,000 | $\pm0.44$ percentage points | $6\times10^{-5}$ |
| 100,000 | $\pm0.31$ percentage points | $3\times10^{-5}$ |

Thus 50,000 is already ample for distributions and correlations. It is not enough to reliably discover an event occurring only once per million classes. Uniform sampling and searching for exceptionally large $\overline{\alpha}$ should remain separate objectives.

These counts are before excluding disconnected matroids and those with $\overline{\alpha}=0$. The pilot will tell us how much oversampling is necessary to obtain 50,000 report-eligible observations.

## Expected storage

The current project occupies exactly 5,360,062,464 allocated bytes:

$$
5.360\text{ GB}=4.992\text{ GiB}.
$$

There is about 46 TiB free on the filesystem, so capacity is not an immediate problem.

Using the actual storage rate of our current compact databases:

| Proposed dataset | Estimated persistent storage |
|---|---:|
| Rank-5 pilot, 12,800 records | about 12 MiB |
| Rank-5 main sample, 50,000 records | about 43–50 MiB |
| Rank-4 sample, 100,000 records | about 75–85 MiB |
| New figures, reports, manifests | about 10–20 MiB |
| Recommended total | about 130–150 MiB |

The raw packed basis masks alone are much smaller. For example, 100,000 rank-4 hexadecimal basis masks require only about 5.3 MB before compression. Most storage comes from invariants, exact $\overline{\alpha}$ values, aggregate ratio distributions, and SQLite indexes.

Downloaded ICARM chunks should be streamed and discarded after validation. They should not become permanent project data.

## Current cleanup opportunities

### 1. Remove the legacy $n=8,r=4$ data

This is the clearest cleanup:

- `data/n8_r4`: about 217 MiB;
- `figures/n8_r4`: about 1.7 MiB.

The compact replacement contains the same 22,375 matroids and the same 622,830 eligible pairs. All current reports already reference `data/n8_r4_compact`.

Expected saving: about 219 MiB.

### 2. Remove regenerable bulk CSV exports

The SQLite files are documented as authoritative. The compressed `matroids.csv.zst` and `pair_ratio_aggregates.csv.zst` files are derived exports and can be regenerated.

Across the current authoritative datasets, these consume approximately:

$$
916\text{ MiB}.
$$

We could keep the small run manifests, selected examples, and selected pair profiles while removing only the two large exports. Reports and README links would need to be adjusted to say that bulk exports are generated on demand.

Together with the legacy $n=8$ cleanup, this saves approximately 1.11 GiB.

### 3. Archive, rather than delete, the finite-field $n=10,r=4$ database

The current rank-4 finite-field directory occupies about 525 MiB:

- SQLite database: 410.9 MiB;
- exports: about 114 MiB;
- manifests and selected profiles: negligible.

A read-only compression test reduced the exact SQLite database from 430.8 MB to 106.3 MB using ordinary Zstandard level 3.

Therefore we could:

- remove the derived exports;
- replace `results.sqlite` with a lossless `results.sqlite.zst`;
- record hashes and decompression instructions;
- update the report links.

That would reduce the rank-4 data from about 525 MiB to roughly 102 MiB, saving about 424 MiB without losing the exact database.

I would not delete it outright. The finite-field experiment samples representations/configurations, whereas the ICARM experiment samples isomorphism classes. They answer different questions. After archiving, complete deletion would save only another approximately 102 MiB.

Also, SQLite `VACUUM` would not help: all current databases have zero free pages.

## Proposed outcome

My recommendation is:

1. Remove the obsolete $n=8,r=4$ snapshot and figures.
2. Remove regenerable bulk CSV exports.
3. Zstandard-archive the finite-field $n=10,r=4$ SQLite database instead of deleting it.
4. Benchmark one ICARM rank-4 and one rank-5 chunk.
5. Run the 100,000-record exact rank-4 sample.
6. Run the 12,800-record rank-5 pilot and use its chunk correlations to choose the final design.

That cleanup would reduce the project from about 4.99 GiB to about 3.57 GiB. Adding the proposed ICARM samples would bring it to roughly 3.7 GiB—still substantially smaller than the project is now. No files have been removed yet.

Yes—I’ll use `$...$` for inline TeX and `$$...$$` for displayed TeX. Here is the previous answer reformatted:



## Basis density of the transversal family

For the transversal family $M_r$,

$$
d_B(M_r)
=
\frac{2\binom{2r+1}{r}^2}
{\binom{4r+2}{2r+1}}.
$$

Indeed, writing

$$
c=\binom{2r}{r},
\qquad
d=\binom{2r}{r-1},
$$

the total number of bases is

$$
\begin{aligned}
|\mathcal B(M_r)|
&=2cd+c^2+(c^2+2d^2)+2cd\\
&=2(c+d)^2\\
&=2\binom{2r+1}{r}^2.
\end{aligned}
$$

For the smallest member beating $100/81$, namely $r=9$,

$$
|\mathcal B(M_9)|=17{,}067{,}389{,}768,
$$

while

$$
\binom{38}{19}=35{,}345{,}263{,}800.
$$

Therefore,

$$
\boxed{
d_B(M_9)
=
\frac{193{,}947{,}611}{401{,}650{,}725}
\approx 0.4828763
}
$$

and

$$
\boxed{
\overline{\alpha}(M_9)
=
\frac{162}{131}
\approx 1.2366412.
}
$$

Some values illustrate the tradeoff:

| $r$ | rank | $|E|$ | $d_B(M_r)$ | $\overline{\alpha}(M_r)$ |
|---:|---:|---:|---:|---:|
| $9$ | $19$ | $38$ | $0.482876$ | $1.236641$ |
| $20$ | $41$ | $82$ | $0.341022$ | $1.289283$ |
| $100$ | $201$ | $402$ | $0.158098$ | $1.324459$ |
| $1000$ | $2001$ | $4002$ | $0.050415$ | $1.332445$ |

Using Stirling’s formula,

$$
d_B(M_r)
=
\sqrt{\frac{8}{\pi r}}
\left(1+O(r^{-1})\right),
$$

whereas

$$
\overline{\alpha}(M_r)
=
\frac{4r^2}{3r^2+2r+1}
=
\frac{4}{3}
-
\frac{8}{9r}
+
O(r^{-2}).
$$

Eliminating $r$ gives

$$
\boxed{
\frac{4}{3}-\overline{\alpha}(M_r)
=
\frac{\pi}{9}\,d_B(M_r)^2
+
O\left(d_B(M_r)^4\right).
}
$$

Thus, within this family:

- $\overline{\alpha}(M_r)$ increases toward $4/3$.
- The proportion of rank-sized subsets that are bases decreases to zero.
- That density decreases only as $r^{-1/2}$, rather than exponentially.

There cannot be an unrestricted universal relationship between $d_B$ and $\overline{\alpha}$: adding loops or coloops preserves the correlation ratios of the original non-loop, non-coloop pairs while making $d_B$ arbitrarily small. Thus, the quadratic relation above is a feature of this natural loopless family, not a general law for all matroids.


Yes. From now on I’ll consistently use `$...$` for inline TeX and `$$...$$` for displayed TeX.

## A family of transversal matroids approaching $\boldsymbol{4/3}$

There is an explicit family of transversal matroids $M_r$ satisfying

$$
\overline{\alpha}(M_r)
=
\frac{4r^2}{3r^2+2r+1}
\longrightarrow
\frac{4}{3}.
$$

In particular, the rank-$19$ member on $38$ elements has

$$
\boxed{
\overline{\alpha}(M_9)
=
\frac{162}{131}
>
\frac{100}{81}.
}
$$

### Construction

Fix an integer $r\geq 3$. Take $2r+1$ matching slots

$$
A\sqcup B\sqcup\{g\},
\qquad
|A|=|B|=r,
$$

and a ground set

$$
E=X\sqcup Y\sqcup\{e,f\},
\qquad
|X|=|Y|=2r.
$$

Define a bipartite presentation as follows:

- Every $x\in X$ is adjacent to all the slots in $A\cup\{g\}$.
- Every $y\in Y$ is adjacent to all the slots in $B\cup\{g\}$.
- The element $e$ is adjacent only to $g$.
- The element $f$ is adjacent to every slot.

A subset of $E$ is independent if it can be matched injectively into the slots. This defines a transversal matroid $M_r$ of rank

$$
\operatorname{rk}(M_r)=2r+1
$$

on

$$
|E|=4r+2
$$

elements.

Equivalently, as an indexed family of sets, the presentation consists of:

- $r$ copies of $X\cup\{f\}$;
- $r$ copies of $Y\cup\{f\}$;
- one copy of $X\cup Y\cup\{e,f\}$.

### Classification of the bases

For a basis $Q$, record the profile

$$
\left(
|Q\cap X|,
|Q\cap Y|,
\mathbf 1_{\{e\in Q\}},
\mathbf 1_{\{f\in Q\}}
\right).
$$

Hall’s condition shows that the possible basis profiles are exactly

$$
\begin{aligned}
&(r+1,r,0,0),
\qquad
(r,r+1,0,0),\\
&(r,r,1,0),\\
&(r,r,0,1),
\qquad
(r+1,r-1,0,1),
\qquad
(r-1,r+1,0,1),\\
&(r,r-1,1,1),
\qquad
(r-1,r,1,1).
\end{aligned}
$$

The reason is that $g$ is the only overflow slot shared by $X$ and $Y$:

- If neither $e$ nor $f$ is present, one of $X,Y$ must use $g$.
- If only $e$ is present, then $e$ occupies $g$, forcing exactly $r$ elements from each bank.
- If only $f$ is present, then $f$ can occupy $g$, an $A$-slot, or a $B$-slot.
- If both are present, then $e$ occupies $g$, while $f$ occupies one slot in either $A$ or $B$.

Set

$$
c=\binom{2r}{r}
$$

and

$$
d
=
\binom{2r}{r-1}
=
\binom{2r}{r+1}
=
\frac{r}{r+1}c.
$$

For the distinguished pair $e,f$, the four basis counts are therefore:

| Status of $e,f$ | Number of bases |
|---|---:|
| neither | $2cd$ |
| $e$ only | $c^2$ |
| $f$ only | $c^2+2d^2$ |
| both | $2cd$ |

Consequently,

$$
\begin{aligned}
\alpha_{e,f}(M_r)
&=
\frac{(2cd)(2cd)}
{c^2(c^2+2d^2)}\\
&=
\frac{4(d/c)^2}
{1+2(d/c)^2}\\
&=
\frac{4r^2}{3r^2+2r+1}.
\end{aligned}
$$

### Checking all other pairs

Permutations within $X$, permutations within $Y$, and interchange of the two banks reduce all other pairs to a few symmetry types.

Substitution into the eight basis profiles gives:

| Pair type | Correlation ratio |
|---|---:|
| $e,f$ | $\displaystyle \frac{4r^2}{3r^2+2r+1}$ |
| two elements of $X$, or two of $Y$ | $\displaystyle \frac{r^2}{(r+1)^2}$ |
| one element of $X$ and one of $Y$ | $\displaystyle \left(\frac{2r(r+1)}{2r(r+1)+1}\right)^2$ |
| $e$ or $f$ paired with an element of $X$ or $Y$ | $\displaystyle \frac{3r^2(5r+3)}{(3r+2)(5r^2+5r+2)}$ |

Every ratio in the last three rows is strictly less than $1$. For example, in the last row the denominator minus the numerator is

$$
(3r+2)(5r^2+5r+2)-3r^2(5r+3)
=
4(2r+1)^2
>
0.
$$

Thus the pair $e,f$ is the unique pair type with positive correlation, and

$$
\boxed{
\overline{\alpha}(M_r)
=
\frac{4r^2}{3r^2+2r+1}.
}
$$

### The first member beating $\boldsymbol{100/81}$

For $r=9$,

$$
c=\binom{18}{9}=48{,}620
$$

and

$$
d=\binom{18}{8}=\binom{18}{10}=43{,}758.
$$

The four basis counts are:

| Status of $e,f$ | Number of bases |
|---|---:|
| neither | $4{,}255{,}027{,}920$ |
| $e$ only | $2{,}363{,}904{,}400$ |
| $f$ only | $6{,}193{,}429{,}528$ |
| both | $4{,}255{,}027{,}920$ |

Therefore,

$$
\overline{\alpha}(M_9)
=
\frac{162}{131}
\approx 1.236641221.
$$

Comparison with the previous example gives

$$
\frac{162}{131}
-
\frac{100}{81}
=
\frac{22}{10{,}611}
>
0.
$$

Thus $M_9$ is a transversal matroid with

$$
\boxed{
\overline{\alpha}(M_9)>\frac{100}{81}.
}
$$

### Why the limit is $\boldsymbol{4/3}$

Since

$$
\frac{d}{c}
=
\frac{r}{r+1}
\longrightarrow 1,
$$

the four basis counts, after normalization by $c^2$, approach the proportions

$$
(2,1,3,2).
$$

Their correlation ratio is

$$
\frac{2\cdot 2}{1\cdot 3}
=
\frac{4}{3}.
$$

Equivalently,

$$
\lim_{r\to\infty}\overline{\alpha}(M_r)
=
\lim_{r\to\infty}
\frac{4r^2}{3r^2+2r+1}
=
\frac{4}{3}.
$$

For example, taking $r=1000$ gives a rank-$2001$ transversal matroid on $4002$ elements with

$$
\overline{\alpha}(M_{1000})
=
\frac{4{,}000{,}000}{3{,}002{,}001}
\approx 1.332444593.
$$

The structural mechanism is the shared overflow slot $g$. The rigid element $e$ and the universal element $f$ interact with that bottleneck in different ways, producing respectively one and three mixed basis profiles, but two profiles in each of the unmixed cases. This is what produces the limiting proportions $(2,1,3,2)$ and hence the limiting ratio $4/3$.