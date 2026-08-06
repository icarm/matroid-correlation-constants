"""
Generate a standalone statistical report for the density-adjusted correlation
excess Θ from every completed experiment registered below.

Command line:

```text
julia --project=. scripts/make_theta_report.jl \
    [REPORT] [FIGURE_DIRECTORY] [SUMMARY_CSV]
```

The analysis population is connected matroids with positive α₁, matching the
main project reports. PolyDB rows are isomorphism classes. Finite-field rows
are accepted configurations or draws from their stated ensembles, while
Johnson-graph rows are labeled independent-set outputs from their stated
random-greedy activities. Nothing is written to the source SQLite databases,
and per-matroid Θ values are not retained: they are derived on demand from the
compact matroid summaries. If `results.sqlite` is absent but
`results.sqlite.zst` exists, the archive is losslessly decompressed into a
temporary directory for that rank scope and removed automatically afterward.
"""

using CairoMakie
using DBInterface
using Printf
using SQLite
using Statistics

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

const PROJECT_DIRECTORY = normpath(joinpath(@__DIR__, ".."))

"""Describe the six nonredundant rank scopes currently available."""
function experiment_specs()
    return [
        (
            slug="n8_r4",
            title="n = 8, rank 4 validation data",
            database=joinpath(PROJECT_DIRECTORY, "data", "n8_r4_compact", "results.sqlite"),
            n=8,
            rank=4,
        ),
        (
            slug="n9_r3",
            title="n = 9, rank 3 exact census",
            database=joinpath(PROJECT_DIRECTORY, "data", "n9_census", "results.sqlite"),
            n=9,
            rank=3,
        ),
        (
            slug="n9_r4",
            title="n = 9, rank 4 exact census",
            database=joinpath(PROJECT_DIRECTORY, "data", "n9_census", "results.sqlite"),
            n=9,
            rank=4,
        ),
        (
            slug="n10_r4",
            title="n = 10, rank 4 finite-field data",
            database=joinpath(
                PROJECT_DIRECTORY,
                "data",
                "n10_finite_fields",
                "r4",
                "results.sqlite",
            ),
            n=10,
            rank=4,
        ),
        (
            slug="n10_r5",
            title="n = 10, rank 5 finite-field data",
            database=joinpath(
                PROJECT_DIRECTORY,
                "data",
                "n10_finite_fields",
                "r5",
                "results.sqlite",
            ),
            n=10,
            rank=5,
        ),
        (
            slug="n12_r6",
            title="n = 12, rank 6 finite-field and Johnson-graph data",
            database=joinpath(
                PROJECT_DIRECTORY,
                "data",
                "n12_finite_fields",
                "r6",
                "results.sqlite",
            ),
            n=12,
            rank=6,
        ),
    ]
end

"""Materialize transient SQLite rows as ordinary named tuples."""
function materialize(database, sql, parameters=())
    return [
        (; (name => getproperty(row, name) for name in propertynames(row))...)
        for row in DBInterface.execute(database, sql, parameters)
    ]
end

"""Return a concise ensemble label for tables and plot legends."""
function ensemble_label(run; simple_only::Bool=false)
    if run.source == "polyDB"
        return simple_only ? "polyDB simple" : "polyDB"
    elseif run.source == "johnson_graph"
        return @sprintf(
            "Johnson greedy p = %.3g",
            johnson_greedy_probability(run.ensemble),
        )
    end
    field = "GF($(run.field_size))"
    if run.ensemble == "projective_subsets_exhaustive"
        return field * " exhaustive, no replacement"
    elseif run.ensemble == "projective_points_with_replacement_random"
        return field * " random, with replacement"
    end
    return field * " random, no replacement"
end

"""Whether rows in an ensemble are independent Monte Carlo draws."""
is_random_ensemble(ensemble) =
    ensemble == "projective_subsets_random" ||
    ensemble == "projective_points_with_replacement_random" ||
    !ismissing(johnson_greedy_probability(ensemble))

"""
Pool seed replicates with the same field and sampling model.

A derived simple-only polyDB group is included because it is the most direct
census comparison with no-replacement projective-point configurations.
"""
function group_specs(database, experiment)
    runs = materialize(
        database,
        """
        SELECT run_id, source, ensemble, field_size, accepted_count
        FROM runs
        WHERE n = ? AND rank_value = ? AND accepted_count > 0
        ORDER BY CASE WHEN source = 'polyDB' THEN 0 ELSE 1 END,
                 field_size, ensemble, run_id
        """,
        (experiment.n, experiment.rank),
    )
    isempty(runs) && error("no completed runs for $(experiment.slug)")
    keys_in_order = Tuple[]
    buckets = Dict{Tuple,Vector{NamedTuple}}()
    for run in runs
        key = (run.source, run.ensemble, run.field_size)
        if !haskey(buckets, key)
            buckets[key] = NamedTuple[]
            push!(keys_in_order, key)
        end
        push!(buckets[key], run)
    end
    groups = NamedTuple[]
    for key in keys_in_order
        bucket = buckets[key]
        representative = first(bucket)
        base = (
            run_ids=String[run.run_id for run in bucket],
            label=ensemble_label(representative),
            source=representative.source,
            ensemble=representative.ensemble,
            field_size=representative.field_size,
            simple_only=false,
            derived=false,
            random=is_random_ensemble(representative.ensemble),
        )
        push!(groups, base)
        if representative.source == "polyDB"
            push!(groups, merge(base, (
                label=ensemble_label(representative; simple_only=true),
                simple_only=true,
                derived=true,
            )))
        end
    end
    return groups
end

"""Construct a SQL placeholder list for a group's run identifiers."""
run_placeholders(group) = join(fill("?", length(group.run_ids)), ", ")

"""Read the minimal connected, positive-α₁ rows needed for Θ analysis."""
function matroid_rows(database, group)
    simple_condition = group.simple_only ? " AND simple = 1" : ""
    return materialize(
        database,
        """
        SELECT run_id, matroid_id, source_id, n, rank_value,
               census_multiplicity, num_bases, basis_density,
               alpha_num, alpha_den, alpha_value, sparse_paving
        FROM matroids
        WHERE run_id IN ($(run_placeholders(group)))
          AND connected = 1 AND alpha_num > 0$simple_condition
        ORDER BY run_id, observation_index
        """,
        Tuple(group.run_ids),
    )
end

"""Evaluate Θ_lambda quickly in floating point for statistics and plotting."""
function theta_lambda_value(row, density_exponent::Integer)
    density_exponent >= 0 ||
        throw(ArgumentError("density_exponent must be nonnegative"))
    n = Int(row.n)
    rank = Int(row.rank_value)
    return row.basis_density^density_exponent * (
        rank * (n - rank) * row.alpha_value -
        (rank - 1) * (n - rank - 1)
    ) / (n - 1)
end

"""Evaluate the primary Θ=Θ_1 invariant."""
theta_value(row) = theta_lambda_value(row, 1)

"""Return the exact reduced rational Θ_lambda value for one stored row."""
theta_exact(row; density_exponent::Integer=1) = density_adjusted_correlation_excess(
    Int(row.n),
    Int(row.rank_value),
    Int(row.num_bases),
    row.alpha_num,
    row.alpha_den,
    ;
    density_exponent=density_exponent,
)

"""Test Θ_lambda > 1 by exact integer cross multiplication."""
function theta_above_one(row; density_exponent::Integer=1)
    density_exponent >= 0 ||
        throw(ArgumentError("density_exponent must be nonnegative"))
    n = Int(row.n)
    rank = Int(row.rank_value)
    excess_numerator =
        Int128(rank * (n - rank)) * Int128(row.alpha_num) -
        Int128((rank - 1) * (n - rank - 1)) * Int128(row.alpha_den)
    basis_total = Int128(binomial(n, rank))
    left = Int128(row.num_bases)^density_exponent * excess_numerator
    right = basis_total^density_exponent * Int128(n - 1) * Int128(row.alpha_den)
    return left > right
end

"""Weighted empirical quantile using the left-continuous inverse CDF."""
function weighted_quantile(values, weights, probability::Real)
    isempty(values) && return missing
    order = sortperm(values)
    target = clamp(probability, 0, 1) * sum(weights)
    cumulative = 0
    for index in order
        cumulative += weights[index]
        cumulative >= target && return values[index]
    end
    return values[last(order)]
end

"""Weighted mean and population standard deviation."""
function weighted_moments(values, weights)
    isempty(values) && return (mean=missing, standard_deviation=missing)
    total = sum(Float64, weights)
    average = sum(
        Float64(value) * Float64(weight) for (value, weight) in zip(values, weights)
    ) / total
    variance = sum(
        Float64(weight) * (Float64(value) - average)^2
        for (value, weight) in zip(values, weights)
    ) / total
    return (mean=average, standard_deviation=sqrt(max(variance, 0.0)))
end

"""Wilson 95% interval for a binomial Monte Carlo proportion."""
function wilson_interval(successes::Integer, total::Integer; z=1.959963984540054)
    total == 0 && return missing
    estimate = successes / total
    denominator = 1 + z^2 / total
    center = (estimate + z^2 / (2total)) / denominator
    radius = z * sqrt(
        estimate * (1 - estimate) / total + z^2 / (4total^2),
    ) / denominator
    return (max(0.0, center - radius), min(1.0, center + radius))
end

"""Summarize a sparse-paving status subset, including its weighted maximum."""
function subset_summary(values, weights)
    isempty(values) && return (
        count=0,
        mean=missing,
        median=missing,
        percentile_95=missing,
        maximum=missing,
    )
    moments = weighted_moments(values, weights)
    return (
        count=sum(Int, weights),
        mean=moments.mean,
        median=weighted_quantile(values, weights, 0.50),
        percentile_95=weighted_quantile(values, weights, 0.95),
        maximum=maximum(values),
    )
end

"""
Compute the weighted probability that a non-sparse-paving score exceeds a
sparse-paving score, with half credit for a tie.
"""
function probability_of_superiority(first_values, first_weights, second_values, second_weights)
    (isempty(first_values) || isempty(second_values)) && return missing
    order = sortperm(second_values)
    sorted_values = second_values[order]
    sorted_weights = Float64.(second_weights[order])
    cumulative = cumsum(sorted_weights)
    second_total = last(cumulative)
    favorable = 0.0
    first_total = sum(Float64, first_weights)
    for (value, weight) in zip(first_values, first_weights)
        lower = searchsortedfirst(sorted_values, value)
        upper = searchsortedlast(sorted_values, value)
        less_weight = lower == 1 ? 0.0 : cumulative[lower - 1]
        equal_weight = upper < lower ? 0.0 :
                       cumulative[upper] - (lower == 1 ? 0.0 : cumulative[lower - 1])
        favorable += Float64(weight) * (less_weight + 0.5equal_weight)
    end
    return favorable / (first_total * second_total)
end

"""Fraction of the Θ upper decile also lying in another variable's upper decile."""
function upper_decile_overlap(theta, other, weights)
    theta_cutoff = weighted_quantile(theta, weights, 0.90)
    other_cutoff = weighted_quantile(other, weights, 0.90)
    theta_top = sum(
        weight for (value, weight) in zip(theta, weights) if value >= theta_cutoff;
        init=0,
    )
    joint_top = sum(
        weight for (theta_value, other_value, weight) in zip(theta, other, weights)
        if theta_value >= theta_cutoff && other_value >= other_cutoff;
        init=0,
    )
    return joint_top / theta_top
end

"""Compute every distributional and association statistic for one group."""
function summarize_group(experiment, group, rows)
    isempty(rows) && error("empty Θ population for $(experiment.slug), $(group.label)")
    theta = Float64[theta_value(row) for row in rows]
    density = Float64[row.basis_density for row in rows]
    theta2 = density .* theta
    alpha = Float64[row.alpha_value for row in rows]
    product = density .* alpha
    weights = Int[row.census_multiplicity for row in rows]
    count = sum(weights)
    moments = weighted_moments(theta, weights)
    moments2 = weighted_moments(theta2, weights)
    maximum_index = argmax(theta)
    maximum_exact = theta_exact(rows[maximum_index])
    maximum2_index = argmax(theta2)
    maximum2_exact = theta_exact(rows[maximum2_index]; density_exponent=2)

    negative = sum(
        weight for (row, weight) in zip(rows, weights)
        if row.alpha_num * row.rank_value * (row.n - row.rank_value) <
           row.alpha_den * (row.rank_value - 1) * (row.n - row.rank_value - 1);
        init=0,
    )
    zero = sum(
        weight for (row, weight) in zip(rows, weights)
        if row.alpha_num * row.rank_value * (row.n - row.rank_value) ==
           row.alpha_den * (row.rank_value - 1) * (row.n - row.rank_value - 1);
        init=0,
    )
    above_density = sum(
        weight for (row, weight) in zip(rows, weights)
        if row.alpha_num > row.alpha_den;
        init=0,
    )
    above_one = sum(
        weight for (row, weight) in zip(rows, weights) if theta_above_one(row);
        init=0,
    )
    above_one2 = sum(
        weight for (row, weight) in zip(rows, weights)
        if theta_above_one(row; density_exponent=2);
        init=0,
    )

    sparse_indices = findall(row -> row.sparse_paving == 1, rows)
    non_sparse_indices = findall(row -> row.sparse_paving == 0, rows)
    sparse = subset_summary(theta[sparse_indices], weights[sparse_indices])
    non_sparse = subset_summary(theta[non_sparse_indices], weights[non_sparse_indices])
    superiority = probability_of_superiority(
        theta[non_sparse_indices],
        weights[non_sparse_indices],
        theta[sparse_indices],
        weights[sparse_indices],
    )
    mean_interval = group.random ? (
        moments.mean - 1.959963984540054 * moments.standard_deviation / sqrt(count),
        moments.mean + 1.959963984540054 * moments.standard_deviation / sqrt(count),
    ) : missing
    return (
        experiment_slug=experiment.slug,
        experiment_title=experiment.title,
        n=experiment.n,
        rank=experiment.rank,
        label=group.label,
        source=group.source,
        random=group.random,
        derived=group.derived,
        count=count,
        mean=moments.mean,
        standard_deviation=moments.standard_deviation,
        mean_interval=mean_interval,
        minimum=minimum(theta),
        median=weighted_quantile(theta, weights, 0.50),
        percentile_95=weighted_quantile(theta, weights, 0.95),
        maximum=maximum(theta),
        maximum_fraction="$(numerator(maximum_exact))/$(denominator(maximum_exact))",
        negative=negative,
        zero=zero,
        above_density=above_density,
        above_one=above_one,
        above_one_interval=group.random ? wilson_interval(above_one, count) : missing,
        alpha_pearson=weighted_pearson(theta, alpha, weights),
        alpha_spearman=weighted_spearman(theta, alpha, weights),
        density_pearson=weighted_pearson(theta, density, weights),
        density_spearman=weighted_spearman(theta, density, weights),
        product_spearman=weighted_spearman(theta, product, weights),
        alpha_top_overlap=upper_decile_overlap(theta, alpha, weights),
        product_top_overlap=upper_decile_overlap(theta, product, weights),
        lambda2_mean=moments2.mean,
        lambda2_standard_deviation=moments2.standard_deviation,
        lambda2_median=weighted_quantile(theta2, weights, 0.50),
        lambda2_percentile_95=weighted_quantile(theta2, weights, 0.95),
        lambda2_maximum=maximum(theta2),
        lambda2_maximum_fraction=
            "$(numerator(maximum2_exact))/$(denominator(maximum2_exact))",
        lambda2_above_one=above_one2,
        lambda2_alpha_pearson=weighted_pearson(theta2, alpha, weights),
        lambda2_alpha_spearman=weighted_spearman(theta2, alpha, weights),
        lambda2_density_pearson=weighted_pearson(theta2, density, weights),
        lambda2_density_spearman=weighted_spearman(theta2, density, weights),
        lambda1_lambda2_spearman=weighted_spearman(theta, theta2, weights),
        lambda2_top_overlap=upper_decile_overlap(theta2, theta, weights),
        sparse=sparse,
        non_sparse=non_sparse,
        non_sparse_superiority=superiority,
    )
end

"""Partition field comparisons and Johnson activities into uncluttered panels."""
function comparison_panels(groups)
    definitions = [
        (title="GF(2) and GF(3), with replacement", fields=Set((2, 3)), replacement=true),
        (title="GF(5) and GF(7), with replacement", fields=Set((5, 7)), replacement=true),
        (title="GF(2) and GF(3), without replacement", fields=Set((2, 3)), replacement=false),
        (title="GF(5) and GF(7), without replacement", fields=Set((5, 7)), replacement=false),
    ]
    panels = NamedTuple[]
    assigned = falses(length(groups))
    for definition in definitions
        indices = Int[]
        for (index, group) in enumerate(groups)
            is_finite_field = group.source == "finite_field"
            matching_field = !ismissing(group.field_size) &&
                             Int(group.field_size) in definition.fields
            replacement = group.ensemble == "projective_points_with_replacement_random"
            if is_finite_field && matching_field && replacement == definition.replacement
                push!(indices, index)
                assigned[index] = true
            end
        end
        isempty(indices) || push!(panels, (title=definition.title, indices=indices))
    end
    johnson_indices = sort(
        [index for (index, group) in enumerate(groups) if group.source == "johnson_graph"];
        by=index -> johnson_greedy_probability(groups[index].ensemble),
    )
    for first_index in 1:2:length(johnson_indices)
        indices = johnson_indices[first_index:min(first_index + 1, end)]
        labels = [
            @sprintf(
                "p = %.3g",
                johnson_greedy_probability(groups[index].ensemble),
            ) for index in indices
        ]
        push!(panels, (
            title="Johnson-graph sparse paving: " * join(labels, " and "),
            indices=indices,
        ))
        assigned[indices] .= true
    end
    remaining = findall(!, assigned)
    isempty(remaining) || push!(panels, (title="Census or other ensembles", indices=remaining))
    return panels
end

"""Shorten a finite-field legend label when the panel supplies the model."""
function panel_label(group)
    group.source == "polyDB" && return group.label
    group.source == "johnson_graph" && return @sprintf(
        "p = %.3g",
        johnson_greedy_probability(group.ensemble),
    )
    suffix = group.ensemble == "projective_subsets_exhaustive" ? " exhaustive" : ""
    return "GF($(group.field_size))" * suffix
end

"""Construct shared finite histogram edges with a safe degenerate case."""
function common_edges(series; number_of_bins::Int=45)
    values = reduce(vcat, series; init=Float64[])
    isempty(values) && return Float64[]
    lower, upper = extrema(values)
    if lower == upper
        padding = max(abs(lower) * 0.05, 0.05)
        lower -= padding
        upper += padding
    end
    return collect(range(lower, upper; length=number_of_bins + 1))
end

"""Compute weighted probability mass for fixed histogram edges."""
function histogram_probabilities(values, weights, edges)
    counts = zeros(Float64, length(edges) - 1)
    total = sum(weights)
    total > 0 || return counts
    for (value, weight) in zip(values, weights)
        index = searchsortedlast(edges, value)
        index == length(edges) && (index -= 1)
        1 <= index <= length(counts) && (counts[index] += weight)
    end
    return counts ./ total
end

"""Choose deterministic evenly spaced rows for scatter rendering only."""
function thin_rows(rows; maximum_rows::Int=15_000)
    length(rows) <= maximum_rows && return rows
    indices = unique(round.(Int, range(1, length(rows); length=maximum_rows)))
    return rows[indices]
end

"""Save a high-resolution PNG and, for nondense plots, a scalable SVG."""
function save_figure(figure, output_directory, stem; save_svg::Bool=true)
    svg_path = joinpath(output_directory, stem * ".svg")
    save_svg ? save(svg_path, figure) : (isfile(svg_path) && rm(svg_path))
    save(joinpath(output_directory, stem * ".png"), figure; px_per_unit=2)
end

"""Consistent ensemble colors across all standalone Θ figures."""
function group_colors(groups)
    field_colors = Dict(
        2 => :steelblue,
        3 => :darkorange,
        5 => :seagreen,
        7 => :mediumpurple,
    )
    johnson_activities = sort(unique(Float64[
        johnson_greedy_probability(group.ensemble) for group in groups
        if group.source == "johnson_graph"
    ]))
    johnson_palette = [:goldenrod, :firebrick, :teal, :navy, :deeppink]
    johnson_colors = Dict(
        activity => johnson_palette[mod1(index, length(johnson_palette))]
        for (index, activity) in enumerate(johnson_activities)
    )
    return [
        group.source == "polyDB" ? (group.derived ? :gray45 : :black) :
        group.source == "johnson_graph" ?
        johnson_colors[johnson_greedy_probability(group.ensemble)] :
        ismissing(group.field_size) ? :goldenrod :
        get(field_colors, Int(group.field_size), :deepskyblue)
        for group in groups
    ]
end

"""Draw the weighted Θ probability histogram for one rank scope."""
function make_theta_histogram(experiment, groups, rows_by_group, output_directory)
    colors = group_colors(groups)
    panels = comparison_panels(groups)
    value_series = [Float64[theta_value(row) for row in rows] for rows in rows_by_group]
    edge_series = copy(value_series)
    push!(edge_series, [0.0, 1.0])
    edges = common_edges(edge_series)
    columns = min(2, length(panels))
    panel_rows = cld(length(panels), columns)
    figure = Figure(size=(1180, 510panel_rows))
    for (panel_index, panel) in enumerate(panels)
        row_index = cld(panel_index, columns)
        column_index = mod1(panel_index, columns)
        axis = Axis(
            figure[row_index, column_index];
            xlabel="Θ",
            ylabel="probability mass per bin",
            title=panel.title,
        )
        for index in panel.indices
            group = groups[index]
            rows = rows_by_group[index]
            values = value_series[index]
            weights = Float64[row.census_multiplicity for row in rows]
            probabilities = histogram_probabilities(values, weights, edges)
            label = panel_label(group) * " (N = $(round(Int, sum(weights))))"
            stairs!(
                axis,
                edges,
                vcat(probabilities, probabilities[end]);
                step=:post,
                color=colors[index],
                linewidth=group.derived ? 2 : 3,
                linestyle=group.derived ? :dash : :solid,
                label=label,
            )
        end
        vlines!(axis, [0.0]; color=:black, linestyle=:dash, linewidth=1.5)
        vlines!(axis, [1.0]; color=:firebrick, linestyle=:dashdot, linewidth=1.5)
        xlims!(axis, first(edges), last(edges))
        axislegend(axis; position=:rt, framevisible=false)
    end
    save_figure(figure, output_directory, experiment.slug * "_theta_histogram")
end

"""
Draw basis density against Θ_lambda for one rank scope.

Triangles mark sparse paving matroids, circles mark all others, and the black
curve is the α₁=1 boundary Θ_lambda=d_B^lambda.
"""
function make_density_scatter(
    experiment,
    groups,
    rows_by_group,
    output_directory;
    density_exponent::Integer=1,
)
    density_exponent in (1, 2) ||
        throw(ArgumentError("standalone figures support density exponents 1 and 2"))
    colors = group_colors(groups)
    panels = comparison_panels(groups)
    columns = min(2, length(panels))
    panel_rows = cld(length(panels), columns)
    figure = Figure(size=(1180, 530panel_rows))
    for (panel_index, panel) in enumerate(panels)
        row_index = cld(panel_index, columns)
        column_index = mod1(panel_index, columns)
        axis = Axis(
            figure[row_index, column_index];
            xlabel="basis density d_B",
            ylabel=density_exponent == 1 ? "Θ₁" : "Θ₂",
            title=panel.title,
        )
        for index in panel.indices
            group = groups[index]
            rows = thin_rows(rows_by_group[index])
            non_sparse = [row for row in rows if row.sparse_paving == 0]
            sparse = [row for row in rows if row.sparse_paving == 1]
            if !isempty(non_sparse)
                scatter!(
                    axis,
                    Float64[row.basis_density for row in non_sparse],
                    Float64[
                        theta_lambda_value(row, density_exponent) for row in non_sparse
                    ];
                    color=(colors[index], group.derived ? 0.40 : 0.24),
                    markersize=group.derived ? 5 : 4,
                    marker=:circle,
                    label=panel_label(group),
                )
            end
            if !isempty(sparse)
                arguments = (
                    color=(colors[index], group.derived ? 0.55 : 0.36),
                    markersize=group.derived ? 7 : 6,
                    marker=:utriangle,
                )
                if isempty(non_sparse)
                    scatter!(
                        axis,
                        Float64[row.basis_density for row in sparse],
                        Float64[
                            theta_lambda_value(row, density_exponent) for row in sparse
                        ];
                        arguments...,
                        label=panel_label(group),
                    )
                else
                    scatter!(
                        axis,
                        Float64[row.basis_density for row in sparse],
                        Float64[
                            theta_lambda_value(row, density_exponent) for row in sparse
                        ];
                        arguments...,
                    )
                end
            end
        end
        reference_density = collect(range(0.0, 1.0; length=101))
        lines!(
            axis,
            reference_density,
            reference_density .^ density_exponent;
            color=:black,
            linestyle=:dash,
        )
        hlines!(axis, [0.0]; color=:gray45, linestyle=:dot)
        hlines!(axis, [1.0]; color=:firebrick, linestyle=:dashdot)
        axislegend(axis; position=:lt, framevisible=false)
    end
    stem = density_exponent == 1 ? "_density_vs_theta" : "_density_vs_theta_lambda2"
    save_figure(figure, output_directory, experiment.slug * stem; save_svg=false)
end

"""Identify high-Θ profiles without materializing every basis encoding."""
function top_profiles(database, experiment, groups; limit::Int=20)
    run_ids = unique(reduce(vcat, [group.run_ids for group in groups]; init=String[]))
    placeholders = join(fill("?", length(run_ids)), ", ")
    candidates = materialize(
        database,
        """
        SELECT r.source, r.ensemble, r.field_size, m.n, m.rank_value,
               MIN(m.source_id) AS source_id, m.num_bases, m.basis_density,
               m.alpha_num, m.alpha_den, m.alpha_value, m.sparse_paving
        FROM matroids m JOIN runs r USING(run_id)
        WHERE m.run_id IN ($(placeholders))
          AND m.connected = 1 AND m.alpha_num > 0
        GROUP BY r.source, r.ensemble, r.field_size, m.rank_value,
                 m.num_bases, m.alpha_num, m.alpha_den, m.sparse_paving
        ORDER BY m.basis_density * (
          m.rank_value * (m.n - m.rank_value) * m.alpha_value -
          (m.rank_value - 1) * (m.n - m.rank_value - 1)
        ) / (m.n - 1) DESC
        LIMIT 200
        """,
        Tuple(run_ids),
    )
    profiles = NamedTuple[]
    for row in candidates
        origin = ensemble_label(row)
        push!(profiles, merge(row, (
            experiment_slug=experiment.slug,
            origin=origin,
            theta=theta_exact(row),
        )))
    end
    sort!(profiles; by=profile -> profile.theta, rev=true)
    return profiles[1:min(limit, length(profiles))]
end

"""Analyze one rank scope from a materialized SQLite path."""
function analyze_materialized_experiment(experiment, database_path, output_directory)
    database = init_database(database_path)
    groups = group_specs(database, experiment)
    rows_by_group = [matroid_rows(database, group) for group in groups]
    summaries = [
        summarize_group(experiment, group, rows)
        for (group, rows) in zip(groups, rows_by_group)
    ]
    make_theta_histogram(experiment, groups, rows_by_group, output_directory)
    make_density_scatter(
        experiment,
        groups,
        rows_by_group,
        output_directory;
        density_exponent=1,
    )
    make_density_scatter(
        experiment,
        groups,
        rows_by_group,
        output_directory;
        density_exponent=2,
    )
    profiles = top_profiles(database, experiment, groups)
    SQLite.close(database)
    return (
        experiment=experiment,
        summaries=summaries,
        profiles=profiles,
    )
end

"""
Analyze one rank scope, transparently materializing a `.zst` archive when the
ordinary SQLite file has been archived. The returned experiment names the
persistent archive, never the ephemeral temporary file.
"""
function analyze_experiment(experiment, output_directory)
    isfile(experiment.database) &&
        return analyze_materialized_experiment(
            experiment,
            experiment.database,
            output_directory,
        )
    archive_path = experiment.database * ".zst"
    isfile(archive_path) || error(
        "missing experiment database $(experiment.database) and archive $archive_path",
    )
    return mktempdir() do temporary_directory
        temporary_database = joinpath(temporary_directory, "results.sqlite")
        open(temporary_database, "w") do output
            run(pipeline(`zstd -q -d -c $archive_path`; stdout=output))
        end
        persistent_experiment = merge(experiment, (database=archive_path,))
        analyze_materialized_experiment(
            persistent_experiment,
            temporary_database,
            output_directory,
        )
    end
end

"""Format a decimal summary, retaining missing values as a dash."""
fixed(value; digits::Int=6) = ismissing(value) ? "—" : @sprintf("%.*f", digits, value)

"""Format a signed association coefficient."""
effect(value) = ismissing(value) ? "—" : @sprintf("%+.4f", value)

"""Format a ratio as a percentage with two decimal places."""
percent(value) = @sprintf("%.2f%%", 100value)

"""Format an exact rational without a redundant denominator one."""
function fraction_string(value::Rational)
    return denominator(value) == 1 ? string(numerator(value)) :
           "$(numerator(value))/$(denominator(value))"
end

"""Format a two-sided interval or the word `census`."""
function mean_interval_string(summary)
    if ismissing(summary.mean_interval)
        return summary.source == "polyDB" ? "census" : "exhaustive"
    end
    return @sprintf("[%.6f, %.6f]", summary.mean_interval...)
end

"""Format a threshold count, percentage, and optional Monte Carlo interval."""
function threshold_string(count, total, interval=missing)
    result = "$(count) ($(percent(count / total)))"
    if !ismissing(interval)
        result *= @sprintf(" [95%% MC %.3f%%–%.3f%%]", 100interval[1], 100interval[2])
    end
    return result
end

"""Escape one value for the compact derived CSV files."""
function csv_cell(value)
    (value === missing || value === nothing) && return ""
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

"""Write one compact row per experiment/ensemble summary."""
function write_summary_csv(path, analyses)
    headers = [
        "experiment", "n", "rank", "ensemble", "derived", "random", "count",
        "mean_theta", "sd_theta", "mean_ci_lower", "mean_ci_upper", "minimum_theta",
        "median_theta", "p95_theta", "maximum_theta", "maximum_theta_exact",
        "theta_negative_count", "theta_zero_count", "theta_above_density_count",
        "theta_above_one_count", "theta_alpha_pearson", "theta_alpha_spearman",
        "theta_density_pearson", "theta_density_spearman", "theta_product_spearman",
        "alpha_top_decile_overlap", "product_top_decile_overlap",
        "mean_theta_lambda2", "sd_theta_lambda2", "median_theta_lambda2",
        "p95_theta_lambda2", "maximum_theta_lambda2", "maximum_theta_lambda2_exact",
        "theta_lambda2_above_one_count", "theta_lambda2_alpha_pearson",
        "theta_lambda2_alpha_spearman", "theta_lambda2_density_pearson",
        "theta_lambda2_density_spearman", "theta1_theta2_spearman",
        "theta_lambda2_top_decile_overlap_with_theta1", "sparse_count",
        "sparse_median", "sparse_maximum", "non_sparse_count", "non_sparse_median",
        "non_sparse_maximum", "non_sparse_superiority",
    ]
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, join(headers, ','))
        for analysis in analyses, summary in analysis.summaries
            mean_lower = ismissing(summary.mean_interval) ? missing : summary.mean_interval[1]
            mean_upper = ismissing(summary.mean_interval) ? missing : summary.mean_interval[2]
            values = Any[
                summary.experiment_slug, summary.n, summary.rank, summary.label,
                summary.derived, summary.random, summary.count, summary.mean,
                summary.standard_deviation, mean_lower, mean_upper, summary.minimum,
                summary.median, summary.percentile_95, summary.maximum,
                summary.maximum_fraction, summary.negative, summary.zero,
                summary.above_density, summary.above_one, summary.alpha_pearson,
                summary.alpha_spearman, summary.density_pearson,
                summary.density_spearman, summary.product_spearman,
                summary.alpha_top_overlap, summary.product_top_overlap,
                summary.lambda2_mean, summary.lambda2_standard_deviation,
                summary.lambda2_median, summary.lambda2_percentile_95,
                summary.lambda2_maximum, summary.lambda2_maximum_fraction,
                summary.lambda2_above_one, summary.lambda2_alpha_pearson,
                summary.lambda2_alpha_spearman, summary.lambda2_density_pearson,
                summary.lambda2_density_spearman, summary.lambda1_lambda2_spearman,
                summary.lambda2_top_overlap,
                summary.sparse.count, summary.sparse.median, summary.sparse.maximum,
                summary.non_sparse.count, summary.non_sparse.median,
                summary.non_sparse.maximum, summary.non_sparse_superiority,
            ]
            println(output, join(csv_cell.(values), ','))
        end
    end
    return path
end

"""Merge repeated extremal profiles and retain every observed origin label."""
function combined_top_profiles(analyses; limit::Int=15)
    records = Dict{Tuple,NamedTuple}()
    for analysis in analyses, profile in analysis.profiles
        key = (
            Int(profile.n),
            Int(profile.rank_value),
            Int(profile.num_bases),
            profile.alpha_num,
            profile.alpha_den,
            Int(profile.sparse_paving),
        )
        origin = "$(profile.experiment_slug): $(profile.origin)"
        if haskey(records, key)
            push!(records[key].origins, origin)
        else
            records[key] = (
                profile=profile,
                origins=Set([origin]),
            )
        end
    end
    ordered = sort!(collect(values(records)); by=record -> record.profile.theta, rev=true)
    return ordered[1:min(limit, length(ordered))]
end

"""Write the compact table of distinct high-Θ profiles."""
function write_profile_csv(path, records)
    headers = [
        "n", "rank", "representative_id", "num_bases", "basis_density",
        "alpha_num", "alpha_den", "theta_num", "theta_den", "theta_value",
        "sparse_paving", "observed_in",
    ]
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, join(headers, ','))
        for record in records
            profile = record.profile
            values = Any[
                profile.n, profile.rank_value, profile.source_id, profile.num_bases,
                profile.basis_density, profile.alpha_num, profile.alpha_den,
                numerator(profile.theta), denominator(profile.theta), Float64(profile.theta),
                profile.sparse_paving, join(sort!(collect(record.origins)), "; "),
            ]
            println(output, join(csv_cell.(values), ','))
        end
    end
    return path
end

"""Write the distribution and threshold tables for one rank scope."""
function write_distribution_tables(output, summaries)
    println(output, "| Ensemble | N | Mean Θ | 95% MC CI for mean | SD | Minimum | Median | 95th percentile | Maximum |")
    println(output, "|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for summary in summaries
        println(
            output,
            "| ", summary.label,
            " | ", summary.count,
            " | ", fixed(summary.mean),
            " | ", mean_interval_string(summary),
            " | ", fixed(summary.standard_deviation),
            " | ", fixed(summary.minimum),
            " | ", fixed(summary.median),
            " | ", fixed(summary.percentile_95),
            " | ", summary.maximum_fraction,
            " (", fixed(summary.maximum), ")",
            " |",
        )
    end
    println(output)
    println(output, "| Ensemble | Θ < 0 | Θ = 0 | Θ > d_B (equiv. α₁ > 1) | Θ > 1 |")
    println(output, "|---|---:|---:|---:|---:|")
    for summary in summaries
        println(
            output,
            "| ", summary.label,
            " | ", threshold_string(summary.negative, summary.count),
            " | ", threshold_string(summary.zero, summary.count),
            " | ", threshold_string(summary.above_density, summary.count),
            " | ", threshold_string(
                summary.above_one,
                summary.count,
                summary.above_one_interval,
            ),
            " |",
        )
    end
end

"""Write descriptive correlations and ranking-overlap statistics."""
function write_relationship_table(output, summaries)
    println(
        output,
        "| Ensemble | Pearson r(Θ, α₁) | Spearman ρ(Θ, α₁) | Pearson r(Θ, d_B) | Spearman ρ(Θ, d_B) | Spearman ρ(Θ, d_B α₁) | Θ top decile also α₁ top decile | Θ top decile also d_B α₁ top decile |",
    )
    println(output, "|---|---:|---:|---:|---:|---:|---:|---:|")
    for summary in summaries
        println(
            output,
            "| ", summary.label,
            " | ", effect(summary.alpha_pearson),
            " | ", effect(summary.alpha_spearman),
            " | ", effect(summary.density_pearson),
            " | ", effect(summary.density_spearman),
            " | ", effect(summary.product_spearman),
            " | ", percent(summary.alpha_top_overlap),
            " | ", percent(summary.product_top_overlap),
            " |",
        )
    end
end

"""Write the lambda=1 versus lambda=2 density-correlation comparison."""
function write_lambda_comparison_tables(output, summaries)
    println(
        output,
        "| Ensemble | Pearson r(d_B, Θ₁) | Pearson r(d_B, Θ₂) | Spearman ρ(d_B, Θ₁) | Spearman ρ(d_B, Θ₂) | Change in Spearman ρ | Spearman ρ(Θ₁, Θ₂) | Θ₂ top decile also Θ₁ top decile |",
    )
    println(output, "|---|---:|---:|---:|---:|---:|---:|---:|")
    for summary in summaries
        println(
            output,
            "| ", summary.label,
            " | ", effect(summary.density_pearson),
            " | ", effect(summary.lambda2_density_pearson),
            " | ", effect(summary.density_spearman),
            " | ", effect(summary.lambda2_density_spearman),
            " | ", effect(summary.lambda2_density_spearman - summary.density_spearman),
            " | ", effect(summary.lambda1_lambda2_spearman),
            " | ", percent(summary.lambda2_top_overlap),
            " |",
        )
    end
    println(output)
    println(
        output,
        "| Ensemble | Median Θ₁ | Median Θ₂ | 95th percentile Θ₂ | Maximum Θ₂ | Θ₂ > 1 |",
    )
    println(output, "|---|---:|---:|---:|---:|---:|")
    for summary in summaries
        println(
            output,
            "| ", summary.label,
            " | ", fixed(summary.median),
            " | ", fixed(summary.lambda2_median),
            " | ", fixed(summary.lambda2_percentile_95),
            " | ", summary.lambda2_maximum_fraction,
            " (", fixed(summary.lambda2_maximum), ")",
            " | ", threshold_string(summary.lambda2_above_one, summary.count),
            " |",
        )
    end
end

"""Write sparse-paving versus non-sparse-paving effect summaries."""
function write_sparse_table(output, summaries)
    println(
        output,
        "| Ensemble | Sparse paving N | Median Θ | 95th percentile | Maximum | Non-sparse-paving N | Median Θ | 95th percentile | Maximum | Mean difference (non-SP − SP) | Ordinal superiority (ties half) |",
    )
    println(output, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for summary in summaries
        difference = summary.sparse.count == 0 || summary.non_sparse.count == 0 ? missing :
                     summary.non_sparse.mean - summary.sparse.mean
        println(
            output,
            "| ", summary.label,
            " | ", summary.sparse.count,
            " | ", fixed(summary.sparse.median),
            " | ", fixed(summary.sparse.percentile_95),
            " | ", fixed(summary.sparse.maximum),
            " | ", summary.non_sparse.count,
            " | ", fixed(summary.non_sparse.median),
            " | ", fixed(summary.non_sparse.percentile_95),
            " | ", fixed(summary.non_sparse.maximum),
            " | ", ismissing(difference) ? "—" : @sprintf("%+.6f", difference),
            " | ", ismissing(summary.non_sparse_superiority) ? "—" :
                   percent(summary.non_sparse_superiority),
            " |",
        )
    end
end

"""Write the complete standalone Markdown report."""
function write_report(path, figure_directory, summary_csv, profile_csv, analyses, profiles)
    mkpath(dirname(path))
    figure_relative = relpath(figure_directory, dirname(path))
    summary_relative = relpath(summary_csv, dirname(path))
    profile_relative = relpath(profile_csv, dirname(path))
    summaries = reduce(vcat, [analysis.summaries for analysis in analyses])
    primary = [summary for summary in summaries if !summary.derived]
    maximum_record = first(profiles)
    maximum_profile = maximum_record.profile
    negative_cells = [summary for summary in primary if summary.negative > 0]
    above_one_cells = [summary for summary in primary if summary.above_one > 0]
    product_correlations = Float64[
        summary.product_spearman for summary in primary
        if !ismissing(summary.product_spearman)
    ]
    alpha_correlations = Float64[
        summary.alpha_spearman for summary in primary
        if !ismissing(summary.alpha_spearman)
    ]
    superiority_values = Float64[
        summary.non_sparse_superiority for summary in primary
        if !ismissing(summary.non_sparse_superiority)
    ]
    n9_r4 = only([
        summary for summary in primary
        if summary.experiment_slug == "n9_r4" && summary.source == "polyDB"
    ])
    large_field = [
        summary for summary in primary
        if occursin("GF(5)", summary.label) || occursin("GF(7)", summary.label)
    ]
    lambda2_above_one_count = sum(summary.lambda2_above_one for summary in primary)
    lambda2_global_maximum = maximum(summary.lambda2_maximum for summary in primary)
    maximum_n = maximum(analysis.experiment.n for analysis in analyses)
    large_field_lambda1_rho = Float64[summary.density_spearman for summary in large_field]
    large_field_lambda2_rho = Float64[
        summary.lambda2_density_spearman for summary in large_field
    ]

    open(path, "w") do output
        println(output, "# Statistical analysis of the density-adjusted correlation excess Θ")
        println(output)
        println(output, "This is a standalone report. The existing α₁ reports are unchanged and do not include Θ.")
        println(output)
        println(output, "## Executive summary")
        println(output)
        if isempty(negative_cells)
            println(
                output,
                "- No primary census, finite-field, or Johnson-graph ensemble contains an ",
                "observed Θ < 0. ",
                "Equivalently, every connected positive-α₁ observation satisfies the ",
                "uniform-baseline inequality α₁(M) ≥ α₁(U_{r,n}). This is evidence, not a ",
                "proof, for the conjectured general inequality.",
            )
        else
            println(output, "- Negative Θ values occur in ", length(negative_cells), " primary ensemble cells.")
        end
        println(
            output,
            "- The largest distinct observed profile has n = ", maximum_profile.n,
            ", rank ", maximum_profile.rank_value,
            ", basis density ", @sprintf("%.6f", maximum_profile.basis_density),
            ", α₁ = ", maximum_profile.alpha_num, "/", maximum_profile.alpha_den,
            ", and Θ = ", fraction_string(maximum_profile.theta),
            " ≈ ", @sprintf("%.6f", Float64(maximum_profile.theta)), ".",
        )
        if isempty(above_one_cells)
            println(output, "- No primary ensemble contains Θ > 1.")
        else
            println(
                output,
                "- Θ > 1 occurs in ", length(above_one_cells),
                " primary ensemble cell", length(above_one_cells) == 1 ? "" : "s",
                ". Every such observation is automatically non-sparse-paving and has α₁ > 1.",
            )
        end
        println(
            output,
            "- In the exact n = 9, rank 4 census, the median is ", fixed(n9_r4.median),
            " and the 95th percentile is ", fixed(n9_r4.percentile_95),
            ". Sparse paving and non-sparse-paving medians are ",
            fixed(n9_r4.sparse.median), " and ", fixed(n9_r4.non_sparse.median),
            ", respectively.",
        )
        println(
            output,
            "- Across primary ensemble cells, Spearman correlation with α₁ ranges from ",
            @sprintf("%.3f", minimum(alpha_correlations)), " to ",
            @sprintf("%.3f", maximum(alpha_correlations)),
            ", whereas correlation with the raw product d_B α₁ ranges from ",
            @sprintf("%.3f", minimum(product_correlations)), " to ",
            @sprintf("%.3f", maximum(product_correlations)),
            ". Thus baseline correction can materially change rankings.",
        )
        println(
            output,
            "- In the GF(5) and GF(7) cells, Spearman ρ(d_B, Θ₁) ranges from ",
            @sprintf("%+.3f", minimum(large_field_lambda1_rho)), " to ",
            @sprintf("%+.3f", maximum(large_field_lambda1_rho)),
            ". After changing to λ = 2, the range becomes ",
            @sprintf("%+.3f", minimum(large_field_lambda2_rho)), " to ",
            @sprintf("%+.3f", maximum(large_field_lambda2_rho)),
            ". The second density factor shifts the association upward but need not ",
            "eliminate it.",
        )
        println(
            output,
            "- The largest observed Θ₂ value in the current n ≤ ", maximum_n, " data is ",
            @sprintf("%.6f", lambda2_global_maximum), ", and the primary cells contain ",
            lambda2_above_one_count, " observations with Θ₂ > 1.",
        )
        if !isempty(superiority_values)
            println(
                output,
                "- Where both sparse-paving statuses occur, the non-sparse-paving versus ",
                "sparse-paving ordinal-superiority statistic ranges from ",
                percent(minimum(superiority_values)), " to ",
                percent(maximum(superiority_values)), ".",
            )
        end
        println(output)
        println(output, "## Definition and calibration")
        println(output)
        println(output, "For a rank-r matroid M on n elements, let")
        println(output)
        println(output, "\$\$")
        println(output, "d_{\\mathcal B}(M)=\\frac{|\\mathcal B(M)|}{\\binom nr},")
        println(output, "\\qquad")
        println(output, "c_{r,n}=\\alpha_1(U_{r,n})=\\frac{(r-1)(n-r-1)}{r(n-r)}.")
        println(output, "\$\$")
        println(output)
        println(output, "The chosen invariant is")
        println(output)
        println(output, "\$\$")
        println(output, "\\Theta(M)=d_{\\mathcal B}(M)\\frac{\\alpha_1(M)-c_{r,n}}{1-c_{r,n}}.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "It is zero at the uniform-matroid baseline, equals d_B at α₁ = 1, lies above ",
            "the diagonal Θ = d_B exactly when α₁ > 1, and satisfies Θ ≤ d_B ≤ 1 for ",
            "sparse paving matroids. Hence Θ > 1 is a structural certificate.",
        )
        println(output)
        println(output, "More generally, consider")
        println(output)
        println(output, "\$\$")
        println(output, "\\Theta_\\lambda(M)")
        println(output, "=")
        println(output, "d_{\\mathcal B}(M)^\\lambda")
        println(output, "\\frac{\\alpha_1(M)-c_{r,n}}{1-c_{r,n}}.")
        println(output, "\$\$")
        println(output)
        println(output, "For λ = 2,")
        println(output)
        println(output, "\$\$")
        println(output, "\\Theta_2(M)=d_{\\mathcal B}(M)\\Theta_1(M).")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "Because every currently observed Θ₁ is nonnegative and 0 < d_B ≤ 1, the ",
            "second factor can only lower observed scores. It preserves the sign and the ",
            "sparse-paving certificate Θ₂ > 1, but makes that certificate harder to attain. ",
            "At α₁ = 1 the calibration changes from Θ₁ = d_B to Θ₂ = d_B².",
        )
        println(output)
        println(
            output,
            "For the rank-6, 12-element matroid attaining α₁ = 100/81, d_B = 57/77 and",
        )
        println(output)
        println(output, "\$\$")
        println(output, "\\Theta_1=\\frac{475}{363}\\approx1.30854,")
        println(output, "\\qquad")
        println(output, "\\Theta_2=\\frac{57}{77}\\Theta_1")
        println(output, "=\\frac{9025}{9317}\\approx0.96867.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "Thus λ = 2 no longer places the benchmark above 1. This is an important cost ",
            "of the stronger density penalty.",
        )
        println(output)
        println(output, "## Why a negative Θ₁–density correlation is not automatic")
        println(output)
        println(output, "Write")
        println(output)
        println(output, "\$\$")
        println(output, "D=d_{\\mathcal B}(M),")
        println(output, "\\qquad")
        println(output, "Z=\\frac{\\alpha_1(M)-c_{r,n}}{1-c_{r,n}},")
        println(output, "\\qquad")
        println(output, "\\Theta_1=DZ.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "At fixed Z, multiplying by D pushes Θ₁ upward. Moreover, the covariance has ",
            "the exact decomposition",
        )
        println(output)
        println(output, "\$\$")
        println(output, "\\operatorname{Cov}(D,DZ)")
        println(output, "=")
        println(output, "\\mathbb E[D]\\operatorname{Cov}(D,Z)")
        println(output, "+\\mathbb E[Z]\\operatorname{Var}(D)")
        println(output, "+\\mathbb E[(D-\\mathbb E[D])^2(Z-\\mathbb E[Z])].")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "The middle term is nonnegative when the average normalized excess is ",
            "nonnegative, while the other terms can be negative. Consequently, a negative ",
            "correlation between α₁ and density does not determine the sign of the ",
            "Θ₁–density correlation. Its observed persistence says that the decline in ",
            "normalized excess is strong enough to overcome one explicit density factor. ",
            "Using λ = 2 tests whether a second factor compensates for that decline.",
        )
        println(output)
        println(output, "## Populations and statistical conventions")
        println(output)
        println(
            output,
            "Every table and figure uses connected matroids with α₁ > 0. PolyDB rows are ",
            "isomorphism classes, so census coefficients and percentages are exact ",
            "descriptions of those finite populations. Finite-field rows are configurations ",
            "or representations sampled from the stated field and replacement model; they ",
            "are not uniform samples of matroid isomorphism classes. Johnson-graph rows are ",
            "independent labeled outputs of a one-pass random-priority greedy law at the ",
            "displayed activation probability p; they are neither uniform independent sets ",
            "nor uniform matroid isomorphism classes.",
        )
        println(output)
        println(
            output,
            "The mean and SD describe the empirical distribution. A 95% Monte Carlo interval ",
            "for the mean and a Wilson interval for P(Θ > 1) are given only for random ",
            "finite-field and Johnson-graph cells. Correlations involving Θ are algebraically ",
            "coupled and are ",
            "therefore reported descriptively without independence p-values. Weighted ",
            "midranks handle ties. The sparse-paving probability-of-superiority statistic ",
            "gives half credit to ties; 50% means no ordinal separation. Upper-decile sets ",
            "include all ties at the empirical 90th percentile and can therefore contain ",
            "more than exactly 10% of a population.",
        )
        println(output)
        println(output, "Data sources:")
        println(output)
        for analysis in analyses
            experiment = analysis.experiment
            database_relative = relpath(experiment.database, dirname(path))
            println(
                output,
                "- ", experiment.title, ": [`", basename(experiment.database), "`](",
                database_relative, ")",
            )
        end

        for analysis in analyses
            experiment = analysis.experiment
            local_summaries = analysis.summaries
            println(output)
            println(output, "## ", experiment.title)
            println(output)
            baseline = uniform_correlation_baseline(experiment.n, experiment.rank)
            println(
                output,
                "Here c_{r,n} = ", fraction_string(baseline),
                " ≈ ", @sprintf("%.6f", Float64(baseline)), ".",
            )
            if any(summary -> summary.source == "johnson_graph", local_summaries)
                println(output)
                println(
                    output,
                    "The Johnson-graph rows use independent stable sets from the labeled ",
                    "random-priority greedy ensemble described above. Separate fixed-p cells ",
                    "show how the conclusions vary with the sampling activity; pooling across ",
                    "those cells would induce an additional between-activity association and ",
                    "is therefore avoided in the reported correlations.",
                )
            end
            println(output)
            println(output, "### Distribution and thresholds")
            println(output)
            write_distribution_tables(output, local_summaries)
            println(output)
            println(
                output,
                "The histogram uses every retained observation and 45 common equal-width ",
                "bins within this rank scope. Curves are probability masses, not CDFs. The ",
                "black dashed line is Θ = 0 and the red dash-dot line is Θ = 1.",
            )
            println(output)
            println(
                output,
                "![Θ probability histogram for ", experiment.slug, "](",
                figure_relative, "/", experiment.slug, "_theta_histogram.png)",
            )
            println(output)
            println(output, "### Relationship with α₁, basis density, and d_B α₁")
            println(output)
            write_relationship_table(output, local_summaries)
            println(output)
            println(
                output,
                "The point clouds are deterministically thinned to at most 15,000 rows per ",
                "ensemble for rendering only; all coefficients and tables use the complete ",
                "population. Circles are non-sparse-paving and triangles are sparse paving. ",
                "The black diagonal is Θ = d_B, equivalently α₁ = 1.",
            )
            println(output)
            println(
                output,
                "![Basis density versus Θ for ", experiment.slug, "](",
                figure_relative, "/", experiment.slug, "_density_vs_theta.png)",
            )
            println(output)
            println(output, "### Effect of changing from λ = 1 to λ = 2")
            println(output)
            write_lambda_comparison_tables(output, local_summaries)
            println(output)
            println(
                output,
                "The companion scatterplot uses Θ₂ = d_B Θ₁. Its black dashed curve is ",
                "Θ₂ = d_B², the α₁ = 1 boundary. Points above the curve have α₁ > 1. ",
                "The same deterministic rendering cap and sparse-paving markers are used.",
            )
            println(output)
            println(
                output,
                "![Basis density versus Θ₂ for ", experiment.slug, "](",
                figure_relative, "/", experiment.slug, "_density_vs_theta_lambda2.png)",
            )
            println(output)
            println(output, "### Sparse-paving comparison")
            println(output)
            write_sparse_table(output, local_summaries)
        end

        println(output)
        println(output, "## Largest distinct observed profiles")
        println(output)
        println(
            output,
            "Profiles are deduplicated by `(n, rank, number of bases, α₁, sparse-paving ",
            "status)`. The identifier is one representative observation. Multiple origins ",
            "are combined when the same profile occurs in several ensembles.",
        )
        println(output)
        println(output, "| n | Rank | Representative | Bases | d_B | α₁ | Θ | Sparse paving | Observed in |")
        println(output, "|---:|---:|---|---:|---:|---:|---:|---:|---|")
        for record in profiles
            profile = record.profile
            println(
                output,
                "| ", profile.n,
                " | ", profile.rank_value,
                " | ", profile.source_id,
                " | ", profile.num_bases,
                " | ", @sprintf("%.6f", profile.basis_density),
                " | ", profile.alpha_num, "/", profile.alpha_den,
                " | ", fraction_string(profile.theta),
                " (", @sprintf("%.6f", Float64(profile.theta)), ")",
                " | ", profile.sparse_paving == 1 ? "yes" : "no",
                " | ", join(sort!(collect(record.origins)), "<br>"),
                " |",
            )
        end
        println(output)
        println(output, "## Reproducibility exports")
        println(output)
        println(output, "- [`theta_summary.csv`](", summary_relative, ")")
        println(output, "- [`theta_extremal_profiles.csv`](", profile_relative, ")")
        println(output)
        println(
            output,
            "These compact exports contain only derived summaries and extremal profiles. ",
            "No per-matroid Θ table is stored. Exact Θ is reconstructed from `n`, rank, ",
            "number of bases, and the exact α₁ numerator and denominator by the shared Julia ",
            "helper `density_adjusted_correlation_excess`.",
        )
    end
    return path
end

"""Run every available scope and write the standalone report artifacts."""
function main()
    report_path = length(ARGS) >= 1 ? ARGS[1] :
                  joinpath(PROJECT_DIRECTORY, "reports", "theta_analysis_report.md")
    figure_directory = length(ARGS) >= 2 ? ARGS[2] :
                       joinpath(PROJECT_DIRECTORY, "figures", "theta_analysis")
    summary_csv = length(ARGS) >= 3 ? ARGS[3] :
                  joinpath(PROJECT_DIRECTORY, "data", "theta_analysis", "theta_summary.csv")
    profile_csv = joinpath(dirname(summary_csv), "theta_extremal_profiles.csv")
    mkpath(figure_directory)

    analyses = NamedTuple[]
    for experiment in experiment_specs()
        println("THETA_SCOPE_START ", experiment.slug)
        push!(analyses, analyze_experiment(experiment, figure_directory))
        println("THETA_SCOPE_COMPLETE ", experiment.slug)
    end
    write_summary_csv(summary_csv, analyses)
    profiles = combined_top_profiles(analyses)
    write_profile_csv(profile_csv, profiles)
    write_report(
        report_path,
        figure_directory,
        summary_csv,
        profile_csv,
        analyses,
        profiles,
    )
    println("THETA_REPORT_COMPLETE path=", report_path)
end

(abspath(PROGRAM_FILE) == @__FILE__) && main()
