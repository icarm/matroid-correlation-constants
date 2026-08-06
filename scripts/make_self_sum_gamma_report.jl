"""
Analyze the relation between alpha_1(M) and the critical density exponent
gamma_*(M direct-sum M), without constructing any direct-sum matroids.

Usage:

    julia --project=. scripts/make_self_sum_gamma_report.jl
"""

include(joinpath(@__DIR__, "make_epsilon_report.jl"))

const SELF_SUM_GAMMA_REPORT =
    joinpath(PROJECT_DIRECTORY, "reports", "self_sum_gamma_analysis.md")
const SELF_SUM_GAMMA_CSV =
    joinpath(DATA_DIRECTORY, "self_sum_gamma_summary.csv")
const SELF_SUM_GAMMA_FIGURE =
    joinpath(FIGURE_DIRECTORY, "self_sum_gamma_vs_alpha.png")
const SELF_SUM_GAMMA_RESERVOIR_SIZE = 2_000

function safe_weighted_spearman(first, second, weights)
    length(first) >= 2 || return missing
    length(unique(first)) >= 2 || return missing
    length(unique(second)) >= 2 || return missing
    return weighted_spearman(first, second, weights)
end

function self_sum_gamma_row_stream(database, group)
    return DBInterface.execute(
        database,
        """
        SELECT census_multiplicity, num_bases, alpha_num, alpha_den
        FROM matroids
        WHERE run_id IN ($(run_placeholders(group)))
          AND connected = 1 AND alpha_num > 0
        ORDER BY run_id, observation_index
        """,
        Tuple(group.run_ids),
    )
end

function analyze_self_sum_gamma_group(database, experiment, group)
    @info "self-sum gamma group" experiment=experiment.slug ensemble=group.label
    alpha_values = Float64[]
    density_values = Float64[]
    self_density_values = Float64[]
    gamma_values = Float64[]
    weights = Int[]
    alpha_le_one = Bool[]
    reservoir = NamedTuple[]
    rng = stable_rng(experiment.slug, group.label, "self-sum-gamma")
    basis_total = binomial(BigInt(experiment.n), experiment.rank)
    self_basis_total =
        binomial(BigInt(2 * experiment.n), 2 * experiment.rank)

    row_count = 0
    weighted_count = 0
    for row in self_sum_gamma_row_stream(database, group)
        row_count += 1
        weight = Int(row.census_multiplicity)
        bases = BigInt(row.num_bases)
        alpha_num = BigInt(row.alpha_num)
        alpha_den = BigInt(row.alpha_den)
        self_alpha_num, self_alpha_den = alpha_num > alpha_den ?
                                         (alpha_num, alpha_den) :
                                         (BigInt(1), BigInt(1))
        self_bases = bases^2
        density = Float64(bases // basis_total)
        self_density = Float64(self_bases // self_basis_total)
        alpha = Float64(alpha_num // alpha_den)
        gamma_value = critical_density_penalty_exponent(
            2 * experiment.n,
            2 * experiment.rank,
            self_bases,
            self_alpha_num,
            self_alpha_den,
        )

        push!(alpha_values, alpha)
        push!(density_values, density)
        push!(self_density_values, self_density)
        push!(gamma_values, gamma_value)
        push!(weights, weight)
        push!(alpha_le_one, alpha_num <= alpha_den)
        weighted_count += weight
        reservoir_consider!(
            reservoir,
            (
                experiment=experiment.slug,
                alpha=alpha,
                density=density,
                self_density=self_density,
                gamma=gamma_value,
            ),
            row_count,
            rng,
            SELF_SUM_GAMMA_RESERVOIR_SIZE,
        )
    end
    row_count > 0 || error("empty gamma group $(experiment.slug), $(group.label)")

    lower_indices = findall(identity, alpha_le_one)
    upper_indices = findall(!, alpha_le_one)
    return (
        experiment=experiment.slug,
        n=experiment.n,
        r=experiment.rank,
        ensemble=group.label,
        category=group.category,
        count=weighted_count,
        alpha_le_one_count=sum(weights[lower_indices]),
        alpha_gt_one_count=sum(weights[upper_indices]),
        gamma_p05=weighted_quantile(gamma_values, weights, 0.05),
        gamma_median=weighted_quantile(gamma_values, weights, 0.50),
        gamma_p95=weighted_quantile(gamma_values, weights, 0.95),
        alpha_gamma_spearman=
            safe_weighted_spearman(alpha_values, gamma_values, weights),
        density_gamma_spearman=
            safe_weighted_spearman(density_values, gamma_values, weights),
        alpha_density_spearman=
            safe_weighted_spearman(alpha_values, density_values, weights),
        lower_alpha_gamma_spearman=isempty(lower_indices) ? missing :
            safe_weighted_spearman(
                alpha_values[lower_indices], gamma_values[lower_indices],
                weights[lower_indices],
            ),
        upper_alpha_gamma_spearman=isempty(upper_indices) ? missing :
            safe_weighted_spearman(
                alpha_values[upper_indices], gamma_values[upper_indices],
                weights[upper_indices],
            ),
        reservoir=reservoir,
    )
end

function analyze_self_sum_gamma_materialized(experiment, database_path)
    database = SQLite.DB(database_path)
    try
        return [
            analyze_self_sum_gamma_group(database, experiment, group)
            for group in group_specs(database, experiment)
        ]
    finally
        close(database)
    end
end

function analyze_self_sum_gamma_experiment(experiment)
    if isfile(experiment.database)
        return analyze_self_sum_gamma_materialized(experiment, experiment.database)
    end
    archive = experiment.database * ".zst"
    isfile(archive) || error("missing $(experiment.database) and $archive")
    return mktempdir() do directory
        temporary_database = joinpath(directory, "results.sqlite")
        open(temporary_database, "w") do output
            run(pipeline(`zstd -q -d -c $archive`; stdout=output))
        end
        analyze_self_sum_gamma_materialized(experiment, temporary_database)
    end
end

function write_self_sum_gamma_csv(path, groups)
    headers = [
        "experiment", "n", "rank", "ensemble", "source_category", "count",
        "alpha_le_one_count", "alpha_gt_one_count", "gamma_p05",
        "gamma_median", "gamma_p95", "alpha_gamma_spearman",
        "density_gamma_spearman", "alpha_density_spearman",
        "alpha_le_one_gamma_spearman", "alpha_gt_one_gamma_spearman",
    ]
    rows = [
        Any[
            group.experiment, group.n, group.r, group.ensemble, group.category,
            group.count, group.alpha_le_one_count, group.alpha_gt_one_count,
            group.gamma_p05, group.gamma_median, group.gamma_p95,
            group.alpha_gamma_spearman, group.density_gamma_spearman,
            group.alpha_density_spearman, group.lower_alpha_gamma_spearman,
            group.upper_alpha_gamma_spearman,
        ]
        for group in groups
    ]
    return write_csv(path, headers, rows)
end

function make_self_sum_gamma_figure(groups)
    mkpath(dirname(SELF_SUM_GAMMA_FIGURE))
    experiments = unique(group.experiment for group in groups)
    palette = [
        :steelblue, :darkorange, :seagreen, :mediumpurple, :firebrick,
        :goldenrod, :teal, :deeppink, :gray35,
    ]
    figure = Figure(size=(1220, 520))
    alpha_axis = Axis(
        figure[1, 1];
        xlabel="α₁(M)",
        ylabel="γ*(M ⊕ M)",
        title="Critical self-sum exponent versus α₁",
    )
    density_axis = Axis(
        figure[1, 2];
        xlabel="basis density d_B(M)",
        ylabel="γ*(M ⊕ M)",
        title="Critical self-sum exponent versus density",
    )
    for (index, experiment) in enumerate(experiments)
        points = reduce(
            vcat,
            (
                filter(point -> point.experiment == experiment, group.reservoir)
                for group in groups
            );
            init=NamedTuple[],
        )
        color = (palette[mod1(index, length(palette))], 0.18)
        scatter!(
            alpha_axis,
            [point.alpha for point in points],
            [point.gamma for point in points];
            color=color,
            markersize=4,
            label=experiment,
        )
        scatter!(
            density_axis,
            [point.density for point in points],
            [point.gamma for point in points];
            color=color,
            markersize=4,
        )
    end
    vlines!(alpha_axis, [1.0]; color=:black, linestyle=:dash, linewidth=1.2)
    axislegend(alpha_axis; position=:lt, framevisible=true, nbanks=2)
    save(SELF_SUM_GAMMA_FIGURE, figure; px_per_unit=2)
end

function write_self_sum_gamma_report(path, groups)
    correlations = collect(skipmissing(group.alpha_gamma_spearman for group in groups))
    negative_cells = count(value -> value < 0, correlations)
    finite_field_correlations = collect(skipmissing(
        group.alpha_gamma_spearman
        for group in groups if group.category == "finite field"
    ))
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, raw"# $\alpha_1(M)$ and $\gamma_*(M\oplus M)$")
        println(output)
        println(output, "_Generated on 2026-08-03._")
        println(output)
        println(output, raw"""
Here $\gamma_*$ is the critical density-penalty exponent already used in the
project. Let $M$ have rank $r$, corank $c=n-r$, $b$ bases, and basis density

$$
D=\frac{b}{\binom nr}.
$$

For a connected nontrivial matroid,

$$
\alpha_1(M\oplus M)=\max\{1,\alpha_1(M)\}.
$$

Also

$$
D_\oplus
=\frac{b^2}{\binom{2n}{2r}}
=K_{r,n}D^2,
\qquad
K_{r,n}=\frac{\binom nr^2}{\binom{2n}{2r}},
$$

and

$$
c_{2r,2n}=\alpha_1(U_{2r,2n})
=\frac{(2r-1)(2c-1)}{4rc}.
$$

Consequently the exact self-sum formula is

$$
\boxed{
\gamma_*(M\oplus M)
=
\frac{
\log\!\left(\max\{1,\alpha_1(M)\}/c_{2r,2n}\right)
}{
\log\!\left(1/(K_{r,n}D^2)\right)
}.
}
$$

This immediately separates direct from indirect effects:

- On the whole region $\alpha_1(M)\leq1$, the numerator is constant, so
  $\gamma_*(M\oplus M)$ has no direct dependence on $\alpha_1(M)$ at all.
  It is strictly increasing in the basis density $D$.
- When $\alpha_1(M)>1$, it is increasing in both $\alpha_1(M)$ and $D$.

Thus a low-$\alpha_1$/high-$\gamma_*$ pattern can occur only indirectly,
because low $\alpha_1$ happens to be associated with high basis density in a
particular population. It cannot be a universal inverse law.
""")
        println(output)
        println(output, "## Database pattern")
        println(output)
        println(
            output,
            "The within-cell Spearman correlation is negative in **",
            negative_cells, " of ", length(correlations),
            "** cells. The median cell correlation is **",
            fixed(median(correlations); digits=4), "**. Among finite-field ",
            "cells it is negative in **",
            count(value -> value < 0, finite_field_correlations),
            " of ", length(finite_field_correlations), "** cells, with median **",
            fixed(median(finite_field_correlations); digits=4), "**.",
        )
        println(output)
        println(output, raw"| Scope | Ensemble | $N$ | Median $\gamma_*$ | $\rho_S(\alpha_1,\gamma_{*,\oplus2})$ | $\rho_S(D,\gamma_{*,\oplus2})$ | $\rho_S(\alpha_1,D)$ | $N(\alpha_1\leq1)$ |")
        println(output, "|---|---|---:|---:|---:|---:|---:|---:|")
        for group in groups
            println(
                output,
                "| ", group.experiment, " | ", group.ensemble, " | ",
                group.count, " | ", fixed(group.gamma_median), " | ",
                fixed(group.alpha_gamma_spearman; digits=4), " | ",
                fixed(group.density_gamma_spearman; digits=4), " | ",
                fixed(group.alpha_density_spearman; digits=4), " | ",
                group.alpha_le_one_count, " |",
            )
        end
        println(output)
        println(output, "![Self-sum critical exponent versus alpha and density](../figures/epsilon_analysis/self_sum_gamma_vs_alpha.png)")
        println(output)
        println(output, "## Reproduction")
        println(output)
        println(output, "- [Compact summary](../data/epsilon_analysis/self_sum_gamma_summary.csv)")
        println(output)
        fence = repeat(string(Char(0x60)), 3)
        println(output, fence, "bash")
        println(output, "julia --project=. scripts/make_self_sum_gamma_report.jl")
        println(output, fence)
    end
    return path
end

function self_sum_gamma_main()
    groups = NamedTuple[]
    for experiment in experiment_specs()
        append!(groups, analyze_self_sum_gamma_experiment(experiment))
    end
    write_self_sum_gamma_csv(SELF_SUM_GAMMA_CSV, groups)
    make_self_sum_gamma_figure(groups)
    write_self_sum_gamma_report(SELF_SUM_GAMMA_REPORT, groups)
    @info "self-sum gamma analysis complete" report=SELF_SUM_GAMMA_REPORT
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && self_sum_gamma_main()
