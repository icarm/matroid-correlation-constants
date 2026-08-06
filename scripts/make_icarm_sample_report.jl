"""
Create the separate report, compact tables, and figures for the ICARM
probability samples at `(n,r)=(10,4)` and `(10,5)`.

Command line:

```text
julia --project=. scripts/make_icarm_sample_report.jl \
    [R4_DATABASE] [R5_DATABASE] [REPORT] [FIGURE_DIRECTORY] [TABLE_DIRECTORY]
```

The rank-4 experiment is analyzed as a simple random sample without
replacement from stored isomorphism classes. The rank-5 experiment is a
two-stage pilot: chunks are selected probability-proportional-to-size with
replacement and 100 offsets are sampled inside each draw. Rank-5 uncertainty
therefore uses the 128 chunk draws as primary sampling units. The script never
treats its 12,800 dependent observations as independent for standard errors.

Only six chosen matroids (maximum alpha, maximum sparse-paving alpha, and a
distinct maximum `Theta_2` at each rank) acquire full eligible-pair profiles.
All other outputs are small summaries derived from the authoritative SQLite
files.
"""

using CairoMakie
using DBInterface
using Dates
using Printf
using Random
using SHA
using SQLite
using Statistics
using TOML

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

const INVARIANT_SPECS = [
    (:basis_density, "basis density"),
    (:num_circuits, "number of circuits"),
    (:num_hyperplanes, "number of hyperplanes"),
    (:beta_invariant, "beta invariant"),
    (:mobius_invariant, "absolute Möbius invariant"),
    (:girth, "girth"),
    (:cogirth, "cogirth"),
    (:circuit_hyperplanes, "circuit-hyperplanes"),
    (:automorphism_group_order, "automorphism-group order"),
]

const PROPERTY_SPECS = [
    (:connected, "connected"),
    (:simple, "simple"),
    (:cosimple, "cosimple"),
    (:three_connected, "3-connected"),
    (:paving, "paving"),
    (:copaving, "copaving"),
    (:sparse_paving, "sparse paving"),
    (:alpha_positive, "alpha1 > 0"),
    (:alpha_gt_one, "alpha1 > 1"),
]

"""Materialize forward-only SQLite rows as ordinary named tuples."""
function materialize(database, sql, parameters=())
    return [
        (; (name => getproperty(row, name) for name in propertynames(row))...)
        for row in DBInterface.execute(database, sql, parameters)
    ]
end

"""Read all scalar report fields and sampling coordinates for one rank."""
function load_sample(database_path::AbstractString, rank_value::Int)
    database = init_database(database_path)
    run = only(materialize(
        database,
        """
        SELECT r.*, s.release_slug, s.population_size, s.sampling_design,
               s.selection_algorithm, s.cluster_draw_count,
               s.draws_per_cluster, s.manifest_sha256,
               s.sample_plan_sha256, s.sampling_design_sha256,
               s.decoder_source_sha256, s.decoder_binary_sha256
        FROM runs r JOIN sampling_runs s USING(run_id)
        WHERE r.rank_value = ? AND r.accepted_count > 0
        """,
        (rank_value,),
    ))
    rows = materialize(
        database,
        """
        SELECT m.matroid_id, m.source_id, m.observation_index,
               o.global_index, o.chunk_index, o.cluster_draw_id,
               o.within_cluster_index, o.design_weight,
               m.num_bases, m.basis_density, m.basis_hex,
               m.connected, m.simple, m.cosimple, m.three_connected,
               m.paving, m.copaving, m.sparse_paving,
               m.component_count, m.girth, m.cogirth,
               m.circuit_hyperplanes, m.num_circuits,
               m.num_hyperplanes, m.beta_invariant,
               m.mobius_invariant, m.automorphism_group_order,
               m.alpha_defined, m.alpha_num, m.alpha_den, m.alpha_value,
               m.positive_pair_fraction, m.maximizer_count
        FROM matroids m
        JOIN sampling_observations o USING(matroid_id)
        WHERE m.run_id = ?
        ORDER BY m.observation_index
        """,
        (run.run_id,),
    )
    length(rows) == Int(run.accepted_count) || error("rank-$rank_value row-count mismatch")
    return (rank=rank_value, database=database, path=database_path, run=run, rows=rows)
end

"""The established distribution filter: connected and positive alpha1."""
primary_rows(sample) = [
    row for row in sample.rows if row.connected == 1 && row.alpha_value > 0
]

"""Return a property indicator, including the two derived alpha events."""
function property_value(row, property::Symbol)
    property == :alpha_positive && return row.alpha_value > 0 ? 1.0 : 0.0
    property == :alpha_gt_one && return row.alpha_num > row.alpha_den ? 1.0 : 0.0
    return Float64(getproperty(row, property))
end

"""Compute the density-adjusted excess using a floating-point input row."""
function theta_value(row, n::Int, r::Int, lambda::Int)
    baseline = Float64(uniform_correlation_baseline(n, r))
    return row.basis_density^lambda * (row.alpha_value - baseline) / (1 - baseline)
end

"""Weighted arithmetic mean."""
weighted_mean(values, weights) = sum(values .* weights) / sum(weights)

"""Kish effective sample size for normalized or unnormalized weights."""
kish_effective_size(weights) = sum(weights)^2 / sum(abs2, weights)

"""Wilson score interval for a binomial proportion."""
function wilson_interval(successes::Int, trials::Int; z::Float64=1.959963984540054)
    trials > 0 || return (missing, missing)
    p = successes / trials
    denominator = 1 + z^2 / trials
    center = (p + z^2 / (2trials)) / denominator
    radius = z * sqrt(p * (1 - p) / trials + z^2 / (4trials^2)) / denominator
    return (max(0.0, center - radius), min(1.0, center + radius))
end

"""Cluster-draw means for a scalar row function."""
function cluster_means(rows, value_function)
    identifiers = sort!(unique(Int(row.cluster_draw_id) for row in rows))
    means = Float64[]
    sizes = Int[]
    for identifier in identifiers
        values = Float64[
            value_function(row) for row in rows if Int(row.cluster_draw_id) == identifier
        ]
        isempty(values) && continue
        push!(means, mean(values))
        push!(sizes, length(values))
    end
    return identifiers, means, sizes
end

"""
Estimate a proportion and a 95% interval under the rank-specific design.

Rank 4 uses a Wilson interval; its finite-population correction differs from
one by less than `1.1e-5`. Rank 5 uses a normal interval based on the standard
deviation of 128 equal-size cluster means. When every cluster mean is equal,
the design supplies no empirical variance estimate and the interval is marked
missing instead of reporting a spuriously zero-width interval.
"""
function property_estimate(sample, property)
    values = Float64[property_value(row, property) for row in sample.rows]
    count_value = round(Int, sum(values))
    estimate = mean(values)
    if sample.rank == 4
        lower, upper = wilson_interval(count_value, length(values))
        se = sqrt(estimate * (1 - estimate) / length(values))
        method = "Wilson SRS"
    else
        _, means, _ = cluster_means(sample.rows, row -> property_value(row, property))
        if length(unique(means)) == 1
            lower, upper, se = missing, missing, missing
        else
            se = std(means) / sqrt(length(means))
            lower = max(0.0, estimate - 1.959963984540054se)
            upper = min(1.0, estimate + 1.959963984540054se)
        end
        method = "cluster-draw normal"
    end
    return (
        rank=sample.rank,
        property=property,
        count=count_value,
        sample_size=length(values),
        estimate=estimate,
        standard_error=se,
        lower95=lower,
        upper95=upper,
        method=method,
    )
end

"""Fisher-transform interval, used descriptively for the rank-4 SRS."""
function fisher_interval(correlation, sample_size)
    ismissing(correlation) && return (missing, missing)
    sample_size > 3 || return (missing, missing)
    clipped = clamp(Float64(correlation), -0.999999999, 0.999999999)
    center = atanh(clipped)
    radius = 1.959963984540054 / sqrt(sample_size - 3)
    return (tanh(center - radius), tanh(center + radius))
end

"""Cluster bootstrap interval for Pearson and Spearman correlations."""
function cluster_correlation_intervals(rows; replicates::Int=400, seed::Int)
    cluster_ids = sort!(unique(Int(row.cluster_draw_id) for row in rows))
    isempty(cluster_ids) && return (missing, missing, missing, missing)
    x = Float64[row.basis_density for row in rows]
    y = Float64[row.alpha_value for row in rows]
    row_clusters = Int[row.cluster_draw_id for row in rows]
    rng = MersenneTwister(seed)
    pearson_values = Float64[]
    spearman_values = Float64[]
    sizehint!(pearson_values, replicates)
    sizehint!(spearman_values, replicates)
    for _ in 1:replicates
        multiplicities = Dict(identifier => 0 for identifier in cluster_ids)
        for identifier in rand(rng, cluster_ids, length(cluster_ids))
            multiplicities[identifier] += 1
        end
        weights = Float64[multiplicities[identifier] for identifier in row_clusters]
        pearson = weighted_pearson(x, y, weights)
        spearman = weighted_spearman(x, y, weights)
        !ismissing(pearson) && push!(pearson_values, pearson)
        !ismissing(spearman) && push!(spearman_values, spearman)
    end
    return (
        quantile(pearson_values, 0.025),
        quantile(pearson_values, 0.975),
        quantile(spearman_values, 0.025),
        quantile(spearman_values, 0.975),
    )
end

"""Density-alpha association within one sparse-paving stratum."""
function density_correlation(sample, stratum::Symbol)
    rows = primary_rows(sample)
    stratum == :sparse && (rows = [row for row in rows if row.sparse_paving == 1])
    stratum == :non_sparse && (rows = [row for row in rows if row.sparse_paving == 0])
    x = Float64[row.basis_density for row in rows]
    y = Float64[row.alpha_value for row in rows]
    weights = ones(length(rows))
    pearson = weighted_pearson(x, y, weights)
    spearman = weighted_spearman(x, y, weights)
    fit = weighted_linear_fit(x, y, weights)
    if sample.rank == 4
        pearson_lower, pearson_upper = fisher_interval(pearson, length(rows))
        spearman_lower, spearman_upper = fisher_interval(spearman, length(rows))
        interval_method = "Fisher SRS (Spearman approximate)"
    else
        seed_offset = stratum == :all ? 0 : stratum == :sparse ? 1 : 2
        pearson_lower, pearson_upper, spearman_lower, spearman_upper =
            cluster_correlation_intervals(rows; seed=202608240 + seed_offset)
        interval_method = "400-replicate cluster bootstrap"
    end
    return (
        rank=sample.rank,
        stratum=stratum,
        sample_size=length(rows),
        pearson=pearson,
        pearson_lower95=pearson_lower,
        pearson_upper95=pearson_upper,
        spearman=spearman,
        spearman_lower95=spearman_lower,
        spearman_upper95=spearman_upper,
        slope_per_point=ismissing(fit) ? missing : fit.slope,
        slope_per_tenth=ismissing(fit) ? missing : fit.slope / 10,
        interval_method=interval_method,
    )
end

"""Correlations of alpha1 with every stored scalar invariant."""
function invariant_correlations(sample)
    rows = primary_rows(sample)
    alpha = Float64[row.alpha_value for row in rows]
    weights = ones(length(rows))
    result = NamedTuple[]
    for (field, label) in INVARIANT_SPECS
        values = Float64[getproperty(row, field) for row in rows]
        push!(result, (
            rank=sample.rank,
            invariant=field,
            label=label,
            sample_size=length(rows),
            pearson=weighted_pearson(values, alpha, weights),
            spearman=weighted_spearman(values, alpha, weights),
        ))
    end
    return result
end

"""Mean, quantiles, and extreme alpha values in the primary population."""
function alpha_summary(sample)
    rows = primary_rows(sample)
    values = Float64[row.alpha_value for row in rows]
    if sample.rank == 4
        standard_error = std(values) / sqrt(length(values))
    else
        _, means, _ = cluster_means(rows, row -> Float64(row.alpha_value))
        standard_error = std(means) / sqrt(length(means))
    end
    return (
        rank=sample.rank,
        sample_size=length(values),
        mean=mean(values),
        standard_error=standard_error,
        q05=quantile(values, 0.05),
        q25=quantile(values, 0.25),
        median=median(values),
        q75=quantile(values, 0.75),
        q95=quantile(values, 0.95),
        maximum=maximum(values),
        above_one=count(>(1.0), values),
        above_record=count(row -> row.alpha_num * 81 > row.alpha_den * 100, rows),
    )
end

"""Empirical design-effect diagnostics for equal-size rank-5 clusters."""
function cluster_diagnostics(sample)
    sample.rank == 5 || return NamedTuple[]
    specs = [
        ("alpha1", row -> Float64(row.alpha_value)),
        ("basis density", row -> Float64(row.basis_density)),
        ("paving indicator", row -> Float64(row.paving)),
        ("sparse-paving indicator", row -> Float64(row.sparse_paving)),
    ]
    result = NamedTuple[]
    for (label, value_function) in specs
        values = Float64[value_function(row) for row in sample.rows]
        _, means, sizes = cluster_means(sample.rows, value_function)
        length(unique(sizes)) == 1 || error("cluster diagnostic requires equal cluster sizes")
        cluster_size = only(unique(sizes))
        observation_variance = var(values)
        cluster_variance = var(means)
        design_effect = cluster_size * cluster_variance / observation_variance
        cluster_standard_error = sqrt(cluster_variance / length(means))
        mean_square_between = cluster_size * cluster_variance
        mean_square_within = sum(
            sum((value_function(row) - means[index])^2 for row in sample.rows if Int(row.cluster_draw_id) == identifier)
            for (index, identifier) in enumerate(sort!(unique(Int(row.cluster_draw_id) for row in sample.rows)))
        ) / (length(means) * (cluster_size - 1))
        intraclass_correlation =
            (mean_square_between - mean_square_within) /
            (mean_square_between + (cluster_size - 1) * mean_square_within)
        push!(result, (
            variable=label,
            mean=mean(values),
            cluster_count=length(means),
            cluster_size=cluster_size,
            cluster_standard_error=cluster_standard_error,
            intraclass_correlation=intraclass_correlation,
            design_effect=design_effect,
            effective_sample_size=length(values) / design_effect,
            minimum_cluster_mean=minimum(means),
            maximum_cluster_mean=maximum(means),
        ))
    end
    return result
end

"""Summaries of Theta_1 and Theta_2 and their density associations."""
function theta_summaries(sample)
    rows = primary_rows(sample)
    density = Float64[row.basis_density for row in rows]
    result = NamedTuple[]
    for lambda in (1, 2)
        theta = Float64[theta_value(row, 10, sample.rank, lambda) for row in rows]
        weights = ones(length(rows))
        push!(result, (
            rank=sample.rank,
            lambda=lambda,
            sample_size=length(rows),
            mean=mean(theta),
            median=median(theta),
            q95=quantile(theta, 0.95),
            maximum=maximum(theta),
            pearson_density=weighted_pearson(density, theta, weights),
            spearman_density=weighted_spearman(density, theta, weights),
            spearman_alpha=weighted_spearman(
                Float64[row.alpha_value for row in rows], theta, weights,
            ),
        ))
    end
    return result
end

"""Class-uniform and inferred labeled-matroid point estimates."""
function labeled_comparison(sample)
    rows = sample.rows
    weights = Float64[1 / row.automorphism_group_order for row in rows]
    specs = [
        ("connected proportion", row -> Float64(row.connected)),
        ("paving proportion", row -> Float64(row.paving)),
        ("sparse-paving proportion", row -> Float64(row.sparse_paving)),
        ("mean alpha1", row -> Float64(row.alpha_value)),
        ("mean basis density", row -> Float64(row.basis_density)),
    ]
    return [(
        rank=sample.rank,
        quantity=label,
        class_uniform=mean(value_function(row) for row in rows),
        labeled_weighted=weighted_mean(
            Float64[value_function(row) for row in rows], weights,
        ),
        weight_effective_size=kish_effective_size(weights),
    ) for (label, value_function) in specs]
end

"""Choose and cache only the pair profiles used by the heatmap figure."""
function select_heatmap_cases!(sample)
    rows = primary_rows(sample)
    alpha_case = argmax(row -> row.alpha_value, rows)
    sparse_case = argmax(
        row -> row.alpha_value,
        [row for row in rows if row.sparse_paving == 1],
    )
    excluded_ids = Set((alpha_case.matroid_id, sparse_case.matroid_id))
    theta_case = argmax(
        row -> theta_value(row, 10, sample.rank, 2),
        [row for row in rows if !(row.matroid_id in excluded_ids)],
    )
    selections = [
        ("maximum alpha1", alpha_case),
        ("maximum sparse-paving alpha1", sparse_case),
        ("maximum Theta_2 distinct from prior cases", theta_case),
    ]
    selected = NamedTuple[]
    for (reason, row) in selections
        store_selected_pair_profile!(
            sample.database,
            row.matroid_id;
            reason=reason,
            selection_group="ICARM n=10 r=$(sample.rank)",
        )
        push!(selected, (
            rank=sample.rank,
            reason=reason,
            matroid_id=Int(row.matroid_id),
            global_index=Int64(row.global_index),
            source_id=String(row.source_id),
            alpha_value=Float64(row.alpha_value),
            basis_density=Float64(row.basis_density),
            sparse_paving=Int(row.sparse_paving),
            theta_1=theta_value(row, 10, sample.rank, 1),
            theta_2=theta_value(row, 10, sample.rank, 2),
            automorphism_group_order=Int(row.automorphism_group_order),
            basis_hex=String(row.basis_hex),
            database=sample.database,
        ))
    end
    return selected
end

"""Normalize a histogram to probability mass, including the upper edge."""
function histogram_mass(values, edges)
    counts = zeros(Float64, length(edges) - 1)
    for value in values
        index = searchsortedlast(edges, value)
        index == length(edges) && (index -= 1)
        1 <= index <= length(counts) && (counts[index] += 1)
    end
    return counts ./ length(values)
end

"""Two-dimensional count array on fixed axis edges."""
function histogram2d(x, y, xedges, yedges)
    counts = zeros(Float64, length(xedges) - 1, length(yedges) - 1)
    for (xvalue, yvalue) in zip(x, y)
        xi = searchsortedlast(xedges, xvalue)
        yi = searchsortedlast(yedges, yvalue)
        xi == length(xedges) && (xi -= 1)
        yi == length(yedges) && (yi -= 1)
        1 <= xi <= size(counts, 1) && 1 <= yi <= size(counts, 2) &&
            (counts[xi, yi] += 1)
    end
    return counts
end

"""Save a figure as a compact high-resolution PNG."""
function save_png(figure, directory, stem)
    mkpath(directory)
    path = joinpath(directory, stem * ".png")
    save(path, figure; px_per_unit=1.5)
    return path
end

"""Plot fixed-width probability-mass histograms for the primary samples."""
function make_alpha_histogram(samples, output_directory; sparse_status=nothing, stem="alpha_histogram")
    edges = collect(0.64:0.005:1.0)
    centers = (edges[1:end-1] + edges[2:end]) / 2
    figure = Figure(size=(1240, 480), figure_padding=25)
    colors = [:steelblue, :darkorange]
    for (index, sample) in enumerate(samples)
        rows = primary_rows(sample)
        if !isnothing(sparse_status)
            rows = [row for row in rows if row.sparse_paving == sparse_status]
        end
        values = Float64[row.alpha_value for row in rows]
        probabilities = histogram_mass(values, edges)
        status_label = isnothing(sparse_status) ? "all primary observations" :
                       sparse_status == 1 ? "sparse paving only" : "non-sparse-paving only"
        axis = Axis(
            figure[1, index];
            xlabel="α₁",
            ylabel="probability mass per 0.005 bin",
            title="n = 10, r = $(sample.rank): $status_label\nN = $(length(rows))",
        )
        barplot!(axis, centers, probabilities; width=0.0047, color=(colors[index], 0.8))
        vlines!(axis, [1.0]; color=:black, linestyle=:dash, linewidth=1.5)
        xlims!(axis, first(edges), last(edges))
    end
    return save_png(figure, output_directory, stem)
end

"""Plot a binned density-alpha cloud for one sparse-paving stratum."""
function make_density_alpha_figure(samples, correlations, output_directory; sparse_status=nothing, stem)
    figure = Figure(size=(1260, 500), figure_padding=25)
    last_plot = nothing
    for (index, sample) in enumerate(samples)
        rows = primary_rows(sample)
        stratum = :all
        if !isnothing(sparse_status)
            rows = [row for row in rows if row.sparse_paving == sparse_status]
            stratum = sparse_status == 1 ? :sparse : :non_sparse
        end
        x = Float64[row.basis_density for row in rows]
        y = Float64[row.alpha_value for row in rows]
        xlower, xupper = extrema(x)
        xpadding = max(0.002, 0.02(xupper - xlower))
        xedges = collect(range(xlower - xpadding, xupper + xpadding; length=66))
        yedges = collect(range(0.64, 1.0; length=73))
        counts = histogram2d(x, y, xedges, yedges)
        display_counts = map(value -> value == 0 ? NaN : log10(value), counts)
        xcenters = (xedges[1:end-1] + xedges[2:end]) / 2
        ycenters = (yedges[1:end-1] + yedges[2:end]) / 2
        status_label = isnothing(sparse_status) ? "all primary observations" :
                       sparse_status == 1 ? "sparse paving only" : "non-sparse-paving only"
        axis = Axis(
            figure[1, index];
            xlabel="basis density d_B",
            ylabel="α₁",
            title="n = 10, r = $(sample.rank): $status_label\nN = $(length(rows))",
        )
        last_plot = heatmap!(
            axis,
            xcenters,
            ycenters,
            display_counts;
            colormap=:viridis,
            nan_color=:white,
        )
        fit = weighted_linear_fit(x, y, ones(length(x)))
        if !ismissing(fit)
            fit_x = [minimum(x), maximum(x)]
            lines!(axis, fit_x, fit.intercept .+ fit.slope .* fit_x; color=:firebrick, linewidth=2.5)
        end
        statistic = only([
            row for row in correlations if row.rank == sample.rank && row.stratum == stratum
        ])
        text!(
            axis,
            0.03,
            0.97;
            text=@sprintf("Pearson r = %.3f\nSpearman ρ = %.3f", statistic.pearson, statistic.spearman),
            space=:relative,
            align=(:left, :top),
            color=:black,
        )
        ylims!(axis, first(yedges), last(yedges))
    end
    Colorbar(figure[1, 3], last_plot; label="log₁₀ observations per cell")
    return save_png(figure, output_directory, stem)
end

"""Plot Spearman invariant associations side-by-side by rank."""
function make_invariant_correlation_figure(correlations, output_directory)
    labels = [label for (_, label) in INVARIANT_SPECS]
    x = collect(eachindex(labels))
    figure = Figure(size=(1280, 540), figure_padding=30)
    axis = Axis(
        figure[1, 1];
        ylabel="Spearman ρ with α₁",
        xticks=(x, labels),
        xticklabelrotation=pi / 5,
        title="Invariant associations in connected, positive-α₁ samples",
    )
    for (offset, rank, color) in ((-0.12, 4, :steelblue), (0.12, 5, :darkorange))
        values = [
            only(row.spearman for row in correlations if row.rank == rank && row.invariant == field)
            for (field, _) in INVARIANT_SPECS
        ]
        scatterlines!(
            axis,
            x .+ offset,
            values;
            color=color,
            marker=:circle,
            markersize=13,
            linewidth=2,
            label="r = $rank",
        )
    end
    hlines!(axis, [0.0]; color=:black, linewidth=1)
    axislegend(axis; position=:rb, framevisible=false)
    return save_png(figure, output_directory, "invariant_spearman_correlations")
end

"""Plot density against Theta_1 and Theta_2 with binned observation counts."""
function make_theta_figure(samples, output_directory)
    figure = Figure(size=(1220, 930), figure_padding=25)
    last_plot = nothing
    for (row_index, sample) in enumerate(samples), (column_index, lambda) in enumerate((1, 2))
        rows = primary_rows(sample)
        x = Float64[row.basis_density for row in rows]
        y = Float64[theta_value(row, 10, sample.rank, lambda) for row in rows]
        xedges = collect(range(minimum(x) - 0.002, maximum(x) + 0.002; length=61))
        ypadding = max(0.002, 0.03(maximum(y) - minimum(y)))
        yedges = collect(range(minimum(y) - ypadding, maximum(y) + ypadding; length=61))
        counts = histogram2d(x, y, xedges, yedges)
        display_counts = map(value -> value == 0 ? NaN : log10(value), counts)
        axis = Axis(
            figure[row_index, column_index];
            xlabel="basis density d_B",
            ylabel="Θ_$lambda",
            title="n = 10, r = $(sample.rank), λ = $lambda",
        )
        last_plot = heatmap!(
            axis,
            (xedges[1:end-1] + xedges[2:end]) / 2,
            (yedges[1:end-1] + yedges[2:end]) / 2,
            display_counts;
            colormap=:plasma,
            nan_color=:white,
        )
    end
    Colorbar(figure[1:2, 3], last_plot; label="log₁₀ observations per cell")
    return save_png(figure, output_directory, "theta_vs_basis_density")
end

"""Draw complete log-ratio matrices for exactly the selected examples."""
function make_pair_heatmaps(cases, output_directory)
    figure = Figure(size=(1320, 850), figure_padding=25)
    last_plot = nothing
    for (index, case) in enumerate(cases)
        row_index = cld(index, 3)
        column_index = mod1(index, 3)
        matrix = fill(NaN, 10, 10)
        pairs = materialize(
            case.database,
            "SELECT i, j, log_ratio FROM selected_pairs WHERE matroid_id = ?",
            (case.matroid_id,),
        )
        for pair in pairs
            value = ismissing(pair.log_ratio) ? -2.0 : clamp(Float64(pair.log_ratio), -2.0, 0.25)
            matrix[Int(pair.i) + 1, Int(pair.j) + 1] = value
            matrix[Int(pair.j) + 1, Int(pair.i) + 1] = value
        end
        display_reason = replace(
            case.reason,
            "alpha1" => "α₁",
            "Theta_2" => "Θ₂",
        )
        axis = Axis(
            figure[row_index, column_index];
            title="r = $(case.rank): $display_reason\nindex $(case.global_index), α₁ = $(@sprintf("%.4f", case.alpha_value))",
            xlabel="element",
            ylabel="element",
            xticks=(1:10, string.(0:9)),
            yticks=(1:10, string.(0:9)),
            yreversed=true,
        )
        last_plot = heatmap!(
            axis,
            1:10,
            1:10,
            matrix';
            colorrange=(-2.0, 0.25),
            colormap=:balance,
            nan_color=:lightgray,
        )
    end
    Colorbar(
        figure[1:2, 4],
        last_plot;
        label="log Rᵢⱼ (zero clipped to -2)",
    )
    return save_png(figure, output_directory, "selected_pair_heatmaps")
end

"""CSV quoting for compact, dependency-free table exports."""
function csv_cell(value)
    ismissing(value) && return ""
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

"""Write a homogeneous vector of named tuples as CSV."""
function write_csv(path, rows)
    isempty(rows) && return path
    mkpath(dirname(path))
    columns = collect(propertynames(first(rows)))
    open(path, "w") do output
        println(output, join(string.(columns), ','))
        for row in rows
            println(output, join((csv_cell(getproperty(row, column)) for column in columns), ','))
        end
    end
    return path
end

fmt(value; digits=4) = ismissing(value) ? "—" : @sprintf("%.*f", digits, Float64(value))
fmt_count(value) = replace(string(value), r"(?<=\d)(?=(\d{3})+$)" => ",")
fmt_percent(value; digits=2) = ismissing(value) ? "—" : @sprintf("%.*f%%", digits, 100Float64(value))
fmt_interval(lower, upper; digits=4) =
    ismissing(lower) || ismissing(upper) ? "—" : "[" * fmt(lower; digits=digits) * ", " * fmt(upper; digits=digits) * "]"

"""Return a report-relative path from the Markdown report to an artifact."""
markdown_path(report_path, artifact_path) = replace(relpath(artifact_path, dirname(report_path)), '\\' => '/')

"""Write the self-contained Markdown report with display-safe TeX blocks."""
function write_report(
    report_path,
    samples,
    property_estimates,
    alpha_summaries,
    density_correlations,
    invariant_results,
    diagnostics,
    theta_results,
    labeled_results,
    selected_cases,
    figures,
    table_paths,
)
    mkpath(dirname(report_path))
    r4 = samples[1]
    r5 = samples[2]
    r4_alpha = only(row for row in alpha_summaries if row.rank == 4)
    r5_alpha = only(row for row in alpha_summaries if row.rank == 5)
    r4_density = only(row for row in density_correlations if row.rank == 4 && row.stratum == :all)
    r5_density = only(row for row in density_correlations if row.rank == 5 && row.stratum == :all)
    r4_sparse = only(row for row in density_correlations if row.rank == 4 && row.stratum == :sparse)
    r5_sparse = only(row for row in density_correlations if row.rank == 5 && row.stratum == :sparse)
    r4_non_sparse = only(row for row in density_correlations if row.rank == 4 && row.stratum == :non_sparse)
    r5_non_sparse = only(row for row in density_correlations if row.rank == 5 && row.stratum == :non_sparse)
    strongest = Dict{Int,NamedTuple}()
    for rank in (4, 5)
        candidates = [row for row in invariant_results if row.rank == rank]
        strongest[rank] = candidates[argmax(abs(row.spearman) for row in candidates)]
    end

    open(report_path, "w") do output
        println(output, "# ICARM \$n=10\$ probability samples: \$r=4\$ and \$r=5\$")
        println(output)
        println(output, "Generated ", Dates.format(now(), dateformat"yyyy-mm-dd HH:MM"), ".")
        println(output)
        println(output, "## Executive summary")
        println(output)
        println(
            output,
            "The rank-4 result is an exact simple random sample without replacement of ",
            fmt_count(length(r4.rows)), " stored isomorphism classes from a population of ",
            fmt_count(r4.run.population_size), ". The rank-5 result is a two-stage pilot of ",
            fmt_count(length(r5.rows)), " observations in 128 independent chunk draws, with 100 offsets per draw. ",
            "Every decoded record matched its saved sampling coordinates, and both SQLite files passed integrity checks.",
        )
        println(output)
        println(
            output,
            "No sampled matroid had \$\\alpha_1>1\$, hence none exceeded \$100/81\$. The observed maxima were ",
            fmt(r4_alpha.maximum; digits=6), " at rank 4 and ", fmt(r5_alpha.maximum; digits=6),
            " at rank 5. These are sample findings, not upper bounds for either complete population.",
        )
        println(output)
        println(
            output,
            "Basis density is negatively associated with \$\\alpha_1\$ in both samples. Spearman correlations are ",
            fmt(r4_density.spearman; digits=3), " at rank 4 and ",
            fmt(r5_density.spearman; digits=3), " at rank 5. Within sparse-paving matroids the association is weak ",
            "(", fmt(r4_sparse.spearman; digits=3), " and ", fmt(r5_sparse.spearman; digits=3),
            "), while within non-sparse-paving matroids it remains appreciable (",
            fmt(r4_non_sparse.spearman; digits=3), " and ", fmt(r5_non_sparse.spearman; digits=3), ").",
        )
        println(output)
        println(
            output,
            "The rank-5 chunk ordering matters statistically. Empirical design effects range from about ",
            fmt(minimum(row.design_effect for row in diagnostics); digits=1), " to ",
            fmt(maximum(row.design_effect for row in diagnostics); digits=1),
            " for the four diagnostics below. Thus the pilot is unbiased for population means under its design, ",
            "but its uncertainty is governed much more by 128 chunk draws than by 12,800 nominal rows.",
        )

        println(output)
        println(output, "## Sampling design and target populations")
        println(output)
        println(output, "| Rank | Stored population | Realized sample | Design | Unit used for uncertainty |")
        println(output, "|---:|---:|---:|---|---|")
        println(
            output,
            "| 4 | ", fmt_count(r4.run.population_size), " | ", fmt_count(length(r4.rows)),
            " | simple random sample without replacement | individual isomorphism class |",
        )
        println(
            output,
            "| 5 | ", fmt_count(r5.run.population_size), " | 128 × 100 = ", fmt_count(length(r5.rows)),
            " | PPS chunks with replacement; offsets without replacement within draw | chunk draw |",
        )
        println(output)
        println(
            output,
            "The primary estimand is the distribution over stored isomorphism classes, so every class has equal target weight. ",
            "For rank 5, selecting a chunk proportional to its record count and then a uniform offset makes every recorded ",
            "observation marginally uniform over the archive. Observations from the same chunk draw are dependent.",
        )
        println(output)
        println(
            output,
            "The distribution summaries below retain only connected matroids with \$\\alpha_1>0\$, matching the standing ",
            "report convention. That removes 9 of 100,000 rank-4 observations and none of the rank-5 observations.",
        )

        println(output)
        println(output, "## Sample composition")
        println(output)
        println(output, "| Rank | Property | Count | Estimate | 95% interval | Method |")
        println(output, "|---:|---|---:|---:|---:|---|")
        for rank in (4, 5), (_, label) in PROPERTY_SPECS
            field = only(field for (field, candidate) in PROPERTY_SPECS if candidate == label)
            row = only(item for item in property_estimates if item.rank == rank && item.property == field)
            println(
                output,
                "| ", rank, " | ", label, " | ", fmt_count(row.count), " / ", fmt_count(row.sample_size),
                " | ", fmt_percent(row.estimate; digits=3), " | ",
                ismissing(row.lower95) ? "not estimable from identical PSU outcomes" :
                "[" * fmt_percent(row.lower95; digits=3) * ", " * fmt_percent(row.upper95; digits=3) * "]",
                " | ", row.method, " |",
            )
        end
        println(output)
        println(
            output,
            "For rank 4, the finite-population correction is numerically negligible. For rank 5, an interval is intentionally ",
            "omitted when all 128 cluster means agree; a zero cluster variance does not justify claiming a zero-width population interval.",
        )

        println(output)
        println(output, "## Distribution of \$\\alpha_1\$")
        println(output)
        println(output, "| Rank | Retained \$N\$ | Mean ± design SE | 5% | 25% | Median | 75% | 95% | Maximum | \$N(\\alpha_1>1)\$ | \$N(\\alpha_1>100/81)\$ |")
        println(output, "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for row in alpha_summaries
            println(
                output,
                "| ", row.rank, " | ", fmt_count(row.sample_size), " | ", fmt(row.mean; digits=6),
                " ± ", fmt(row.standard_error; digits=6), " | ", fmt(row.q05), " | ", fmt(row.q25),
                " | ", fmt(row.median), " | ", fmt(row.q75), " | ", fmt(row.q95), " | ",
                fmt(row.maximum; digits=6), " | ", row.above_one, " | ", row.above_record, " |",
            )
        end
        println(output)
        println(output, "![Probability-mass histograms](", markdown_path(report_path, figures[:alpha]), ")")
        println(output)
        println(
            output,
            "Each bar is the observed probability mass in a fixed-width \$0.005\$ bin, not a CDF and not a smoothed density. ",
            "The panels use identical edges from \$0.64\$ to \$1\$. Jaggedness can reflect both bin alignment and the fact that ",
            "\$\\alpha_1\$ is the maximum of finitely many exact rational pair ratios; it should not be read as fine-scale ",
            "population structure without a bin-sensitivity check.",
        )
        println(output)
        println(output, "![Sparse-paving alpha histograms](", markdown_path(report_path, figures[:alpha_sparse]), ")")
        println(output)
        println(
            output,
            "This companion uses the same bin edges but retains only sparse-paving matroids, so differences in shape are not ",
            "caused by changing the histogram grid.",
        )
        println(output)
        println(output, "![Non-sparse-paving alpha histograms](", markdown_path(report_path, figures[:alpha_non_sparse]), ")")
        println(output)
        println(
            output,
            "This second companion retains only non-sparse-paving matroids and again uses the common bin grid. Its smaller ",
            "rank-5 sample should be interpreted with the chunk dependence described below.",
        )

        println(output)
        println(output, "## Basis density versus \$\\alpha_1\$")
        println(output)
        println(output, "| Rank | Stratum | \$N\$ | Pearson \$r\$ (95% interval) | Spearman \$\\rho\$ (95% interval) | \$\\Delta\\alpha_1\$ per +0.1 density | Interval method |")
        println(output, "|---:|---|---:|---:|---:|---:|---|")
        stratum_names = Dict(:all => "all primary", :sparse => "sparse paving", :non_sparse => "non-sparse-paving")
        for rank in (4, 5), stratum in (:all, :sparse, :non_sparse)
            row = only(item for item in density_correlations if item.rank == rank && item.stratum == stratum)
            println(
                output,
                "| ", rank, " | ", stratum_names[stratum], " | ", fmt_count(row.sample_size), " | ",
                fmt(row.pearson; digits=3), " ", fmt_interval(row.pearson_lower95, row.pearson_upper95; digits=3),
                " | ", fmt(row.spearman; digits=3), " ", fmt_interval(row.spearman_lower95, row.spearman_upper95; digits=3),
                " | ", fmt(row.slope_per_tenth; digits=4), " | ", row.interval_method, " |",
            )
        end
        println(output)
        println(output, "![Basis density and alpha](", markdown_path(report_path, figures[:density_all]), ")")
        println(output)
        println(
            output,
            "These are two-dimensional count histograms: color records the base-10 logarithm of the number of observations ",
            "in each density–\$\\alpha_1\$ cell, and the red line is the unweighted least-squares fit. Correlations use every ",
            "retained observation, not the binned cells. The broad negative association partly reflects the mixture of sparse- ",
            "and non-sparse-paving classes, so the next two figures condition on that status.",
        )
        println(output)
        println(output, "![Sparse-paving basis density and alpha](", markdown_path(report_path, figures[:density_sparse]), ")")
        println(output)
        println(
            output,
            "Sparse-paving observations alone show little monotone density–\$\\alpha_1\$ association in these class-uniform ",
            "database samples. This does not reproduce the stronger negative association seen in some finite-field random ",
            "ensembles; the target distributions are different.",
        )
        println(output)
        println(output, "![Non-sparse-paving basis density and alpha](", markdown_path(report_path, figures[:density_non_sparse]), ")")
        println(output)
        println(
            output,
            "For non-sparse-paving matroids, the negative association remains visible within each rank. Thus it is not solely ",
            "a sparse-paving versus non-sparse-paving composition effect.",
        )

        println(output)
        println(output, "## Other invariants")
        println(output)
        println(output, "| Rank | Invariant | Pearson \$r\$ | Spearman \$\\rho\$ |")
        println(output, "|---:|---|---:|---:|")
        for rank in (4, 5)
            for row in sort([item for item in invariant_results if item.rank == rank]; by=item -> -abs(item.spearman))
                println(output, "| ", rank, " | ", row.label, " | ", fmt(row.pearson; digits=3), " | ", fmt(row.spearman; digits=3), " |")
            end
        end
        println(output)
        println(output, "![Invariant correlations](", markdown_path(report_path, figures[:invariants]), ")")
        println(output)
        println(
            output,
            "The plot reports Spearman correlations in the primary samples. At rank 4 the strongest absolute association is ",
            strongest[4].label, " (\$\\rho=", fmt(strongest[4].spearman; digits=3),
            "\$); at rank 5 it is ", strongest[5].label, " (\$\\rho=", fmt(strongest[5].spearman; digits=3),
            "\$). These are marginal associations among interdependent invariants, not causal effects or partial correlations.",
        )

        println(output)
        println(output, "## The density-adjusted excess \$\\Theta_\\lambda\$")
        println(output)
        println(output, "We use the previously adopted uniform-matroid baseline:")
        println(output)
        println(output, "\$\$")
        println(output, "\\Theta_\\lambda(M)=d_B(M)^\\lambda\\,\\frac{\\alpha_1(M)-\\alpha_1(U_{r,n})}{1-\\alpha_1(U_{r,n})}.")
        println(output, "\$\$")
        println(output)
        println(output, "| Rank | \$\\lambda\$ | Mean | Median | 95% quantile | Maximum | Pearson \$r(d_B,\\Theta_\\lambda)\$ | Spearman \$\\rho(d_B,\\Theta_\\lambda)\$ | Spearman \$\\rho(\\alpha_1,\\Theta_\\lambda)\$ |")
        println(output, "|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for row in theta_results
            println(
                output,
                "| ", row.rank, " | ", row.lambda, " | ", fmt(row.mean), " | ", fmt(row.median),
                " | ", fmt(row.q95), " | ", fmt(row.maximum), " | ", fmt(row.pearson_density; digits=3),
                " | ", fmt(row.spearman_density; digits=3), " | ", fmt(row.spearman_alpha; digits=3), " |",
            )
        end
        println(output)
        println(output, "![Theta versus density](", markdown_path(report_path, figures[:theta]), ")")
        println(output)
        println(
            output,
            "Color again shows log observation count per cell. Comparing the two columns measures what changes when the density ",
            "factor is strengthened from \$\\lambda=1\$ to \$\\lambda=2\$; it does not choose an optimal exponent from these data.",
        )

        println(output)
        println(output, "## Rank-5 cluster diagnostics")
        println(output)
        println(output, "| Variable | Cluster SE of mean | ICC | Design effect | Effective \$N\$ | Range of cluster means |")
        println(output, "|---|---:|---:|---:|---:|---:|")
        for row in diagnostics
            println(
                output,
                "| ", row.variable, " | ", fmt(row.cluster_standard_error; digits=6),
                " | ", fmt(row.intraclass_correlation; digits=3), " | ", fmt(row.design_effect; digits=1),
                " | ", fmt(row.effective_sample_size; digits=1), " | [", fmt(row.minimum_cluster_mean),
                ", ", fmt(row.maximum_cluster_mean), "] |",
            )
        end
        println(output)
        println(
            output,
            "The near-unit ICCs for paving indicators show that the enumeration order groups structurally similar classes. ",
            "For future rank-5 work, more chunk draws and fewer offsets per chunk would buy much more precision per analyzed ",
            "matroid, at the cost of downloading more complete chunks. A design such as 512 chunks × 25 offsets is a sensible ",
            "next pilot before scaling further.",
        )

        println(output)
        println(output, "## Isomorphism-class versus labeled weighting")
        println(output)
        println(output, "A class with automorphism group \$\\operatorname{Aut}(M)\$ represents")
        println(output)
        println(output, "\$\$")
        println(output, "\\frac{10!}{|\\operatorname{Aut}(M)|}")
        println(output, "\$\$")
        println(output)
        println(output, "labeled matroids. The factor \$10!\$ cancels in normalized estimates, so labeled point estimates use weight \$1/|\\operatorname{Aut}(M)|\$.")
        println(output)
        println(output, "| Rank | Quantity | Uniform over stored classes | Inferred labeled weighting | Kish effective \$N\$ of weights |")
        println(output, "|---:|---|---:|---:|---:|")
        for row in labeled_results
            println(
                output,
                "| ", row.rank, " | ", row.quantity, " | ", fmt(row.class_uniform; digits=6),
                " | ", fmt(row.labeled_weighted; digits=6), " | ", fmt(row.weight_effective_size; digits=1), " |",
            )
        end
        println(output)
        println(
            output,
            "These labeled-weighted values are secondary ratio estimates from the class-uniform samples. Rank-5 uncertainty ",
            "would still need to respect chunk clustering; the table intentionally gives point estimates only.",
        )

        println(output)
        println(output, "## Selected pair profiles")
        println(output)
        println(output, "| Rank | Selection reason | Global index | \$\\alpha_1\$ | \$d_B\$ | Sparse paving | \$\\Theta_1\$ | \$\\Theta_2\$ | \$|\\operatorname{Aut}|\$ |")
        println(output, "|---:|---|---:|---:|---:|---:|---:|---:|---:|")
        for row in selected_cases
            println(
                output,
                "| ", row.rank, " | ", row.reason, " | ", row.global_index, " | ", fmt(row.alpha_value; digits=6),
                " | ", fmt(row.basis_density; digits=6), " | ", row.sparse_paving == 1 ? "yes" : "no",
                " | ", fmt(row.theta_1), " | ", fmt(row.theta_2), " | ", row.automorphism_group_order, " |",
            )
        end
        println(output)
        println(output, "![Selected pair-ratio heatmaps](", markdown_path(report_path, figures[:pairs]), ")")
        println(output)
        println(
            output,
            "Each panel contains every eligible element pair for one selected matroid. Entry \$(i,j)\$ is \$\\log R_{ij}\$; ",
            "gray diagonal cells are undefined, gray off-diagonal cells would be ineligible, and a zero pair ratio is clipped ",
            "to \$-2\$ for display. Only these selected examples have persistent pair rows; routine observations retain compact ",
            "matroid summaries and exact run-level ratio aggregates.",
        )

        println(output)
        println(output, "## Reproducibility and limitations")
        println(output)
        println(output, "- The target is the ICARM release as represented by the pinned local manifest, not an abstract distribution over all labeled matroids.")
        println(output)
        println(output, "- The database records the manifest, realized-plan, design-file, decoder-source, decoder-binary, and per-downloaded-chunk SHA-256 hashes.")
        println(output)
        println(
            output,
            "- Canonical sampled basis masks: [rank 4 pack](",
            markdown_path(report_path, joinpath(dirname(r4.path), "sample_basis.tsv.zst")),
            ") and [rank 5 pack](",
            markdown_path(report_path, joinpath(dirname(r5.path), "sample_basis.tsv.zst")),
            "). Each adjacent `sample_basis_manifest.toml` records its format and hashes.",
        )
        println(output)
        println(output, "- The current ICARM manifest does not publish authoritative chunk hashes; our chunk hashes identify the bytes actually analyzed but cannot prove immutability of the remote release.")
        println(output)
        println(output, "- Rank-4 SRS estimates are precise for common properties but a sample maximum is not a population maximum, and zero observed violations is not a proof.")
        println(output)
        println(output, "- Rank-5 point estimates are design-unbiased under successful PPS chunk sampling, but the pilot has only 128 independent first-stage draws and strong within-chunk homogeneity.")

        println(output)
        println(output, "## Compact tables")
        println(output)
        for (label, path) in table_paths
            println(output, "- [", label, "](", markdown_path(report_path, path), ")")
        end
    end
    return report_path
end

"""Write a small hash manifest for the authoritative and derived artifacts."""
function write_artifact_manifest(path, samples, report_path, figures, tables)
    artifacts = Dict{String,Any}()
    for sample in samples
        artifacts["rank_$(sample.rank)_database"] = Dict(
            "path" => relpath(sample.path, dirname(path)),
            "bytes" => filesize(sample.path),
            "sha256" => open(bytes2hex ∘ sha256, sample.path),
            "run_id" => String(sample.run.run_id),
        )
        pack_path = joinpath(dirname(sample.path), "sample_basis.tsv.zst")
        pack_manifest_path = joinpath(dirname(sample.path), "sample_basis_manifest.toml")
        for (suffix, artifact_path) in (
            ("sample_pack", pack_path),
            ("sample_pack_manifest", pack_manifest_path),
        )
            isfile(artifact_path) || continue
            artifacts["rank_$(sample.rank)_$(suffix)"] = Dict(
                "path" => relpath(artifact_path, dirname(path)),
                "bytes" => filesize(artifact_path),
                "sha256" => open(bytes2hex ∘ sha256, artifact_path),
            )
        end
    end
    artifacts["report"] = Dict(
        "path" => relpath(report_path, dirname(path)),
        "bytes" => filesize(report_path),
        "sha256" => open(bytes2hex ∘ sha256, report_path),
    )
    for (name, artifact_path) in figures
        artifacts["figure_$(name)"] = Dict(
            "path" => relpath(artifact_path, dirname(path)),
            "bytes" => filesize(artifact_path),
            "sha256" => open(bytes2hex ∘ sha256, artifact_path),
        )
    end
    for (name, artifact_path) in tables
        artifacts["table_$(name)"] = Dict(
            "path" => relpath(artifact_path, dirname(path)),
            "bytes" => filesize(artifact_path),
            "sha256" => open(bytes2hex ∘ sha256, artifact_path),
        )
    end
    manifest = Dict(
        "generated_at" => Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        "schema_version" => CorrelationRatiosDistributions.SCHEMA_VERSION,
        "artifacts" => artifacts,
    )
    mkpath(dirname(path))
    open(path, "w") do output
        TOML.print(output, manifest)
    end
    return path
end

function main(args=ARGS)
    project_root = normpath(joinpath(@__DIR__, ".."))
    r4_path = length(args) >= 1 ? abspath(args[1]) : joinpath(project_root, "data", "icarm_n10", "r4", "results.sqlite")
    r5_path = length(args) >= 2 ? abspath(args[2]) : joinpath(project_root, "data", "icarm_n10", "r5", "results.sqlite")
    report_path = length(args) >= 3 ? abspath(args[3]) : joinpath(project_root, "reports", "icarm_n10_probability_samples.md")
    figure_directory = length(args) >= 4 ? abspath(args[4]) : joinpath(project_root, "figures", "icarm_n10")
    table_directory = length(args) >= 5 ? abspath(args[5]) : joinpath(project_root, "data", "icarm_n10", "report_tables")

    samples = [load_sample(r4_path, 4), load_sample(r5_path, 5)]
    try
        property_estimates = [
            property_estimate(sample, property)
            for sample in samples for (property, _) in PROPERTY_SPECS
        ]
        alpha_summaries = alpha_summary.(samples)
        density_correlations = [
            density_correlation(sample, stratum)
            for sample in samples for stratum in (:all, :sparse, :non_sparse)
        ]
        invariant_results = reduce(vcat, invariant_correlations.(samples))
        diagnostics = cluster_diagnostics(samples[2])
        theta_results = reduce(vcat, theta_summaries.(samples))
        labeled_results = reduce(vcat, labeled_comparison.(samples))
        selected_cases = reduce(vcat, select_heatmap_cases!.(samples))

        figures = Dict{Symbol,String}()
        figures[:alpha] = make_alpha_histogram(samples, figure_directory)
        figures[:alpha_sparse] = make_alpha_histogram(
            samples, figure_directory; sparse_status=1, stem="alpha_histogram_sparse_paving",
        )
        figures[:alpha_non_sparse] = make_alpha_histogram(
            samples, figure_directory; sparse_status=0, stem="alpha_histogram_non_sparse_paving",
        )
        figures[:density_all] = make_density_alpha_figure(
            samples, density_correlations, figure_directory; stem="basis_density_vs_alpha",
        )
        figures[:density_sparse] = make_density_alpha_figure(
            samples, density_correlations, figure_directory;
            sparse_status=1, stem="basis_density_vs_alpha_sparse_paving",
        )
        figures[:density_non_sparse] = make_density_alpha_figure(
            samples, density_correlations, figure_directory;
            sparse_status=0, stem="basis_density_vs_alpha_non_sparse_paving",
        )
        figures[:invariants] = make_invariant_correlation_figure(invariant_results, figure_directory)
        figures[:theta] = make_theta_figure(samples, figure_directory)
        figures[:pairs] = make_pair_heatmaps(selected_cases, figure_directory)

        table_paths = Dict{String,String}()
        table_paths["property estimates"] = write_csv(joinpath(table_directory, "property_estimates.csv"), property_estimates)
        table_paths["alpha summaries"] = write_csv(joinpath(table_directory, "alpha_summaries.csv"), alpha_summaries)
        table_paths["density correlations"] = write_csv(joinpath(table_directory, "density_correlations.csv"), density_correlations)
        table_paths["invariant correlations"] = write_csv(joinpath(table_directory, "invariant_correlations.csv"), invariant_results)
        table_paths["rank-5 cluster diagnostics"] = write_csv(joinpath(table_directory, "rank5_cluster_diagnostics.csv"), diagnostics)
        table_paths["Theta summaries"] = write_csv(joinpath(table_directory, "theta_summaries.csv"), theta_results)
        table_paths["class versus labeled weighting"] = write_csv(joinpath(table_directory, "labeled_weighting.csv"), labeled_results)
        export_cases = [Base.structdiff(row, NamedTuple{(:database,)}) for row in selected_cases]
        table_paths["selected heatmap cases"] = write_csv(joinpath(table_directory, "selected_heatmap_cases.csv"), export_cases)

        write_report(
            report_path,
            samples,
            property_estimates,
            alpha_summaries,
            density_correlations,
            invariant_results,
            diagnostics,
            theta_results,
            labeled_results,
            selected_cases,
            figures,
            table_paths,
        )
        # Selected-profile writes occur in WAL mode. Checkpoint before hashing
        # so the manifest describes the stable main database files that remain
        # after connections close, not a pre-checkpoint snapshot.
        for sample in samples
            collect(DBInterface.execute(sample.database, "PRAGMA wal_checkpoint(TRUNCATE)"))
        end
        manifest_path = write_artifact_manifest(
            joinpath(project_root, "data", "icarm_n10", "report_manifest.toml"),
            samples,
            report_path,
            figures,
            table_paths,
        )
        println("ICARM_REPORT_COMPLETE report=$report_path figures=$(length(figures)) tables=$(length(table_paths)) manifest=$manifest_path")
    finally
        for sample in samples
            SQLite.close(sample.database)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
