"""
Generate rank-scoped or all-ranks figures from a compact correlation-ratio
SQLite database.

Command line:

```text
julia --project=. scripts/make_figures.jl \
    DATABASE OUTPUT_DIRECTORY [N] [RANK_SCOPE]
```

`RANK_SCOPE` is one rank, a comma list, an inclusive range, or `all`. By
duality, accepted ranks stop at `floor(N/2)`; `all` means all completed ranks
through that bound. The main distribution figures include only connected
matroids with positive α₁. Exact histograms use every stored observation;
dense scatterplots are deterministically thinned for rendering only. The α₁
output includes a companion histogram conditioned on the matroid not being
sparse paving, with the same bin edges as the main histogram. To avoid
overplotting, finite-field comparisons are faceted by replacement model and
the field pairs `(2, 3)` and `(5, 7)`.
Generating the heatmaps marks their source matroids in `selected_matroids` and
regenerates their full pair profiles from the packed basis masks.
"""

using CairoMakie
using DBInterface
using Printf
using Statistics

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

"""Materialize a SQLite result because `SQLite.Row` objects are iterator views."""
function materialize(database, sql, parameters=())
    return [
        (; (name => getproperty(row, name) for name in propertynames(row))...)
        for row in DBInterface.execute(database, sql, parameters)
    ]
end

"""Parse a rank scope and enforce the nonredundant bound `r <= floor(n/2)`."""
function parse_rank_scope(database, n::Int, specification::AbstractString)
    maximum_rank = fld(n, 2)
    ranks = if lowercase(specification) == "all"
        sort!(unique([
            Int(row.rank_value) for row in DBInterface.execute(
                database,
                """
                SELECT rank_value FROM runs
                WHERE n = ? AND rank_value <= ? AND accepted_count > 0
                """,
                (n, maximum_rank),
            )
        ]))
    elseif occursin(':', specification)
        endpoints = parse.(Int, split(specification, ':'))
        length(endpoints) == 2 || throw(ArgumentError("rank range must be a:b"))
        collect(endpoints[1]:endpoints[2])
    elseif occursin(',', specification)
        sort!(unique(parse.(Int, split(specification, ','))))
    else
        [parse(Int, specification)]
    end
    all(rank -> 0 <= rank <= maximum_rank, ranks) || throw(
        ArgumentError("by duality, ranks must lie between 0 and floor(n/2) = $(maximum_rank)"),
    )
    return ranks
end

"""Human-readable ensemble label for legends and report explanations."""
function display_label(run; aggregate_ranks::Bool=false)
    suffix = aggregate_ranks ? " (combined ranks)" : ""
    if run.source == "polyDB"
        return "polyDB" * suffix
    elseif run.source == "johnson_graph"
        probability = johnson_greedy_probability(run.ensemble)
        return @sprintf("Johnson greedy p = %.3g%s", probability, suffix)
    elseif run.ensemble == "projective_subsets_exhaustive"
        return "GF($(run.field_size)) exhaustive, no replacement" * suffix
    elseif run.ensemble == "projective_points_with_replacement_random"
        return "GF($(run.field_size)) random, with replacement" * suffix
    end
    return "GF($(run.field_size)) random, no replacement" * suffix
end

"""Whether an ensemble consists of independent Monte Carlo draws."""
is_random_ensemble(ensemble) =
    ensemble == "projective_subsets_random" ||
    ensemble == "projective_points_with_replacement_random" ||
    !ismissing(johnson_greedy_probability(ensemble))

"""
Build plotting groups by pooling runs with the same source, ensemble, and
field. This combines seed replicates and, when requested, several ranks.
"""
function group_specs(database, n::Int, ranks::Vector{Int})
    rank_set = Set(ranks)
    runs = [
        row for row in materialize(
            database,
            """
            SELECT run_id, source, ensemble, field_size, rank_value,
                   accepted_count
            FROM runs
            WHERE n = ? AND accepted_count > 0
            ORDER BY CASE WHEN source = 'polyDB' THEN 0 ELSE 1 END,
                     field_size, rank_value, run_id
            """,
            (n,),
        ) if Int(row.rank_value) in rank_set
    ]
    isempty(runs) && error("database contains no completed runs for the requested scope")
    aggregate_ranks = length(ranks) > 1
    base_groups = NamedTuple[]
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
    for key in keys_in_order
        bucket = buckets[key]
        representative = first(bucket)
        push!(base_groups, (
            run_ids=String[run.run_id for run in bucket],
            label=display_label(representative; aggregate_ranks=aggregate_ranks),
            source=representative.source,
            ensemble=representative.ensemble,
            field_size=representative.field_size,
            simple_only=false,
            derived=false,
            random=is_random_ensemble(representative.ensemble),
        ))
    end

    groups = NamedTuple[]
    for group in base_groups
        push!(groups, group)
        if group.source == "polyDB"
            push!(groups, merge(group, (
                label=replace(group.label, "polyDB" => "polyDB simple"),
                simple_only=true,
                derived=true,
            )))
        end
    end
    return groups
end

"""
Partition comparison groups into uncluttered panels.

Finite-field panels contain at most the two fields in one of the pairs
`(2, 3)` and `(5, 7)`, and never mix replacement with no-replacement
ensembles. Johnson random-greedy activities are sorted and placed two per
panel. Census data and any remaining ensembles receive a separate panel.
"""
function comparison_panels(groups)
    definitions = [
        (
            title="GF(2) and GF(3), with replacement",
            fields=Set((2, 3)),
            replacement=true,
        ),
        (
            title="GF(5) and GF(7), with replacement",
            fields=Set((5, 7)),
            replacement=true,
        ),
        (
            title="GF(2) and GF(3), without replacement",
            fields=Set((2, 3)),
            replacement=false,
        ),
        (
            title="GF(5) and GF(7), without replacement",
            fields=Set((5, 7)),
            replacement=false,
        ),
    ]
    panels = NamedTuple[]
    assigned = falses(length(groups))
    for definition in definitions
        indices = Int[]
        for (index, group) in enumerate(groups)
            is_finite_field = group.source == "finite_field"
            has_matching_field =
                !ismissing(group.field_size) && Int(group.field_size) in definition.fields
            uses_replacement =
                group.ensemble == "projective_points_with_replacement_random"
            if is_finite_field && has_matching_field &&
               uses_replacement == definition.replacement
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

"""Short legend label when the panel title already states the sampling model."""
function panel_label(group)
    group.source == "polyDB" && return group.label
    group.source == "johnson_graph" && return @sprintf(
        "p = %.3g",
        johnson_greedy_probability(group.ensemble),
    )
    field = "GF($(group.field_size))"
    return group.ensemble == "projective_subsets_exhaustive" ?
           field * ", exhaustive" : field
end

"""Return the SQL placeholder list for a group's run identifiers."""
run_placeholders(group) = join(fill("?", length(group.run_ids)), ", ")

"""
Read matroid summaries for a group. `distribution_only=true` implements the
report's analysis population: connected matroids with α₁ > 0.
"""
function matroid_rows(database, group; distribution_only::Bool=false)
    conditions = String[]
    group.simple_only && push!(conditions, "simple = 1")
    distribution_only && append!(conditions, ["connected = 1", "alpha_num > 0"])
    suffix = isempty(conditions) ? "" : " AND " * join(conditions, " AND ")
    return materialize(
        database,
        """
        SELECT matroid_id, source_id, field_size, census_multiplicity,
               num_bases, basis_density, alpha_num, alpha_den, alpha_value,
               log_alpha, best_i, best_j, positive_pair_fraction,
               eligible_pair_count, max_pearson, simple, cosimple, connected,
               three_connected, paving, sparse_paving
        FROM matroids
        WHERE run_id IN ($(run_placeholders(group)))$suffix
        ORDER BY run_id, observation_index
        """,
        Tuple(group.run_ids),
    )
end

"""Read exact reduced-ratio frequencies used by the pair histogram."""
function pair_aggregate_rows(database, group)
    suffix = group.simple_only ? " AND simple = 1" : ""
    return materialize(
        database,
        """
        SELECT ratio_num, ratio_den, MIN(ratio_value) AS ratio_value,
               MIN(log_ratio) AS log_ratio,
               SUM(matroid_weight) AS matroid_weight
        FROM pair_ratio_aggregates
        WHERE run_id IN ($(run_placeholders(group)))
          AND connected = 1 AND alpha_positive = 1$suffix
        GROUP BY ratio_num, ratio_den
        """,
        Tuple(group.run_ids),
    )
end

"""Save a high-resolution PNG and, for nondense plots, a scalable SVG."""
function save_figure(figure, output_directory, stem; save_svg::Bool=true)
    svg_path = joinpath(output_directory, stem * ".svg")
    save_svg ? save(svg_path, figure) : (isfile(svg_path) && rm(svg_path))
    save(joinpath(output_directory, stem * ".png"), figure; px_per_unit=2)
end

"""Construct common finite bin edges, including a safe degenerate-data case."""
function common_edges(series; number_of_bins::Int=40)
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

"""Compute normalized histogram mass with optional external total weight."""
function histogram_probabilities(values, weights, edges; total_weight=sum(weights))
    counts = zeros(Float64, length(edges) - 1)
    total_weight > 0 || return counts
    for (value, weight) in zip(values, weights)
        index = searchsortedlast(edges, value)
        index == length(edges) && (index -= 1)
        1 <= index <= length(counts) && (counts[index] += weight)
    end
    return counts ./ total_weight
end

"""Select at most `maximum_rows` deterministic, evenly spaced scatter rows."""
function thin_rows(rows; maximum_rows::Int=15_000)
    length(rows) <= maximum_rows && return rows
    indices = unique(round.(Int, range(1, length(rows); length=maximum_rows)))
    return rows[indices]
end

"""
Draw an exact probability histogram from preloaded matroid rows. The optional
subtitle and sample sizes make filtered companion figures self-describing.
"""
function draw_alpha_histogram(
    rows_by_group,
    groups,
    colors,
    output_directory,
    edges;
    stem::AbstractString,
    subtitle::AbstractString="",
    show_sample_sizes::Bool=false,
)
    panels = [
        panel for panel in comparison_panels(groups)
        if any(index -> !isempty(rows_by_group[index]), panel.indices)
    ]
    isempty(panels) && push!(panels, (
        title="No retained populations",
        indices=Int[],
    ))
    columns = min(2, length(panels))
    panel_rows = cld(length(panels), columns)
    figure = Figure(size=(1180, 520panel_rows))
    for (panel_index, panel) in enumerate(panels)
        row = cld(panel_index, columns)
        column = mod1(panel_index, columns)
        axis = Axis(
            figure[row, column];
            xlabel="α₁",
            ylabel="probability mass per bin",
            title=isempty(subtitle) ? panel.title : panel.title * "\n" * subtitle,
        )
        plotted_series = false
        for index in panel.indices
            group = groups[index]
            rows = rows_by_group[index]
            isempty(rows) && continue
            plotted_series = true
            values = Float64[item.alpha_value for item in rows]
            weights = Float64[item.census_multiplicity for item in rows]
            probabilities = histogram_probabilities(values, weights, edges)
            label = panel_label(group)
            show_sample_sizes &&
                (label *= " (N = $(round(Int, sum(weights))))")
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
        vlines!(axis, [1.0]; color=:black, linestyle=:dash, linewidth=1.5)
        vlines!(axis, [8 / 7]; color=:gray45, linestyle=:dot, linewidth=1.5)
        vlines!(axis, [100 / 81]; color=:firebrick, linestyle=:dashdot, linewidth=1.5)
        xlims!(axis, first(edges), last(edges))
        if plotted_series
            axislegend(axis; position=:rt, framevisible=false)
        else
            text!(
                axis,
                0.5,
                0.5;
                text="No observations after filtering",
                space=:relative,
                align=(:center, :center),
                color=:gray45,
            )
        end
    end
    save_figure(figure, output_directory, stem)
end

"""
Plot the report population's exact α₁ histogram and a companion histogram
conditioned on not being sparse paving. Both figures use identical bin edges.
"""
function make_alpha_histograms(database, groups, colors, output_directory)
    rows_by_group = [
        matroid_rows(database, group; distribution_only=true) for group in groups
    ]
    value_series = [Float64[row.alpha_value for row in rows] for rows in rows_by_group]
    edges = common_edges(value_series; number_of_bins=45)
    isempty(edges) && return
    draw_alpha_histogram(
        rows_by_group,
        groups,
        colors,
        output_directory,
        edges;
        stem="alpha_histogram",
    )

    non_sparse_rows = [
        [row for row in rows if row.sparse_paving == 0] for rows in rows_by_group
    ]
    draw_alpha_histogram(
        non_sparse_rows,
        groups,
        colors,
        output_directory,
        edges;
        stem="alpha_histogram_non_sparse_paving",
        subtitle="non-sparse-paving matroids only",
        show_sample_sizes=true,
    )
end

"""
Plot basis-density and positive-pair summaries with one row per uncluttered
comparison panel.
"""
function make_matroid_scatters(database, groups, colors, output_directory)
    panels = comparison_panels(groups)
    rows_by_group = [
        thin_rows(matroid_rows(database, group; distribution_only=true))
        for group in groups
    ]
    figure = Figure(size=(1450, 470length(panels)))
    for (panel_index, panel) in enumerate(panels)
        basis_axis = Axis(
            figure[panel_index, 1];
            xlabel="basis density",
            ylabel="α₁",
            title=panel.title * ": correlation ratio versus basis density",
        )
        prevalence_axis = Axis(
            figure[panel_index, 2];
            xlabel="fraction of eligible pairs with Rᵢⱼ > 1",
            ylabel="α₁",
            title=panel.title * ": localized versus diffuse dependence",
        )
        for index in panel.indices
            group = groups[index]
            rows = rows_by_group[index]
            isempty(rows) && continue
            alpha = [item.alpha_value for item in rows]
            scatter!(
                basis_axis,
                [item.basis_density for item in rows],
                alpha;
                color=(colors[index], group.derived ? 0.45 : 0.25),
                markersize=group.derived ? 5 : 4,
                label=panel_label(group),
            )
            valid = [
                item for item in rows if !ismissing(item.positive_pair_fraction)
            ]
            scatter!(
                prevalence_axis,
                [item.positive_pair_fraction for item in valid],
                [item.alpha_value for item in valid];
                color=(colors[index], group.derived ? 0.45 : 0.25),
                markersize=group.derived ? 5 : 4,
            )
        end
        for axis in (basis_axis, prevalence_axis)
            hlines!(axis, [1.0]; color=:black, linestyle=:dash)
            hlines!(axis, [100 / 81]; color=:firebrick, linestyle=:dashdot)
        end
        axislegend(basis_axis; position=:lt, framevisible=false)
    end
    save_figure(figure, output_directory, "matroid_scatterplots"; save_svg=false)
end

"""
Plot α₁ against basis density for one sparse-paving status. Rendering
points may be thinned, but correlations and fitted lines use all observations.
"""
function make_basis_density_status_scatter(
    database,
    groups,
    colors,
    output_directory;
    sparse_paving_value::Int,
    subtitle::AbstractString,
    stem::AbstractString,
    show_record_line::Bool,
)
    rows_by_group = [
        [
            row for row in matroid_rows(database, group; distribution_only=true)
            if row.sparse_paving == sparse_paving_value
        ] for group in groups
    ]
    panels = [
        panel for panel in comparison_panels(groups)
        if any(index -> !isempty(rows_by_group[index]), panel.indices)
    ]
    isempty(panels) && push!(panels, (
        title="No retained populations",
        indices=Int[],
    ))
    columns = min(2, length(panels))
    figure = Figure(
        size=(1220, 540cld(length(panels), columns)),
        figure_padding=30,
    )
    for (panel_index, panel) in enumerate(panels)
        axis = Axis(
            figure[cld(panel_index, columns), mod1(panel_index, columns)];
            xlabel="basis density",
            ylabel="α₁",
            title=panel.title * "\n" * subtitle,
        )
        plotted_series = false
        for index in panel.indices
            group = groups[index]
            full_rows = rows_by_group[index]
            isempty(full_rows) && continue
            plotted_series = true
            plot_rows = thin_rows(full_rows)
            densities = Float64[row.basis_density for row in full_rows]
            alpha = Float64[row.alpha_value for row in full_rows]
            weights = Float64[row.census_multiplicity for row in full_rows]
            pearson = weighted_pearson(densities, alpha, weights)
            correlation_label = ismissing(pearson) ? "r = —" :
                                @sprintf("r = %.3f", pearson)
            label = @sprintf(
                "%s (%s, N = %d)",
                panel_label(group),
                correlation_label,
                round(Int, sum(weights)),
            )
            scatter!(
                axis,
                [row.basis_density for row in plot_rows],
                [row.alpha_value for row in plot_rows];
                color=(colors[index], group.derived ? 0.45 : 0.22),
                markersize=group.derived ? 5 : 4,
                label=label,
            )
            fit = weighted_linear_fit(densities, alpha, weights)
            if !ismissing(fit)
                density_limits = collect(extrema(densities))
                lines!(
                    axis,
                    density_limits,
                    fit.intercept .+ fit.slope .* density_limits;
                    color=colors[index],
                    linewidth=3,
                    linestyle=group.derived ? :dash : :solid,
                )
            end
        end
        hlines!(axis, [1.0]; color=:black, linestyle=:dash, linewidth=1.5)
        show_record_line && hlines!(
            axis,
            [100 / 81];
            color=:firebrick,
            linestyle=:dashdot,
            linewidth=1.5,
        )
        if plotted_series
            axislegend(axis; position=:lt, framevisible=false)
        else
            xlims!(axis, 0, 1)
            ylims!(axis, 0, 1.05)
            text!(
                axis,
                0.5,
                0.5;
                text="No observations after filtering",
                space=:relative,
                align=(:center, :center),
                color=:gray45,
            )
        end
    end
    save_figure(figure, output_directory, stem; save_svg=false)
end

"""Generate the non-sparse-paving basis-density companion figure."""
function make_non_sparse_basis_density_scatter(database, groups, colors, output_directory)
    make_basis_density_status_scatter(
        database,
        groups,
        colors,
        output_directory;
        sparse_paving_value=0,
        subtitle="non-sparse-paving matroids only",
        stem="basis_density_vs_alpha_non_sparse_paving",
        show_record_line=true,
    )
end

"""Generate the sparse-paving-only basis-density figure."""
function make_sparse_basis_density_scatter(database, groups, colors, output_directory)
    make_basis_density_status_scatter(
        database,
        groups,
        colors,
        output_directory;
        sparse_paving_value=1,
        subtitle="sparse paving matroids only",
        stem="basis_density_vs_alpha_sparse_paving",
        show_record_line=false,
    )
end

"""
Plot equal-matroid-weight histograms of nonzero within-matroid ratios in
sampling-model-by-field-pair panels.
"""
function make_pair_histogram(database, groups, colors, output_directory)
    rows_by_group = [pair_aggregate_rows(database, group) for group in groups]
    value_series = [
        Float64[row.log_ratio for row in rows if !ismissing(row.log_ratio)]
        for rows in rows_by_group
    ]
    edges = common_edges(value_series; number_of_bins=50)
    isempty(edges) && return
    panels = comparison_panels(groups)
    columns = min(2, length(panels))
    panel_rows = cld(length(panels), columns)
    figure = Figure(size=(1220, 540panel_rows))
    for (panel_index, panel) in enumerate(panels)
        row = cld(panel_index, columns)
        column = mod1(panel_index, columns)
        axis = Axis(
            figure[row, column];
            xlabel="log Rᵢⱼ for nonzero ratios",
            ylabel="equal-matroid-weight probability mass per bin",
            title=panel.title,
        )
        for index in panel.indices
            group = groups[index]
            rows = rows_by_group[index]
            total_weight = sum(item.matroid_weight for item in rows)
            nonzero = [item for item in rows if !ismissing(item.log_ratio)]
            isempty(nonzero) && continue
            zero_weight = total_weight - sum(item.matroid_weight for item in nonzero)
            values = Float64[item.log_ratio for item in nonzero]
            weights = Float64[item.matroid_weight for item in nonzero]
            probabilities = histogram_probabilities(
                values,
                weights,
                edges;
                total_weight=total_weight,
            )
            label = panel_label(group) *
                    @sprintf(" (R=0: %.1f%%)", 100zero_weight / total_weight)
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
        vlines!(axis, [0.0]; color=:black, linestyle=:dash)
        vlines!(axis, [log(8 / 7)]; color=:gray45, linestyle=:dot)
        vlines!(axis, [log(100 / 81)]; color=:firebrick, linestyle=:dashdot)
        xlims!(axis, first(edges), last(edges))
        axislegend(axis; position=:rt, framevisible=false)
    end
    save_figure(figure, output_directory, "pair_logratio_histogram")
end

"""
Compare maximum odds ratios with maximum Pearson correlations in uncluttered
sampling-model-by-field-pair panels.
"""
function make_odds_vs_pearson(database, groups, colors, output_directory)
    panels = comparison_panels(groups)
    rows_by_group = [
        [
            row for row in thin_rows(
                matroid_rows(database, group; distribution_only=true),
            ) if !ismissing(row.max_pearson)
        ] for group in groups
    ]
    columns = min(2, length(panels))
    panel_rows = cld(length(panels), columns)
    figure = Figure(size=(1180, 540panel_rows))
    for (panel_index, panel) in enumerate(panels)
        row = cld(panel_index, columns)
        column = mod1(panel_index, columns)
        axis = Axis(
            figure[row, column];
            xlabel="α₁ (maximum odds ratio)",
            ylabel="maximum Pearson correlation",
            title=panel.title,
        )
        for index in panel.indices
            group = groups[index]
            rows = rows_by_group[index]
            scatter!(
                axis,
                [item.alpha_value for item in rows],
                [item.max_pearson for item in rows];
                color=(colors[index], group.derived ? 0.45 : 0.25),
                markersize=group.derived ? 5 : 4,
                label=panel_label(group),
            )
        end
        vlines!(axis, [1.0]; color=:black, linestyle=:dash)
        vlines!(axis, [100 / 81]; color=:firebrick, linestyle=:dashdot)
        hlines!(axis, [0.0]; color=:gray45, linestyle=:dot)
        axislegend(axis; position=:lt, framevisible=false)
    end
    save_figure(figure, output_directory, "odds_ratio_vs_pearson"; save_svg=false)
end

"""
Select the connected positive-α₁ maximum from each primary ensemble,
cache its pair profile, and return plotting records.
"""
function top_entries(database, groups)
    entries = NamedTuple[]
    for group in groups
        group.derived && continue
        matroids = materialize(
            database,
            """
            SELECT matroid_id, source_id, n, rank_value, alpha_num, alpha_den,
                   alpha_value, best_i, best_j
            FROM matroids
            WHERE run_id IN ($(run_placeholders(group)))
              AND connected = 1 AND alpha_num > 0
            ORDER BY alpha_value DESC, source_id
            LIMIT 1
            """,
            Tuple(group.run_ids),
        )
        isempty(matroids) && continue
        matroid = first(matroids)
        store_selected_pair_profile!(
            database,
            matroid.matroid_id;
            reason="analysis_population_maximum",
            selection_group=join(group.run_ids, ","),
        )
        pairs = materialize(
            database,
            """
            SELECT i, j, b00, b01, b10, b11, ratio_value
            FROM selected_pairs
            WHERE matroid_id = ? AND is_maximizer = 1
            ORDER BY i, j
            LIMIT 1
            """,
            (matroid.matroid_id,),
        )
        isempty(pairs) || push!(entries, (group=group, matroid=matroid, pair=first(pairs)))
    end
    return entries
end

"""Draw normalized maximizing-pair contingency tables for selected maxima."""
function make_maximizer_profiles(database, groups, output_directory)
    entries = top_entries(database, groups)
    isempty(entries) && return
    columns = min(3, length(entries))
    rows = cld(length(entries), columns)
    figure = Figure(size=(390columns, 390rows))
    for (index, entry) in enumerate(entries)
        row = cld(index, columns)
        column = mod1(index, columns)
        pair = entry.pair
        total = pair.b00 + pair.b01 + pair.b10 + pair.b11
        cells = [pair.b00 / total pair.b01 / total; pair.b10 / total pair.b11 / total]
        axis = Axis(
            figure[row, column];
            title=entry.group.label * "\n" * entry.matroid.source_id *
                  @sprintf(
                "\nα₁ = %d/%d, pair {%d,%d}",
                entry.matroid.alpha_num,
                entry.matroid.alpha_den,
                pair.i,
                pair.j,
            ),
            xticks=([1, 2], ["Xⱼ=0", "Xⱼ=1"]),
            yticks=([1, 2], ["Xᵢ=0", "Xᵢ=1"]),
            yreversed=true,
        )
        heatmap!(axis, 1:2, 1:2, cells'; colorrange=(0, 0.5), colormap=:Blues)
        raw_cells = [pair.b00 pair.b01; pair.b10 pair.b11]
        for cell_row in 1:2, cell_column in 1:2
            text!(
                axis,
                cell_column,
                cell_row;
                text=@sprintf(
                    "%d\n(%.3f)",
                    raw_cells[cell_row, cell_column],
                    cells[cell_row, cell_column],
                ),
                align=(:center, :center),
                color=cells[cell_row, cell_column] > 0.32 ? :white : :black,
                fontsize=16,
            )
        end
    end
    save_figure(figure, output_directory, "maximizing_pair_profiles")
end

"""Draw complete element-pair log-ratio heatmaps for selected maxima."""
function make_top_heatmaps(database, groups, output_directory)
    entries = top_entries(database, groups)
    isempty(entries) && return
    columns = min(3, length(entries))
    rows = cld(length(entries), columns)
    figure = Figure(size=(390columns + 80, 370rows))
    last_plot = nothing
    for (index, entry) in enumerate(entries)
        row_index = cld(index, columns)
        column_index = mod1(index, columns)
        n = entry.matroid.n
        matrix = fill(NaN, n, n)
        pair_values = materialize(
            database,
            "SELECT i, j, log_ratio FROM selected_pairs WHERE matroid_id = ?",
            (entry.matroid.matroid_id,),
        )
        for pair in pair_values
            value = ismissing(pair.log_ratio) ? -3.0 : clamp(pair.log_ratio, -3.0, 3.0)
            matrix[pair.i + 1, pair.j + 1] = value
            matrix[pair.j + 1, pair.i + 1] = value
        end
        axis = Axis(
            figure[row_index, column_index];
            title=entry.group.label * "\n" * entry.matroid.source_id,
            xlabel="element",
            ylabel="element",
            xticks=(1:n, string.(0:n-1)),
            yticks=(1:n, string.(0:n-1)),
            yreversed=true,
        )
        last_plot = heatmap!(
            axis,
            1:n,
            1:n,
            matrix';
            colorrange=(-3, 3),
            colormap=:balance,
            nan_color=:lightgray,
        )
    end
    Colorbar(
        figure[1:rows, columns + 1],
        last_plot;
        label="log Rᵢⱼ (zero clipped to -3)",
    )
    save_figure(figure, output_directory, "top_pair_heatmaps")
end

"""Parse figure CLI arguments and generate every requested visualization."""
function main()
    database_path = length(ARGS) >= 1 ? ARGS[1] :
                    joinpath(@__DIR__, "..", "data", "n8_r4_compact", "results.sqlite")
    output_directory = length(ARGS) >= 2 ? ARGS[2] :
                       joinpath(@__DIR__, "..", "figures", "n8_r4_compact")
    n = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 8
    rank_scope = length(ARGS) >= 4 ? ARGS[4] : "4"
    mkpath(output_directory)
    database = init_database(database_path)
    ranks = parse_rank_scope(database, n, rank_scope)
    groups = group_specs(database, n, ranks)
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
    colors = [
        group.source == "polyDB" ? (group.derived ? :gray45 : :black) :
        group.source == "johnson_graph" ?
        johnson_colors[johnson_greedy_probability(group.ensemble)] :
        ismissing(group.field_size) ? :goldenrod :
        get(field_colors, Int(group.field_size), :deepskyblue)
        for group in groups
    ]

    make_alpha_histograms(database, groups, colors, output_directory)
    make_matroid_scatters(database, groups, colors, output_directory)
    make_non_sparse_basis_density_scatter(database, groups, colors, output_directory)
    make_sparse_basis_density_scatter(database, groups, colors, output_directory)
    make_pair_histogram(database, groups, colors, output_directory)
    make_odds_vs_pearson(database, groups, colors, output_directory)
    make_maximizer_profiles(database, groups, output_directory)
    make_top_heatmaps(database, groups, output_directory)
    println(
        "FIGURES_COMPLETE n=",
        n,
        " ranks=",
        join(ranks, ','),
        " directory=",
        output_directory,
    )
end

(abspath(PROGRAM_FILE) == @__FILE__) && main()
