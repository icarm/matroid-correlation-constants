"""
Generate a documented rank-scoped Markdown report, CSV exports, and a TOML
manifest from a compact correlation-ratio database.

Command line:

```text
julia --project=. scripts/make_report.jl \
    DATABASE REPORT EXPORT_DIRECTORY MANIFEST FIGURE_DIRECTORY [N] [RANK_SCOPE]
```

`RANK_SCOPE` accepts one rank, a comma list, an inclusive range, or `all`. By
duality, accepted ranks stop at `floor(N/2)`; `all` means all completed ranks
through that bound. Distribution summaries use connected matroids with
positive α₁ only. For polyDB groups, reported counts are counts of isomorphism
classes; finite-field groups are counts of accepted projective configurations
or draws, and Johnson-graph groups are labeled independent-set draws from the
stated random-greedy activity.
"""

using DBInterface
using Dates
using Printf
using Statistics
using TOML

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

"""Materialize SQLite rows into ordinary named tuples."""
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

"""Human-readable population label."""
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

"""Create report populations, pooling seed replicates and requested ranks."""
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

"""SQL placeholders for a group's run identifiers."""
run_placeholders(group) = join(fill("?", length(group.run_ids)), ", ")

"""Read all or distribution-filtered matroid rows for a report group."""
function matroid_rows(database, group; distribution_only::Bool=false)
    conditions = String[]
    group.simple_only && push!(conditions, "simple = 1")
    distribution_only && append!(conditions, ["connected = 1", "alpha_num > 0"])
    suffix = isempty(conditions) ? "" : " AND " * join(conditions, " AND ")
    return materialize(
        database,
        """
        SELECT matroid_id, source_id, rank_value, census_multiplicity, num_bases,
               basis_density, basis_hex, alpha_num, alpha_den,
               alpha_value, best_i, best_j, positive_pair_fraction, simple,
               cosimple, connected, three_connected, paving, sparse_paving,
               circuit_hyperplanes
        FROM matroids
        WHERE run_id IN ($(run_placeholders(group)))$suffix
        ORDER BY run_id, observation_index
        """,
        Tuple(group.run_ids),
    )
end

"""Weighted count of rows satisfying `predicate`."""
weighted_count(predicate, rows) =
    sum(Int(row.census_multiplicity) for row in rows if predicate(row); init=0)

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

"""Wilson score interval for a binomial proportion."""
function wilson_interval(successes, total; z=1.959963984540054)
    total == 0 && return (0.0, 0.0)
    estimate = successes / total
    denominator = 1 + z^2 / total
    center = (estimate + z^2 / (2total)) / denominator
    radius =
        z * sqrt(estimate * (1 - estimate) / total + z^2 / (4total^2)) /
        denominator
    return max(0.0, center - radius), min(1.0, center + radius)
end

"""Exact threshold count by integer cross multiplication."""
function threshold_count(rows, numerator, denominator; strict::Bool=false)
    return weighted_count(rows) do row
        left = row.alpha_num * denominator
        right = numerator * row.alpha_den
        strict ? left > right : left >= right
    end
end

"""Format a reduced integer fraction."""
fraction_string(numerator, denominator) =
    denominator == 1 ? string(numerator) : "$(numerator)/$(denominator)"

"""Format a proportion as a percentage with two decimal places."""
percent(value) = @sprintf("%.2f%%", 100value)

"""Approximate a two-sided standard-normal p-value without extra packages."""
function two_sided_normal_pvalue(z::Real)
    magnitude = abs(Float64(z))
    magnitude >= 8 && return 0.0
    t = 1 / (1 + 0.2316419magnitude)
    polynomial = t * (
        0.319381530 + t * (
            -0.356563782 + t * (1.781477937 + t * (-1.821255978 + 1.330274429t))
        )
    )
    upper_tail = exp(-magnitude^2 / 2) * polynomial / sqrt(2π)
    return clamp(2upper_tail, 0.0, 1.0)
end

"""Fisher-transform confidence interval for a Pearson correlation."""
function fisher_correlation_interval(correlation::Real, sample_size::Integer)
    sample_size > 3 || return missing
    bounded = clamp(Float64(correlation), -1 + eps(Float64), 1 - eps(Float64))
    center = atanh(bounded)
    margin = 1.959963984540054 / sqrt(sample_size - 3)
    return (tanh(center - margin), tanh(center + margin))
end

"""Compute weighted density/α₁ association statistics for one group."""
function basis_density_correlation_summary(rows; inferential::Bool)
    isempty(rows) && return (
        pearson=missing,
        pearson_interval=missing,
        pearson_p=missing,
        spearman=missing,
        spearman_p=missing,
        slope_per_tenth=missing,
    )
    densities = Float64[row.basis_density for row in rows]
    alpha = Float64[row.alpha_value for row in rows]
    weights = Float64[row.census_multiplicity for row in rows]
    sample_size = round(Int, sum(weights))
    pearson = weighted_pearson(densities, alpha, weights)
    spearman = weighted_spearman(densities, alpha, weights)
    fit = weighted_linear_fit(densities, alpha, weights)
    can_test = inferential && sample_size > 3
    pearson_z = ismissing(pearson) ? missing :
                atanh(clamp(pearson, -1 + eps(Float64), 1 - eps(Float64))) *
                sqrt(sample_size - 3)
    spearman_z = ismissing(spearman) ? missing :
                 spearman * sqrt(
        (sample_size - 2) / max(1 - spearman^2, eps(Float64)),
    )
    return (
        pearson=pearson,
        pearson_interval=can_test && !ismissing(pearson) ?
                         fisher_correlation_interval(pearson, sample_size) : missing,
        pearson_p=can_test && !ismissing(pearson_z) ?
                  two_sided_normal_pvalue(pearson_z) : missing,
        spearman=spearman,
        spearman_p=can_test && !ismissing(spearman_z) ?
                   two_sided_normal_pvalue(spearman_z) : missing,
        slope_per_tenth=ismissing(fit) ? missing : 0.1 * fit.slope,
    )
end

"""Format a p-value while avoiding meaningless underflowed precision."""
function pvalue_string(value)
    ismissing(value) && return "—"
    value < 1e-15 && return "< 1e-15"
    return @sprintf("%.3g", value)
end

"""Format a correlation or regression effect, preserving missing values."""
effect_string(value) = ismissing(value) ? "—" : @sprintf("%+.4f", value)

"""Format a two-sided correlation interval."""
interval_string(value) = ismissing(value) ? "—" :
                         @sprintf("[%+.4f, %+.4f]", value[1], value[2])

"""Summarize one ensemble under the requested distribution filter."""
function group_summary(database, group)
    all_rows = matroid_rows(database, group)
    rows = matroid_rows(database, group; distribution_only=true)
    total_count = sum(Int(row.census_multiplicity) for row in all_rows; init=0)
    included_count = sum(Int(row.census_multiplicity) for row in rows; init=0)
    included_count > 0 || error("group $(group.label) has an empty analysis population")
    values = Float64[row.alpha_value for row in rows]
    weights = Int[row.census_multiplicity for row in rows]
    positive = threshold_count(rows, 1, 1; strict=true)
    non_sparse_rows = [row for row in rows if row.sparse_paving == 0]
    non_sparse_count = sum(
        Int(row.census_multiplicity) for row in non_sparse_rows;
        init=0,
    )
    non_sparse_values = Float64[row.alpha_value for row in non_sparse_rows]
    non_sparse_weights = Int[row.census_multiplicity for row in non_sparse_rows]
    non_sparse_positive = threshold_count(non_sparse_rows, 1, 1; strict=true)
    non_sparse_maximum_row =
        isempty(non_sparse_rows) ? nothing : non_sparse_rows[argmax(non_sparse_values)]
    density_correlation = basis_density_correlation_summary(
        non_sparse_rows;
        inferential=group.random,
    )
    sparse_rows = [row for row in rows if row.sparse_paving == 1]
    sparse_count = sum(
        Int(row.census_multiplicity) for row in sparse_rows;
        init=0,
    )
    sparse_density_correlation = basis_density_correlation_summary(
        sparse_rows;
        inferential=group.random,
    )
    circuit_hyperplanes = Float64[row.circuit_hyperplanes for row in all_rows]
    structural_weights = Int[row.census_multiplicity for row in all_rows]
    density_values = Float64[row.basis_density for row in all_rows]
    maximum_row = rows[argmax(values)]
    lower, upper = group.random ? wilson_interval(positive, included_count) :
                   (positive / included_count, positive / included_count)
    structural_denominator = max(total_count, 1)
    return (
        label=group.label,
        source=group.source,
        derived=group.derived,
        random=group.random,
        included_count=included_count,
        excluded_count=total_count - included_count,
        distinct_encodings=length(
            unique((row.rank_value, row.basis_hex) for row in rows),
        ),
        median=weighted_quantile(values, weights, 0.50),
        percentile_95=weighted_quantile(values, weights, 0.95),
        maximum_fraction=fraction_string(maximum_row.alpha_num, maximum_row.alpha_den),
        maximum_value=maximum_row.alpha_value,
        positive=positive,
        positive_fraction=positive / included_count,
        positive_interval=(lower, upper),
        non_sparse_count=non_sparse_count,
        non_sparse_retained_fraction=non_sparse_count / included_count,
        non_sparse_median=isempty(non_sparse_rows) ? missing :
                          weighted_quantile(non_sparse_values, non_sparse_weights, 0.50),
        non_sparse_percentile_95=isempty(non_sparse_rows) ? missing :
                                 weighted_quantile(
            non_sparse_values,
            non_sparse_weights,
            0.95,
        ),
        non_sparse_maximum_fraction=isempty(non_sparse_rows) ? missing :
                                    fraction_string(
            non_sparse_maximum_row.alpha_num,
            non_sparse_maximum_row.alpha_den,
        ),
        non_sparse_maximum_value=isempty(non_sparse_rows) ? missing :
                                 non_sparse_maximum_row.alpha_value,
        non_sparse_positive=non_sparse_positive,
        non_sparse_positive_fraction=non_sparse_count == 0 ? missing :
                                     non_sparse_positive / non_sparse_count,
        non_sparse_density_pearson=density_correlation.pearson,
        non_sparse_density_pearson_interval=density_correlation.pearson_interval,
        non_sparse_density_pearson_p=density_correlation.pearson_p,
        non_sparse_density_spearman=density_correlation.spearman,
        non_sparse_density_spearman_p=density_correlation.spearman_p,
        non_sparse_density_slope_per_tenth=density_correlation.slope_per_tenth,
        sparse_count=sparse_count,
        sparse_retained_fraction=sparse_count / included_count,
        sparse_distinct_density_levels=length(unique(row.num_bases for row in sparse_rows)),
        sparse_density_pearson=sparse_density_correlation.pearson,
        sparse_density_pearson_interval=sparse_density_correlation.pearson_interval,
        sparse_density_pearson_p=sparse_density_correlation.pearson_p,
        sparse_density_spearman=sparse_density_correlation.spearman,
        sparse_density_spearman_p=sparse_density_correlation.spearman_p,
        sparse_density_slope_per_tenth=sparse_density_correlation.slope_per_tenth,
        sparse_paving_above_one=weighted_count(
            row -> row.sparse_paving == 1 && row.alpha_num > row.alpha_den,
            all_rows,
        ),
        at_eight_sevenths=threshold_count(rows, 8, 7),
        at_record=threshold_count(rows, 100, 81),
        structural_count=total_count,
        simple_fraction=weighted_count(row -> row.simple == 1, all_rows) /
                        structural_denominator,
        cosimple_fraction=weighted_count(row -> row.cosimple == 1, all_rows) /
                          structural_denominator,
        connected_fraction=weighted_count(row -> row.connected == 1, all_rows) /
                           structural_denominator,
        three_connected_fraction=
            weighted_count(row -> row.three_connected == 1, all_rows) /
            structural_denominator,
        paving_fraction=weighted_count(row -> row.paving == 1, all_rows) /
                        structural_denominator,
        sparse_paving_fraction=
            weighted_count(row -> row.sparse_paving == 1, all_rows) /
            structural_denominator,
        circuit_hyperplane_minimum=minimum(circuit_hyperplanes),
        circuit_hyperplane_median=weighted_quantile(
            circuit_hyperplanes,
            structural_weights,
            0.50,
        ),
        circuit_hyperplane_mean=sum(
            value * weight
            for (value, weight) in zip(circuit_hyperplanes, structural_weights)
        ) / total_count,
        circuit_hyperplane_maximum=maximum(circuit_hyperplanes),
        basis_density_minimum=minimum(density_values),
        basis_density_maximum=maximum(density_values),
    )
end

"""Return a report title and a short prose description of its rank scope."""
function scope_description(n::Int, ranks::Vector{Int})
    if length(ranks) == 1
        rank = only(ranks)
        return (
            title="Unweighted correlation ratios for rank-$(rank) matroids on $(n) elements",
            prose="rank $(rank)",
        )
    end
    maximum_rank = fld(n, 2)
    if ranks == collect(0:maximum_rank)
        return (
            title="Unweighted correlation ratios for matroids on $(n) elements, ranks 0–$(maximum_rank) up to duality",
            prose="ranks 0 through $(maximum_rank), one side of matroid duality",
        )
    end
    return (
        title="Unweighted correlation ratios for matroids on $(n) elements across selected ranks",
        prose="ranks " * join(ranks, ", "),
    )
end

"""Write scoped run metadata and database provenance as TOML."""
function write_manifest(path, database_path, n::Int, ranks::Vector{Int}, runs)
    manifest = Dict{String,Any}(
        "experiment" => Dict(
            "n" => n,
            "ranks" => ranks,
            "database" => abspath(database_path),
            "analysis_population" => "connected matroids with alpha_1 > 0",
            "generated_at" => Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        ),
        "runs" => Dict{String,Any}[],
    )
    for run in runs
        values = Dict{String,Any}()
        for name in propertynames(run)
            value = getproperty(run, name)
            ismissing(value) || (values[string(name)] = value)
        end
        push!(manifest["runs"], values)
    end
    mkpath(dirname(path))
    open(path, "w") do output
        TOML.print(output, manifest)
    end
end

"""Write the complete Markdown report with explanations adjacent to figures."""
function write_report(
    path,
    database,
    database_path,
    export_directory,
    figure_directory,
    n::Int,
    ranks::Vector{Int},
)
    groups = group_specs(database, n, ranks)
    summaries = [group_summary(database, group) for group in groups]
    run_ids = unique(reduce(vcat, [group.run_ids for group in groups]; init=String[]))
    placeholders = join(fill("?", length(run_ids)), ", ")
    parameters = Tuple(run_ids)
    runs = materialize(
        database,
        "SELECT * FROM runs WHERE run_id IN ($(placeholders)) ORDER BY rank_value, run_id",
        parameters,
    )
    total_matroids = first(
        DBInterface.execute(
            database,
            "SELECT COUNT(*) AS n FROM matroids WHERE run_id IN ($(placeholders))",
            parameters,
        ),
    ).n
    expected_pairs = first(
        DBInterface.execute(
            database,
            "SELECT COALESCE(SUM(eligible_pair_count), 0) AS n FROM matroids WHERE run_id IN ($(placeholders))",
            parameters,
        ),
    ).n
    aggregated_pairs = first(
        DBInterface.execute(
            database,
            "SELECT COALESCE(SUM(pair_count), 0) AS n FROM pair_ratio_aggregates WHERE run_id IN ($(placeholders))",
            parameters,
        ),
    ).n
    selected_matroid_count = first(
        DBInterface.execute(
            database,
            """
            SELECT COUNT(DISTINCT s.matroid_id) AS n
            FROM selected_matroids s
            JOIN matroids m USING(matroid_id)
            WHERE m.run_id IN ($(placeholders))
            """,
            parameters,
        ),
    ).n
    selected_pair_count = first(
        DBInterface.execute(
            database,
            """
            SELECT COUNT(*) AS n
            FROM selected_pairs p
            JOIN matroids m USING(matroid_id)
            WHERE m.run_id IN ($(placeholders))
            """,
            parameters,
        ),
    ).n
    bad_alpha = first(
        DBInterface.execute(
            database,
            """
            SELECT COUNT(*) AS n
            FROM matroids m
            WHERE m.run_id IN ($(placeholders))
              AND EXISTS (
                    SELECT 1 FROM selected_pairs p WHERE p.matroid_id = m.matroid_id
                  )
              AND ABS(
                    m.alpha_value -
                    (SELECT MAX(ratio_value) FROM selected_pairs p
                     WHERE p.matroid_id = m.matroid_id)
                  ) > 1e-12
            """,
            parameters,
        ),
    ).n
    bad_denominators = first(
        DBInterface.execute(
            database,
            """
            SELECT COUNT(*) AS n
            FROM selected_pairs p
            JOIN matroids m USING(matroid_id)
            WHERE m.run_id IN ($(placeholders))
              AND (p.ratio_den <= 0 OR p.b01 <= 0 OR p.b10 <= 0)
            """,
            parameters,
        ),
    ).n
    tail = materialize(
        database,
        """
        SELECT r.source, r.ensemble, r.field_size, m.rank_value, m.source_id,
               m.num_bases, m.alpha_num, m.alpha_den, m.alpha_value,
               m.best_i, m.best_j, m.positive_pair_fraction
        FROM matroids m
        JOIN runs r USING(run_id)
        WHERE m.run_id IN ($(placeholders))
          AND m.connected = 1 AND m.alpha_num > 0
        ORDER BY m.alpha_value DESC, m.source_id
        LIMIT 10
        """,
        parameters,
    )
    figure_relative = relpath(figure_directory, dirname(path))
    export_relative = relpath(export_directory, dirname(path))
    database_relative = relpath(database_path, dirname(path))
    scope = scope_description(n, ranks)

    mkpath(dirname(path))
    open(path, "w") do output
        println(output, "# ", scope.title)
        println(output)
        println(
            output,
            "This report studies ",
            scope.prose,
            ". For every distributional table and matroid-level distribution figure, ",
            "the analysis population excludes disconnected matroids and all matroids with ",
            "zero correlation ratio; equivalently, it uses `connected = 1` and ",
            "`alpha_num > 0`.",
        )
        println(output)
        println(output, "## Reproducibility and validation")
        println(output)
        println(output, "- SQLite database: [`", basename(database_path), "`](", database_relative, ")")
        println(output, "- Stored matroid observations in this rank scope: ", total_matroids)
        println(output, "- Eligible pairs represented in aggregate tables: ", aggregated_pairs)
        println(output, "- Eligible pairs expected from matroid summaries: ", expected_pairs)
        println(output, "- Matroids selected for detailed pair profiles: ", selected_matroid_count)
        println(output, "- Detailed selected-pair rows: ", selected_pair_count)
        println(output, "- Selected matroids whose α₁ disagrees with their recomputed pair maximum: ", bad_alpha)
        println(output, "- Selected pairs with a nonpositive mixed cell or denominator: ", bad_denominators)
        println(output, "- Element labels and maximizing pairs are zero-based.")
        println(output)
        println(
            output,
            "Every matroid is stored losslessly as a packed hexadecimal form of its ",
            "polyDB-compatible `REVLEX_BASIS_ENCODING`. Decoding gives one character for ",
            "each rank-sized subset in reverse-lexicographic/colex order, with `*` for a ",
            "basis and `0` for a nonbasis. Complete pair profiles are ",
            "reproducible derived data and are retained only for selected examples.",
        )
        println(output)
        println(output, "## Runs")
        println(output)
        println(output, "| Run | Rank | Ensemble | Field | Accepted | Rejected | Seed |")
        println(output, "|---|---:|---|---:|---:|---:|---:|")
        for run in runs
            println(
                output,
                "| ", run.run_id,
                " | ", run.rank_value,
                " | ", run.ensemble,
                " | ", ismissing(run.field_size) ? "—" : run.field_size,
                " | ", run.accepted_count,
                " | ", run.rejected_count,
                " | ", ismissing(run.seed) ? "—" : run.seed,
                " |",
            )
        end
        println(output)
        println(output, "## Distribution summary")
        println(output)
        println(
            output,
            "`Included N` is the number remaining after removing disconnected and ",
            "α₁ = 0 matroids. `Excluded` reports how many stored observations were removed. ",
            "For polyDB, these are counts of matroids up to isomorphism. For finite-field ",
            "runs, they are counts of accepted projective configurations or draws, not ",
            "deduplicated isomorphism classes. For Johnson-graph runs, they are independent ",
            "labeled stable-set outputs of the stated random-priority greedy activity, not ",
            "uniform independent sets or matroid isomorphism classes.",
        )
        println(output)
        println(
            output,
            "| Ensemble | Included N | Excluded | Distinct encodings | Median α₁ | 95th percentile | Maximum | α₁ > 1, count (%) | α₁ ≥ 8/7 | α₁ ≥ 100/81 |",
        )
        println(output, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for summary in summaries
            interval = summary.positive_interval
            positive_text = string(summary.positive, " (", percent(summary.positive_fraction), ")")
            if interval[1] != interval[2]
                positive_text *= @sprintf(
                    " [95%% CI %.2f%%–%.2f%%]",
                    100interval[1],
                    100interval[2],
                )
            end
            println(
                output,
                "| ", summary.label,
                " | ", summary.included_count,
                " | ", summary.excluded_count,
                " | ", summary.distinct_encodings,
                " | ", @sprintf("%.6f", summary.median),
                " | ", @sprintf("%.6f", summary.percentile_95),
                " | ", summary.maximum_fraction,
                " (", @sprintf("%.6f", summary.maximum_value), ")",
                " | ", positive_text,
                " | ", summary.at_eight_sevenths,
                " | ", summary.at_record,
                " |",
            )
        end
        println(output)
        println(
            output,
            "The normalized histogram below uses every included observation and 45 ",
            "equal-width bins; each curve's bin masses sum to one. The staircase traces ",
            "the bin heights and is not a CDF. Since α₁ is an exact rational statistic ",
            "on a finite matroid population, many classes can share the same value. Thus ",
            "some jaggedness is genuine atomic mass, while its precise placement also ",
            "depends on the bin edges. The black dashed line is α₁ = 1, the gray dotted ",
            "line is 8/7, and the red dash-dot line is 100/81. To avoid overplotting, the ",
            "finite-field curves are split into four panels: GF(2)/GF(3) with replacement, ",
            "GF(5)/GF(7) with replacement, GF(2)/GF(3) without replacement, and ",
            "GF(5)/GF(7) without replacement. An exhaustive subset population, when ",
            "present, belongs to the corresponding without-replacement panel. Johnson ",
            "random-greedy populations are placed in separate panels with at most two ",
            "activity values each. Common bin edges make all panels directly comparable.",
        )
        println(output)
        println(
            output,
            "![Probability histogram of α₁](",
            figure_relative,
            "/alpha_histogram.png)",
        )
        println(output)
        println(output, "## Distribution after excluding sparse paving matroids")
        println(output)
        println(
            output,
            "Sparse paving matroids satisfy α₁ ≤ 1, so they cannot contribute to the ",
            "positive tail beyond 1. The table and companion histogram therefore condition ",
            "the usual connected, positive-α₁ population further on `sparse_paving = 0`. ",
            "Each histogram curve is renormalized within this smaller population; `N` in its ",
            "legend and the retained-percentage column below prevent that conditional ",
            "normalization from hiding the amount of data removed. The companion figure uses ",
            "exactly the same bin edges, panels, and reference lines as the preceding figure.",
        )
        println(output)
        println(
            output,
            "| Ensemble | Non-sparse-paving N | Retained | Median α₁ | 95th percentile | Maximum | α₁ > 1, count (%) |",
        )
        println(output, "|---|---:|---:|---:|---:|---:|---:|")
        for summary in summaries
            if summary.non_sparse_count == 0
                println(
                    output,
                    "| ", summary.label,
                    " | 0 | 0.00% | — | — | — | 0 (—) |",
                )
                continue
            end
            println(
                output,
                "| ", summary.label,
                " | ", summary.non_sparse_count,
                " | ", percent(summary.non_sparse_retained_fraction),
                " | ", @sprintf("%.6f", summary.non_sparse_median),
                " | ", @sprintf("%.6f", summary.non_sparse_percentile_95),
                " | ", summary.non_sparse_maximum_fraction,
                " (", @sprintf("%.6f", summary.non_sparse_maximum_value), ")",
                " | ", summary.non_sparse_positive,
                " (", percent(summary.non_sparse_positive_fraction), ")",
                " |",
            )
        end
        sparse_paving_above_one = sum(
            summary.sparse_paving_above_one for summary in summaries if !summary.derived;
            init=0,
        )
        println(output)
        println(
            output,
            "As a consistency check, the primary ensembles in this report contain ",
            sparse_paving_above_one,
            " stored sparse paving observation",
            sparse_paving_above_one == 1 ? "" : "s",
            " with α₁ > 1.",
        )
        println(output)
        println(
            output,
            "![Probability histogram of α₁ for non-sparse-paving matroids](",
            figure_relative,
            "/alpha_histogram_non_sparse_paving.png)",
        )
        println(output)
        println(output, "## Basis density versus α₁ after excluding sparse paving matroids")
        println(output)
        println(
            output,
            "This analysis uses the same connected, positive-α₁, non-sparse-paving ",
            "population as the preceding conditional histogram. Pearson's `r` measures ",
            "linear association, while Spearman's `ρ` uses weighted midranks and measures ",
            "monotone association. The final column is the fitted change in α₁ associated ",
            "with a 0.1 increase in basis density.",
        )
        println(output)
        println(
            output,
            "For random finite-field and Johnson-graph ensembles, the table gives two-sided ",
            "tests of zero association. Pearson intervals and tests use the Fisher ",
            "transformation; the ",
            "Spearman test uses the usual large-sample normal approximation after assigning ",
            "midranks to ties. A `census` entry means the row is polyDB or exhaustive, so its ",
            "coefficient is an exact population description and an inferential p-value would ",
            "be inappropriate. With the very large random samples here, effect sizes are more ",
            "informative than tiny p-values.",
        )
        println(output)
        println(
            output,
            "| Ensemble | N | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δα₁ per +0.1 density |",
        )
        println(output, "|---|---:|---:|---:|---:|---:|---:|---:|")
        for summary in summaries
            println(
                output,
                "| ", summary.label,
                " | ", summary.non_sparse_count,
                " | ", effect_string(summary.non_sparse_density_pearson),
                " | ", interval_string(summary.non_sparse_density_pearson_interval),
                " | ", summary.random ?
                       pvalue_string(summary.non_sparse_density_pearson_p) : "census",
                " | ", effect_string(summary.non_sparse_density_spearman),
                " | ", summary.random ?
                       pvalue_string(summary.non_sparse_density_spearman_p) : "census",
                " | ", effect_string(summary.non_sparse_density_slope_per_tenth),
                " |",
            )
        end
        println(output)
        println(
            output,
            "The scatterplots show the filtered observations and the weighted least-squares ",
            "lines used for the final table column. Legend values of `r` and all fitted lines ",
            "use every observation. Only the point clouds are thinned, at deterministic ",
            "evenly spaced indices, when a group exceeds 15,000 observations.",
        )
        println(output)
        println(
            output,
            "![Basis density versus α₁ for non-sparse-paving matroids](",
            figure_relative,
            "/basis_density_vs_alpha_non_sparse_paving.png)",
        )
        println(output)
        println(output, "## Basis density versus α₁ for sparse paving matroids")
        println(output)
        println(
            output,
            "This companion instead conditions on `sparse_paving = 1`, while retaining ",
            "the report's connected and positive-α₁ filters. `Retained` is the percentage ",
            "of that main analysis population which is sparse paving. The number of distinct ",
            "basis-density levels is included because sparse paving samples often have many ",
            "ties or only a few possible basis counts.",
        )
        println(output)
        println(
            output,
            "The coefficients, intervals, tests, and fitted effect use the same definitions ",
            "as in the preceding non-sparse-paving analysis. A dash means that the ensemble ",
            "has no retained sparse paving observations or that a coefficient is undefined ",
            "because one variable is constant. Census and exhaustive rows again receive no ",
            "inferential p-value.",
        )
        println(output)
        println(
            output,
            "| Ensemble | N | Retained | Density levels | Pearson r | 95% CI | Pearson p | Spearman ρ | Spearman p | Δα₁ per +0.1 density |",
        )
        println(output, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for summary in summaries
            pearson_p = summary.sparse_count == 0 ? "—" :
                        summary.random ? pvalue_string(summary.sparse_density_pearson_p) :
                        "census"
            spearman_p = summary.sparse_count == 0 ? "—" :
                         summary.random ? pvalue_string(summary.sparse_density_spearman_p) :
                         "census"
            println(
                output,
                "| ", summary.label,
                " | ", summary.sparse_count,
                " | ", percent(summary.sparse_retained_fraction),
                " | ", summary.sparse_distinct_density_levels,
                " | ", effect_string(summary.sparse_density_pearson),
                " | ", interval_string(summary.sparse_density_pearson_interval),
                " | ", pearson_p,
                " | ", effect_string(summary.sparse_density_spearman),
                " | ", spearman_p,
                " | ", effect_string(summary.sparse_density_slope_per_tenth),
                " |",
            )
        end
        println(output)
        println(
            output,
            "The sparse-paving plots use all observations for correlations and fitted lines ",
            "and the same deterministic 15,000-point rendering cap. Empty panels explicitly ",
            "say that no observations survived the filter. Because sparse paving matroids ",
            "satisfy α₁ ≤ 1, only the black α₁ = 1 reference line is drawn.",
        )
        println(output)
        println(
            output,
            "![Basis density versus α₁ for sparse paving matroids](",
            figure_relative,
            "/basis_density_vs_alpha_sparse_paving.png)",
        )
        println(output)
        johnson_summaries = [
            summary for summary in summaries
            if summary.source == "johnson_graph" && !summary.derived
        ]
        if !isempty(johnson_summaries)
            println(output, "## Johnson-graph sampling diagnostics")
            println(output)
            println(
                output,
                "For a stable set \$H\$ of the Johnson graph \$J(n,r)\$, the corresponding ",
                "sparse paving matroid has \$H\$ as its circuit-hyperplanes and therefore ",
                "\$\\lvert\\mathcal B(M)\\rvert=\\binom nr-\\lvert H\\rvert\$. For each draw, the ",
                "sampler traverses a fresh uniform random vertex order and selects an ",
                "available vertex with probability p. At p = 1 the resulting stable set is ",
                "maximal, which does not mean maximum. The table uses all labeled draws; ",
                "duplicate encodings remain part of the sampling distribution.",
            )
            println(output)
            println(
                output,
                "| Ensemble | Draws | Distinct encodings | Minimum \$\\lvert H\\rvert\$ | Median \$\\lvert H\\rvert\$ | Mean \$\\lvert H\\rvert\$ | Maximum \$\\lvert H\\rvert\$ | Basis-density range |",
            )
            println(output, "|---|---:|---:|---:|---:|---:|---:|---:|")
            for summary in johnson_summaries
                println(
                    output,
                    "| ", summary.label,
                    " | ", summary.structural_count,
                    " | ", summary.distinct_encodings,
                    " | ", round(Int, summary.circuit_hyperplane_minimum),
                    " | ", @sprintf("%.1f", summary.circuit_hyperplane_median),
                    " | ", @sprintf("%.3f", summary.circuit_hyperplane_mean),
                    " | ", round(Int, summary.circuit_hyperplane_maximum),
                    " | ", @sprintf(
                        "%.6f–%.6f",
                        summary.basis_density_minimum,
                        summary.basis_density_maximum,
                    ),
                    " |",
                )
            end
            println(output)
        end
        println(output, "## Structural prevalence")
        println(output)
        println(
            output,
            "This table uses the complete stored rank scope before the distribution filter, ",
            "so the connected column also documents how much of the original population is ",
            "retained for distributional analysis.",
        )
        println(output)
        println(output, "| Ensemble | N | Simple | Cosimple | Connected | 3-connected | Paving | Sparse paving |")
        println(output, "|---|---:|---:|---:|---:|---:|---:|---:|")
        for summary in summaries
            println(
                output,
                "| ", summary.label,
                " | ", summary.structural_count,
                " | ", percent(summary.simple_fraction),
                " | ", percent(summary.cosimple_fraction),
                " | ", percent(summary.connected_fraction),
                " | ", percent(summary.three_connected_fraction),
                " | ", percent(summary.paving_fraction),
                " | ", percent(summary.sparse_paving_fraction),
                " |",
            )
        end
        println(output)
        println(
            output,
            "Each row uses the same field-pair/replacement or Johnson-activity comparison ",
            "panels as the distribution figure. ",
            "The left column relates α₁ to the fraction of rank-sized subsets that are bases; ",
            "the right column compares α₁ with the fraction of eligible element pairs having ",
            "positive association. Every panel uses the connected, positive-α₁ population. ",
            "For rendering only, groups larger than 15,000 are thinned at deterministic ",
            "evenly spaced indices; summary tables and histograms remain exact.",
        )
        println(output)
        println(output, "![Matroid-level scatterplots](", figure_relative, "/matroid_scatterplots.png)")
        println(output)
        println(output, "## Pair-association distribution")
        println(output)
        println(
            output,
            "The pair histogram also uses only connected matroids with α₁ > 0. Within each ",
            "matroid, every eligible pair receives weight `1 / eligible_pair_count`, so each ",
            "matroid contributes total weight one regardless of how many eligible pairs it ",
            "has. Zero ratios cannot be shown on the logarithmic axis; their probability mass ",
            "is reported in the legend. The vertical reference lines have the same meanings as ",
            "in the α₁ histogram after taking logarithms. The panels use the same ",
            "field-pair/replacement and Johnson-activity split as the matroid-level ",
            "histogram.",
        )
        println(output)
        println(output, "![Pair log-ratio probability histogram](", figure_relative, "/pair_logratio_histogram.png)")
        println(output)
        println(
            output,
            "The next scatterplot compares the maximum odds ratio α₁ with the largest Pearson ",
            "correlation among eligible pairs. It shows whether a large odds ratio is also a ",
            "large standardized effect. It uses the same filtered population and deterministic ",
            "rendering sample as the other scatterplots, again separated into the same ",
            "comparison panels.",
        )
        println(output)
        println(output, "![Odds ratio versus Pearson correlation](", figure_relative, "/odds_ratio_vs_pearson.png)")
        println(output)
        println(output, "## Upper-tail observations")
        println(output)
        println(
            output,
            "The table lists the ten largest connected, positive-α₁ observations in this ",
            "rank scope. PolyDB rows are isomorphism-class representatives.",
        )
        println(output)
        println(output, "| Source | Rank | Field | Identifier | Bases | α₁ | Maximizing pair | Positive-pair fraction |")
        println(output, "|---|---:|---:|---|---:|---:|---|---:|")
        for row in tail
            source_label = if row.source == "polyDB"
                "polyDB"
            elseif row.source == "johnson_graph"
                @sprintf(
                    "Johnson greedy p = %.3g",
                    johnson_greedy_probability(row.ensemble),
                )
            else
                replace(row.ensemble, "_" => " ")
            end
            println(
                output,
                "| ", source_label,
                " | ", row.rank_value,
                " | ", ismissing(row.field_size) ? "—" : row.field_size,
                " | ", row.source_id,
                " | ", row.num_bases,
                " | ", fraction_string(row.alpha_num, row.alpha_den),
                " | {", row.best_i, ", ", row.best_j, "}",
                " | ", ismissing(row.positive_pair_fraction) ? "—" :
                       percent(row.positive_pair_fraction),
                " |",
            )
        end
        println(output)
        println(
            output,
            "For the maximum in each primary ensemble, the following 2×2 panel shows the raw ",
            "basis counts and, in parentheses, their normalized cell probabilities. Rows and ",
            "columns indicate exclusion or inclusion of the maximizing elements.",
        )
        println(output)
        println(output, "![Maximizing-pair contingency tables](", figure_relative, "/maximizing_pair_profiles.png)")
        println(output)
        println(
            output,
            "The final heatmap shows `log Rᵢⱼ` for every eligible element pair of the same ",
            "selected matroid. Red indicates positive association, blue negative association, ",
            "and light gray marks the diagonal or an ineligible pair. Exact zero ratios are ",
            "displayed at the plotting floor -3. Element labels match the stored zero-based ",
            "basis encoding.",
        )
        println(output)
        println(output, "![Pair heatmaps for ensemble maxima](", figure_relative, "/top_pair_heatmaps.png)")
        println(output)
        println(output, "## Data exports")
        println(output)
        println(output, "- [`runs.csv`](", export_relative, "/runs.csv)")
        println(output, "- [`selected_matroids.csv`](", export_relative, "/selected_matroids.csv)")
        println(output, "- [`selected_pairs.csv`](", export_relative, "/selected_pairs.csv)")
        println(output)
        println(
            output,
            "The SQLite tables are authoritative. Full `matroids` and ",
            "`pair_ratio_aggregates` CSV files are deliberately not retained because they ",
            "duplicate the database; `scripts/export_bulk_tables.jl` regenerates lossless ",
            "Zstandard exports on demand. Exact α₁ values, aggregate ratio keys, and ",
            "selected pair ratios use reduced integer numerators and denominators; floating-point ",
            "columns are supplied for summaries and visualization.",
        )
    end
end

"""
Export only small provenance and selected-profile tables for one scope.

Bulk matroid and aggregate exports duplicate the authoritative SQLite tables
and are intentionally omitted. Use `scripts/export_bulk_tables.jl` when a
temporary interchange file is actually needed.
"""
function write_exports(database, directory, n::Int, ranks::Vector{Int})
    mkpath(directory)
    rank_list = join(ranks, ",")
    run_scope = "n = $(n) AND rank_value IN ($(rank_list))"
    joined_scope = "r.n = $(n) AND r.rank_value IN ($(rank_list))"
    export_table_csv(
        database,
        "SELECT * FROM runs WHERE $(run_scope) ORDER BY rank_value, run_id",
        joinpath(directory, "runs.csv"),
    )
    export_table_csv(
        database,
        """
        SELECT m.run_id, m.source_id, s.*
        FROM selected_matroids s
        JOIN matroids m USING(matroid_id)
        JOIN runs r USING(run_id)
        WHERE $(joined_scope)
        ORDER BY m.rank_value, m.run_id, m.observation_index, s.selection_reason
        """,
        joinpath(directory, "selected_matroids.csv"),
    )
    export_table_csv(
        database,
        """
        SELECT m.run_id, m.source_id, p.*
        FROM selected_pairs p
        JOIN matroids m USING(matroid_id)
        JOIN runs r USING(run_id)
        WHERE $(joined_scope)
        ORDER BY m.rank_value, m.run_id, m.observation_index, p.i, p.j
        """,
        joinpath(directory, "selected_pairs.csv"),
    )
end

"""Parse report CLI arguments, export scoped data, and write report artifacts."""
function main()
    database_path = length(ARGS) >= 1 ? ARGS[1] :
                    joinpath(@__DIR__, "..", "data", "n8_r4_compact", "results.sqlite")
    report_path = length(ARGS) >= 2 ? ARGS[2] :
                  joinpath(@__DIR__, "..", "reports", "n8_r4_report.md")
    export_directory = length(ARGS) >= 3 ? ARGS[3] :
                       joinpath(@__DIR__, "..", "data", "n8_r4_compact", "exports")
    manifest_path = length(ARGS) >= 4 ? ARGS[4] :
                    joinpath(@__DIR__, "..", "data", "n8_r4_compact", "run_manifest.toml")
    figure_directory = length(ARGS) >= 5 ? ARGS[5] :
                       joinpath(@__DIR__, "..", "figures", "n8_r4_compact")
    n = length(ARGS) >= 6 ? parse(Int, ARGS[6]) : 8
    rank_scope = length(ARGS) >= 7 ? ARGS[7] : "4"

    database = init_database(database_path)
    ranks = parse_rank_scope(database, n, rank_scope)
    write_exports(database, export_directory, n, ranks)
    rank_set = Set(ranks)
    runs = [
        row for row in materialize(database, "SELECT * FROM runs ORDER BY rank_value, run_id")
        if Int(row.n) == n && Int(row.rank_value) in rank_set
    ]
    write_manifest(manifest_path, database_path, n, ranks, runs)
    write_report(
        report_path,
        database,
        database_path,
        export_directory,
        figure_directory,
        n,
        ranks,
    )
    println(
        "REPORT_COMPLETE n=",
        n,
        " ranks=",
        join(ranks, ','),
        " path=",
        report_path,
    )
end

(abspath(PROGRAM_FILE) == @__FILE__) && main()
