"""
Analyze infinite base-2-design matroid families for the self-direct-sum
epsilon invariant.

Usage:

    julia --project=. scripts/make_two_design_self_sum_report.jl
"""

using CairoMakie
using Printf

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

const PROJECT_DIRECTORY = normpath(joinpath(@__DIR__, ".."))
const REPORT_PATH =
    joinpath(PROJECT_DIRECTORY, "reports", "two_design_self_sum_report.md")
const CSV_PATH =
    joinpath(PROJECT_DIRECTORY, "data", "epsilon_analysis", "two_design_family_summary.csv")
const FIGURE_PATH =
    joinpath(PROJECT_DIRECTORY, "figures", "epsilon_analysis", "two_design_self_sum_limits.png")

function gaussian_binomial(n::Int, k::Int, q::Int)
    (k < 0 || k > n) && return BigInt(0)
    k = min(k, n - k)
    numerator_value = BigInt(1)
    denominator_value = BigInt(1)
    field_size = BigInt(q)
    for index in 0:k-1
        numerator_value *= field_size^(n - index) - 1
        denominator_value *= field_size^(k - index) - 1
    end
    return div(numerator_value, denominator_value)
end

projective_point_count(rank::Int, q::Int) =
    div(BigInt(q)^rank - 1, q - 1)

function projective_spanning_subsets(rank::Int, size::Int, q::Int)
    total = BigInt(0)
    for flat_rank in 0:rank
        points = projective_point_count(flat_rank, q)
        points < size && continue
        codimension = rank - flat_rank
        mobius = (-1)^codimension *
                 BigInt(q)^(codimension * (codimension - 1) ÷ 2)
        total += gaussian_binomial(rank, flat_rank, q) *
                 mobius * binomial(points, size)
    end
    total >= 0 || error("negative projective spanning-subset count")
    return total
end

function projective_geometry_profile(q::Int, rank::Int)
    hyperplanes = gaussian_binomial(rank, rank - 1, q)
    independent =
        hyperplanes * projective_spanning_subsets(rank - 1, rank - 1, q)
    bases = projective_spanning_subsets(rank, rank, q)
    almost_bases =
        bases + hyperplanes * projective_spanning_subsets(rank - 1, rank, q)
    spanning = projective_spanning_subsets(rank, rank + 1, q)
    return (
        n=projective_point_count(rank, q),
        r=rank,
        independent_r_minus_1=independent,
        num_bases=bases,
        rank_at_least_r_minus_1=almost_bases,
        spanning_r_plus_1=spanning,
    )
end

function affine_flat_count(ambient_rank::Int, flat_rank::Int, q::Int)
    1 <= flat_rank <= ambient_rank || return BigInt(0)
    return BigInt(q)^(ambient_rank - flat_rank) *
           gaussian_binomial(ambient_rank - 1, flat_rank - 1, q)
end

function affine_spanning_subsets(rank::Int, size::Int, q::Int)
    total = BigInt(0)
    for flat_rank in 1:rank
        points = BigInt(q)^(flat_rank - 1)
        points < size && continue
        codimension = rank - flat_rank
        mobius = (-1)^codimension *
                 BigInt(q)^(codimension * (codimension - 1) ÷ 2)
        total += affine_flat_count(rank, flat_rank, q) *
                 mobius * binomial(points, size)
    end
    total >= 0 || error("negative affine spanning-subset count")
    return total
end

function affine_geometry_profile(q::Int, rank::Int)
    hyperplanes = affine_flat_count(rank, rank - 1, q)
    independent =
        hyperplanes * affine_spanning_subsets(rank - 1, rank - 1, q)
    bases = affine_spanning_subsets(rank, rank, q)
    almost_bases =
        bases + hyperplanes * affine_spanning_subsets(rank - 1, rank, q)
    spanning = affine_spanning_subsets(rank, rank + 1, q)
    return (
        n=BigInt(q)^(rank - 1),
        r=rank,
        independent_r_minus_1=independent,
        num_bases=bases,
        rank_at_least_r_minus_1=almost_bases,
        spanning_r_plus_1=spanning,
    )
end

function rational_float(value::Rational)
    return Float64(BigFloat(numerator(value)) / BigFloat(denominator(value)))
end

function geometry_row(family::String, q::Int, rank::Int)
    profile = family == "PG" ?
              projective_geometry_profile(q, rank) :
              affine_geometry_profile(q, rank)
    independent = BigInt(profile.independent_r_minus_1)
    bases = BigInt(profile.num_bases)
    almost_bases = BigInt(profile.rank_at_least_r_minus_1)
    spanning = BigInt(profile.spanning_r_plus_1)
    epsilon = independent * spanning // (almost_bases * bases)
    beta = bases // almost_bases
    defect = almost_bases // bases - independent * spanning // bases^2
    self_sum = direct_sum_epsilon_statistics(profile, profile).epsilon
    n = BigInt(profile.n)
    alpha =
        BigInt(rank - 1) * (n - rank - 1) //
        (BigInt(rank) * (n - rank))
    return (
        family=family,
        q=q,
        rank=rank,
        n=n,
        independent=independent,
        bases=bases,
        almost_bases=almost_bases,
        spanning=spanning,
        alpha=alpha,
        epsilon=epsilon,
        beta=beta,
        defect=defect,
        self_sum=self_sum,
        epsilon_value=rational_float(epsilon),
        beta_value=rational_float(beta),
        defect_value=rational_float(defect),
        self_sum_value=rational_float(self_sum),
    )
end

function geometry_rows()
    rows = NamedTuple[]
    for family in ("PG", "AG"), q in (2, 3, 5, 7),
        rank in (3, 4, 5, 6, 8, 10, 15, 20, 30)
        @info "base-2-design geometry" family=family q=q rank=rank
        push!(rows, geometry_row(family, q, rank))
    end
    return rows
end

function validate_small_profiles()
    fano = projective_geometry_profile(2, 3)
    @assert (
        fano.independent_r_minus_1,
        fano.num_bases,
        fano.rank_at_least_r_minus_1,
        fano.spanning_r_plus_1,
    ) == (21, 28, 35, 35)

    affine_binary = affine_geometry_profile(2, 3)
    @assert (
        affine_binary.independent_r_minus_1,
        affine_binary.num_bases,
        affine_binary.rank_at_least_r_minus_1,
        affine_binary.spanning_r_plus_1,
    ) == (6, 4, 4, 1)

    affine_ternary = affine_geometry_profile(3, 3)
    @assert (
        affine_ternary.independent_r_minus_1,
        affine_ternary.num_bases,
        affine_ternary.rank_at_least_r_minus_1,
        affine_ternary.spanning_r_plus_1,
    ) == (36, 72, 84, 126)
end

function csv_cell(value)
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

function write_csv(path, rows)
    headers = [
        "family", "field_size", "rank", "ground_set_size",
        "independent_r_minus_1", "num_bases", "rank_at_least_r_minus_1",
        "spanning_r_plus_1", "alpha_one", "epsilon", "basis_purity",
        "defect", "self_sum_epsilon", "epsilon_value",
        "basis_purity_value", "defect_value", "self_sum_epsilon_value",
    ]
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, join(headers, ','))
        for row in rows
            values = Any[
                row.family, row.q, row.rank, row.n, row.independent, row.bases,
                row.almost_bases, row.spanning, row.alpha, row.epsilon,
                row.beta, row.defect, row.self_sum, row.epsilon_value,
                row.beta_value, row.defect_value, row.self_sum_value,
            ]
            println(output, join(csv_cell.(values), ','))
        end
    end
    return path
end

fraction_string(value::Rational) =
    denominator(value) == 1 ? string(numerator(value)) :
    "$(numerator(value))/$(denominator(value))"

fixed(value; digits::Int=6) = @sprintf("%.*f", digits, value)

function geometry_limit(q::Int)
    epsilon = BigInt(q)^2 // (BigInt(q)^2 - q + 1)
    beta = BigInt(q - 1)^2 // (BigInt(q)^2 - q + 1)
    defect = -BigInt(1) // (q - 1)
    self_sum = 4BigInt(q)^2 // (3BigInt(q)^2 + 1)
    return (
        epsilon=epsilon,
        beta=beta,
        defect=defect,
        self_sum=self_sum,
    )
end

function make_figure(rows)
    mkpath(dirname(FIGURE_PATH))
    figure = Figure(size=(1080, 720))
    axis = Axis(
        figure[1, 1];
        xlabel="rank r",
        ylabel="ε(M ⊕ M)",
        title="Affine and projective base-2-design families",
    )
    palette = Dict(2 => :steelblue, 3 => :darkorange, 5 => :seagreen, 7 => :mediumpurple)
    for family in ("PG", "AG"), q in (2, 3, 5, 7)
        selected = sort(
            filter(row -> row.family == family && row.q == q, rows);
            by=row -> row.rank,
        )
        lines!(
            axis,
            [row.rank for row in selected],
            [row.self_sum_value for row in selected];
            color=palette[q],
            linestyle=family == "PG" ? :solid : :dash,
            linewidth=2,
            label="$(family), q=$(q)",
        )
        scatter!(
            axis,
            [row.rank for row in selected],
            [row.self_sum_value for row in selected];
            color=palette[q],
            marker=family == "PG" ? :circle : :utriangle,
            markersize=7,
        )
    end
    hlines!(
        axis,
        [4 / 3];
        color=:black,
        linestyle=:dot,
        linewidth=1.5,
        label="4/3",
    )
    axislegend(axis; position=:rb, nbanks=2)
    save(FIGURE_PATH, figure; px_per_unit=2)
end

function write_report(path, rows)
    selected_ranks = (3, 5, 10, 20, 30)
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, "# Base \$2\$-designs and large self-direct-sum \$\\epsilon\$")
        println(output)
        println(output, "_Generated from exact flat-lattice counts on 2026-08-02._")
        println(output)
        println(output, "## Why the base \$2\$-design condition fixes \$\\alpha_1\$")
        println(output)
        println(output, raw"""
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
\alpha_1(M)
=
\frac{(r-1)(n-r-1)}{r(n-r)}
=
\alpha_1(U_{r,n}).
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
""")
        println(output)
        println(output, "## Affine and projective geometries")
        println(output)
        println(output, raw"""
The groups $\operatorname{AGL}(r-1,q)$ and $\operatorname{PGL}(r,q)$ are
$2$-transitive on the points of $\operatorname{AG}(r-1,q)$ and
$\operatorname{PG}(r-1,q)$, respectively. Hence their bases form
$2$-designs.

Exact finite-rank values below are obtained by Möbius inversion on the affine
and projective flat lattices. No subsets of the exponentially large ground
sets are materialized.
""")
        println(output)
        println(output, raw"| Family | $q$ | $r$ | $n$ | $\epsilon(M)$ | $\beta=b/a$ | $\Delta$ | $\epsilon(M\oplus M)$ |")
        println(output, "|---|---:|---:|---:|---:|---:|---:|---:|")
        for family in ("PG", "AG"), q in (2, 3, 5, 7), rank in selected_ranks
            row = only(filter(
                candidate ->
                    candidate.family == family &&
                    candidate.q == q &&
                    candidate.rank == rank,
                rows,
            ))
            println(
                output,
                "| ", family, " | ", q, " | ", rank, " | ", row.n,
                " | ", fixed(row.epsilon_value), " | ",
                fixed(row.beta_value), " | ", fixed(row.defect_value),
                " | ", fixed(row.self_sum_value), " |",
            )
        end
        println(output)
        println(output, "![Affine and projective self-sum limits](../figures/epsilon_analysis/two_design_self_sum_limits.png)")
        println(output)
        println(output, "### Fixed-field, growing-rank limits")
        println(output)
        println(output, raw"""
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
""")
        println(output)
        println(output, raw"| $q$ | Limit of $\epsilon(M)$ | Limit of $\beta$ | Limit of $\epsilon(M\oplus M)$ | Decimal self-sum limit |")
        println(output, "|---:|---:|---:|---:|---:|")
        for q in (2, 3, 5, 7)
            limit = geometry_limit(q)
            println(
                output,
                "| ", q, " | ", fraction_string(limit.epsilon),
                " | ", fraction_string(limit.beta), " | ",
                fraction_string(limit.self_sum), " | ",
                fixed(rational_float(limit.self_sum)), " |",
            )
        end
        println(output)
        println(output, raw"""
Thus the ternary geometries tend to $9/7$, the quinary geometries tend to
$25/19$, and the limiting values approach $4/3$ as $q\to\infty$. These are
nonuniform, highly structured matroids with the same $\alpha_1$ as the
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
""")
        println(output)
        println(output, "## Steiner-system sparse-paving families")
        println(output)
        println(output, raw"""
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
""")
        println(output)
        println(output, "## More than two uniform summands")
        println(output)
        println(output, raw"""
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
""")
        println(output)
        println(output, "## Reproduction")
        println(output)
        println(output, "- [Exact finite-rank data](../data/epsilon_analysis/two_design_family_summary.csv)")
        println(output, "- [Convergence figure](../figures/epsilon_analysis/two_design_self_sum_limits.png)")
        println(output)
        fence = repeat(string(Char(0x60)), 3)
        println(output, fence, "bash")
        println(output, "julia --project=. scripts/make_two_design_self_sum_report.jl")
        println(output, fence)
    end
    return path
end

function main()
    validate_small_profiles()
    rows = geometry_rows()
    write_csv(CSV_PATH, rows)
    make_figure(rows)
    write_report(REPORT_PATH, rows)
    @info "two-design self-sum analysis complete" report=REPORT_PATH
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
