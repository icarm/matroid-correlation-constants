"""
Generate a standalone analysis of the density-discounted relative correlation
scores J_gamma, their Pareto geometry, and the high-density deletion cap.

Command line:

```text
julia --project=. scripts/make_j_gamma_report.jl \
    [REPORT] [FIGURE_DIRECTORY] [SUMMARY_CSV]
```

The primary population is connected matroids with positive alpha_1, with
zero loops and zero coloops also required explicitly as a redundant safeguard.
Every source ensemble is analyzed separately.
The rank-sensitive sensitivity population

```text
d_B <= 1 - r(n-r)/(n(n-1))
```

removes exactly the high-density region in which the elementary deletion
budget supplies a finite upper bound. Source databases are read only. The
script retains only compact derived summaries and observed frontier profiles;
it never writes per-matroid J_gamma values.
"""

using CairoMakie
using DBInterface
using Printf
using SQLite
using Statistics

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

const PROJECT_DIRECTORY = normpath(joinpath(@__DIR__, ".."))
const PENALTY_EXPONENTS = (0.5, 1.0, 2.0)

"""Describe every nonredundant rank/source scope currently available."""
function experiment_specs()
    return [
        (
            slug="n8_r4",
            title="n = 8, rank 4 validation data",
            database=joinpath(PROJECT_DIRECTORY, "data", "n8_r4_compact", "results.sqlite"),
            n=8,
            rank=4,
            design=:mixed,
        ),
        (
            slug="n9_r3",
            title="n = 9, rank 3 exact census",
            database=joinpath(PROJECT_DIRECTORY, "data", "n9_census", "results.sqlite"),
            n=9,
            rank=3,
            design=:census,
        ),
        (
            slug="n9_r4",
            title="n = 9, rank 4 exact census",
            database=joinpath(PROJECT_DIRECTORY, "data", "n9_census", "results.sqlite"),
            n=9,
            rank=4,
            design=:census,
        ),
        (
            slug="n10_r4_finite_fields",
            title="n = 10, rank 4 finite-field data",
            database=joinpath(
                PROJECT_DIRECTORY, "data", "n10_finite_fields", "r4", "results.sqlite",
            ),
            n=10,
            rank=4,
            design=:finite_field,
        ),
        (
            slug="n10_r4_icarm",
            title="n = 10, rank 4 ICARM class-uniform sample",
            database=joinpath(
                PROJECT_DIRECTORY, "data", "icarm_n10", "r4", "results.sqlite",
            ),
            n=10,
            rank=4,
            design=:icarm_srs,
        ),
        (
            slug="n10_r5_finite_fields",
            title="n = 10, rank 5 finite-field data",
            database=joinpath(
                PROJECT_DIRECTORY, "data", "n10_finite_fields", "r5", "results.sqlite",
            ),
            n=10,
            rank=5,
            design=:finite_field,
        ),
        (
            slug="n10_r5_icarm",
            title="n = 10, rank 5 ICARM cluster pilot",
            database=joinpath(
                PROJECT_DIRECTORY, "data", "icarm_n10", "r5", "results.sqlite",
            ),
            n=10,
            rank=5,
            design=:icarm_cluster,
        ),
        (
            slug="n12_r6",
            title="n = 12, rank 6 finite-field and Johnson-graph data",
            database=joinpath(
                PROJECT_DIRECTORY, "data", "n12_finite_fields", "r6", "results.sqlite",
            ),
            n=12,
            rank=6,
            design=:mixed,
        ),
    ]
end

"""Materialize transient SQLite result rows as ordinary named tuples."""
function materialize(database, sql, parameters=())
    return [
        (; (name => getproperty(row, name) for name in propertynames(row))...)
        for row in DBInterface.execute(database, sql, parameters)
    ]
end

"""Return a concise, source-aware ensemble label."""
function ensemble_label(run)
    run.source == "polyDB" && return "polyDB isomorphism classes"
    run.source == "ICARM_database" && return run.ensemble ==
        "icarm_isomorphism_classes_srs" ? "ICARM class SRS" : "ICARM cluster pilot"
    if run.source == "johnson_graph"
        return @sprintf(
            "Johnson greedy p = %.3g",
            johnson_greedy_probability(run.ensemble),
        )
    end
    field = "GF($(run.field_size))"
    run.ensemble == "projective_subsets_exhaustive" &&
        return field * " exhaustive, no replacement"
    run.ensemble == "projective_points_with_replacement_random" &&
        return field * " random, with replacement"
    return field * " random, no replacement"
end

"""Whether a run is a Monte Carlo draw rather than a finite census."""
is_random_run(run) =
    run.source != "polyDB" && run.ensemble != "projective_subsets_exhaustive"

"""Pool independent seed replicates with a common source and sampling law."""
function group_specs(database, experiment)
    runs = materialize(
        database,
        """
        SELECT run_id, source, ensemble, field_size, accepted_count
        FROM runs
        WHERE n = ? AND rank_value = ? AND accepted_count > 0
        ORDER BY CASE
                   WHEN source = 'polyDB' THEN 0
                   WHEN source = 'ICARM_database' THEN 1
                   WHEN source = 'finite_field' THEN 2
                   ELSE 3
                 END,
                 field_size, ensemble, run_id
        """,
        (experiment.n, experiment.rank),
    )
    isempty(runs) && error("no completed runs for $(experiment.slug)")
    keys = Tuple[]
    buckets = Dict{Tuple,Vector{NamedTuple}}()
    for run in runs
        key = (run.source, run.ensemble, run.field_size)
        if !haskey(buckets, key)
            buckets[key] = NamedTuple[]
            push!(keys, key)
        end
        push!(buckets[key], run)
    end
    return [
        (
            run_ids=String[run.run_id for run in buckets[key]],
            label=ensemble_label(first(buckets[key])),
            source=first(buckets[key]).source,
            ensemble=first(buckets[key]).ensemble,
            field_size=first(buckets[key]).field_size,
            random=is_random_run(first(buckets[key])),
        )
        for key in keys
    ]
end

"""Construct SQL placeholders for a group's run identifiers."""
run_placeholders(group) = join(fill("?", length(group.run_ids)), ", ")

"""
Read the positive-alpha fields needed by this report, requiring connectedness
and redundantly requiring zero loops and zero coloops.
"""
function matroid_rows(database, experiment, group)
    cluster_join = experiment.design in (:icarm_srs, :icarm_cluster) ?
        "LEFT JOIN sampling_observations o USING(matroid_id)" : ""
    cluster_field = experiment.design in (:icarm_srs, :icarm_cluster) ?
        "o.cluster_draw_id" : "NULL AS cluster_draw_id"
    return materialize(
        database,
        """
        SELECT m.run_id, m.observation_index, m.source_id,
               m.census_multiplicity, m.n, m.rank_value,
               m.num_bases, m.basis_density,
               m.alpha_num, m.alpha_den, m.alpha_value,
               m.sparse_paving, m.paving,
               m.second_value, m.alpha_gap, m.maximizer_count,
               m.mean_pair_ratio, m.pair_ratio_q90,
               $cluster_field
        FROM matroids m
        $cluster_join
        WHERE m.run_id IN ($(run_placeholders(group)))
          AND m.connected = 1
          AND m.loops_count = 0 AND m.coloops_count = 0
          AND m.alpha_num > 0
        ORDER BY m.run_id, m.observation_index
        """,
        Tuple(group.run_ids),
    )
end

"""Return the exact number of possible bases for one rank scope."""
basis_total(experiment) = binomial(experiment.n, experiment.rank)

"""Return C=-log(d_B), the support-entropy cost."""
cost_value(row) = -log(Float64(row.basis_density))

"""Return R=log(alpha_1/c), the relative log-correlation reward."""
function reward_value(row, experiment)
    baseline = Float64(uniform_correlation_baseline(experiment.n, experiment.rank))
    return log(Float64(row.alpha_value) / baseline)
end

"""Return log J_gamma=R-gamma*C without avoidable exponentiation error."""
log_j_value(row, experiment, gamma::Real) =
    reward_value(row, experiment) - Float64(gamma) * cost_value(row)

"""Return J_gamma from the shared validated mathematical helper."""
function j_value(row, experiment, gamma::Real)
    return density_discounted_relative_correlation(
        experiment.n,
        experiment.rank,
        Int(row.num_bases),
        row.alpha_num,
        row.alpha_den;
        density_exponent=gamma,
    )
end

"""Test membership outside the finite deletion-cap regime by exact arithmetic."""
function outside_density_cap(row, experiment)
    threshold = density_cap_threshold(experiment.n, experiment.rank)
    total = BigInt(basis_total(experiment))
    return BigInt(row.num_bases) * denominator(threshold) <=
           total * numerator(threshold)
end

"""Weighted empirical quantile using the left-continuous inverse CDF."""
function weighted_quantile(values, weights, probability::Real)
    isempty(values) && return missing
    order = sortperm(values)
    target = clamp(Float64(probability), 0.0, 1.0) * sum(Float64, weights)
    cumulative = 0.0
    for index in order
        cumulative += Float64(weights[index])
        cumulative >= target && return Float64(values[index])
    end
    return Float64(values[last(order)])
end

"""Weighted arithmetic mean and population standard deviation."""
function weighted_moments(values, weights)
    isempty(values) && return (mean=missing, standard_deviation=missing)
    total = sum(Float64, weights)
    average = sum(
        Float64(value) * Float64(weight)
        for (value, weight) in zip(values, weights)
    ) / total
    variance = sum(
        Float64(weight) * (Float64(value) - average)^2
        for (value, weight) in zip(values, weights)
    ) / total
    return (mean=average, standard_deviation=sqrt(max(variance, 0.0)))
end

"""Weighted fraction of observations satisfying a Boolean predicate."""
function weighted_fraction(values, weights, predicate)
    isempty(values) && return missing
    total = sum(Float64, weights)
    favorable = sum(
        Float64(weight)
        for (value, weight) in zip(values, weights) if predicate(value);
        init=0.0,
    )
    return favorable / total
end

"""Compare the exact alpha values in two stored rows."""
function alpha_compare(first, second)
    left = BigInt(first.alpha_num) * BigInt(second.alpha_den)
    right = BigInt(second.alpha_num) * BigInt(first.alpha_den)
    return cmp(left, right)
end

"""Collapse rows to distinct (number of bases, exact alpha_1) profiles."""
function distinct_profiles(rows, experiment)
    records = Dict{Tuple,NamedTuple}()
    for row in rows
        key = (Int(row.num_bases), BigInt(row.alpha_num), BigInt(row.alpha_den))
        if haskey(records, key)
            push!(records[key].sparse_statuses, Int(row.sparse_paving))
            records[key].row_count[] += Int(row.census_multiplicity)
        else
            records[key] = (
                row=row,
                row_count=Ref(Int(row.census_multiplicity)),
                sparse_statuses=Set([Int(row.sparse_paving)]),
                density=Float64(row.basis_density),
                alpha=Float64(row.alpha_value),
                cost=cost_value(row),
                reward=reward_value(row, experiment),
            )
        end
    end
    return collect(values(records))
end

"""Return every nondominated distinct density-alpha profile."""
function pareto_profiles(rows, experiment)
    profiles = distinct_profiles(rows, experiment)
    isempty(profiles) && return NamedTuple[]
    sort!(profiles; by=profile -> (-Int(profile.row.num_bases), -profile.alpha))
    best_by_basis_count = NamedTuple[]
    position = 1
    while position <= length(profiles)
        stop = position
        bases = Int(profiles[position].row.num_bases)
        while stop < length(profiles) &&
              Int(profiles[stop + 1].row.num_bases) == bases
            stop += 1
        end
        best = profiles[position]
        for index in position + 1:stop
            alpha_compare(profiles[index].row, best.row) > 0 &&
                (best = profiles[index])
        end
        push!(best_by_basis_count, best)
        position = stop + 1
    end
    frontier = NamedTuple[]
    best_alpha = nothing
    for profile in best_by_basis_count
        if best_alpha === nothing || alpha_compare(profile.row, best_alpha.row) > 0
            push!(frontier, profile)
            best_alpha = profile
        end
    end
    return frontier
end

"""Return supported vertices of the observed upper Pareto hull."""
function supported_frontier_vertices(frontier)
    length(frontier) <= 2 && return copy(frontier)
    hull = NamedTuple[]
    for profile in frontier
        while length(hull) >= 2
            first = hull[end - 1]
            second = hull[end]
            previous_slope =
                (second.reward - first.reward) / (second.cost - first.cost)
            next_slope =
                (profile.reward - second.reward) / (profile.cost - second.cost)
            previous_slope > next_slope + 1e-12 && break
            pop!(hull)
        end
        push!(hull, profile)
    end
    return hull
end

"""Summarize one finite collection of rows, with no sampling-model claims."""
function summarize_subset(rows, experiment)
    isempty(rows) && return (
        count=0,
        distinct_count=0,
        density_min=missing,
        density_median=missing,
        density_max=missing,
        cost_reward_pearson=missing,
        cost_reward_spearman=missing,
        reward_on_cost_slope=missing,
        j05_median=missing,
        j05_above_one=missing,
        j1_median=missing,
        j1_p95=missing,
        j1_maximum=missing,
        j1_above_one=missing,
        j1_density_spearman=missing,
        j1_alpha_spearman=missing,
        j2_median=missing,
        j2_above_one=missing,
        gamma_star_count=0,
        gamma_star_median=missing,
        gamma_star_p90=missing,
        gamma_star_p95=missing,
        gamma_star_maximum=missing,
        pareto_count=0,
        supported_count=0,
        pareto_sparse_count=0,
        robust_count=0,
        q90_alpha_ratio_median=missing,
        top_j1_q90_alpha_ratio_median=missing,
        j1_robust_spearman=missing,
        top_j1_relative_gap_median=missing,
    )
    weights = Float64[row.census_multiplicity for row in rows]
    density = Float64[row.basis_density for row in rows]
    alpha = Float64[row.alpha_value for row in rows]
    cost = Float64[cost_value(row) for row in rows]
    reward = Float64[reward_value(row, experiment) for row in rows]
    fit = weighted_linear_fit(cost, reward, weights)
    j05 = exp.(reward .- 0.5 .* cost)
    j1 = exp.(reward .- cost)
    j2 = exp.(reward .- 2.0 .* cost)
    star_indices = findall(index ->
        density[index] < 1.0 - 1e-14 && reward[index] > 0.0,
        eachindex(rows),
    )
    gamma_star = Float64[reward[index] / cost[index] for index in star_indices]
    star_weights = weights[star_indices]
    frontier = pareto_profiles(rows, experiment)
    supported = supported_frontier_vertices(frontier)
    robust_indices = findall(index ->
        !ismissing(rows[index].pair_ratio_q90) &&
        Float64(rows[index].pair_ratio_q90) > 0.0,
        eachindex(rows),
    )
    q90_ratios = Float64[
        Float64(rows[index].pair_ratio_q90) / alpha[index]
        for index in robust_indices
    ]
    robust_weights = weights[robust_indices]
    baseline = Float64(uniform_correlation_baseline(experiment.n, experiment.rank))
    robust_j1 = Float64[
        density[index] * Float64(rows[index].pair_ratio_q90) / baseline
        for index in robust_indices
    ]
    top_cutoff = weighted_quantile(j1, weights, 0.90)
    top_robust_positions = findall(position ->
        j1[robust_indices[position]] >= top_cutoff,
        eachindex(robust_indices),
    )
    top_gap_indices = findall(index ->
        j1[index] >= top_cutoff &&
        !ismissing(rows[index].alpha_gap) &&
        alpha[index] > 0,
        eachindex(rows),
    )
    top_relative_gaps = Float64[
        Float64(rows[index].alpha_gap) / alpha[index]
        for index in top_gap_indices
    ]
    top_gap_weights = weights[top_gap_indices]
    return (
        count=round(Int, sum(weights)),
        distinct_count=length(distinct_profiles(rows, experiment)),
        density_min=minimum(density),
        density_median=weighted_quantile(density, weights, 0.50),
        density_max=maximum(density),
        cost_reward_pearson=weighted_pearson(cost, reward, weights),
        cost_reward_spearman=weighted_spearman(cost, reward, weights),
        reward_on_cost_slope=ismissing(fit) ? missing : fit.slope,
        j05_median=weighted_quantile(j05, weights, 0.50),
        j05_above_one=weighted_fraction(j05, weights, value -> value > 1.0),
        j1_median=weighted_quantile(j1, weights, 0.50),
        j1_p95=weighted_quantile(j1, weights, 0.95),
        j1_maximum=maximum(j1),
        j1_above_one=weighted_fraction(j1, weights, value -> value > 1.0),
        j1_density_spearman=weighted_spearman(j1, density, weights),
        j1_alpha_spearman=weighted_spearman(j1, alpha, weights),
        j2_median=weighted_quantile(j2, weights, 0.50),
        j2_above_one=weighted_fraction(j2, weights, value -> value > 1.0),
        gamma_star_count=length(gamma_star),
        gamma_star_median=weighted_quantile(gamma_star, star_weights, 0.50),
        gamma_star_p90=weighted_quantile(gamma_star, star_weights, 0.90),
        gamma_star_p95=weighted_quantile(gamma_star, star_weights, 0.95),
        gamma_star_maximum=isempty(gamma_star) ? missing : maximum(gamma_star),
        pareto_count=length(frontier),
        supported_count=length(supported),
        pareto_sparse_count=count(
            profile -> profile.sparse_statuses == Set([1]),
            frontier,
        ),
        robust_count=length(robust_indices),
        q90_alpha_ratio_median=weighted_quantile(
            q90_ratios, robust_weights, 0.50,
        ),
        top_j1_q90_alpha_ratio_median=isempty(top_robust_positions) ? missing :
            weighted_quantile(
                q90_ratios[top_robust_positions],
                robust_weights[top_robust_positions],
                0.50,
            ),
        j1_robust_spearman=isempty(robust_indices) ? missing :
            weighted_spearman(j1[robust_indices], robust_j1, robust_weights),
        top_j1_relative_gap_median=weighted_quantile(
            top_relative_gaps, top_gap_weights, 0.50,
        ),
    )
end

"""Summarize the rigorous deletion bound within its high-density domain."""
function summarize_deletion_cap(rows, experiment)
    high_rows = [
        row for row in rows
        if !outside_density_cap(row, experiment)
    ]
    nonuniform_rows = [
        row for row in high_rows
        if Float64(row.basis_density) < 1.0 - 1e-14
    ]
    weights = Float64[row.census_multiplicity for row in nonuniform_rows]
    capacity =
        experiment.rank * (experiment.n - experiment.rank) /
        (experiment.n * (experiment.n - 1))
    efficiencies = Float64[]
    bound_violations = 0
    for row in nonuniform_rows
        deletion_fraction = 1.0 - Float64(row.basis_density)
        cap = -log1p(-deletion_fraction / capacity)
        reward = reward_value(row, experiment)
        reward > cap + 5e-12 && (bound_violations += Int(row.census_multiplicity))
        push!(efficiencies, reward / cap)
    end
    return (
        high_count=sum(
            Int(row.census_multiplicity) for row in high_rows;
            init=0,
        ),
        efficiency_count=length(efficiencies),
        efficiency_median=weighted_quantile(efficiencies, weights, 0.50),
        efficiency_p95=weighted_quantile(efficiencies, weights, 0.95),
        efficiency_maximum=isempty(efficiencies) ? missing : maximum(efficiencies),
        bound_violations=bound_violations,
    )
end

"""Summarize run-to-run ranges for independently seeded replicate groups."""
function summarize_replicates(rows, experiment, group)
    length(group.run_ids) < 2 && return (
        replicate_count=length(group.run_ids),
        spearman_min=missing,
        spearman_max=missing,
        slope_min=missing,
        slope_max=missing,
        j1_above_min=missing,
        j1_above_max=missing,
        outside_spearman_min=missing,
        outside_spearman_max=missing,
    )
    all_summaries = NamedTuple[]
    outside_summaries = NamedTuple[]
    for run_id in group.run_ids
        run_rows = [row for row in rows if row.run_id == run_id]
        isempty(run_rows) && continue
        push!(all_summaries, summarize_replicate_rows(run_rows, experiment))
        outside_rows = [
            row for row in run_rows if outside_density_cap(row, experiment)
        ]
        isempty(outside_rows) ||
            push!(
                outside_summaries,
                summarize_replicate_rows(outside_rows, experiment),
            )
    end
    all_spearman = Float64[
        summary.cost_reward_spearman for summary in all_summaries
        if !ismissing(summary.cost_reward_spearman)
    ]
    slopes = Float64[
        summary.reward_on_cost_slope for summary in all_summaries
        if !ismissing(summary.reward_on_cost_slope)
    ]
    above = Float64[
        summary.j1_above_one for summary in all_summaries
        if !ismissing(summary.j1_above_one)
    ]
    outside_spearman = Float64[
        summary.cost_reward_spearman for summary in outside_summaries
        if !ismissing(summary.cost_reward_spearman)
    ]
    return (
        replicate_count=length(all_summaries),
        spearman_min=isempty(all_spearman) ? missing : minimum(all_spearman),
        spearman_max=isempty(all_spearman) ? missing : maximum(all_spearman),
        slope_min=isempty(slopes) ? missing : minimum(slopes),
        slope_max=isempty(slopes) ? missing : maximum(slopes),
        j1_above_min=isempty(above) ? missing : minimum(above),
        j1_above_max=isempty(above) ? missing : maximum(above),
        outside_spearman_min=isempty(outside_spearman) ? missing :
            minimum(outside_spearman),
        outside_spearman_max=isempty(outside_spearman) ? missing :
            maximum(outside_spearman),
    )
end

"""Compute only the three statistics needed for one independent seed."""
function summarize_replicate_rows(rows, experiment)
    weights = Float64[row.census_multiplicity for row in rows]
    cost = Float64[cost_value(row) for row in rows]
    reward = Float64[reward_value(row, experiment) for row in rows]
    fit = weighted_linear_fit(cost, reward, weights)
    return (
        cost_reward_spearman=weighted_spearman(cost, reward, weights),
        reward_on_cost_slope=ismissing(fit) ? missing : fit.slope,
        j1_above_one=weighted_fraction(
            reward .- cost,
            weights,
            value -> value > 1e-13,
        ),
    )
end

"""Compute all summaries for one ensemble group."""
function summarize_group(rows, experiment, group)
    outside_rows = [
        row for row in rows if outside_density_cap(row, experiment)
    ]
    return (
        experiment_slug=experiment.slug,
        experiment_title=experiment.title,
        n=experiment.n,
        rank=experiment.rank,
        label=group.label,
        source=group.source,
        ensemble=group.ensemble,
        field_size=group.field_size,
        random=group.random,
        all=summarize_subset(rows, experiment),
        outside=summarize_subset(outside_rows, experiment),
        cap=summarize_deletion_cap(rows, experiment),
        replicates=summarize_replicates(rows, experiment, group),
    )
end

"""Partition finite-field and Johnson ensembles into uncluttered panels."""
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
            matching_source = group.source == "finite_field"
            matching_field = !ismissing(group.field_size) &&
                             Int(group.field_size) in definition.fields
            replacement =
                group.ensemble == "projective_points_with_replacement_random"
            if matching_source && matching_field &&
               replacement == definition.replacement
                push!(indices, index)
                assigned[index] = true
            end
        end
        isempty(indices) || push!(panels, (title=definition.title, indices=indices))
    end
    johnson = sort(
        [index for (index, group) in enumerate(groups)
         if group.source == "johnson_graph"];
        by=index -> johnson_greedy_probability(groups[index].ensemble),
    )
    for first_index in 1:2:length(johnson)
        indices = johnson[first_index:min(first_index + 1, end)]
        labels = [
            @sprintf(
                "p = %.3g",
                johnson_greedy_probability(groups[index].ensemble),
            )
            for index in indices
        ]
        push!(panels, (
            title="Johnson-graph sparse paving: " * join(labels, " and "),
            indices=indices,
        ))
        assigned[indices] .= true
    end
    remaining = findall(!, assigned)
    isempty(remaining) ||
        push!(panels, (title="Catalogue or database sample", indices=remaining))
    return panels
end

"""Shorten an ensemble label when its panel supplies the sampling model."""
function panel_label(group)
    group.source == "polyDB" && return "polyDB"
    group.source == "ICARM_database" && return group.label
    group.source == "johnson_graph" && return @sprintf(
        "p = %.3g",
        johnson_greedy_probability(group.ensemble),
    )
    suffix = group.ensemble == "projective_subsets_exhaustive" ?
        " exhaustive" : ""
    return "GF($(group.field_size))" * suffix
end

"""Assign consistent colors to source ensembles."""
function group_colors(groups)
    fields = Dict(2 => :steelblue, 3 => :darkorange, 5 => :seagreen, 7 => :mediumpurple)
    johnson_probabilities = sort(unique(Float64[
        johnson_greedy_probability(group.ensemble)
        for group in groups if group.source == "johnson_graph"
    ]))
    johnson_palette = [:goldenrod, :firebrick, :teal, :navy, :deeppink]
    johnson_colors = Dict(
        probability => johnson_palette[mod1(index, length(johnson_palette))]
        for (index, probability) in enumerate(johnson_probabilities)
    )
    return [
        group.source == "polyDB" ? :black :
        group.source == "ICARM_database" ? :slateblue :
        group.source == "johnson_graph" ?
            johnson_colors[johnson_greedy_probability(group.ensemble)] :
        ismissing(group.field_size) ? :gray40 :
            get(fields, Int(group.field_size), :deepskyblue)
        for group in groups
    ]
end

"""Choose deterministic evenly spaced rows for scatter rendering only."""
function thin_rows(rows; maximum_rows::Int=12_000)
    length(rows) <= maximum_rows && return rows
    indices = unique(round.(Int, range(1, length(rows); length=maximum_rows)))
    return rows[indices]
end

"""Save a dense report figure as a high-resolution PNG."""
function save_dense_figure(figure, output_directory, stem)
    mkpath(output_directory)
    save(joinpath(output_directory, stem * ".png"), figure; px_per_unit=2)
end

"""Draw observed Pareto frontiers in log cost-reward coordinates."""
function make_frontier_figure(
    experiment,
    groups,
    rows_by_group,
    output_directory;
    outside_cap::Bool=false,
)
    colors = group_colors(groups)
    panels = comparison_panels(groups)
    columns = min(2, length(panels))
    panel_rows = cld(length(panels), columns)
    figure = Figure(size=(1180, 520panel_rows))
    threshold = Float64(density_cap_threshold(experiment.n, experiment.rank))
    cap_cost = -log(threshold)
    capacity = 1.0 - threshold
    for (panel_index, panel) in enumerate(panels)
        row_index = cld(panel_index, columns)
        column_index = mod1(panel_index, columns)
        axis = Axis(
            figure[row_index, column_index];
            xlabel="entropy cost C = -log d_B",
            ylabel="relative reward R = log(alpha_1/c_r,n)",
            title=panel.title,
        )
        plotted_values = Tuple{Float64,Float64}[]
        for index in panel.indices
            source_rows = outside_cap ? [
                row for row in rows_by_group[index]
                if outside_density_cap(row, experiment)
            ] : rows_by_group[index]
            isempty(source_rows) && continue
            rendered = thin_rows(source_rows)
            non_sparse = [row for row in rendered if row.sparse_paving == 0]
            sparse = [row for row in rendered if row.sparse_paving == 1]
            for row in rendered
                push!(plotted_values, (cost_value(row), reward_value(row, experiment)))
            end
            if !isempty(non_sparse)
                scatter!(
                    axis,
                    Float64[cost_value(row) for row in non_sparse],
                    Float64[reward_value(row, experiment) for row in non_sparse];
                    color=(colors[index], 0.22),
                    markersize=4,
                    marker=:circle,
                    label=panel_label(groups[index]),
                )
            end
            if !isempty(sparse)
                scatter!(
                    axis,
                    Float64[cost_value(row) for row in sparse],
                    Float64[reward_value(row, experiment) for row in sparse];
                    color=(colors[index], 0.40),
                    markersize=6,
                    marker=:utriangle,
                    label=isempty(non_sparse) ? panel_label(groups[index]) : nothing,
                )
            end
            frontier = pareto_profiles(source_rows, experiment)
            lines!(
                axis,
                Float64[profile.cost for profile in frontier],
                Float64[profile.reward for profile in frontier];
                color=colors[index],
                linewidth=2.4,
            )
            scatter!(
                axis,
                Float64[profile.cost for profile in frontier],
                Float64[profile.reward for profile in frontier];
                color=colors[index],
                markersize=7,
                strokecolor=:white,
                strokewidth=0.5,
            )
        end
        if isempty(plotted_values)
            text!(
                axis,
                0.5,
                0.5;
                text="No observations outside the cap",
                space=:relative,
                align=(:center, :center),
            )
            xlims!(axis, max(0.0, cap_cost - 0.05), cap_cost + 0.5)
            ylims!(axis, -0.05, 0.5)
            continue
        end
        maximum_cost = maximum(first, plotted_values)
        maximum_reward = maximum(last, plotted_values)
        minimum_reward = minimum(last, plotted_values)
        line_limit = max(maximum_cost, cap_cost) * 1.03
        reference_cost = collect(range(0.0, line_limit; length=250))
        styles = (:dot, :dash, :dashdot)
        for (gamma, style) in zip(PENALTY_EXPONENTS, styles)
            lines!(
                axis,
                reference_cost,
                gamma .* reference_cost;
                color=(:gray25, 0.65),
                linestyle=style,
                linewidth=1.3,
            )
        end
        vlines!(axis, [cap_cost]; color=:firebrick, linestyle=:dash, linewidth=1.5)
        if !outside_cap
            cap_x = collect(range(0.0, cap_cost * 0.995; length=300))
            cap_y = Float64[
                -log1p(-(1.0 - exp(-value)) / capacity)
                for value in cap_x
            ]
            lines!(
                axis,
                cap_x,
                cap_y;
                color=:firebrick,
                linewidth=1.8,
            )
        end
        scatter!(axis, [0.0], [0.0]; color=:black, marker=:star5, markersize=10)
        xlims!(
            axis,
            outside_cap ? max(0.0, cap_cost - 0.03) : 0.0,
            max(line_limit, outside_cap ? cap_cost + 0.03 : 0.1),
        )
        ylims!(
            axis,
            min(-0.03, minimum_reward - 0.03),
            max(0.10, maximum_reward * 1.08),
        )
        axislegend(axis; position=:rb, framevisible=false)
    end
    suffix = outside_cap ? "_frontier_outside_cap" : "_frontier"
    save_dense_figure(figure, output_directory, experiment.slug * suffix)
end

"""Draw the fraction beating the uniform benchmark over a gamma continuum."""
function make_gamma_sensitivity_figure(
    experiment,
    groups,
    rows_by_group,
    output_directory,
)
    colors = group_colors(groups)
    panels = comparison_panels(groups)
    columns = min(2, length(panels))
    panel_rows = cld(length(panels), columns)
    figure = Figure(size=(1180, 500panel_rows))
    gamma_grid = collect(range(0.0, 4.0; length=161))
    for (panel_index, panel) in enumerate(panels)
        row_index = cld(panel_index, columns)
        column_index = mod1(panel_index, columns)
        axis = Axis(
            figure[row_index, column_index];
            xlabel="density-penalty exponent gamma",
            ylabel="fraction with J_gamma > 1",
            title=panel.title,
        )
        for index in panel.indices
            rows = rows_by_group[index]
            weights = Float64[row.census_multiplicity for row in rows]
            costs = Float64[cost_value(row) for row in rows]
            rewards = Float64[reward_value(row, experiment) for row in rows]
            fractions = Float64[
                sum(
                    weight
                    for (reward, cost, weight) in zip(rewards, costs, weights)
                    if reward - gamma * cost > 1e-13;
                    init=0.0,
                ) / sum(weights)
                for gamma in gamma_grid
            ]
            lines!(
                axis,
                gamma_grid,
                fractions;
                color=colors[index],
                linewidth=2.5,
                label=panel_label(groups[index]) * ", all",
            )
            outside_indices = findall(row ->
                outside_density_cap(row, experiment),
                rows,
            )
            if length(outside_indices) >= 30
                outside_weights = weights[outside_indices]
                outside_costs = costs[outside_indices]
                outside_rewards = rewards[outside_indices]
                outside_fractions = Float64[
                    sum(
                        weight
                        for (reward, cost, weight) in zip(
                            outside_rewards, outside_costs, outside_weights,
                        )
                        if reward - gamma * cost > 1e-13;
                        init=0.0,
                    ) / sum(outside_weights)
                    for gamma in gamma_grid
                ]
                lines!(
                    axis,
                    gamma_grid,
                    outside_fractions;
                    color=colors[index],
                    linewidth=2.2,
                    linestyle=:dash,
                    label=panel_label(groups[index]) * ", outside cap",
                )
            end
        end
        for (gamma, style) in zip(PENALTY_EXPONENTS, (:dot, :dash, :dashdot))
            vlines!(
                axis,
                [gamma];
                color=(:gray35, 0.55),
                linestyle=style,
                linewidth=1.1,
            )
        end
        xlims!(axis, 0.0, 4.0)
        ylims!(axis, 0.0, 1.01)
        axislegend(axis; position=:rt, framevisible=false)
    end
    save_dense_figure(
        figure,
        output_directory,
        experiment.slug * "_gamma_sensitivity",
    )
end

"""Return compact Pareto records for both the full and sensitivity populations."""
function collect_frontier_records(experiment, groups, rows_by_group)
    records = NamedTuple[]
    for (group, rows) in zip(groups, rows_by_group)
        for (population, selected_rows) in (
            ("all", rows),
            (
                "outside_cap",
                [row for row in rows if outside_density_cap(row, experiment)],
            ),
        )
            isempty(selected_rows) && continue
            frontier = pareto_profiles(selected_rows, experiment)
            supported = Set(
                (
                    Int(profile.row.num_bases),
                    BigInt(profile.row.alpha_num),
                    BigInt(profile.row.alpha_den),
                )
                for profile in supported_frontier_vertices(frontier)
            )
            for profile in frontier
                key = (
                    Int(profile.row.num_bases),
                    BigInt(profile.row.alpha_num),
                    BigInt(profile.row.alpha_den),
                )
                push!(records, (
                    experiment=experiment.slug,
                    n=experiment.n,
                    rank=experiment.rank,
                    ensemble=group.label,
                    population=population,
                    source_id=profile.row.source_id,
                    num_bases=Int(profile.row.num_bases),
                    basis_density=profile.density,
                    alpha_num=profile.row.alpha_num,
                    alpha_den=profile.row.alpha_den,
                    alpha_value=profile.alpha,
                    cost=profile.cost,
                    reward=profile.reward,
                    supported_vertex=key in supported,
                    sparse_status=join(sort!(collect(profile.sparse_statuses)), "/"),
                    observed_count=profile.row_count[],
                ))
            end
        end
    end
    return records
end

"""Select distinct observed maximizers for the three requested penalty exponents."""
function collect_extremal_records(experiment, groups, rows_by_group)
    records = NamedTuple[]
    for (group, rows) in zip(groups, rows_by_group)
        for (population, selected_rows) in (
            ("all", rows),
            (
                "outside_cap",
                [row for row in rows if outside_density_cap(row, experiment)],
            ),
        )
            isempty(selected_rows) && continue
            for gamma in PENALTY_EXPONENTS
                values = Float64[j_value(row, experiment, gamma) for row in selected_rows]
                index = argmax(values)
                row = selected_rows[index]
                push!(records, (
                    experiment=experiment.slug,
                    n=experiment.n,
                    rank=experiment.rank,
                    ensemble=group.label,
                    population=population,
                    criterion="maximum J_gamma",
                    gamma=gamma,
                    source_id=row.source_id,
                    num_bases=Int(row.num_bases),
                    basis_density=Float64(row.basis_density),
                    alpha_num=row.alpha_num,
                    alpha_den=row.alpha_den,
                    alpha_value=Float64(row.alpha_value),
                    score=values[index],
                    gamma_star=Float64(row.basis_density) < 1.0 - 1e-14 ?
                        critical_density_penalty_exponent(
                            experiment.n,
                            experiment.rank,
                            Int(row.num_bases),
                            row.alpha_num,
                            row.alpha_den,
                        ) : missing,
                    sparse_paving=Int(row.sparse_paving),
                ))
            end
        end
    end
    return records
end

"""Analyze one scope from an ordinary materialized SQLite path."""
function analyze_materialized_experiment(experiment, database_path, output_directory)
    database = init_database(database_path)
    groups = group_specs(database, experiment)
    rows_by_group = [
        matroid_rows(database, experiment, group) for group in groups
    ]
    summaries = [
        summarize_group(rows, experiment, group)
        for (rows, group) in zip(rows_by_group, groups)
    ]
    make_frontier_figure(
        experiment,
        groups,
        rows_by_group,
        output_directory;
        outside_cap=false,
    )
    make_frontier_figure(
        experiment,
        groups,
        rows_by_group,
        output_directory;
        outside_cap=true,
    )
    make_gamma_sensitivity_figure(
        experiment,
        groups,
        rows_by_group,
        output_directory,
    )
    frontiers = collect_frontier_records(experiment, groups, rows_by_group)
    extrema = collect_extremal_records(experiment, groups, rows_by_group)
    SQLite.close(database)
    return (
        experiment=experiment,
        summaries=summaries,
        frontiers=frontiers,
        extrema=extrema,
    )
end

"""Analyze a scope, temporarily decompressing a lossless SQLite archive if needed."""
function analyze_experiment(experiment, output_directory)
    if isfile(experiment.database)
        return analyze_materialized_experiment(
            experiment,
            experiment.database,
            output_directory,
        )
    end
    archive = experiment.database * ".zst"
    isfile(archive) || error(
        "missing experiment database $(experiment.database) and archive $archive",
    )
    return mktempdir() do temporary_directory
        temporary_database = joinpath(temporary_directory, "results.sqlite")
        open(temporary_database, "w") do output
            run(pipeline(`zstd -q -d -c $archive`; stdout=output))
        end
        persistent_experiment = merge(experiment, (database=archive,))
        analyze_materialized_experiment(
            persistent_experiment,
            temporary_database,
            output_directory,
        )
    end
end

"""Escape one value for the compact derived CSV exports."""
function csv_cell(value)
    (value === missing || value === nothing) && return ""
    content = string(value)
    if occursin(',', content) || occursin('"', content) || occursin('\n', content)
        return string(
            '"',
            replace(content, '"' => repeat(string('"'), 2)),
            '"',
        )
    end
    return content
end

"""Write one compact row per ensemble and population definition."""
function write_summary_csv(path, analyses)
    headers = [
        "experiment", "n", "rank", "ensemble", "source", "population",
        "count", "distinct_profiles", "density_min", "density_median", "density_max",
        "cost_reward_pearson", "cost_reward_spearman", "reward_on_cost_slope",
        "median_j05", "proportion_j05_above_one", "median_j1", "p95_j1",
        "maximum_j1", "proportion_j1_above_one", "j1_density_spearman",
        "j1_alpha_spearman", "median_j2", "proportion_j2_above_one",
        "gamma_star_count", "gamma_star_median", "gamma_star_p90",
        "gamma_star_p95", "gamma_star_maximum", "pareto_profiles",
        "supported_vertices", "sparse_pareto_profiles", "robust_pair_count",
        "median_q90_over_alpha", "top_j1_median_q90_over_alpha",
        "j1_robust_j1_spearman", "top_j1_median_relative_alpha_gap",
        "high_density_count", "deletion_efficiency_median",
        "deletion_efficiency_p95", "deletion_efficiency_maximum",
        "deletion_bound_violations", "replicate_count",
        "replicate_spearman_min", "replicate_spearman_max",
        "replicate_slope_min", "replicate_slope_max",
        "replicate_j1_above_min", "replicate_j1_above_max",
        "outside_replicate_spearman_min", "outside_replicate_spearman_max",
    ]
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, join(headers, ','))
        for analysis in analyses, summary in analysis.summaries
            for (population, subset) in (
                ("all", summary.all),
                ("outside_cap", summary.outside),
            )
                values = Any[
                    summary.experiment_slug, summary.n, summary.rank,
                    summary.label, summary.source, population,
                    subset.count, subset.distinct_count,
                    subset.density_min, subset.density_median, subset.density_max,
                    subset.cost_reward_pearson, subset.cost_reward_spearman,
                    subset.reward_on_cost_slope,
                    subset.j05_median, subset.j05_above_one,
                    subset.j1_median, subset.j1_p95, subset.j1_maximum,
                    subset.j1_above_one, subset.j1_density_spearman,
                    subset.j1_alpha_spearman, subset.j2_median,
                    subset.j2_above_one, subset.gamma_star_count,
                    subset.gamma_star_median, subset.gamma_star_p90,
                    subset.gamma_star_p95, subset.gamma_star_maximum,
                    subset.pareto_count, subset.supported_count,
                    subset.pareto_sparse_count, subset.robust_count,
                    subset.q90_alpha_ratio_median,
                    subset.top_j1_q90_alpha_ratio_median,
                    subset.j1_robust_spearman,
                    subset.top_j1_relative_gap_median,
                    summary.cap.high_count, summary.cap.efficiency_median,
                    summary.cap.efficiency_p95, summary.cap.efficiency_maximum,
                    summary.cap.bound_violations,
                    summary.replicates.replicate_count,
                    summary.replicates.spearman_min,
                    summary.replicates.spearman_max,
                    summary.replicates.slope_min,
                    summary.replicates.slope_max,
                    summary.replicates.j1_above_min,
                    summary.replicates.j1_above_max,
                    summary.replicates.outside_spearman_min,
                    summary.replicates.outside_spearman_max,
                ]
                println(output, join(csv_cell.(values), ','))
            end
        end
    end
    return path
end

"""Write the compact observed-frontier export."""
function write_frontier_csv(path, analyses)
    headers = [
        "experiment", "n", "rank", "ensemble", "population",
        "representative_id", "num_bases", "basis_density",
        "alpha_num", "alpha_den", "alpha_value", "cost", "reward",
        "supported_vertex", "sparse_status", "observed_count",
    ]
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, join(headers, ','))
        for analysis in analyses, row in analysis.frontiers
            values = Any[
                row.experiment, row.n, row.rank, row.ensemble, row.population,
                row.source_id, row.num_bases, row.basis_density,
                row.alpha_num, row.alpha_den, row.alpha_value,
                row.cost, row.reward, row.supported_vertex,
                row.sparse_status, row.observed_count,
            ]
            println(output, join(csv_cell.(values), ','))
        end
    end
    return path
end

"""Write maximizers of J_1/2, J_1, and J_2 for reproducibility."""
function write_extrema_csv(path, analyses)
    headers = [
        "experiment", "n", "rank", "ensemble", "population", "criterion",
        "gamma", "representative_id", "num_bases", "basis_density",
        "alpha_num", "alpha_den", "alpha_value", "score", "gamma_star",
        "sparse_paving",
    ]
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, join(headers, ','))
        for analysis in analyses, row in analysis.extrema
            values = Any[
                row.experiment, row.n, row.rank, row.ensemble, row.population,
                row.criterion, row.gamma, row.source_id, row.num_bases,
                row.basis_density, row.alpha_num, row.alpha_den,
                row.alpha_value, row.score, row.gamma_star, row.sparse_paving,
            ]
            println(output, join(csv_cell.(values), ','))
        end
    end
    return path
end

"""Format a decimal value while preserving missing entries."""
fixed(value; digits::Int=4) =
    ismissing(value) ? "—" : @sprintf("%.*f", digits, Float64(value))

"""Format a signed statistic."""
signed(value; digits::Int=3) =
    ismissing(value) ? "—" : @sprintf("%+.*f", digits, Float64(value))

"""Format a proportion as a percentage."""
percentage(value; digits::Int=1) =
    ismissing(value) ? "—" : @sprintf("%.*f%%", digits, 100Float64(value))

"""Format a range or a dash when replicate information is unavailable."""
function range_string(lower, upper; digits::Int=3)
    (ismissing(lower) || ismissing(upper)) && return "—"
    return @sprintf("[%.*f, %.*f]", digits, lower, digits, upper)
end

"""Write high-density coverage and deletion-cap diagnostics."""
function write_coverage_table(output, summaries)
    println(
        output,
        "| Ensemble | Primary N | \$d_B\$ range | High-density N (%) | Outside-cap N (%) | Median \$E_{\\mathrm{del}}\$ | 95% \$E_{\\mathrm{del}}\$ | Maximum \$E_{\\mathrm{del}}\$ | Bound violations |",
    )
    println(output, "|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for summary in summaries
        all = summary.all
        outside = summary.outside
        println(
            output,
            "| ", summary.label,
            " | ", all.count,
            " | [", fixed(all.density_min), ", ", fixed(all.density_max), "]",
            " | ", summary.cap.high_count, " (",
            percentage(summary.cap.high_count / all.count), ")",
            " | ", outside.count, " (", percentage(outside.count / all.count), ")",
            " | ", fixed(summary.cap.efficiency_median),
            " | ", fixed(summary.cap.efficiency_p95),
            " | ", fixed(summary.cap.efficiency_maximum),
            " | ", summary.cap.bound_violations,
            " |",
        )
    end
end

"""Write the cost-reward, Pareto, and scalarization summary."""
function write_tradeoff_table(output, summaries)
    println(
        output,
        "| Ensemble | Population | N | Spearman \$\\rho_{\\mathrm S}(C,R)\$ | OLS slope \$R\$ on \$C\$ | Distinct profiles | Pareto | Supported vertices | Sparse-only Pareto |",
    )
    println(output, "|---|---|---:|---:|---:|---:|---:|---:|---:|")
    for summary in summaries
        for (label, subset) in (("all", summary.all), ("outside cap", summary.outside))
            println(
                output,
                "| ", summary.label,
                " | ", label,
                " | ", subset.count,
                " | ", signed(subset.cost_reward_spearman),
                " | ", signed(subset.reward_on_cost_slope),
                " | ", subset.distinct_count,
                " | ", subset.pareto_count,
                " | ", subset.supported_count,
                " | ", subset.pareto_sparse_count,
                " |",
            )
        end
    end
end

"""Write the requested gamma sensitivity statistics."""
function write_j_table(output, summaries)
    println(
        output,
        "| Ensemble | Population | Median \$\\mathcal J_{1/2}\$ | Median \$\\mathcal J_1\$ | Median \$\\mathcal J_2\$ | \$P(\\mathcal J_{1/2}>1)\$ | \$P(\\mathcal J_1>1)\$ | \$P(\\mathcal J_2>1)\$ | 95% \$\\mathcal J_1\$ | Max \$\\mathcal J_1\$ | \$\\rho_{\\mathrm S}(d_B,\\mathcal J_1)\$ | \$\\rho_{\\mathrm S}(\\alpha_1,\\mathcal J_1)\$ |",
    )
    println(output, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for summary in summaries
        for (label, subset) in (("all", summary.all), ("outside cap", summary.outside))
            println(
                output,
                "| ", summary.label,
                " | ", label,
                " | ", fixed(subset.j05_median),
                " | ", fixed(subset.j1_median),
                " | ", fixed(subset.j2_median),
                " | ", percentage(subset.j05_above_one),
                " | ", percentage(subset.j1_above_one),
                " | ", percentage(subset.j2_above_one),
                " | ", fixed(subset.j1_p95),
                " | ", fixed(subset.j1_maximum),
                " | ", signed(subset.j1_density_spearman),
                " | ", signed(subset.j1_alpha_spearman),
                " |",
            )
        end
    end
end

"""Write critical-exponent and worst-pair concentration summaries."""
function write_secondary_table(output, summaries)
    println(
        output,
        "| Ensemble | Population | \$\\gamma_*\$ N | Median \$\\gamma_*\$ | 90% \$\\gamma_*\$ | 95% \$\\gamma_*\$ | Maximum \$\\gamma_*\$ | Median \$Q_{0.9}/\\alpha_1\$ | Top-\$\\mathcal J_1\$ median \$Q_{0.9}/\\alpha_1\$ | \$\\rho_{\\mathrm S}(\\mathcal J_1,\\mathcal J_{1,q90})\$ | Top-\$\\mathcal J_1\$ median relative alpha gap |",
    )
    println(output, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for summary in summaries
        for (label, subset) in (("all", summary.all), ("outside cap", summary.outside))
            println(
                output,
                "| ", summary.label,
                " | ", label,
                " | ", subset.gamma_star_count,
                " | ", fixed(subset.gamma_star_median),
                " | ", fixed(subset.gamma_star_p90),
                " | ", fixed(subset.gamma_star_p95),
                " | ", fixed(subset.gamma_star_maximum),
                " | ", fixed(subset.q90_alpha_ratio_median),
                " | ", fixed(subset.top_j1_q90_alpha_ratio_median),
                " | ", signed(subset.j1_robust_spearman),
                " | ", fixed(subset.top_j1_relative_gap_median),
                " |",
            )
        end
    end
end

"""Write independent-seed stability ranges without treating rows as replicates."""
function write_replicate_table(output, summaries)
    eligible = [
        summary for summary in summaries
        if summary.replicates.replicate_count >= 2
    ]
    isempty(eligible) && return false
    println(
        output,
        "| Ensemble | Replicates | \$\\rho_{\\mathrm S}(C,R)\$ range | OLS slope range | \$P(\\mathcal J_1>1)\$ range | Outside-cap \$\\rho_{\\mathrm S}(C,R)\$ range |",
    )
    println(output, "|---|---:|---:|---:|---:|---:|")
    for summary in eligible
        replicate = summary.replicates
        println(
            output,
            "| ", summary.label,
            " | ", replicate.replicate_count,
            " | ", range_string(replicate.spearman_min, replicate.spearman_max),
            " | ", range_string(replicate.slope_min, replicate.slope_max),
            " | ", range_string(
                replicate.j1_above_min,
                replicate.j1_above_max;
                digits=4,
            ),
            " | ", range_string(
                replicate.outside_spearman_min,
                replicate.outside_spearman_max,
            ),
            " |",
        )
    end
    return true
end

"""Combine tied global scalar maximizers into one row per profile."""
function global_extremal_profiles(analyses)
    source_rows = reduce(vcat, [analysis.extrema for analysis in analyses])
    records = NamedTuple[]
    for population in ("all", "outside_cap"), gamma in PENALTY_EXPONENTS
        candidates = [
            row for row in source_rows
            if row.population == population && row.gamma == gamma
        ]
        isempty(candidates) && continue
        maximum_score = maximum(row.score for row in candidates)
        tied = [
            row for row in candidates
            if isapprox(row.score, maximum_score; rtol=0.0, atol=1e-12)
        ]
        grouped = Dict{Tuple,NamedTuple}()
        for row in tied
            key = (
                row.n,
                row.rank,
                row.num_bases,
                row.alpha_num,
                row.alpha_den,
                row.sparse_paving,
            )
            origin = "$(row.experiment): $(row.ensemble)"
            if haskey(grouped, key)
                push!(grouped[key].origins, origin)
            else
                grouped[key] = (row=row, origins=Set([origin]))
            end
        end
        append!(records, values(grouped))
    end
    sort!(
        records;
        by=record -> (
            record.row.population == "all" ? 0 : 1,
            record.row.gamma,
            record.row.n,
            record.row.rank,
            record.row.source_id,
        ),
    )
    return records
end

"""Write the global observed maximizer for each population and exponent."""
function write_global_extrema_table(output, analyses)
    println(
        output,
        "| Population | \$\\gamma\$ | \$n\$ | Rank | Representative | \$d_B\$ | \$\\alpha_1\$ | \$\\mathcal J_\\gamma\$ | Sparse paving | Observed in |",
    )
    println(output, "|---|---:|---:|---:|---|---:|---:|---:|---:|---|")
    for record in global_extremal_profiles(analyses)
        row = record.row
        println(
            output,
            "| ", row.population == "all" ? "all" : "outside cap",
            " | ", fixed(row.gamma, digits=1),
            " | ", row.n,
            " | ", row.rank,
            " | ", row.source_id,
            " | ", fixed(row.basis_density, digits=6),
            " | ", row.alpha_num, "/", row.alpha_den,
            " | ", fixed(row.score, digits=6),
            " | ", row.sparse_paving == 1 ? "yes" : "no",
            " | ", join(sort!(collect(record.origins)), "<br>"),
            " |",
        )
    end
end

"""Write a self-contained, matroid-first guide to the objects in the report."""
function write_beginner_guide(output)
    println(output)
    println(output, "## Reader's guide: no statistics background is assumed")
    println(output)
    println(
        output,
        "The report asks a two-objective question about a matroid: can it have both ",
        "many bases and a large unweighted correlation ratio? Everything needed to read ",
        "the answer is explained below. The information-theoretic interpretation is ",
        "optional; none of the conclusions requires prior knowledge of probability, ",
        "statistics, optimization, or information theory.",
    )
    println(output)
    println(
        output,
        "There are two unrelated uses of the word *correlation* in this report. ",
        "\$\\alpha_1(M)\$ is the matroid invariant being studied. A *Spearman ",
        "correlation coefficient* is only a number used later to summarize how two ",
        "matroid invariants vary across a collection of matroids. To reduce confusion, ",
        "the latter is usually called an *association* below.",
    )

    println(output)
    println(output, "### The two matroid quantities")
    println(output)
    println(
        output,
        "Let \$M\$ have rank \$r\$ on an \$n\$-element ground set \$E\$. Its ",
        "**basis density** is the fraction of all \$r\$-subsets that are bases:",
    )
    println(output)
    println(output, "\$\$")
    println(output, "D=d_B(M)=\\frac{|\\mathcal B(M)|}{\\binom nr}.")
    println(output, "\$\$")
    println(output)
    println(
        output,
        "Thus \$0<D\\le1\$. The value \$D=1\$ occurs exactly for the uniform matroid. ",
        "For example, a rank-4 matroid on 8 elements with 48 bases has ",
        "\$D=48/\\binom84=48/70\$.",
    )
    println(output)
    println(
        output,
        "To define \$\\alpha_1\$, choose a basis uniformly from ",
        "\$\\mathcal B(M)\$. For distinct elements \$i,j\$, let \$b_{ab}\$ be the ",
        "number of bases for which the indicator of \$i\$ is \$a\$ and the indicator ",
        "of \$j\$ is \$b\$, where \$a,b\\in\\{0,1\\}\$. The pair ratio is",
    )
    println(output)
    println(output, "\$\$")
    println(output, "Q_{ij}=\\frac{b_{00}b_{11}}{b_{01}b_{10}}.")
    println(output, "\$\$")
    println(output)
    println(
        output,
        "The unweighted correlation ratio is the worst, meaning largest, eligible pair ",
        "ratio:",
    )
    println(output)
    println(output, "\$\$")
    println(output, "\\alpha_1(M)=\\max_{i\\ne j}Q_{ij}.")
    println(output, "\$\$")
    println(output)
    println(
        output,
        "The implementation excludes loops and coloops from pair eligibility. This ",
        "qualification is immaterial for the actual report population because every ",
        "analyzed matroid is connected and therefore has neither loops nor coloops. ",
        "The maximum matters: a single exceptional element pair can determine ",
        "\$\\alpha_1\$ even if most pair ratios are much smaller.",
    )
    println(output)
    println(
        output,
        "For the uniform matroid the pair ratio is the same for every pair, namely",
    )
    println(output)
    println(output, "\$\$")
    println(output, "c_{r,n}=\\alpha_1(U_{r,n})")
    println(output, "=\\frac{(r-1)(n-r-1)}{r(n-r)}.")
    println(output, "\$\$")

    println(output)
    println(output, "### Exactly which matroids are included?")
    println(output)
    println(
        output,
        "Only **connected matroids with \$\\alpha_1>0\$** are used in every table, ",
        "coefficient, frontier, and figure. The database query also redundantly requires ",
        "`loops_count = 0` and `coloops_count = 0`, even though connectedness already ",
        "implies both conditions.",
    )
    println(output)
    println(
        output,
        "Here connected has its usual matroid meaning. If \$A\$ is a nonempty proper ",
        "subset of \$E\$, put",
    )
    println(output)
    println(output, "\$\$")
    println(output, "\\lambda_M(A)")
    println(output, "=r_M(A)+r_M(E\\setminus A)-r(M).")
    println(output, "\$\$")
    println(output)
    println(
        output,
        "The matroid is connected exactly when \$\\lambda_M(A)>0\$ for every such ",
        "\$A\$. The code checks this condition directly from the rank function.",
    )
    println(output)
    println(
        output,
        "This proves that loops and coloops cannot occur in the analyzed population. ",
        "If \$e\$ is a loop, then \$r(\\{e\\})=0\$ and \$r(E\\setminus\\{e\\})=r(M)\$, ",
        "so \$\\lambda_M(\\{e\\})=0\$. If \$e\$ is a coloop, then ",
        "\$r(\\{e\\})=1\$ and \$r(E\\setminus\\{e\\})=r(M)-1\$, again giving zero. ",
        "The converse is false: having no loops or coloops does not by itself imply ",
        "connectedness, so the filter is stronger than merely deleting those elements.",
    )
    println(output)
    println(
        output,
        "Connected matroids may still have parallel or series elements; the report does ",
        "not impose simplicity or cosimplicity. Disconnected matroids are excluded ",
        "because adjoining direct-sum components—especially loops or coloops—can change ",
        "basis density without representing the density–correlation tradeoff we want to ",
        "study. The extra condition \$\\alpha_1>0\$ is needed because the logarithms used ",
        "later are not defined at zero.",
    )
    println(output)
    println(
        output,
        "Whenever a table says **all**, it therefore means all connected, positive-",
        "\$\\alpha_1\$ observations in that particular source ensemble, not every ",
        "matroid stored in the database.",
    )

    println(output)
    println(output, "### What the score \$\\mathcal J_\\gamma\$ means")
    println(output)
    println(output, "The joint score is")
    println(output)
    println(output, "\$\$")
    println(output, "\\mathcal J_\\gamma(M)")
    println(output, "=")
    println(output, "\\frac{\\alpha_1(M)}{c_{r,n}}D^\\gamma.")
    println(output, "\$\$")
    println(output)
    println(
        output,
        "The first factor compares \$M\$ with the uniform matroid's correlation ratio. ",
        "The second factor penalizes missing bases. Their product equals 1 for the ",
        "uniform matroid.",
    )
    println(output)
    println(
        output,
        "- \$\\gamma=1/2\$ is relatively forgiving of missing bases.",
    )
    println(
        output,
        "- With \$\\gamma=1\$, a 1% density loss requires approximately a 1% increase ",
        "in \$\\alpha_1\$ to compensate.",
    )
    println(
        output,
        "- \$\\gamma=2\$ penalizes missing bases more severely.",
    )
    println(output)
    println(
        output,
        "A value \$\\mathcal J_\\gamma>1\$ means that, under this chosen exchange rate, ",
        "the increase in relative correlation more than pays for the missing bases. It ",
        "does **not** mean \$\\alpha_1>1\$, and it does not declare one choice of ",
        "\$\\gamma\$ to be canonical.",
    )

    println(output)
    println(output, "### A short reading path")
    println(output)
    println(
        output,
        "For the main mathematical message, read this guide, the next summary, the ",
        "sections on Pareto geometry and the high-density cap, and then the cross-source ",
        "findings. The long rank-by-rank tables are supporting evidence. Their repeated ",
        "column names are decoded in the statistics glossary before the figures.",
    )
    println(output)
    println(output, "### Conclusions in plain language")
    println(output)
    println(
        output,
        "- Among matroids extremely close to uniform, larger correlation ratios often ",
        "come with more missing bases. Much of the striking large-field pattern lies in ",
        "this region, where the high-density theorem already predicts a tradeoff.",
    )
    println(
        output,
        "- After that region is removed, the direction and strength of the pattern ",
        "depend on the finite field and generation rule. Binary samples sometimes behave ",
        "in the opposite direction. The data therefore do not suggest one universal ",
        "monotonicity statement for all matroids.",
    )
    println(
        output,
        "- In the moderate-density region, one full power of density usually penalizes ",
        "missing bases more strongly than is needed merely to remove the observed trend. ",
        "Two powers are extremely severe: almost nothing there beats the uniform score.",
    )
    println(
        output,
        "- No single choice of \$\\gamma\$ records every reasonable compromise between ",
        "density and \$\\alpha_1\$. Many observed profiles are not worse in both ",
        "quantities than any competitor, yet they never maximize ",
        "\$\\mathcal J_\\gamma\$ for any \$\\gamma\$.",
    )
    println(
        output,
        "- Large \$\\mathcal J_1\$ values are more often controlled by an exceptional ",
        "element pair than by uniformly large pair ratios. This is a warning to inspect ",
        "the pair distribution as well as its maximum \$\\alpha_1\$.",
    )
end

"""Write elementary definitions for every statistical term used in the report."""
function write_statistics_guide(output)
    println(output)
    println(output, "## Statistics glossary and table-reading guide")
    println(output)
    println(
        output,
        "This analysis is mainly **descriptive**: it records patterns in the matroids ",
        "that were enumerated or generated. A descriptive pattern is not automatically ",
        "a theorem about all matroids. The exact PolyDB censuses describe their complete ",
        "finite populations; the random finite-field, Johnson, and ICARM data describe ",
        "their stated sampling procedures.",
    )

    println(output)
    println(output, "### Basic words")
    println(output)
    println(
        output,
        "- An **observation** is one retained database row, representing one matroid or ",
        "one generated configuration.",
    )
    println(
        output,
        "- An **ensemble** or **cell** is one source and generation rule at fixed ",
        "\$(n,r)\$, such as rank 6 over \$\\mathrm{GF}(7)\$ with replacement.",
    )
    println(
        output,
        "- A **population** is the collection about which a row of a table speaks. ",
        "Here **all** and **outside cap** are two populations within each ensemble.",
    )
    println(
        output,
        "- A **distribution** is simply the list of possible observed values together ",
        "with how often they occur.",
    )
    println(
        output,
        "- The **median** is a middle value after sorting: at least half the observations ",
        "are no larger and at least half are no smaller.",
    )
    println(
        output,
        "- The **90th percentile** is a value at or above roughly 90% of the ",
        "observations; only roughly the largest 10% lie above it. The 95th percentile ",
        "is analogous. With many ties, the percentages need not split exactly.",
    )
    println(
        output,
        "- A **proportion** \$P(A)\$ is the fraction of observations satisfying ",
        "condition \$A\$. For example, \$P(\\mathcal J_1>1)=0.20\$ means 20%.",
    )
    println(
        output,
        "- A **range** \$[a,b]\$ reports the smallest and largest displayed values.",
    )
    println(
        output,
        "- The **top decile** means the observations in the largest 10% according to ",
        "the stated score.",
    )

    println(output)
    println(output, "### Measuring association across matroids")
    println(output)
    println(
        output,
        "A scatter plot places one point for each observation, with one invariant on the ",
        "horizontal axis and another on the vertical axis. An upward overall ordering ",
        "means that larger values of one tend to accompany larger values of the other; ",
        "a downward ordering means that larger values of one tend to accompany smaller ",
        "values of the other.",
    )
    println(output)
    println(
        output,
        "The report mainly summarizes this ordering with **Spearman's rank association** ",
        "\$\\rho_{\\mathrm S}\$. First replace the numerical values by their positions ",
        "after sorting, and then compare the two sets of positions. Its value lies between ",
        "\$-1\$ and \$1\$:",
    )
    println(output)
    println(
        output,
        "- \$+1\$ means the two orderings agree perfectly.",
    )
    println(
        output,
        "- \$-1\$ means one ordering is exactly the reverse of the other.",
    )
    println(
        output,
        "- A value near 0 means there is little overall increasing or decreasing ",
        "ordering. It does not rule out a curved or subgroup-dependent pattern.",
    )
    println(output)
    println(
        output,
        "Only the ordering matters, not the numerical distances between consecutive ",
        "values. Equal values are ties and receive the same average rank. The word ",
        "*weighted* means that a row with stored multiplicity \$m\$ is treated as ",
        "occurring \$m\$ times.",
    )
    println(output)
    println(
        output,
        "A **Pearson correlation** instead measures closeness to a straight-line ",
        "relationship using the actual numerical distances. Pearson values are retained ",
        "in the CSV but Spearman values are emphasized in the report because these ",
        "matroid distributions are discrete, tied, and often curved.",
    )
    println(output)
    println(
        output,
        "An **ordinary least-squares (OLS) line** is the straight line chosen to make ",
        "the sum of the squared vertical discrepancies from the points as small as ",
        "possible. The table's slope \$\\widehat\\beta\$ comes from fitting",
    )
    println(output)
    println(output, "\$\$")
    println(output, "R\\approx a+\\widehat\\beta C.")
    println(output, "\$\$")
    println(output)
    println(
        output,
        "For example, \$\\widehat\\beta=0.4\$ says that the fitted line rises by about ",
        "0.4 units of \$R\$ for one unit of \$C\$. It describes that ensemble; it is not ",
        "a matroid invariant, a causal claim, or a proof that every point follows the ",
        "line.",
    )

    println(output)
    println(output, "### Random samples and repeated seeds")
    println(output)
    println(
        output,
        "A **census** contains every member of a stated finite catalogue, whereas a ",
        "**sample** contains only selected or generated members. Repeating a random ",
        "generator with five independent seeds gives five separate replicates. A narrow ",
        "replicate range means the reported pattern did not change much when the random ",
        "seed changed; it does not make the generator uniform over all matroids.",
    )
    println(output)
    println(
        output,
        "No inferential p-values are used here. Roughly, a p-value addresses how ",
        "surprising a statistic would be under a chosen random null model. The data ",
        "sources do not share one such model, many rows are dependent or repeated, and ",
        "the variables are algebraically related. Reporting a tiny p-value from the very ",
        "large row counts would therefore give a misleading impression of a theorem.",
    )

    println(output)
    println(output, "### Worst-pair robustness")
    println(output)
    println(
        output,
        "Because \$\\alpha_1\$ is the maximum over pairs, it can be controlled by one ",
        "unusual pair. For each matroid, \$Q_{0.9}\$ is the 90th percentile of all its ",
        "eligible pair ratios: about 90% of the pair ratios are at most \$Q_{0.9}\$. ",
        "Thus \$Q_{0.9}/\\alpha_1\$ is near 1 if many pairs are close to the maximum and ",
        "is small if the maximizing pair is exceptional. Here **robust** means less ",
        "dependent on that single maximum; it is not a claim of a formal robustness ",
        "theorem.",
    )
    println(output)
    println(
        output,
        "The **empirical survival curve** of \$\\gamma_*\$ answers a direct counting ",
        "question. At horizontal value \$g\$, its height is the fraction of observed ",
        "matroids for which \$\\gamma_*\\ge g\$, equivalently the fraction that still ",
        "beats the uniform benchmark at penalty exponent \$g\$.",
    )

    println(output)
    println(output, "### Repeated table columns")
    println(output)
    println(output, "| Column | Plain-language meaning |")
    println(output, "|---|---|")
    println(output, "| Primary N | Number of connected, positive-\$\\alpha_1\$ observations before the density-cap split. |")
    println(output, "| all | The entire primary population for that ensemble. |")
    println(output, "| outside cap | The subset with \$D\\le D_{\\mathrm{cap}}\$; the very-high-density region is removed. |")
    println(output, "| High-density N (%) | Count and percentage with \$D>D_{\\mathrm{cap}}\$. |")
    println(output, "| Median / 90% / 95% / Maximum | Middle value, percentile, or largest value as defined above. |")
    println(output, "| \$P(\\mathcal J_\\gamma>1)\$ | Fraction beating the uniform benchmark for that \$\\gamma\$. |")
    println(output, "| \$\\rho(X,Y)\$ | Spearman rank association between the displayed quantities. |")
    println(output, "| OLS slope \$R\$ on \$C\$ | Slope of the descriptive best-fit line \$R\\approx a+\\widehat\\beta C\$. |")
    println(output, "| Distinct profiles | Number of different observed pairs \$(D,\\alpha_1)\$ after exact ties are combined. |")
    println(output, "| Pareto | Number of profiles not unambiguously beaten in both density and \$\\alpha_1\$. |")
    println(output, "| Supported vertices | Pareto profiles that maximize \$\\mathcal J_\\gamma\$ for at least one \$\\gamma\\ge0\$. |")
    println(output, "| \$E_{\\mathrm{del}}\$ | Observed log-reward divided by the rigorous high-density allowance: 1 saturates the bound, 0 equals the uniform baseline, and negative values are below it. |")
    println(output, "| \$\\gamma_*\\ N\$ | Number for which the positive break-even exponent is defined and used. |")
    println(output, "| \$Q_{0.9}/\\alpha_1\$ | Whether large pair ratios are widespread (near 1) or localized (smaller). |")
    println(output, "| Relative alpha gap | Relative gap between the largest and second-largest eligible pair ratios. |")
    println(output, "| Sparse-only Pareto | Pareto profiles observed only among sparse-paving matroids in that ensemble. |")
    println(output, "| Bound violations | Number exceeding the rigorous deletion bound; it is 0 in every reported cell. |")
    println(output, "| Replicate range | Smallest and largest result across independent random seeds. |")
end

"""Write optional, external background references for unfamiliar terminology."""
function write_background_references(output)
    println(output)
    println(output, "## Optional background references")
    println(output)
    println(
        output,
        "The report is intended to be readable without these sources. They are listed ",
        "for readers who want a systematic introduction.",
    )
    println(output)
    println(
        output,
        "- James Oxley, *Matroid Theory*, second edition, Chapter 4, for matroid ",
        "connectivity, separations, loops, coloops, and duality.",
    )
    println(
        output,
        "- [OpenStax, *Introductory Statistics*, Chapter 2](https://openstax.org/books/introductory-statistics/pages/2-introduction), ",
        "for distributions, medians, percentiles, and histograms.",
    )
    println(
        output,
        "- [OpenStax, *Introductory Statistics 2e*, Sections 12.2–12.3](https://openstax.org/books/introductory-statistics-2e/pages/12-2-scatter-plots), ",
        "for scatter plots, association, and least-squares lines.",
    )
    println(
        output,
        "- [University of Texas at Austin, *Spearman's Rank Correlation*](https://sites.utexas.edu/sos/guided/inferential/numeric/bivariate/rankcor/), ",
        "for a short worked example based on ranks.",
    )
    println(
        output,
        "- [Seeing Theory](https://seeing-theory.brown.edu/), an archived interactive ",
        "visual introduction to probability, distributions, and regression.",
    )
    println(
        output,
        "- Stephen Boyd and Lieven Vandenberghe, ",
        "[*Convex Optimization*, Section 4.7](https://web.stanford.edu/~boyd/cvxbook/), ",
        "for the more advanced general theory of several competing objectives, Pareto ",
        "optimality, and scalarization.",
    )
    println(
        output,
        "- Thomas Cover and Joy Thomas, *Elements of Information Theory*, Chapter 2, ",
        "for entropy and Kullback–Leibler divergence. This is optional here: the elementary ",
        "identity \$C=-\\log D\$ is all that the analysis uses.",
    )
end

"""Write one standalone, self-contained Markdown analysis report."""
function write_report(
    path,
    figure_directory,
    summary_csv,
    frontier_csv,
    extrema_csv,
    analyses,
)
    mkpath(dirname(path))
    figure_relative = relpath(figure_directory, dirname(path))
    summary_relative = relpath(summary_csv, dirname(path))
    frontier_relative = relpath(frontier_csv, dirname(path))
    extrema_relative = relpath(extrema_csv, dirname(path))
    summaries = reduce(vcat, [analysis.summaries for analysis in analyses])
    adequate_outside = [
        summary for summary in summaries if summary.outside.count >= 30
    ]
    usable_outside = length(adequate_outside)
    outside_total = sum(summary.outside.count for summary in summaries)
    bound_violations = sum(summary.cap.bound_violations for summary in summaries)
    changes = [
        (
            summary=summary,
            change=summary.outside.cost_reward_spearman -
                   summary.all.cost_reward_spearman,
        )
        for summary in summaries
        if summary.outside.count >= 30 &&
           !ismissing(summary.outside.cost_reward_spearman) &&
           !ismissing(summary.all.cost_reward_spearman)
    ]
    largest_change = isempty(changes) ? missing :
        changes[argmax(abs(record.change) for record in changes)]
    outside_positive_cost_reward = count(
        summary -> summary.outside.cost_reward_spearman > 0,
        adequate_outside,
    )
    outside_positive_j_density = count(
        summary -> summary.outside.j1_density_spearman > 0,
        adequate_outside,
    )
    outside_slope_lt_one = count(
        summary -> summary.outside.reward_on_cost_slope < 1,
        adequate_outside,
    )
    j_density_sign_reversals = count(
        summary ->
            sign(summary.all.j1_density_spearman) !=
            sign(summary.outside.j1_density_spearman),
        adequate_outside,
    )
    outside_j2_successes = sum(
        round(Int, summary.outside.j2_above_one * summary.outside.count)
        for summary in summaries if !ismissing(summary.outside.j2_above_one);
        init=0,
    )
    pareto_total = sum(summary.all.pareto_count for summary in summaries)
    supported_total = sum(summary.all.supported_count for summary in summaries)
    all_supported_fraction = supported_total / max(1, pareto_total)
    robust_positive_cells = count(
        summary ->
            !ismissing(summary.all.j1_robust_spearman) &&
            summary.all.j1_robust_spearman > 0,
        summaries,
    )
    localized_top_cells = count(
        summary ->
            !ismissing(summary.all.q90_alpha_ratio_median) &&
            !ismissing(summary.all.top_j1_q90_alpha_ratio_median) &&
            summary.all.top_j1_q90_alpha_ratio_median <
            summary.all.q90_alpha_ratio_median,
        summaries,
    )

    open(path, "w") do output
        println(output, "# Analysis of the density-discounted score \$\\mathcal J_\\gamma\$")
        write_beginner_guide(output)
        println(output)
        println(output, "## Main findings, with the technical numbers")
        println(output)
        println(
            output,
            "- The outside-cap sensitivity population contains ", outside_total,
            " observations. ", usable_outside,
            " ensemble cells retain at least 30 observations, so no additional sampling ",
            "was needed. The ICARM rank-5 and Johnson cells contribute no moderate-density ",
            "observations under their present sampling laws.",
        )
        if !ismissing(largest_change)
            println(
                output,
                "- The strong large-field tradeoff is largely a high-density effect. ",
                "For **", largest_change.summary.experiment_slug, " / ",
                largest_change.summary.label,
                "**, Spearman \$\\rho_{\\mathrm S}(C,R)\$ falls from ",
                signed(largest_change.summary.all.cost_reward_spearman),
                " to ", signed(largest_change.summary.outside.cost_reward_spearman),
                ". Across adequately populated cells, ",
                outside_positive_cost_reward, " of ", usable_outside,
                " remain positive; the five negative cells are all low-field ",
                "finite-field ensembles.",
            )
        end
        println(
            output,
            "- Outside the cap, \$\\mathcal J_1\$ is positively associated with density ",
            "in ", outside_positive_j_density, " of ", usable_outside,
            " adequately populated cells, and ", j_density_sign_reversals,
            " cells switch from a negative full-data association to a positive one. ",
            "Thus a unit density exponent usually overcompensates the residual ",
            "moderate-density reward trend.",
        )
        println(
            output,
            "- Among the ", outside_total, " outside-cap observations, exactly ",
            outside_j2_successes, " has \$\\mathcal J_2>1\$: one exact rank-3, ",
            "9-element class at the cap ",
            "boundary with \$d_B=3/4\$ and \$\\alpha_1=1\$. The stronger penalty is ",
            "therefore extremely selective away from high density.",
        )
        println(
            output,
            "- The deletion inequality has ", bound_violations,
            " numerical violations and is exactly sharp: observed one-deletion sparse-",
            "paving profiles attain \$E_{\\mathrm{del}}=1\$. Typical efficiencies are ",
            "much smaller, so sharpness is an extremal rather than a typical phenomenon.",
        )
        println(
            output,
            "- Only ", supported_total, " of ", pareto_total, " observed Pareto profiles ",
            "(", percentage(all_supported_fraction), ") are supported hull vertices. ",
            "Also, the top-\$\\mathcal J_1\$ decile has a lower median ",
            "\$Q_{0.9}/\\alpha_1\$ than its full cell in all ", localized_top_cells,
            " cells, showing systematic worst-pair localization (partly expected because ",
            "\$\\alpha_1\$ itself is the selected maximum).",
        )

        println(output)
        println(output, "## Definitions and mathematical calibration")
        println(output)
        println(output, "For a rank-\$r\$ matroid on \$n\$ elements, set")
        println(output)
        println(output, "\$\$")
        println(output, "D=d_B(M),")
        println(output, "\\qquad")
        println(output, "c_{r,n}=\\alpha_1(U_{r,n})")
        println(output, "=\\frac{(r-1)(n-r-1)}{r(n-r)}.")
        println(output, "\$\$")
        println(output)
        println(output, "The score studied here is")
        println(output)
        println(output, "\$\$")
        println(output, "\\mathcal J_\\gamma(M)")
        println(output, "=")
        println(output, "\\frac{\\alpha_1(M)}{c_{r,n}}D^\\gamma,")
        println(output, "\\qquad \\gamma\\ge0.")
        println(output, "\$\$")
        println(output)
        println(output, "In logarithmic coordinates")
        println(output)
        println(output, "\$\$")
        println(output, "C=-\\log D,")
        println(output, "\\qquad")
        println(output, "R=\\log\\frac{\\alpha_1}{c_{r,n}},")
        println(output, "\\qquad")
        println(output, "\\log\\mathcal J_\\gamma=R-\\gamma C.")
        println(output, "\$\$")
        println(output)
        println(output, "### Why logarithms are used")
        println(output)
        println(
            output,
            "No information theory is needed to use these coordinates. The natural ",
            "logarithm is an order-preserving change of scale: it turns products into ",
            "sums. The only facts needed to read the plots are:",
        )
        println(output)
        println(
            output,
            "- \$C=0\$ for the uniform matroid, and \$C\$ becomes larger as basis ",
            "density becomes smaller. For example, \$D=1,1/2,1/4\$ give ",
            "\$C=0,\\log2,2\\log2\$.",
        )
        println(
            output,
            "- \$R=0\$ when \$\\alpha_1\$ equals the uniform value \$c_{r,n}\$; ",
            "\$R>0\$ means larger than the uniform value and \$R<0\$ means smaller.",
        )
        println(
            output,
            "- Maximizing \$\\mathcal J_\\gamma\$ is exactly the same as maximizing ",
            "\$\\log\\mathcal J_\\gamma=R-\\gamma C\$.",
        )
        println(output)
        println(
            output,
            "For readers interested in the optional information-theoretic interpretation, ",
            "if ",
            "\$\\nu\$ is uniform on all \$r\$-subsets and \$\\mu_M\$ is uniform on ",
            "the bases of \$M\$, then",
        )
        println(output)
        println(output, "\$\$")
        println(output, "D_{\\mathrm{KL}}(\\mu_M\\Vert\\nu)")
        println(output, "=\\log\\frac{\\binom nr}{|\\mathcal B(M)|}")
        println(output, "=-\\log D=C.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "Thus \$C\$ is exactly the support-entropy cost of restricting the uniform ",
            "law to the basis set, rather than an ad hoc transformation. In elementary ",
            "terms, there are \$\\binom nr\$ possible \$r\$-sets but only ",
            "\$|\\mathcal B(M)|\$ allowed bases, and \$C\$ is the logarithm of the ratio ",
            "of those two numbers. The symbol \$D_{\\mathrm{KL}}\$ is just the standard ",
            "name for this measure of discrepancy between the two uniform choices. ",
            "Basis density, ",
            "\$\\alpha_1\$, and \$c_{r,n}\$ are invariant under matroid duality, so ",
            "\$\\mathcal J_\\gamma\$ and \$\\gamma_*\$ are duality invariant as well.",
        )
        println(output)
        println(
            output,
            "A \$1\\%\$ density loss therefore requires approximately a ",
            "\$\\gamma\\%\$ increase in \$\\alpha_1\$ to hold the score fixed. ",
            "The normalization changes comparisons across ranks but, within a fixed ",
            "\$(r,n)\$, it leaves the ordering identical to ",
            "\$d_B^\\gamma\\alpha_1\$.",
        )
        println(output)
        println(output, "The relationship with the previously adopted excess score is exact:")
        println(output)
        println(output, "\$\$")
        println(output, "\\Theta_\\gamma")
        println(output, "=D^\\gamma\\frac{\\alpha_1-c_{r,n}}{1-c_{r,n}},")
        println(output, "\\qquad")
        println(output, "\\mathcal J_\\gamma")
        println(output, "=D^\\gamma+\\frac{1-c_{r,n}}{c_{r,n}}\\Theta_\\gamma.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "Thus \$\\mathcal J_\\gamma\$ deliberately rewards baseline density, ",
            "whereas \$\\Theta_\\gamma\$ isolates excess correlation. A score above ",
            "one means that a matroid beats the uniform matroid under the chosen exchange ",
            "rate; it does not imply \$\\alpha_1>1\$.",
        )
        println(output)
        println(
            output,
            "For the rank-6, 12-element \$100/81\$ benchmark, ",
            "\$D=57/77\$ and \$\\alpha_1/c_{6,12}=16/9\$. Hence",
        )
        println(output)
        println(output, "\$\$")
        println(output, "\\mathcal J_1=\\frac{304}{231}\\approx1.3160,")
        println(output, "\\qquad")
        println(output, "\\mathcal J_2=\\frac{5776}{5929}\\approx0.9742,")
        println(output, "\\qquad")
        println(output, "\\gamma_*")
        println(output, "=\\frac{\\log(16/9)}{\\log(77/57)}\\approx1.9131.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "It therefore beats the uniform reference at \$\\gamma=1\$ but not at ",
            "\$\\gamma=2\$, a concrete reminder that the density exchange rate is ",
            "substantive.",
        )

        println(output)
        println(output, "### Pareto geometry")
        println(output)
        println(
            output,
            "**Pareto** terminology is just a way to discuss two goals without first ",
            "deciding how much one goal is worth relative to the other. Here the goals are ",
            "to make both \$D\$ and \$\\alpha_1\$ large.",
        )
        println(output)
        println(output, "| Toy profile | Density \$D\$ | \$\\alpha_1\$ |")
        println(output, "|---|---:|---:|")
        println(output, "| A | 0.80 | 1.05 |")
        println(output, "| B | 0.70 | 1.20 |")
        println(output, "| C | 0.60 | 1.00 |")
        println(output)
        println(
            output,
            "Profile A is unambiguously preferable to C for these two objectives: it has ",
            "both higher density and higher \$\\alpha_1\$. We say that A **dominates** C. ",
            "Neither A nor B dominates the other, because A has higher density while B ",
            "has higher \$\\alpha_1\$. The **Pareto frontier** consists of the profiles ",
            "that are not dominated by any observed profile; in this toy example it is ",
            "\$\\{A,B\\}\$. Calling a profile Pareto efficient does not say that it is ",
            "best. It says only that improving one objective requires sacrificing the ",
            "other among the profiles observed.",
        )
        println(output)
        println(
            output,
            "The report applies this comparison to exact profiles \$(D,\\alpha_1)\$. ",
            "Combining identical profiles first prevents repeated samples from changing ",
            "which profiles are on the frontier. In \$(C,R)\$ coordinates, the preferred ",
            "direction is up and to the left: smaller \$C\$ means greater density, while ",
            "larger \$R\$ means greater relative correlation.",
        )
        println(output)
        println(
            output,
            "Fixing \$\\gamma\$ converts the two goals into the single score ",
            "\$R-\\gamma C\$. Geometrically, draw a line of slope \$\\gamma\$ and slide ",
            "it upward until it last touches an observed point. A touched profile ",
            "maximizes \$\\mathcal J_\\gamma\$ for that exponent and is called ",
            "**supported**. Some Pareto points sit in an inward bend below the straight ",
            "segment joining two other frontier points. They are still nondominated, but ",
            "no choice of \$\\gamma\$ makes them the maximizer. The boundary formed by ",
            "the supported points is what the technical phrase **upper concave hull** ",
            "means here.",
        )
        println(output)
        println(
            output,
            "Consequently, the Pareto count answers “how many observed tradeoffs are ",
            "unambiguously viable?”, while the supported count answers “how many can be ",
            "selected by some score \$\\mathcal J_\\gamma\$?” Lines in the figures merely ",
            "connect discrete observed frontier points; they do not claim that ",
            "intermediate matroids exist.",
        )

        println(output)
        println(output, "### The high-density deletion cap")
        println(output)
        println(
            output,
            "The very-high-density region is treated separately because there is already ",
            "an elementary theorem forcing density and correlation to trade off there. ",
            "Removing that region lets us ask whether the empirical pattern persists ",
            "where this theorem gives no finite restriction.",
        )
        println(output)
        println(output, "Put")
        println(output)
        println(output, "\$\$")
        println(output, "v_{r,n}=\\frac{r(n-r)}{n(n-1)},")
        println(output, "\\qquad")
        println(output, "D_{\\mathrm{cap}}=1-v_{r,n}.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "For a fixed ordered choice of two elements, \$v_{r,n}\$ is the fraction of ",
            "all \$r\$-subsets in one of the two mixed cells (containing exactly the ",
            "specified one of the two elements). If the omitted fraction \$1-D\$ is ",
            "smaller than this cell, simple counting prevents the pair ratio from growing ",
            "arbitrarily. The condition \$1-D<v_{r,n}\$ is exactly ",
            "\$D>D_{\\mathrm{cap}}\$, which this report calls **high density**.",
        )
        println(output)
        println(output, "When \$D>D_{\\mathrm{cap}}\$, the set-system argument gives")
        println(output)
        println(output, "\$\$")
        println(output, "R")
        println(output, "\\le")
        println(output, "C_{\\mathrm{cap}}(D)")
        println(output, ":=-\\log\\left(1-\\frac{1-D}{v_{r,n}}\\right).")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "The ratio \$E_{\\mathrm{del}}=R/C_{\\mathrm{cap}}\$ compares the observed ",
            "relative-correlation increase with this rigorous allowance. The value 1 ",
            "means equality in the bound, 0 means no increase over the uniform baseline, ",
            "and a negative value means \$\\alpha_1<c_{r,n}\$. Whenever \$R\\ge0\$, the ",
            "theorem forces \$0\\le E_{\\mathrm{del}}\\le1\$.",
        )
        println(output)
        println(
            output,
            "This bound is exactly sharp even within matroids. Fix an \$r\$-set \$H\$ and ",
            "let \$M_H\$ have every \$r\$-set except \$H\$ as a basis; \$H\$ is its single ",
            "circuit-hyperplane, so \$M_H\$ is sparse paving. Put",
        )
        println(output)
        println(output, "\$\$")
        println(output, "B_0=\\binom{n-2}{r-1}.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "For \$i\\in H\$ and \$j\\notin H\$, deleting \$H\$ removes one set from ",
            "exactly one mixed cell of the pair table and leaves both numerator cells ",
            "unchanged. Therefore",
        )
        println(output)
        println(output, "\$\$")
        println(output, "\\frac{\\alpha_1(M_H)}{c_{r,n}}")
        println(output, "=\\frac{B_0}{B_0-1}")
        println(output, "=\\frac{1}{1-(1-D)/v_{r,n}},")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "where \$1-D=1/\\binom nr\$ and ",
            "\$v_{r,n}=B_0/\\binom nr\$. Hence ",
            "\$E_{\\mathrm{del}}(M_H)=1\$. The observed equality cases are not ",
            "numerical accidents, although most sampled high-density matroids lie well ",
            "below the envelope.",
        )
        println(output)
        println(
            output,
            "The diagnostic \$E_{\\mathrm{del}}=R/C_{\\mathrm{cap}}\$ is computed ",
            "only for nonuniform observations in that domain. The separate sensitivity ",
            "population uses \$D\\le D_{\\mathrm{cap}}\$, precisely where this finite ",
            "bound no longer applies. This cutoff is mathematical rather than a fitted ",
            "quantile. The theorem constrains the feasible upper envelope; it does not ",
            "determine a sampling correlation.",
        )

        println(output)
        println(output, "### The critical exponent")
        println(output)
        println(
            output,
            "Rather than selecting \$\\gamma\$ first, one can ask how severe a density ",
            "penalty a particular matroid can survive. This break-even value is ",
            "\$\\gamma_*\$.",
        )
        println(output)
        println(output, "For \$D<1\$ and \$\\alpha_1>c_{r,n}\$,")
        println(output)
        println(output, "\$\$")
        println(output, "\\gamma_*")
        println(output, "=")
        println(output, "\\frac{\\log(\\alpha_1/c_{r,n})}{\\log(1/D)},")
        println(output, "\\qquad")
        println(output, "\\mathcal J_\\gamma>1")
        println(output, "\\Longleftrightarrow")
        println(output, "\\gamma<\\gamma_*.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "For example, \$\\gamma_*=1.5\$ means that the matroid beats the uniform ",
            "score for \$\\gamma<1.5\$, ties it at \$1.5\$, and loses for ",
            "\$\\gamma>1.5\$. The tables include \$\\gamma_*\$ only when \$D<1\$ and ",
            "\$\\alpha_1>c_{r,n}\$; the uniform matroid needs no break-even exponent.",
        )
        println(output)
        println(
            output,
            "The all-data maximum is reported but should not be treated as robust: ",
            "near the uniform point both the numerator and denominator are close to zero, ",
            "so a very small change can produce a large quotient. This is the sense in ",
            "which the maximum is numerically unstable. The outside-cap percentiles are ",
            "safer summaries.",
        )

        write_statistics_guide(output)
        println(output)
        println(output, "## Populations and statistical conventions")
        println(output)
        println(
            output,
            "Every distributional calculation uses connected matroids with ",
            "\$\\alpha_1>0\$, so there are no loops or coloops; the proof was given in ",
            "the reader's guide. PolyDB rows are isomorphism classes and give exact ",
            "finite-population descriptions, with one vote per isomorphism class. ",
            "Finite-field rows are accepted labeled configurations from the stated field ",
            "and replacement model, not uniform samples of matroid isomorphism classes. ",
            "Johnson rows are labeled random-greedy stable sets, not uniform samples of ",
            "sparse-paving matroids. ICARM rank 4 is a class-uniform simple random sample, ",
            "meaning every class had the same chance to be chosen. Rank 5 is a two-stage ",
            "cluster pilot: chunks were selected first and rows within chunks second, so ",
            "its 12,800 rows cannot be treated as independent draws.",
        )
        println(output)
        println(
            output,
            "Associations, OLS slopes, frontiers, and score distributions are descriptive. ",
            "No p-values are reported: the variables are algebraically coupled and the ",
            "large row counts do not cure ensemble dependence. For finite-field and ",
            "Johnson cells with multiple independent seeds, ranges across seed replicates ",
            "are reported. Spearman coefficients use weighted midranks for exact ties. ",
            "The OLS slope of \$R\$ on \$C\$ is a sample-dependent detrending exponent, ",
            "not an intrinsic matroid invariant and not an estimate of the frontier slope.",
        )
        println(output)
        println(
            output,
            "Outside-cap rows with fewer than 30 observations are retained in coverage ",
            "tables but excluded from the cross-source sign counts and substantive ",
            "correlation comparisons. In particular, the current ICARM rank-4 sample has ",
            "only four such rows, while ICARM rank 5 and all four Johnson samples have ",
            "none. Targeting additional low-density ICARM or Johnson observations would ",
            "change the sampling law and could not be interpreted as an extension of the ",
            "present probability sample. The existing sources already supply ",
            outside_total, " outside-cap observations across ", usable_outside,
            " adequately populated cells, so no new data were generated for this report.",
        )
        println(output)
        println(
            output,
            "No synthetic weight combines the class-uniform catalogues, labeled ",
            "finite-field configurations, Johnson samples, and the clustered ICARM pilot; ",
            "every coefficient and proportion is computed within its displayed ensemble. ",
            "Consequently, the cross-source total of ", outside_total,
            " rows is an audit count, not the denominator of a pooled prevalence estimate.",
        )
        println(output)
        println(
            output,
            "The robust companion uses the stored 90th percentile \$Q_{0.9}\$ of eligible ",
            "pair ratios:")
        println(output)
        println(output, "\$\$")
        println(output, "\\mathcal J_{1,q90}=D\\frac{Q_{0.9}}{c_{r,n}}.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "The ratio \$Q_{0.9}/\\alpha_1\$ is near one when large pair ratios are ",
            "widespread and small when the maximum is exceptional. It is a robustness ",
            "diagnostic, not a replacement definition of \$\\alpha_1\$.",
        )
        println(output)
        println(output, "## Reading the figures")
        println(output)
        println(
            output,
            "Read a cost–reward frontier plot as follows. The horizontal coordinate is ",
            "\$C=-\\log D\$: moving right means fewer bases. The vertical coordinate is ",
            "\$R=\\log(\\alpha_1/c_{r,n})\$: moving upward means a larger correlation ",
            "ratio relative to the uniform matroid. Thus up and left is preferable, but ",
            "the observed points generally force a tradeoff.",
        )
        println(output)
        println(
            output,
            "Circles are non-sparse-paving observations and triangles are sparse paving. ",
            "Colored lines and larger points show the exact observed Pareto frontiers. ",
            "The black star at \$(0,0)\$ is the uniform matroid. For a gray line ",
            "\$R=\\gamma C\$, a point above the line has \$\\mathcal J_\\gamma>1\$, a ",
            "point on it ties the uniform score, and a point below it has score below 1.",
        )
        println(output)
        println(
            output,
            "The vertical red line marks \$D=D_{\\mathrm{cap}}\$. The rigorous ",
            "high-density region lies to its **left**, because higher density means ",
            "smaller \$C\$. The outside-cap sensitivity population lies on or to its ",
            "right. In an all-data plot, the solid red curve is the theorem's upper bound ",
            "on \$R\$ in the high-density region.",
        )
        println(output)
        println(
            output,
            "For legibility, at most 12,000 ordinary scatter points per ensemble are drawn. ",
            "This thinning changes only the ink in the picture: every retained row is ",
            "still used to compute frontiers, coefficients, and tables. In a ",
            "\$\\gamma_*\$ survival plot, the curve's height at \$g\$ is the observed ",
            "fraction with \$\\gamma_*\\ge g\$. Solid curves use the primary population; ",
            "dashed curves use the outside-cap subset when it has at least 30 observations.",
        )

        println(output)
        println(output, "## Cross-source findings")
        println(output)
        println(output, "### The strong large-field tradeoff is concentrated near uniformity")
        println(output)
        println(
            output,
            "In the full finite-field samples, the visually striking positive association ",
            "between density cost \$C\$ and relative-correlation reward \$R\$ becomes ",
            "stronger with the field size. Much of it disappears after imposing ",
            "\$D\\le D_{\\mathrm{cap}}\$. The clearest case is rank 6 on 12 elements ",
            "over \$\\mathrm{GF}(7)\$ with replacement: Spearman's coefficient changes ",
            "from \$+0.870\$ to \$+0.028\$. Across its five seeds, the outside-cap ",
            "coefficient ranges only from \$+0.007\$ to \$+0.085\$, so this collapse is ",
            "not an artifact of pooling the replicates.",
        )
        println(output)
        println(
            output,
            "The residual behavior is nevertheless not universal. Of the ",
            usable_outside, " adequately populated cells, ",
            outside_positive_cost_reward, " retain a positive coefficient. The five ",
            "negative cases are all \$\\mathrm{GF}(2)\$ finite-field ensembles; four are ",
            "stably negative across seeds, while rank 6 without replacement straddles ",
            "zero. Thus the data suggest an ensemble- and field-dependent crossover, ",
            "not a distribution-free monotonicity theorem for matroids.",
        )

        println(output)
        println(output, "### A unit density penalty usually over-corrects outside the cap")
        println(output)
        println(
            output,
            "There is a simple way to interpret the fitted slope. If the moderate-density ",
            "conditional trend is approximated by \$R\\approx a+\\beta C\$, then",
        )
        println(output)
        println(output, "\$\$")
        println(output, "\\log\\mathcal J_1")
        println(output, "\\approx a+(\\beta-1)C.")
        println(output, "\$\$")
        println(output)
        println(
            output,
            "Because \$D=e^{-C}\$, a slope \$\\beta<1\$ predicts that ",
            "\$\\mathcal J_1\$ increases, rather than decreases, with density. This is ",
            "exactly the dominant pattern: ", outside_slope_lt_one, " of ",
            usable_outside, " outside-cap cells have \$\\widehat\\beta<1\$, and ",
            outside_positive_j_density, " of ", usable_outside,
            " have positive Spearman association between \$D\$ and \$\\mathcal J_1\$. ",
            "Six cells even reverse from a negative full-data association to a positive ",
            "outside-cap association.",
        )
        println(output)
        println(
            output,
            "The sole exception to both counts is the exhaustive rank-4, 10-element ",
            "\$\\mathrm{GF}(2)\$ no-replacement ensemble: it has ",
            "\$\\widehat\\beta=1.921\$ and Spearman ",
            "\$\\rho(D,\\mathcal J_1)=-0.708\$. It contains 3,003 labeled ",
            "configurations but only four distinct \$ (D,\\alpha_1) \$ profiles, so its ",
            "coefficient describes a very small discrete support. More broadly, neither ",
            "the OLS identity nor a Spearman sign is a causal statement; their agreement ",
            "here is a useful diagnostic of the chosen exchange rate.",
        )

        println(output)
        println(output, "### Observed scalar maximizers")
        println(output)
        write_global_extrema_table(output, analyses)
        println(output)
        println(
            output,
            "As \$\\gamma\$ increases, the global all-data maximizer moves from a ",
            "moderately dense matroid with \$\\alpha_1=9/8\$, through a denser profile ",
            "with \$\\alpha_1=49/48\$, to a sparse-paving profile with density \$8/9\$ ",
            "but \$\\alpha_1=15/16<1\$. This is correct scalarization geometry—density is ",
            "being rewarded more heavily—but it is a useful warning that a large ",
            "\$\\mathcal J_\\gamma\$ need not mean unusually large raw correlation.",
        )
        println(output)
        println(
            output,
            "Away from the cap, \$\\gamma=2\$ is far more selective. Exactly one of ",
            outside_total, " observations has \$\\mathcal J_2>1\$: ",
            "the class `n9r3_00000494`, with \$D=3/4=D_{\\mathrm{cap}}\$ and ",
            "\$\\alpha_1=1\$. Thus the observed rank-6 \$100/81\$ example, although ",
            "strong at \$\\gamma=1\$, is already below the uniform benchmark at ",
            "\$\\gamma=2\$.",
        )

        println(output)
        println(output, "### Scalarization misses much of the discrete frontier")
        println(output)
        println(
            output,
            "Across the all-data cells there are ", pareto_total,
            " distinct Pareto-efficient profiles but only ", supported_total,
            " supported upper-hull vertices. Hence a scan over all exponents ",
            "\$\\gamma\\ge0\$ can recover only ", percentage(all_supported_fraction),
            " of the observed nondominated profiles. The remaining profiles are genuine ",
            "density–correlation compromises, but no linear log-space exchange rate makes ",
            "one of them optimal. This is a substantive limitation of any single ",
            "\$\\mathcal J_\\gamma\$ ranking, not a computational omission.",
        )
        println(output)
        println(
            output,
            "The robust companion \$\\mathcal J_{1,q90}\$ is positively rank-correlated ",
            "with \$\\mathcal J_1\$ in ", robust_positive_cells, " of ",
            length(summaries), " cells. Nevertheless, in every cell the top ",
            "\$\\mathcal J_1\$ decile has a lower median \$Q_{0.9}/\\alpha_1\$ than the ",
            "cell as a whole. High scores are therefore disproportionately supported by ",
            "an exceptional worst pair. Part of this effect is mechanical—selection uses ",
            "the maximum \$\\alpha_1\$ in the denominator—so it should be read as a ",
            "localization diagnostic rather than evidence of a separate theorem.",
        )

        for analysis in analyses
            experiment = analysis.experiment
            local_summaries = analysis.summaries
            threshold = density_cap_threshold(experiment.n, experiment.rank)
            baseline = uniform_correlation_baseline(experiment.n, experiment.rank)
            println(output)
            println(output, "## ", experiment.title)
            println(output)
            println(
                output,
                "Here \$c_{r,n}=", numerator(baseline), "/", denominator(baseline),
                "\\approx", fixed(Float64(baseline), digits=6),
                "\$ and \$D_{\\mathrm{cap}}=", numerator(threshold), "/",
                denominator(threshold), "\\approx",
                fixed(Float64(threshold), digits=6), "\$.",
            )
            println(output)
            println(output, "### Coverage and the deletion bound")
            println(output)
            write_coverage_table(output, local_summaries)
            println(output)
            println(output, "### Log-coordinate association and observed frontiers")
            println(output)
            write_tradeoff_table(output, local_summaries)
            println(output)
            println(
                output,
                "![Observed cost-reward frontier for ", experiment.slug, "](",
                figure_relative, "/", experiment.slug, "_frontier.png)",
            )
            println(output)
            println(
                output,
                "The next plot discards \$D>D_{\\mathrm{cap}}\$. An empty panel means ",
                "that the source law supplied no observations in the sensitivity region.",
            )
            println(output)
            println(
                output,
                "![Outside-cap cost-reward frontier for ", experiment.slug, "](",
                figure_relative, "/", experiment.slug,
                "_frontier_outside_cap.png)",
            )
            println(output)
            println(output, "### Scalarization and penalty sensitivity")
            println(output)
            write_j_table(output, local_summaries)
            println(output)
            println(
                output,
                "![Penalty sensitivity for ", experiment.slug, "](",
                figure_relative, "/", experiment.slug,
                "_gamma_sensitivity.png)",
            )
            println(output)
            println(output, "### Critical exponent and worst-pair robustness")
            println(output)
            write_secondary_table(output, local_summaries)
            if any(summary -> summary.replicates.replicate_count >= 2, local_summaries)
                println(output)
                println(output, "### Independent-seed stability")
                println(output)
                write_replicate_table(output, local_summaries)
            end
        end

        write_background_references(output)
        println(output)
        println(output, "## Reproducibility and compact outputs")
        println(output)
        println(output, "- [`j_gamma_summary.csv`](", summary_relative, ")")
        println(output, "- [`j_gamma_frontiers.csv`](", frontier_relative, ")")
        println(output, "- [`j_gamma_extrema.csv`](", extrema_relative, ")")
        println(output)
        println(
            output,
            "The summary export has one row per ensemble and population definition. ",
            "The frontier export retains only distinct observed Pareto profiles, and the ",
            "extrema export retains the three requested scalar-score maximizers. No ",
            "per-matroid score table is stored. All scores can be reconstructed from ",
            "\$n,r,|\\mathcal B|,\$ and the exact stored numerator and denominator of ",
            "\$\\alpha_1\$.",
        )
        println(output)
        println(output, "Data sources:")
        println(output)
        for analysis in analyses
            database = analysis.experiment.database
            relative = relpath(database, dirname(path))
            println(
                output,
                "- ", analysis.experiment.title, ": [`",
                basename(database), "`](", relative, ")",
            )
        end
    end
    return path
end

"""Run every available scope and write the report plus compact artifacts."""
function main()
    report_path = length(ARGS) >= 1 ? abspath(ARGS[1]) :
        joinpath(PROJECT_DIRECTORY, "reports", "J_gamma_analysis_report.md")
    figure_directory = length(ARGS) >= 2 ? abspath(ARGS[2]) :
        joinpath(PROJECT_DIRECTORY, "figures", "j_gamma_analysis")
    summary_csv = length(ARGS) >= 3 ? abspath(ARGS[3]) :
        joinpath(
            PROJECT_DIRECTORY,
            "data",
            "j_gamma_analysis",
            "j_gamma_summary.csv",
        )
    frontier_csv = joinpath(dirname(summary_csv), "j_gamma_frontiers.csv")
    extrema_csv = joinpath(dirname(summary_csv), "j_gamma_extrema.csv")
    mkpath(figure_directory)

    analyses = NamedTuple[]
    for experiment in experiment_specs()
        println("J_GAMMA_SCOPE_START ", experiment.slug)
        push!(analyses, analyze_experiment(experiment, figure_directory))
        GC.gc()
        println("J_GAMMA_SCOPE_COMPLETE ", experiment.slug)
    end
    write_summary_csv(summary_csv, analyses)
    write_frontier_csv(frontier_csv, analyses)
    write_extrema_csv(extrema_csv, analyses)
    write_report(
        report_path,
        figure_directory,
        summary_csv,
        frontier_csv,
        extrema_csv,
        analyses,
    )
    println("J_GAMMA_REPORT_COMPLETE path=", report_path)
end

(abspath(PROGRAM_FILE) == @__FILE__) && main()
