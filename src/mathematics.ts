// The mathematics page: definitions, background, the discovery record, and
// full proofs of the family formulas — adapted from Chris Eur's draft site,
// with the verification section rewritten for this site's verifier and
// computational remarks added where this site has checked something new.
//
// This is the one page that renders LaTeX, via MathJax from CDN (as in the
// draft). The content is a raw template literal, so backslashes below are
// literal TeX.

import { layout, type User } from './pages'

const MATHJAX_HEAD = `
    <script>
      window.MathJax = {
        tex: {
          inlineMath: [['\\(', '\\)']],
          displayMath: [['\\[', '\\]']],
          processEscapes: true,
        },
        chtml: { scale: 0.98 },
      };
    </script>
    <script defer src="https://cdn.jsdelivr.net/npm/mathjax@4/tex-chtml.js"></script>`

const CONTENT = String.raw`
    <section class="prose math-page">
      <p class="page-nav"><a href="/">&larr; home</a></p>
      <p class="eyebrow">Definitions, proofs, and provenance</p>
      <h2>The mathematics behind the records</h2>
      <p>
        On the <a href="/">Explore</a> chart, a solid curve is a proved value of the full
        invariant; a dashed curve is an exact value for a specified pair and therefore a
        certified lower bound. This page fixes the notation, explains what a verification on
        this site proves, proves every displayed family formula, and records who found each
        construction.
      </p>

      <nav class="math-toc" aria-label="Contents">
        <a href="#definition">Definition</a>
        <a href="#background">Background</a>
        <a href="#discovery">Discovery record</a>
        <a href="#verification">Exact finite check</a>
        <a href="#counting">Counting identity</a>
        <a href="#two-design">2-design mechanism</a>
        <a href="#uniform-family">Uniform family</a>
        <a href="#geometries">Geometries</a>
        <a href="#steiner">Steiner systems</a>
        <a href="#representability">Representability</a>
        <a href="#references">References</a>
      </nav>

      <h3 id="definition">Definition <span class="muted">&mdash; unweighted and weighted correlation ratios</span></h3>
      <p>
        Let \(M\) be a matroid on \([n]=\{0,\ldots,n-1\}\). For distinct \(i,j\in[n]\), set
      </p>
      <div class="math-panel">
      \[
      \begin{aligned}
      B^{ij}(M) &:= \{B \text{ a basis of } M : i, j \notin B\},\\
      B_{ij}(M) &:= \{B \text{ a basis of } M : i, j \in B\},\\
      B^i_j(M) &:= \{B \text{ a basis of } M : i \notin B,\ j \in B\},
      \end{aligned}
      \]
      \[
      R_{ij}(M) := \frac{|B^{ij}(M)|\,|B_{ij}(M)|}{|B^i_j(M)|\,|B^j_i(M)|},
      \qquad
      \overline{\alpha}(M) := \max_{i\ne j} R_{ij}(M),
      \]
      </div>
      <p>
        where the maximum ranges over pairs of nonloop, noncoloop elements. For such a pair the
        two denominator factors are positive. If \(M\) consists only of loops and coloops, the
        convention is \(\overline{\alpha}(M)=0\). This unweighted invariant
        \(\overline{\alpha}\) &mdash; written simply \(\alpha\) elsewhere on this site &mdash;
        is what every record entry certifies exactly.
      </p>
      <p>
        For positive weights \(w=(w_x)_{x\in E(M)}\), replace each cardinality by its weighted
        basis sum, for example
        \(B^{ij}(M,w) := \sum_{B\in B^{ij}(M)}\prod_{x\in B} w_x\), and set
      </p>
      <div class="math-panel">
      \[
      \alpha(M) := \sup_{\substack{i\ne j\\ w\in\mathbb R_{>0}^{E(M)}}}
      \frac{B^{ij}(M,w)\,B_{ij}(M,w)}{B^i_j(M,w)\,B^j_i(M,w)}.
      \]
      </div>
      <p>
        The weighted \(\alpha\) permits arbitrary positive weights and dominates
        \(\overline{\alpha}\); it is out of scope for this site's automated verification.
      </p>

      <h3 id="background">Background <span class="muted">&mdash; negative correlation, balance, and the half-plane property</span></h3>
      <p>
        Choose a basis \(B\) of \(M\) uniformly at random. For distinct nonloop, noncoloop
        elements \(i,j\), <em>negative correlation</em> means
        \(\Pr(i,j\in B)\leq \Pr(i\in B)\Pr(j\in B)\). For the associated \(2\times2\) table
        this is equivalent to
        \(|B^{ij}(M)|\,|B_{ij}(M)| \leq |B^i_j(M)|\,|B^j_i(M)|\), or simply
        \(R_{ij}(M)\leq 1\).
      </p>
      <p>
        Negative correlation does not hold for every matroid. Seymour and Welsh gave the first
        example with a positively correlated pair: the eight-element binary matroid \(S_8\),
        for which \(R_{ij}(S_8)>1\) for some pair [9].
      </p>
      <p>
        A matroid is <em>balanced</em> if the uniform negative-correlation inequality holds for
        every pair in every minor; in particular a balanced matroid satisfies
        \(\overline{\alpha}(M)\leq1\). The terminology and systematic study of balanced
        matroids are due to Feder and Mihail [2]. The basis-generating polynomial is
        \(Z_M(z)=\sum_{B\in\mathcal B(M)}\prod_{e\in B}z_e\), and \(M\) has the
        <em>half-plane property</em> (HPP) when \(Z_M(z)\neq0\) whenever every variable has
        positive real part [3]. The HPP implies the weighted Rayleigh inequality for every pair
        and every positive weight vector &mdash; that is, \(\alpha(M)\leq1\), also called the
        1-Rayleigh property [3][5] &mdash; and taking weights to zero or infinity passes the
        inequality to deletions and contractions, so every 1-Rayleigh matroid is balanced [4].
        Thus
      </p>
      <div class="math-panel">
      \[
      \mathrm{HPP} \Longrightarrow 1\text{-Rayleigh} \Longrightarrow \text{balanced}
      \Longrightarrow \overline{\alpha}(M)\leq1.
      \]
      </div>
      <p>
        Examples with the HPP &mdash; hence balanced &mdash; include uniform and regular
        matroids; in particular graphic and cographic matroids, and more generally every
        sixth-root-of-unity matroid. The HPP class is closed under minors, duality, direct
        sums, and 2-sums, among other operations [2][3]. Not every matroid is balanced or
        1-Rayleigh. Nevertheless, Huh&ndash;Schr&ouml;ter&ndash;Wang [1] proved the universal
        bound
      </p>
      <div class="math-panel emphasized">
      \[
      \boxed{\ \overline{\alpha}(M)\leq\alpha(M)\leq 2\ }
      \]
      </div>
      <p>for every matroid \(M\).</p>

      <h3 id="discovery">Discovery record <span class="muted">&mdash; known values and how they were found</span></h3>
      <p>
        <strong>Literature family &middot; June 2018 &middot; \(\overline{\alpha}=8/7\).</strong>
        The finite-field spike family \(M_p^5\) is due to June Huh, Benjamin Schr&ouml;ter, and
        Botong Wang; it appears in Section 5 of their paper on correlation bounds [1]. No AI
        use is reported in that discovery record. This site holds verified members over
        GF(2), GF(3), GF(4), GF(5), and GF(7) (<a href="/matroids">records table</a>).
      </p>
      <p>
        <strong>Finite example &middot; August 2026 &middot; \(\overline{\alpha}=100/81\).</strong>
        Chris Eur and David Renshaw found the ternary example in a computer search using
        AlphaEvolve [6]. Independently, June Huh found it through the study of Mathieu groups
        with ChatGPT 5.5 Pro assisting the exploration. Huh observed additional structure:
        contracting two elements yields the matroid of the Steiner system \(S(3,4,10)\), and
        the relevant linear subclasses are related to the duads and synthemes for the
        permutation group on six letters. The complete matrix and exact maximizing-pair
        certificate are on <a href="/matroid/3">its record page</a>; the unique maximizing
        pair is \((5,10)\) with basis counts \((180,162,162,180)\).
      </p>
      <p>
        <strong>Infinite lower-bound families &middot; August 2026 &middot; \(R_{ef}\to 4/3\).</strong>
        Alexander Divoux and Shouda Wang first found the uniform self-sum family with the aid
        of ChatGPT 5.6 Sol Ultra; its reinterpretation as a double free-extension is due to
        humans, and the original formulation used transversal matroids. Using the double-free
        construction, Chris Eur then found the affine-geometry, projective-geometry, and
        Steiner-system families below via ChatGPT 5.6 Sol Max on Codex, which assisted the
        mathematical exploration and formula checks. The organizing observation is that the
        bases of all four starting matroids form 2-designs. No public chat links are currently
        recorded.
      </p>

      <h3 id="verification">Exact finite check <span class="muted">&mdash; what a record entry on this site proves</span></h3>
      <p>
        The verifier is pure TypeScript and runs on every submission
        (<a class="external" href="https://github.com/icarm/matroid-correlation-constants">source</a>).
        It reconstructs the matroid from one complete description &mdash; a matrix over
        \(\mathbb Q\), a prime field, or an extension field \(\mathrm{GF}(p^d)\) up to order
        1024 in the Conway-polynomial basis; or the complete list of bases, circuits, or
        hyperplanes. It validates the relevant axioms exactly (basis exchange for a bases list;
        nonemptiness, incomparability, and weak elimination for circuits; the dual circuit
        axioms for hyperplanes), streams every basis, computes the four counts above for every
        eligible pair, and compares all ratios by exact integer cross multiplication &mdash;
        no floating point touches any verdict. An optional claimed \(\overline{\alpha}\) is
        checked against the computed value, so a recorded entry is a verified claim. Ground
        sets go up to \(n = 30\) elements when the rank keeps the enumeration feasible
        (everything with \(n \le 24\) is accepted). A record entry also requires a discovery
        record &mdash; discoverers, a discovery date, and an explicit AI-use declaration.
        Submitted code is never executed.
      </p>

      <h3 id="counting">Construction program <span class="muted">&mdash; families built by double-(co)-extending self-direct-sums</span></h3>
      <p>
        All four families below use the same template: begin with a matroid \(M\), form
        \(M\oplus M\), freely extend by \(e\), and freely coextend by \(f\). Write
        \(N+e\times f\) for the free coextension by \(f\) of the free extension by \(e\) of
        \(N\). Let \(M\) have rank \(m\), and define the four adjacent-rank counts
      </p>
      <div class="math-panel">
      \[
      \begin{aligned}
      i &= \#\{I\subseteq E(M) : |I|=m-1,\ I \text{ independent}\},\\
      b &= |\mathcal B(M)|,\\
      a &= \#\{A\subseteq E(M) : |A|=m,\ \operatorname{rk}_M(A)\ge m-1\},\\
      s &= \#\{S\subseteq E(M) : |S|=m+1,\ \operatorname{rk}_M(S)=m\}.
      \end{aligned}
      \]
      </div>
      <p>
        The four basis classes of \(M+e\times f\), according to whether they contain \(e\) and
        \(f\), correspond respectively to the independent \((m-1)\)-sets, bases, rank-\(m\)
        sets of rank at least \(m-1\), and spanning \((m+1)\)-sets of \(M\). Hence
      </p>
      <div class="math-panel emphasized">
      \[
      \boxed{\ \epsilon(M) := R_{ef}(M+e\times f) = \frac{is}{ab}.\ } \tag{1}
      \]
      </div>
      <p>
        For \(N=M\oplus M\), distributing an almost-basis or an almost-spanning set between the
        two summands gives \(b_N=b^2\), \(i_N=2ib\), \(s_N=2sb\), and \(a_N=2ab-b^2+2is\), so
      </p>
      <div class="math-panel emphasized">
      \[
      \boxed{\ \epsilon(M\oplus M) = R_{ef}\bigl((M\oplus M)+e\times f\bigr)
        = \frac{4is}{2ab-b^2+2is}.\ } \tag{2}
      \]
      </div>
      <p>
        Equivalently, with \(Q(M)=is/b^2\), \(Z(M)=a/b\), and \(\beta(M)=b/a\),
      </p>
      <div class="math-panel">
      \[
      \epsilon(M\oplus M) = \frac{4Q(M)}{2Z(M)-1+2Q(M)}
        = \frac{4\epsilon(M)}{2(1+\epsilon(M))-\beta(M)}. \tag{3}
      \]
      </div>
      <h3 id="two-design">Common mechanism <span class="muted">&mdash; why the starting matroids all have the uniform value</span></h3>
      <p>
        Suppose the bases of a rank-\(r\) matroid \(M\) form a \(2\)-\((n,r,\lambda)\) design,
        and let \(b=|\mathcal B(M)|\). Double counting bases through zero, one, or two
        specified elements gives, for every distinct \(i,j\),
      </p>
      <div class="math-panel emphasized">
      \[
      |B_{ij}(M)| = \frac{br(r-1)}{n(n-1)}, \qquad
      |B^i_j(M)| = |B^j_i(M)| = \frac{br(n-r)}{n(n-1)}, \qquad
      |B^{ij}(M)| = \frac{b(n-r)(n-r-1)}{n(n-1)},
      \]
      \[
      \boxed{\ \overline{\alpha}(M) = \frac{(r-1)(n-r-1)}{r(n-r)} = \overline{\alpha}(U_{r,n}).\ } \tag{4}
      \]
      </div>
      <p>
        The 2-design condition determines these four basis-incidence counts, but it does not
        determine \(i,a,s\). Therefore it fixes \(\overline{\alpha}(M)\) without fixing
        \(\epsilon(M\oplus M)\) &mdash; precisely the room exploited by the geometry and
        Steiner constructions.
      </p>

      <h3 id="uniform-family">Family 1 <span class="muted">&mdash; uniform self-sum extensions</span></h3>
      <p>Take \(M=U_{r,2r}\) and \(P_r=(M\oplus M)+e\times f\). Then</p>
      <div class="math-panel emphasized">
      \[
      a=b=\binom{2r}{r}, \qquad i=s=\binom{2r}{r-1}, \qquad
      Q(M) = \left(\frac{\binom{2r}{r-1}}{\binom{2r}{r}}\right)^{\!2} = \frac{r^2}{(r+1)^2},
      \qquad Z(M)=1,
      \]
      \[
      \boxed{\ R_{ef}(P_r) = \frac{4r^2}{3r^2+2r+1} \longrightarrow \frac43.\ } \tag{5}
      \]
      </div>
      <p>
        The displayed value is exact for \((e,f)\), so it proves
        \(\overline{\alpha}(P_r)\ge R_{ef}(P_r)\). It is not presently proved that \((e,f)\)
        maximizes the full invariant for every \(r\) &mdash; this is why the curve is dashed.
        <em>Computational remark (this site):</em> exact enumeration confirms that \((e,f)\) is
        the unique maximizing pair for \(2\le r\le 5\), so
        \(\overline{\alpha}(P_r)=R_{ef}(P_r)\) on the nose for those members;
        \(P_5\) is <a href="/matroid/8">record entry #8</a>.
      </p>
      <p class="muted">
        Credit: Alexander Divoux and Shouda Wang, August 2026, with the aid of ChatGPT 5.6 Sol
        Ultra; the double free-extension reinterpretation is due to humans.
      </p>

      <h3 id="geometries">Families 2 and 3 <span class="muted">&mdash; affine and projective geometries</span></h3>
      <p>
        Let \(G\) be either \(\operatorname{AG}(d-1,q)\), of rank \(d\) on \(q^{d-1}\) points,
        or \(\operatorname{PG}(d-1,q)\), of rank \(d\) on \((q^d-1)/(q-1)\) points. Their
        point-automorphism groups are 2-transitive, so their bases form 2-designs and (4)
        applies. For a rank-\(d\) geometry \(G\), let \(\sigma_G(k)\) be the number of
        spanning \(k\)-subsets. M&ouml;bius inversion on the flat lattice gives
      </p>
      <div class="math-panel">
      \[
      \sigma_{\operatorname{PG}(d-1,q)}(k) = \sum_{j=0}^{d} { d \brack j }_q (-1)^{d-j}
        q^{\binom{d-j}{2}} \binom{(q^j-1)/(q-1)}{k}, \tag{6}
      \]
      \[
      \sigma_{\operatorname{AG}(d-1,q)}(k) = \sum_{j=1}^{d} q^{d-j} { d-1 \brack j-1 }_q
        (-1)^{d-j} q^{\binom{d-j}{2}} \binom{q^{j-1}}{k}, \tag{7}
      \]
      </div>
      <p>
        where \({d \brack j}_q\) is a Gaussian binomial coefficient. Let \(h_G\) be the number
        of hyperplanes of \(G\) and \(H\) one such hyperplane. Every independent
        \((d-1)\)-set spans a unique hyperplane, as does every nonspanning \(d\)-set of rank
        \(d-1\). Consequently the four inputs to (2) are
      </p>
      <div class="math-panel">
      \[
      i = h_G\,\sigma_H(d-1), \qquad b = \sigma_G(d), \qquad
      a = b + h_G\,\sigma_H(d), \qquad s = \sigma_G(d+1), \tag{8}
      \]
      </div>
      <p>
        and equations (2), (6)&ndash;(8) give every plotted affine and projective point as an
        exact rational number, without enumerating subsets of the exponentially large ground
        sets. For fixed \(q\) and \(d\to\infty\), the relevant rank probabilities converge to
        those of random matrices over \(\operatorname{GF}(q)\), giving
      </p>
      <div class="math-panel emphasized">
      \[
      \boxed{\ R_{ef}\bigl((G\oplus G)+e\times f\bigr) \longrightarrow \frac{4q^2}{3q^2+1};\ } \tag{9}
      \]
      </div>
      <p>for fixed \(d\) and \(q\to\infty\) the geometry is asymptotically uniform in all the
      counts relevant to (2), giving</p>
      <div class="math-panel emphasized">
      \[
      \boxed{\ R_{ef}\bigl((G\oplus G)+e\times f\bigr) \longrightarrow \frac{4d}{3d+1}.\ } \tag{10}
      \]
      </div>
      <p>Either subsequent limit &mdash; \(q\to\infty\) in (9) or \(d\to\infty\) in (10) &mdash;
      approaches \(4/3\).</p>
      <p class="muted">
        Credit: Chris Eur, August 2026, via ChatGPT 5.6 Sol Max on Codex, using the double-free
        construction and the shared 2-design mechanism.
      </p>

      <h3 id="steiner">Family 4 <span class="muted">&mdash; Steiner-system sparse-paving matroids</span></h3>
      <p>
        Let the circuit-hyperplanes of a rank-\(r\) sparse-paving matroid \(M_{r,n}\) be the
        blocks of a Steiner system \(S(r-1,r,n)\). Two blocks intersect in at most \(r-2\)
        elements, so this is a valid sparse-paving matroid; the blocks form a 2-design, hence
        so do the bases. Put \(c=n-r\). The number of circuit-hyperplanes is
        \(h = \frac1r\binom{n}{r-1} = \frac1{c+1}\binom nr\). Every \((r-1)\)-set is
        independent, every \(r\)-set has rank at least \(r-1\), and every \((r+1)\)-set is
        spanning, so
      </p>
      <div class="math-panel">
      \[
      i = \binom{n}{r-1}, \qquad b = \frac{c}{c+1}\binom nr, \qquad a = \binom nr,
      \qquad s = \binom{n}{r+1},
      \qquad \epsilon(M_{r,n}) = \frac{r}{r+1}, \qquad \beta(M_{r,n}) = \frac{c}{c+1}.
      \]
      </div>
      <p>Substitution in (3) proves the displayed family formula:</p>
      <div class="math-panel emphasized">
      \[
      \boxed{\ R_{ef}\bigl((M_{r,n}\oplus M_{r,n})+e\times f\bigr)
        = \frac{4r(c+1)}{(3r+1)c+4r+2},\ } \tag{11}
      \]
      \[
      \lim_{n\to\infty} R_{ef} = \frac{4r}{3r+1}, \qquad \lim_{r\to\infty}\frac{4r}{3r+1} = \frac43.
      \]
      </div>
      <p>The two plotted subfamilies are</p>
      <div class="math-panel">
      \[
      \begin{array}{c|c|c}
      \text{systems} & \text{admissible } n & R_{ef}\\
      \hline
      S(2,3,n) & n\equiv1,3 \pmod 6 & \dfrac{6(n-2)}{5n-8} \longrightarrow \dfrac65\\[8pt]
      S(3,4,n) & n\equiv2,4 \pmod 6 & \dfrac{16(n-3)}{13n-34} \longrightarrow \dfrac{16}{13}.
      \end{array}
      \]
      </div>
      <p>
        The existence of \(S(3,4,n)\) for every \(n\equiv2,4\pmod6\) is Hanani's theorem [8];
        for every fixed \(r\), Keevash's existence theorem for designs [7] supplies
        \(S(r-1,r,n)\) for all sufficiently large admissible \(n\), making (11) an infinite
        family at every fixed rank.
      </p>
      <p class="muted">
        Credit: Chris Eur, August 2026, beginning with Steiner triples, via ChatGPT 5.6 Sol Max
        on Codex.
      </p>

      <h3 id="representability">Field of representation <span class="muted">&mdash; representability may require a field extension</span></h3>
      <p>
        Suppose the starting matroid is represented over a finite field \(K\). After passing to
        a sufficiently large finite extension \(L/K\), the finitely many linear spans of its
        nonspanning flats cannot cover the ambient \(L\)-vector space; choosing a vector
        outside their union realizes a free extension, and the same argument in the dual
        realizes a free coextension. So if the starting matroid is representable in
        characteristic \(p\), the double-(co)-extended matroid is too. This does <em>not</em>
        imply representability over the original field: for
        \(G=\operatorname{AG}(d-1,2)\) with \(d\geq3\), every nonzero binary vector lies in the
        span of at most two columns of the standard representation, so \(G+e\) is not binary;
        since \(\bigl((G\oplus G)+e\times f\bigr)/f = (G\oplus G)+e\) and binary
        representability passes to minors, the affine-geometry construction is not binary,
        although it is representable over a large enough field of characteristic 2.
        (This is why this site's explicit realizations of such members use large prime fields,
        with genericity certified by exact count matching.)
      </p>

      <h3 id="references">References</h3>
      <ol class="references">
        <li>June Huh, Benjamin Schr&ouml;ter, and Botong Wang,
          <a class="external" href="https://arxiv.org/abs/1806.02675">&ldquo;Correlation bounds for fields and matroids&rdquo;</a>,
          J. Eur. Math. Soc. 24 (2022), 1335&ndash;1351. The general correlation bound and the
          \(8/7\) family (Section 5).</li>
        <li>Tom&aacute;s Feder and Milena Mihail,
          &ldquo;Balanced matroids&rdquo;, STOC 1992, 26&ndash;38. Introduces balanced matroids;
          proves balance for graphic and regular matroids.</li>
        <li>Young-Bin Choe, James G. Oxley, Alan D. Sokal, and David G. Wagner,
          <a class="external" href="https://arxiv.org/abs/math/0202034">&ldquo;Homogeneous multivariate polynomials with the half-plane property&rdquo;</a>,
          Adv. Appl. Math. 32 (2004), 88&ndash;187.</li>
        <li>Young-Bin Choe and David G. Wagner,
          <a class="external" href="https://arxiv.org/abs/math/0410328">&ldquo;Rayleigh matroids&rdquo;</a>,
          Combin. Probab. Comput. 15 (2006), 765&ndash;781.</li>
        <li>Petter Br&auml;nd&eacute;n,
          <a class="external" href="https://arxiv.org/abs/math/0605678">&ldquo;Polynomials with the half-plane property and matroid theory&rdquo;</a>,
          Adv. Math. 216 (2007), 302&ndash;320.</li>
        <li>Alexander Novikov et al.,
          <a class="external" href="https://arxiv.org/abs/2506.13131">&ldquo;AlphaEvolve: a coding agent for scientific and algorithmic discovery&rdquo;</a>.
          The system used in the Eur&ndash;Renshaw search that found the \(100/81\) example.</li>
        <li>Peter Keevash,
          <a class="external" href="https://arxiv.org/abs/1401.3665">&ldquo;The existence of designs&rdquo;</a>.
          Supplies the general Steiner systems used in the sparse-paving family.</li>
        <li>Haim Hanani, &ldquo;On quadruple systems&rdquo;, Canad. J. Math. 12 (1960),
          145&ndash;157. Steiner quadruple systems exist exactly in the admissible congruence
          classes used above.</li>
        <li>P. D. Seymour and D. J. A. Welsh,
          &ldquo;Combinatorial applications of an inequality from statistical mechanics&rdquo;,
          Math. Proc. Cambridge Philos. Soc. 77 (1975), 485&ndash;495. The first example of a
          matroid with a positively correlated pair, the binary matroid now denoted \(S_8\).</li>
      </ol>
    </section>`

export function mathematicsPage(user: User | null = null): string {
  return layout(
    'Mathematics — Matroid Correlation Constants',
    CONTENT,
    user,
    MATHJAX_HEAD,
  )
}
