"""
Generate the cross-database analysis of the free-extension/free-coextension
invariant epsilon. Source SQLite files are opened read-only in practice and
are never modified. The archived n=10, rank-4 database is decompressed only
into a temporary directory.

Usage:

    julia --project=. scripts/make_epsilon_report.jl
"""

using CairoMakie
using DBInterface
using Printf
using Random
using SHA
using SQLite
using Statistics

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

const PROJECT_DIRECTORY = normpath(joinpath(@__DIR__, ".."))
const REPORT_PATH = joinpath(PROJECT_DIRECTORY, "reports", "epsilon_analysis_report.md")
const FIGURE_DIRECTORY = joinpath(PROJECT_DIRECTORY, "figures", "epsilon_analysis")
const DATA_DIRECTORY = joinpath(PROJECT_DIRECTORY, "data", "epsilon_analysis")
const RESERVOIR_SIZE = 2_000
const PLOT_RESERVOIR_SIZE = 4_000

function experiment_specs()
    return [
        (slug="n8_r4", title="n = 8, rank 4 validation data",
         database=joinpath(PROJECT_DIRECTORY, "data", "n8_r4_compact", "results.sqlite"),
         n=8, rank=4),
        (slug="n9_r2", title="n = 9, rank 2 exact census",
         database=joinpath(PROJECT_DIRECTORY, "data", "n9_census", "results.sqlite"),
         n=9, rank=2),
        (slug="n9_r3", title="n = 9, rank 3 exact census",
         database=joinpath(PROJECT_DIRECTORY, "data", "n9_census", "results.sqlite"),
         n=9, rank=3),
        (slug="n9_r4", title="n = 9, rank 4 exact census",
         database=joinpath(PROJECT_DIRECTORY, "data", "n9_census", "results.sqlite"),
         n=9, rank=4),
        (slug="n10_r4_finite_fields", title="n = 10, rank 4 finite-field data",
         database=joinpath(PROJECT_DIRECTORY, "data", "n10_finite_fields", "r4", "results.sqlite"),
         n=10, rank=4),
        (slug="n10_r5_finite_fields", title="n = 10, rank 5 finite-field data",
         database=joinpath(PROJECT_DIRECTORY, "data", "n10_finite_fields", "r5", "results.sqlite"),
         n=10, rank=5),
        (slug="n12_r6", title="n = 12, rank 6 finite-field and Johnson data",
         database=joinpath(PROJECT_DIRECTORY, "data", "n12_finite_fields", "r6", "results.sqlite"),
         n=12, rank=6),
        (slug="n10_r4_icarm", title="n = 10, rank 4 ICARM census sample",
         database=joinpath(PROJECT_DIRECTORY, "data", "icarm_n10", "r4", "results.sqlite"),
         n=10, rank=4),
        (slug="n10_r5_icarm", title="n = 10, rank 5 ICARM census sample",
         database=joinpath(PROJECT_DIRECTORY, "data", "icarm_n10", "r5", "results.sqlite"),
         n=10, rank=5),
    ]
end

function materialize(database, sql, parameters=())
    return [
        (; (name => getproperty(row, name) for name in propertynames(row))...)
        for row in DBInterface.execute(database, sql, parameters)
    ]
end

function ensemble_label(run)
    source = String(run.source)
    ensemble = String(run.ensemble)
    if source == "polyDB"
        return "polyDB isomorphism classes"
    elseif source == "ICARM_database"
        return occursin("pps_cluster", ensemble) ? "ICARM two-stage sample" :
               "ICARM simple random sample"
    elseif source == "johnson_graph"
        return @sprintf(
            "Johnson greedy p = %.3g",
            johnson_greedy_probability(ensemble),
        )
    end
    field = "GF($(run.field_size))"
    if ensemble == "projective_subsets_exhaustive"
        return field * " exhaustive, no replacement"
    elseif ensemble == "projective_points_with_replacement_random"
        return field * " random, with replacement"
    end
    return field * " random, no replacement"
end

function source_category(source)
    source == "polyDB" && return "polyDB"
    source == "finite_field" && return "finite field"
    source == "johnson_graph" && return "Johnson graph"
    source == "ICARM_database" && return "ICARM"
    return String(source)
end

function group_specs(database, experiment)
    runs = materialize(
        database,
        """
        SELECT run_id, source, ensemble, field_size, accepted_count
        FROM runs
        WHERE n = ? AND rank_value = ? AND accepted_count > 0
        ORDER BY source, field_size, ensemble, run_id
        """,
        (experiment.n, experiment.rank),
    )
    buckets = Dict{Tuple,Vector{NamedTuple}}()
    order = Tuple[]
    for run in runs
        key = (run.source, run.ensemble, run.field_size)
        if !haskey(buckets, key)
            buckets[key] = NamedTuple[]
            push!(order, key)
        end
        push!(buckets[key], run)
    end
    return [
        (
            run_ids=String[row.run_id for row in buckets[key]],
            label=ensemble_label(first(buckets[key])),
            source=String(first(buckets[key]).source),
            category=source_category(String(first(buckets[key]).source)),
        )
        for key in order
    ]
end

run_placeholders(group) = join(fill("?", length(group.run_ids)), ", ")

function stable_rng(parts...)
    digest = sha256(join(string.(parts), "|"))
    seed = zero(UInt32)
    for byte in digest[1:4]
        seed = (seed << 8) | UInt32(byte)
    end
    return MersenneTwister(seed)
end

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

function weighted_mean(values, weights)
    total = sum(Float64, weights)
    return sum(
        Float64(value) * Float64(weight)
        for (value, weight) in zip(values, weights)
    ) / total
end

function retain_smallest!(items, item, field::Symbol; limit::Int=12)
    push!(items, item)
    sort!(items; by=value -> getproperty(value, field))
    length(items) > limit && resize!(items, limit)
    return items
end

function reservoir_consider!(reservoir, item, seen::Int, rng, limit::Int)
    if length(reservoir) < limit
        push!(reservoir, item)
    else
        replacement = rand(rng, 1:seen)
        replacement <= limit && (reservoir[replacement] = item)
    end
    return reservoir
end

function row_stream(database, group)
    return DBInterface.execute(
        database,
        """
        SELECT run_id, matroid_id, source_id, census_multiplicity,
               num_bases, basis_density, basis_hex, paving, sparse_paving,
               alpha_num, alpha_den, alpha_value
        FROM matroids
        WHERE run_id IN ($(run_placeholders(group)))
          AND connected = 1 AND alpha_num > 0
        ORDER BY run_id, observation_index
        """,
        Tuple(group.run_ids),
    )
end

function analyze_group(database, experiment, group)
    @info "epsilon group" experiment=experiment.slug ensemble=group.label
    counter = EpsilonCounter(experiment.n, experiment.rank)
    epsilon_values = Float64[]
    self_sum_values = Float64[]
    defect_values = Float64[]
    q_values = Float64[]
    z_values = Float64[]
    beta_values = Float64[]
    alpha_values = Float64[]
    density_values = Float64[]
    baseline_ratios = Float64[]
    weights = Int[]
    sparse_flags = Bool[]
    reservoir = NamedTuple[]
    plot_reservoir = NamedTuple[]
    rng = stable_rng(experiment.slug, group.label, "direct")
    plot_rng = stable_rng(experiment.slug, group.label, "plot")

    row_count = 0
    weighted_count = 0
    epsilon_ge_alpha_count = 0
    epsilon_gt_one_count = 0
    alpha_gt_one_count = 0
    alpha_gt_one_epsilon_gt_one_count = 0
    epsilon_gt_one_alpha_le_one_count = 0
    sparse_epsilon_gt_one_count = 0
    sparse_count = 0
    self_sum_gt_one_count = 0
    self_sum_gt_original_count = 0
    implication_failures = NamedTuple[]
    comparison_failures = NamedTuple[]
    maximum_record = nothing
    minimum_self_sum_record = nothing
    maximum_self_sum_record = nothing
    uniform_epsilon =
        experiment.rank * (experiment.n - experiment.rank) /
        ((experiment.rank + 1) * (experiment.n - experiment.rank + 1))

    for row in row_stream(database, group)
        row_count += 1
        weight = Int(row.census_multiplicity)
        statistics = epsilon_statistics(
            counter,
            String(row.basis_hex);
            num_bases=Int(row.num_bases),
            paving=row.paving == 1,
            copaving=row.sparse_paving == 1,
        )
        epsilon = statistics.epsilon_value
        alpha = Float64(row.alpha_value)
        epsilon_numerator =
            Int128(statistics.spanning_r_plus_1) *
            Int128(statistics.independent_r_minus_1)
        epsilon_denominator =
            Int128(statistics.rank_at_least_r_minus_1) *
            Int128(statistics.num_bases)
        basis_squared = Int128(statistics.num_bases)^2
        self_sum_numerator = 4 * epsilon_numerator
        self_sum_denominator =
            2 * epsilon_denominator - basis_squared + 2 * epsilon_numerator
        self_sum_epsilon =
            Float64(self_sum_numerator) / Float64(self_sum_denominator)
        q = Float64(epsilon_numerator) / Float64(basis_squared)
        z = Float64(statistics.rank_at_least_r_minus_1) /
            Float64(statistics.num_bases)
        beta = 1 / z
        defect = z - q
        epsilon_ge_alpha =
            epsilon_numerator * Int128(row.alpha_den) >=
            epsilon_denominator * Int128(row.alpha_num)
        epsilon_gt_one = epsilon_numerator > epsilon_denominator
        self_sum_gt_one = self_sum_numerator > self_sum_denominator
        self_sum_gt_original =
            self_sum_numerator * epsilon_denominator >
            self_sum_denominator * epsilon_numerator
        alpha_gt_one = row.alpha_num > row.alpha_den
        sparse = row.sparse_paving == 1

        push!(epsilon_values, epsilon)
        push!(self_sum_values, self_sum_epsilon)
        push!(defect_values, defect)
        push!(q_values, q)
        push!(z_values, z)
        push!(beta_values, beta)
        push!(alpha_values, alpha)
        push!(density_values, Float64(row.basis_density))
        push!(baseline_ratios, epsilon / uniform_epsilon)
        push!(weights, weight)
        push!(sparse_flags, sparse)
        weighted_count += weight
        epsilon_ge_alpha_count += weight * epsilon_ge_alpha
        epsilon_gt_one_count += weight * epsilon_gt_one
        alpha_gt_one_count += weight * alpha_gt_one
        alpha_gt_one_epsilon_gt_one_count += weight * (alpha_gt_one && epsilon_gt_one)
        epsilon_gt_one_alpha_le_one_count += weight * (epsilon_gt_one && !alpha_gt_one)
        sparse_count += weight * sparse
        sparse_epsilon_gt_one_count += weight * (sparse && epsilon_gt_one)
        self_sum_gt_one_count += weight * self_sum_gt_one
        self_sum_gt_original_count += weight * self_sum_gt_original

        record = (
            experiment=experiment.slug,
            ensemble=group.label,
            category=group.category,
            run_id=String(row.run_id),
            matroid_id=Int(row.matroid_id),
            source_id=String(row.source_id),
            n=experiment.n,
            r=experiment.rank,
            independent_r_minus_1=statistics.independent_r_minus_1,
            num_bases=statistics.num_bases,
            rank_at_least_r_minus_1=statistics.rank_at_least_r_minus_1,
            spanning_r_plus_1=statistics.spanning_r_plus_1,
            epsilon=epsilon,
            epsilon_exact=statistics.epsilon,
            self_sum_epsilon=self_sum_epsilon,
            self_sum_epsilon_exact=
                BigInt(self_sum_numerator) // BigInt(self_sum_denominator),
            defect=defect,
            q=q,
            z=z,
            beta=beta,
            alpha_num=Int(row.alpha_num),
            alpha_den=Int(row.alpha_den),
            alpha=alpha,
            density=Float64(row.basis_density),
            sparse=sparse,
        )
        reservoir_consider!(reservoir, record, row_count, rng, RESERVOIR_SIZE)
        reservoir_consider!(
            plot_reservoir,
            (epsilon=epsilon, alpha=alpha, experiment=experiment.slug),
            row_count,
            plot_rng,
            PLOT_RESERVOIR_SIZE,
        )
        if maximum_record === nothing || epsilon > maximum_record.epsilon
            maximum_record = record
        end
        if minimum_self_sum_record === nothing ||
           self_sum_epsilon < minimum_self_sum_record.self_sum_epsilon
            minimum_self_sum_record = record
        end
        if maximum_self_sum_record === nothing ||
           self_sum_epsilon > maximum_self_sum_record.self_sum_epsilon
            maximum_self_sum_record = record
        end
        if alpha_gt_one && !epsilon_gt_one
            retain_smallest!(implication_failures, record, :epsilon)
        end
        if !epsilon_ge_alpha
            retain_smallest!(
                comparison_failures,
                merge(record, (difference=epsilon - alpha,)),
                :difference,
            )
        end
    end

    row_count > 0 || error("empty epsilon group $(experiment.slug), $(group.label)")
    sparse_indices = findall(identity, sparse_flags)
    nonsparse_indices = findall(!, sparse_flags)
    return (
        experiment=experiment.slug,
        title=experiment.title,
        n=experiment.n,
        r=experiment.rank,
        ensemble=group.label,
        source=group.source,
        category=group.category,
        row_count=row_count,
        count=weighted_count,
        mean=weighted_mean(epsilon_values, weights),
        median=weighted_quantile(epsilon_values, weights, 0.50),
        p05=weighted_quantile(epsilon_values, weights, 0.05),
        p95=weighted_quantile(epsilon_values, weights, 0.95),
        maximum=maximum_record.epsilon,
        maximum_exact=maximum_record.epsilon_exact,
        maximum_record=maximum_record,
        epsilon_ge_alpha=epsilon_ge_alpha_count,
        epsilon_gt_one=epsilon_gt_one_count,
        alpha_gt_one=alpha_gt_one_count,
        alpha_gt_one_epsilon_gt_one=alpha_gt_one_epsilon_gt_one_count,
        epsilon_gt_one_alpha_le_one=epsilon_gt_one_alpha_le_one_count,
        sparse_count=sparse_count,
        sparse_epsilon_gt_one=sparse_epsilon_gt_one_count,
        sparse_median=isempty(sparse_indices) ? missing :
            weighted_quantile(epsilon_values[sparse_indices], weights[sparse_indices], 0.50),
        nonsparse_median=isempty(nonsparse_indices) ? missing :
            weighted_quantile(epsilon_values[nonsparse_indices], weights[nonsparse_indices], 0.50),
        alpha_spearman=weighted_spearman(epsilon_values, alpha_values, weights),
        density_spearman=weighted_spearman(epsilon_values, density_values, weights),
        median_uniform_multiple=weighted_quantile(baseline_ratios, weights, 0.50),
        self_sum_mean=weighted_mean(self_sum_values, weights),
        self_sum_p05=weighted_quantile(self_sum_values, weights, 0.05),
        self_sum_median=weighted_quantile(self_sum_values, weights, 0.50),
        self_sum_p95=weighted_quantile(self_sum_values, weights, 0.95),
        self_sum_minimum=minimum_self_sum_record.self_sum_epsilon,
        self_sum_minimum_exact=minimum_self_sum_record.self_sum_epsilon_exact,
        self_sum_minimum_record=minimum_self_sum_record,
        self_sum_maximum=maximum_self_sum_record.self_sum_epsilon,
        self_sum_maximum_exact=maximum_self_sum_record.self_sum_epsilon_exact,
        self_sum_maximum_record=maximum_self_sum_record,
        self_sum_gt_one=self_sum_gt_one_count,
        self_sum_gt_original=self_sum_gt_original_count,
        defect_mean=weighted_mean(defect_values, weights),
        defect_p05=weighted_quantile(defect_values, weights, 0.05),
        defect_median=weighted_quantile(defect_values, weights, 0.50),
        defect_p95=weighted_quantile(defect_values, weights, 0.95),
        beta_mean=weighted_mean(beta_values, weights),
        beta_median=weighted_quantile(beta_values, weights, 0.50),
        self_sum_defect_spearman=
            weighted_spearman(self_sum_values, defect_values, weights),
        self_sum_q_spearman=
            weighted_spearman(self_sum_values, q_values, weights),
        self_sum_z_spearman=
            weighted_spearman(self_sum_values, z_values, weights),
        self_sum_beta_spearman=
            weighted_spearman(self_sum_values, beta_values, weights),
        self_sum_original_spearman=
            weighted_spearman(self_sum_values, epsilon_values, weights),
        self_sum_alpha_spearman=
            weighted_spearman(self_sum_values, alpha_values, weights),
        self_sum_density_spearman=
            weighted_spearman(self_sum_values, density_values, weights),
        implication_failures=implication_failures,
        comparison_failures=comparison_failures,
        reservoir=reservoir,
        plot_reservoir=plot_reservoir,
    )
end

function analyze_materialized_experiment(experiment, database_path)
    database = SQLite.DB(database_path)
    try
        return [
            analyze_group(database, experiment, group)
            for group in group_specs(database, experiment)
        ]
    finally
        close(database)
    end
end

function analyze_experiment(experiment)
    if isfile(experiment.database)
        return analyze_materialized_experiment(experiment, experiment.database)
    end
    archive = experiment.database * ".zst"
    isfile(archive) || error("missing $(experiment.database) and $archive")
    return mktempdir() do directory
        temporary_database = joinpath(directory, "results.sqlite")
        open(temporary_database, "w") do output
            run(pipeline(`zstd -q -d -c $archive`; stdout=output))
        end
        analyze_materialized_experiment(experiment, temporary_database)
    end
end

function larger_alpha(first, second)
    left = Int128(first.alpha_num) * Int128(second.alpha_den)
    right = Int128(second.alpha_num) * Int128(first.alpha_den)
    return left >= right ? (first.alpha_num, first.alpha_den) :
           (second.alpha_num, second.alpha_den)
end

function direct_sum_observation(first, second)
    i1 = Int128(first.independent_r_minus_1)
    b1 = Int128(first.num_bases)
    a1 = Int128(first.rank_at_least_r_minus_1)
    s1 = Int128(first.spanning_r_plus_1)
    i2 = Int128(second.independent_r_minus_1)
    b2 = Int128(second.num_bases)
    a2 = Int128(second.rank_at_least_r_minus_1)
    s2 = Int128(second.spanning_r_plus_1)
    bases = b1 * b2
    independent = i1 * b2 + b1 * i2
    spanning = s1 * b2 + b1 * s2
    almost_bases =
        a1 * b2 + b1 * a2 - b1 * b2 + s1 * i2 + i1 * s2
    epsilon_numerator = spanning * independent
    epsilon_denominator = almost_bases * bases
    alpha_num, alpha_den = larger_alpha(first, second)
    if alpha_num < alpha_den
        alpha_num, alpha_den = 1, 1
    end
    epsilon = Float64(epsilon_numerator) / Float64(epsilon_denominator)
    alpha = alpha_num / alpha_den
    return (
        epsilon=epsilon,
        alpha=alpha,
        epsilon_ge_alpha=
            epsilon_numerator * Int128(alpha_den) >=
            epsilon_denominator * Int128(alpha_num),
        epsilon_gt_one=epsilon_numerator > epsilon_denominator,
        alpha_gt_one=alpha_num > alpha_den,
        epsilon_gt_both=
            epsilon_numerator * (a1 * b1) >
            epsilon_denominator * (s1 * i1) &&
            epsilon_numerator * (a2 * b2) >
            epsilon_denominator * (s2 * i2),
        first=first,
        second=second,
    )
end

function select_group(rng, groups, selection::Symbol)
    selection == :balanced && return rand(rng, groups)
    total = sum(group.row_count for group in groups)
    draw = rand(rng, 1:total)
    cumulative = 0
    for group in groups
        cumulative += group.row_count
        draw <= cumulative && return group
    end
    return last(groups)
end

select_record(rng, group) = rand(rng, group.reservoir)

function direct_sum_scenarios(groups)
    specifications = [
        (label="All cells, stored-observation weighted", category=nothing,
         selection=:weighted, same_group=false, draws=500_000),
        (label="All cells, ensemble-cell balanced", category=nothing,
         selection=:balanced, same_group=false, draws=250_000),
        (label="Within the same ensemble cell", category=nothing,
         selection=:weighted, same_group=true, draws=300_000),
        (label="polyDB only", category="polyDB",
         selection=:weighted, same_group=false, draws=200_000),
        (label="Finite-field cells only", category="finite field",
         selection=:weighted, same_group=false, draws=300_000),
        (label="Johnson-graph cells only", category="Johnson graph",
         selection=:weighted, same_group=false, draws=100_000),
        (label="ICARM samples only", category="ICARM",
         selection=:weighted, same_group=false, draws=100_000),
    ]
    return [
        merge(
            specification,
            (
                groups=specification.category === nothing ? groups :
                    filter(group -> group.category == specification.category, groups),
            ),
        )
        for specification in specifications
    ]
end

function analyze_direct_sum_scenario(specification)
    isempty(specification.groups) && error(
        "no groups in direct-sum scenario $(specification.label)",
    )
    @info "direct-sum scenario" label=specification.label draws=specification.draws
    rng = stable_rng("direct sum", specification.label)
    epsilon_values = Vector{Float64}(undef, specification.draws)
    alpha_values = Vector{Float64}(undef, specification.draws)
    epsilon_ge_alpha = 0
    epsilon_gt_one = 0
    alpha_gt_one = 0
    alpha_gt_one_epsilon_gt_one = 0
    epsilon_gt_one_alpha_le_one = 0
    epsilon_gt_both = 0
    failures = NamedTuple[]
    plot_reservoir = NamedTuple[]
    for draw in 1:specification.draws
        first_group = select_group(rng, specification.groups, specification.selection)
        second_group = specification.same_group ? first_group :
                       select_group(rng, specification.groups, specification.selection)
        first = select_record(rng, first_group)
        second = select_record(rng, second_group)
        observation = direct_sum_observation(first, second)
        epsilon_values[draw] = observation.epsilon
        alpha_values[draw] = observation.alpha
        epsilon_ge_alpha += observation.epsilon_ge_alpha
        epsilon_gt_one += observation.epsilon_gt_one
        alpha_gt_one += observation.alpha_gt_one
        alpha_gt_one_epsilon_gt_one +=
            observation.alpha_gt_one && observation.epsilon_gt_one
        epsilon_gt_one_alpha_le_one +=
            observation.epsilon_gt_one && !observation.alpha_gt_one
        epsilon_gt_both += observation.epsilon_gt_both
        if observation.alpha_gt_one && !observation.epsilon_gt_one
            failure = (
                epsilon=observation.epsilon,
                alpha=observation.alpha,
                first=first,
                second=second,
            )
            retain_smallest!(failures, failure, :epsilon)
        end
        reservoir_consider!(
            plot_reservoir,
            (epsilon=observation.epsilon, alpha=observation.alpha,
             scenario=specification.label),
            draw,
            rng,
            5_000,
        )
    end
    return (
        label=specification.label,
        category=specification.category,
        draws=specification.draws,
        mean=mean(epsilon_values),
        median=median(epsilon_values),
        p05=quantile(epsilon_values, 0.05),
        p95=quantile(epsilon_values, 0.95),
        maximum=maximum(epsilon_values),
        epsilon_ge_alpha=epsilon_ge_alpha,
        epsilon_gt_one=epsilon_gt_one,
        alpha_gt_one=alpha_gt_one,
        alpha_gt_one_epsilon_gt_one=alpha_gt_one_epsilon_gt_one,
        epsilon_gt_one_alpha_le_one=epsilon_gt_one_alpha_le_one,
        epsilon_gt_both=epsilon_gt_both,
        alpha_spearman=weighted_spearman(
            epsilon_values,
            alpha_values,
            ones(Int, specification.draws),
        ),
        failures=failures,
        plot_reservoir=plot_reservoir,
    )
end

function hsw_columns(p::Int; d::Int=5)
    columns = Vector{Vector{Int}}()
    tip = zeros(Int, d)
    tip[1] = 1
    push!(columns, tip)
    distinguished = zeros(Int, d)
    distinguished[2:end] .= 1
    push!(columns, distinguished)
    for coordinate in 2:d
        for coefficient in 1:p
            column = zeros(Int, d)
            column[1] = mod(coefficient, p)
            column[coordinate] = 1
            push!(columns, column)
        end
    end
    return columns
end

function alpha_one_from_encoding(encoding, n::Int, r::Int)
    masks = colex_masks(n, r)
    degrees = zeros(Int, n)
    codegrees = zeros(Int, n, n)
    number_of_bases = 0
    for index in eachindex(masks)
        codeunit(encoding, index) == UInt8('*') || continue
        number_of_bases += 1
        elements = Int[]
        inside = masks[index]
        while inside != 0
            bit = inside & (-inside)
            element = trailing_zeros(bit) + 1
            push!(elements, element)
            degrees[element] += 1
            inside ⊻= bit
        end
        for left in 1:length(elements)-1, right in left+1:length(elements)
            i = elements[left]
            j = elements[right]
            codegrees[i, j] += 1
        end
    end

    best_numerator = BigInt(0)
    best_denominator = BigInt(1)
    for i in 1:n-1, j in i+1:n
        b11 = codegrees[i, j]
        b10 = degrees[i] - b11
        b01 = degrees[j] - b11
        b00 = number_of_bases - b11 - b10 - b01
        b10 > 0 && b01 > 0 || continue
        numerator_value = BigInt(b00) * BigInt(b11)
        denominator_value = BigInt(b10) * BigInt(b01)
        if numerator_value * best_denominator >
           best_numerator * denominator_value
            best_numerator = numerator_value
            best_denominator = denominator_value
        end
    end
    return best_numerator // best_denominator
end

function analyze_hsw_family()
    results = NamedTuple[]
    for p in (2, 3, 5, 7)
        @info "HSW 8/7 family" p=p
        columns = hsw_columns(p)
        n = length(columns)
        encoding = encoding_from_columns(columns, p, 5)
        counter = EpsilonCounter(n, 5)
        epsilon = epsilon_statistics(
            counter,
            basis_hex(encoding);
            num_bases=count(==('*'), encoding),
        )
        self_sum = direct_sum_epsilon_statistics(epsilon, epsilon)
        alpha = alpha_one_from_encoding(encoding, n, 5)
        push!(results, (
            family="HSW finite-field spike",
            parameter=p,
            field="GF($p)",
            n=n,
            r=5,
            num_bases=epsilon.num_bases,
            independent_r_minus_1=epsilon.independent_r_minus_1,
            rank_at_least_r_minus_1=epsilon.rank_at_least_r_minus_1,
            spanning_r_plus_1=epsilon.spanning_r_plus_1,
            alpha=alpha,
            epsilon=epsilon.epsilon,
            epsilon_value=epsilon.epsilon_value,
            epsilon_ge_alpha=epsilon.epsilon >= alpha,
            epsilon_gt_one=epsilon.epsilon > 1,
            self_sum_epsilon=self_sum.epsilon,
            self_sum_epsilon_value=self_sum.epsilon_value,
        ))
        encoding = nothing
        counter = nothing
        GC.gc()
    end
    return results
end

function benchmark_100_81_columns()
    rows = [
        [1, 2, 1, 2, 2, 2, 1, 1, 0, 0, 1, 2],
        [0, 0, 2, 0, 0, 0, 0, 0, 2, 1, 1, 1],
        [0, 1, 1, 1, 0, 1, 1, 2, 1, 1, 1, 2],
        [1, 1, 1, 2, 2, 1, 1, 2, 1, 1, 0, 1],
        [0, 1, 0, 1, 2, 1, 1, 0, 2, 0, 1, 0],
        [0, 1, 1, 1, 1, 0, 2, 0, 0, 1, 0, 0],
    ]
    return [[rows[row][column] for row in 1:6] for column in 1:12]
end

function analyze_known_families()
    results = analyze_hsw_family()
    columns = benchmark_100_81_columns()
    encoding = encoding_from_columns(columns, 3, 6)
    epsilon = epsilon_statistics(encoding, 12, 6)
    alpha = alpha_one_from_encoding(encoding, 12, 6)
    epsilon.num_bases == 684 || error("unexpected basis count for 100/81 benchmark")
    alpha == 100 // 81 || error("unexpected alpha_1 for 100/81 benchmark")
    self_sum = direct_sum_epsilon_statistics(epsilon, epsilon)
    push!(results, (
        family="Supplied 100/81 benchmark",
        parameter="GF(3) matrix",
        field="GF(3)",
        n=12,
        r=6,
        num_bases=epsilon.num_bases,
        independent_r_minus_1=epsilon.independent_r_minus_1,
        rank_at_least_r_minus_1=epsilon.rank_at_least_r_minus_1,
        spanning_r_plus_1=epsilon.spanning_r_plus_1,
        alpha=alpha,
        epsilon=epsilon.epsilon,
        epsilon_value=epsilon.epsilon_value,
        epsilon_ge_alpha=epsilon.epsilon >= alpha,
        epsilon_gt_one=epsilon.epsilon > 1,
        self_sum_epsilon=self_sum.epsilon,
        self_sum_epsilon_value=self_sum.epsilon_value,
    ))
    return results
end

function csv_cell(value)
    (value === missing || value === nothing) && return ""
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

function write_csv(path, headers, rows)
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, join(headers, ','))
        for row in rows
            println(output, join(csv_cell.(row), ','))
        end
    end
    return path
end

function write_individual_summary_csv(path, groups)
    headers = [
        "experiment", "n", "rank", "ensemble", "source_category", "count",
        "mean_epsilon", "p05_epsilon", "median_epsilon", "p95_epsilon",
        "maximum_epsilon", "maximum_epsilon_exact", "epsilon_ge_alpha_count",
        "epsilon_gt_one_count", "alpha_gt_one_count",
        "alpha_gt_one_and_epsilon_gt_one_count",
        "epsilon_gt_one_and_alpha_le_one_count", "sparse_count",
        "sparse_epsilon_gt_one_count", "sparse_median_epsilon",
        "nonsparse_median_epsilon", "epsilon_alpha_spearman",
        "epsilon_density_spearman", "median_uniform_epsilon_multiple",
        "self_sum_mean", "self_sum_p05", "self_sum_median",
        "self_sum_p95", "self_sum_minimum", "self_sum_minimum_exact",
        "self_sum_maximum", "self_sum_maximum_exact",
        "self_sum_gt_one_count", "self_sum_gt_original_count",
        "defect_mean", "defect_p05", "defect_median", "defect_p95",
        "basis_purity_mean", "basis_purity_median",
        "self_sum_defect_spearman", "self_sum_q_spearman",
        "self_sum_z_spearman", "self_sum_basis_purity_spearman",
        "self_sum_original_spearman", "self_sum_alpha_spearman",
        "self_sum_density_spearman",
    ]
    rows = [
        Any[
            group.experiment, group.n, group.r, group.ensemble, group.category,
            group.count, group.mean, group.p05, group.median, group.p95,
            group.maximum, group.maximum_exact, group.epsilon_ge_alpha,
            group.epsilon_gt_one, group.alpha_gt_one,
            group.alpha_gt_one_epsilon_gt_one,
            group.epsilon_gt_one_alpha_le_one, group.sparse_count,
            group.sparse_epsilon_gt_one, group.sparse_median,
            group.nonsparse_median, group.alpha_spearman,
            group.density_spearman, group.median_uniform_multiple,
            group.self_sum_mean, group.self_sum_p05, group.self_sum_median,
            group.self_sum_p95, group.self_sum_minimum,
            group.self_sum_minimum_exact, group.self_sum_maximum,
            group.self_sum_maximum_exact, group.self_sum_gt_one,
            group.self_sum_gt_original, group.defect_mean, group.defect_p05,
            group.defect_median, group.defect_p95,
            group.beta_mean, group.beta_median,
            group.self_sum_defect_spearman, group.self_sum_q_spearman,
            group.self_sum_z_spearman, group.self_sum_beta_spearman,
            group.self_sum_original_spearman,
            group.self_sum_alpha_spearman,
            group.self_sum_density_spearman,
        ]
        for group in groups
    ]
    return write_csv(path, headers, rows)
end

function write_direct_sum_csv(path, summaries)
    headers = [
        "scenario", "draws", "mean_epsilon", "p05_epsilon", "median_epsilon",
        "p95_epsilon", "maximum_epsilon", "epsilon_ge_alpha_count",
        "epsilon_gt_one_count", "alpha_gt_one_count",
        "alpha_gt_one_and_epsilon_gt_one_count",
        "epsilon_gt_one_and_alpha_le_one_count", "epsilon_gt_both_summands_count",
        "epsilon_alpha_spearman",
    ]
    rows = [
        Any[
            summary.label, summary.draws, summary.mean, summary.p05, summary.median,
            summary.p95, summary.maximum, summary.epsilon_ge_alpha,
            summary.epsilon_gt_one, summary.alpha_gt_one,
            summary.alpha_gt_one_epsilon_gt_one,
            summary.epsilon_gt_one_alpha_le_one, summary.epsilon_gt_both,
            summary.alpha_spearman,
        ]
        for summary in summaries
    ]
    return write_csv(path, headers, rows)
end

function write_family_csv(path, family)
    headers = [
        "family", "parameter", "field", "n", "rank", "num_bases",
        "independent_r_minus_1", "rank_at_least_r_minus_1",
        "spanning_r_plus_1", "alpha_one", "epsilon", "epsilon_value",
        "epsilon_ge_alpha", "epsilon_gt_one", "self_sum_epsilon",
        "self_sum_epsilon_value",
    ]
    rows = [
        Any[
            row.family, row.parameter, row.field, row.n, row.r, row.num_bases,
            row.independent_r_minus_1, row.rank_at_least_r_minus_1,
            row.spanning_r_plus_1, row.alpha, row.epsilon, row.epsilon_value,
            row.epsilon_ge_alpha, row.epsilon_gt_one, row.self_sum_epsilon,
            row.self_sum_epsilon_value,
        ]
        for row in family
    ]
    return write_csv(path, headers, rows)
end

function write_extrema_csv(path, groups)
    headers = [
        "kind", "experiment", "ensemble", "run_id", "matroid_id", "source_id",
        "n", "rank", "num_bases", "alpha", "epsilon", "epsilon_exact",
    ]
    rows = Vector{Vector{Any}}()
    for group in groups
        maximum = group.maximum_record
        push!(rows, Any[
            "group maximum epsilon", maximum.experiment, maximum.ensemble,
            maximum.run_id, maximum.matroid_id, maximum.source_id, maximum.n,
            maximum.r, maximum.num_bases, maximum.alpha, maximum.epsilon,
            maximum.epsilon_exact,
        ])
        for record in group.implication_failures
            push!(rows, Any[
                "alpha_gt_one_epsilon_le_one", record.experiment, record.ensemble,
                record.run_id, record.matroid_id, record.source_id, record.n,
                record.r, record.num_bases, record.alpha, record.epsilon,
                record.epsilon_exact,
            ])
        end
    end
    return write_csv(path, headers, rows)
end

function make_individual_figure(groups)
    mkpath(FIGURE_DIRECTORY)
    experiments = unique(group.experiment for group in groups)
    palette = [
        :steelblue, :darkorange, :seagreen, :mediumpurple, :firebrick,
        :goldenrod, :teal, :deeppink, :gray35,
    ]
    figure = Figure(size=(1050, 760))
    axis = Axis(
        figure[1, 1];
        xlabel="α₁(M)",
        ylabel="ε(M)",
        title="Stored matroids: ε versus α₁ (deterministic display reservoirs)",
    )
    all_points = reduce(vcat, (group.plot_reservoir for group in groups); init=NamedTuple[])
    for (index, experiment) in enumerate(experiments)
        points = filter(point -> point.experiment == experiment, all_points)
        scatter!(
            axis,
            Float64[point.alpha for point in points],
            Float64[point.epsilon for point in points];
            color=(palette[mod1(index, length(palette))], 0.22),
            markersize=4,
            label=experiment,
        )
    end
    lower = min(
        minimum(point.alpha for point in all_points),
        minimum(point.epsilon for point in all_points),
        1.0,
    )
    upper = max(
        maximum(point.alpha for point in all_points),
        maximum(point.epsilon for point in all_points),
        1.0,
    )
    padding = 0.03 * (upper - lower)
    lines!(axis, [lower - padding, upper + padding], [lower - padding, upper + padding];
           color=:black, linestyle=:dash, linewidth=1.5, label="ε = α₁")
    vlines!(axis, [1.0]; color=:gray40, linestyle=:dot, linewidth=1.2)
    hlines!(axis, [1.0]; color=:gray40, linestyle=:dot, linewidth=1.2)
    xlims!(axis, lower - padding, upper + padding)
    ylims!(axis, lower - padding, upper + padding)
    axislegend(axis; position=:rb, framevisible=true)
    save(
        joinpath(FIGURE_DIRECTORY, "epsilon_vs_alpha.png"),
        figure;
        px_per_unit=2,
    )
end

function make_direct_sum_figure(summaries)
    mkpath(FIGURE_DIRECTORY)
    palette = [:steelblue, :darkorange, :seagreen, :mediumpurple,
               :firebrick, :goldenrod, :teal]
    figure = Figure(size=(1050, 760))
    axis = Axis(
        figure[1, 1];
        xlabel="α₁(M₁ ⊕ M₂)",
        ylabel="ε(M₁ ⊕ M₂)",
        title="Direct sums: deterministic empirical pair samples",
    )
    all_points = reduce(vcat, (summary.plot_reservoir for summary in summaries);
                        init=NamedTuple[])
    for (index, summary) in enumerate(summaries)
        points = summary.plot_reservoir
        scatter!(
            axis,
            Float64[point.alpha for point in points],
            Float64[point.epsilon for point in points];
            color=(palette[mod1(index, length(palette))], 0.22),
            markersize=4,
            label=summary.label,
        )
    end
    lower = min(
        minimum(point.alpha for point in all_points),
        minimum(point.epsilon for point in all_points),
        1.0,
    )
    upper = max(
        maximum(point.alpha for point in all_points),
        maximum(point.epsilon for point in all_points),
        1.0,
    )
    padding = 0.03 * (upper - lower)
    lines!(axis, [lower - padding, upper + padding], [lower - padding, upper + padding];
           color=:black, linestyle=:dash, linewidth=1.5, label="ε = α₁")
    vlines!(axis, [1.0]; color=:gray40, linestyle=:dot, linewidth=1.2)
    hlines!(axis, [1.0]; color=:gray40, linestyle=:dot, linewidth=1.2)
    xlims!(axis, lower - padding, upper + padding)
    ylims!(axis, lower - padding, upper + padding)
    axislegend(axis; position=:rb, framevisible=true)
    save(
        joinpath(FIGURE_DIRECTORY, "direct_sum_epsilon_vs_alpha.png"),
        figure;
        px_per_unit=2,
    )
end

function make_self_sum_figure(groups)
    mkpath(FIGURE_DIRECTORY)
    experiments = unique(group.experiment for group in groups)
    palette = [
        :steelblue, :darkorange, :seagreen, :mediumpurple, :firebrick,
        :goldenrod, :teal, :deeppink, :gray35,
    ]
    figure = Figure(size=(1680, 520))
    defect_axis = Axis(
        figure[1, 1];
        xlabel="Δ(M) = a/b - is/b²",
        ylabel="ε(M ⊕ M)",
        title="Self-sum versus normalized defect",
    )
    original_axis = Axis(
        figure[1, 2];
        xlabel="ε(M)",
        ylabel="ε(M ⊕ M)",
        title="Self-sum versus original invariant",
    )
    alpha_axis = Axis(
        figure[1, 3];
        xlabel="α₁(M)",
        ylabel="ε(M ⊕ M)",
        title="Self-sum versus α₁",
    )
    for (index, experiment) in enumerate(experiments)
        points = reduce(
            vcat,
            (
                filter(record -> record.experiment == experiment, group.reservoir)
                for group in groups
            );
            init=NamedTuple[],
        )
        color = (palette[mod1(index, length(palette))], 0.20)
        scatter!(
            defect_axis,
            Float64[point.defect for point in points],
            Float64[point.self_sum_epsilon for point in points];
            color=color,
            markersize=4,
            label=experiment,
        )
        scatter!(
            original_axis,
            Float64[point.epsilon for point in points],
            Float64[point.self_sum_epsilon for point in points];
            color=color,
            markersize=4,
        )
        scatter!(
            alpha_axis,
            Float64[point.alpha for point in points],
            Float64[point.self_sum_epsilon for point in points];
            color=color,
            markersize=4,
        )
    end
    vlines!(defect_axis, [0.5]; color=:black, linestyle=:dash, linewidth=1.5)
    hlines!(defect_axis, [1.0]; color=:gray40, linestyle=:dot, linewidth=1.2)
    hlines!(original_axis, [1.0]; color=:gray40, linestyle=:dot, linewidth=1.2)
    hlines!(alpha_axis, [1.0]; color=:gray40, linestyle=:dot, linewidth=1.2)
    axislegend(defect_axis; position=:lb, framevisible=true, nbanks=2)
    save(
        joinpath(FIGURE_DIRECTORY, "self_sum_epsilon_vs_defect.png"),
        figure;
        px_per_unit=2,
    )
end

fixed(value; digits::Int=6) =
    ismissing(value) ? "—" : @sprintf("%.*f", digits, value)
percent(numerator_value, denominator_value) =
    denominator_value == 0 ? "—" :
    @sprintf("%.2f%%", 100 * numerator_value / denominator_value)
fraction_string(value::Rational) =
    denominator(value) == 1 ? string(numerator(value)) :
    "$(numerator(value))/$(denominator(value))"

function implication_cell(successes, total)
    total == 0 && return "—"
    return "$(successes)/$(total) ($(percent(successes, total)))"
end

function integer_partitions(total::Int, cap::Int=total)
    total == 0 && return [Int[]]
    partitions = Vector{Vector{Int}}()
    for first_part in min(total, cap):-1:1
        for tail in integer_partitions(total - first_part, first_part)
            push!(partitions, vcat(first_part, tail))
        end
    end
    return partitions
end

function rank_two_parallel_profile(parts)
    n = sum(parts)
    bases = (n^2 - sum(part^2 for part in parts)) ÷ 2
    independent = n
    almost_bases = binomial(n, 2)
    spanning =
        binomial(n, 3) - sum(binomial(part, 3) for part in parts)
    statistics = (
        independent_r_minus_1=independent,
        num_bases=bases,
        rank_at_least_r_minus_1=almost_bases,
        spanning_r_plus_1=spanning,
    )
    return statistics, direct_sum_epsilon_statistics(statistics, statistics)
end

function analyze_rank_two_parallel_classes()
    results = NamedTuple[]
    for n in 3:30
        candidates = [
            (
                parts=parts,
                self_sum=last(rank_two_parallel_profile(parts)).epsilon,
            )
            for parts in integer_partitions(n)
            if length(parts) >= 3
        ]
        push!(results, (
            n=n,
            minimum=argmin(row -> row.self_sum, candidates),
            maximum=argmax(row -> row.self_sum, candidates),
        ))
    end
    return results
end


function write_report(path, groups, direct_sums, family)
    total = sum(group.count for group in groups)
    epsilon_ge_alpha = sum(group.epsilon_ge_alpha for group in groups)
    alpha_gt_one = sum(group.alpha_gt_one for group in groups)
    implication_successes =
        sum(group.alpha_gt_one_epsilon_gt_one for group in groups)
    converse_only =
        sum(group.epsilon_gt_one_alpha_le_one for group in groups)
    sparse_count = sum(group.sparse_count for group in groups)
    sparse_epsilon_gt_one = sum(group.sparse_epsilon_gt_one for group in groups)
    self_sum_gt_one = sum(group.self_sum_gt_one for group in groups)
    self_sum_gt_original = sum(group.self_sum_gt_original for group in groups)
    minimum_self_sum = argmin(
        record -> record.self_sum_epsilon,
        [group.self_sum_minimum_record for group in groups],
    )
    maximum_self_sum = argmax(
        record -> record.self_sum_epsilon,
        [group.self_sum_maximum_record for group in groups],
    )
    hsw_family = filter(row -> row.family == "HSW finite-field spike", family)
    benchmark_100_81 = only(
        filter(row -> row.family == "Supplied 100/81 benchmark", family),
    )
    rank_two_families = analyze_rank_two_parallel_classes()
    finite_field_groups =
        filter(group -> group.category == "finite field", groups)
    finite_density_correlation_range = extrema(
        group.self_sum_density_spearman for group in finite_field_groups
    )
    finite_beta_correlation_range = extrema(
        group.self_sum_beta_spearman for group in finite_field_groups
    )
    finite_original_correlation_range = extrema(
        group.self_sum_original_spearman for group in finite_field_groups
    )
    finite_alpha_correlation_range = extrema(
        group.self_sum_alpha_spearman for group in finite_field_groups
    )
    implication_failures = reduce(
        vcat,
        (group.implication_failures for group in groups);
        init=NamedTuple[],
    )
    comparison_failures = reduce(
        vcat,
        (group.comparison_failures for group in groups);
        init=NamedTuple[],
    )
    sort!(implication_failures; by=record -> record.epsilon)
    sort!(comparison_failures; by=record -> record.difference)
    weighted_direct = first(direct_sums)

    mkpath(dirname(path))
    open(path, "w") do output
        println(output, "# The free-extension/free-coextension invariant \$\\epsilon(M)\$")
        println(output)
        println(output, "_Generated deterministically from the project databases on 2026-08-02._")
        println(output)
        println(output, "## Executive summary")
        println(output)
        println(
            output,
            "The exhaustive single-matroid pass evaluated **", total,
            "** stored observations or census classes in **", length(groups),
            "** ensemble cells. This is a bookkeeping total across distinct sampling ",
            "laws, not a uniform sample from a universal population of matroids.",
        )
        println(output)
        println(
            output,
            "- \$\\epsilon(M)\\geq\\alpha_1(M)\$ for **", epsilon_ge_alpha,
            "** of **", total, "** observations (",
            percent(epsilon_ge_alpha, total), ").",
        )
        println(
            output,
            "- Among **", alpha_gt_one,
            "** observations with \$\\alpha_1(M)>1\$, **", implication_successes,
            "** have \$\\epsilon(M)>1\$ (",
            percent(implication_successes, alpha_gt_one), ").",
        )
        println(
            output,
            "- The converse occurs **", converse_only,
            "** times: \$\\epsilon(M)>1\$ while \$\\alpha_1(M)\\leq1\$.",
        )
        println(
            output,
            "- Among **", sparse_count, "** sparse-paving observations, **",
            sparse_epsilon_gt_one, "** have \$\\epsilon(M)>1\$ (",
            percent(sparse_epsilon_gt_one, sparse_count), ").",
        )
        println(
            output,
            "- In the observation-weighted direct-sum experiment, ",
            weighted_direct.epsilon_ge_alpha, " of ", weighted_direct.draws,
            " draws satisfy \$\\epsilon\\geq\\alpha_1\$ (",
            percent(weighted_direct.epsilon_ge_alpha, weighted_direct.draws),
            "), and all ", weighted_direct.epsilon_gt_one,
            " draws have \$\\epsilon>1\$. The conditional implication holds in ",
            implication_cell(
                weighted_direct.alpha_gt_one_epsilon_gt_one,
                weighted_direct.alpha_gt_one,
            ), ".",
        )
        println(
            output,
            "- For the exhaustive self-sum calculation, **", self_sum_gt_one,
            "** of **", total, "** observations have ",
            "\$\\epsilon(M\\oplus M)>1\$ (",
            percent(self_sum_gt_one, total), "), and **", self_sum_gt_original,
            "** exceed \$\\epsilon(M)\$.",
        )
        println(output)
        println(
            output,
            "The fully specified finite-field spike family with \$\\alpha_1=8/7\$ is ",
            "computed exactly; its \$p=2\$ and \$p=3\$ members already disprove ",
            "\$\\alpha_1>1\\Rightarrow\\epsilon>1\$. The supplied ",
            "\$\\operatorname{GF}(3)\$ matrix closes the former \$100/81\$ ",
            "reproducibility gap and is checked directly from all ",
            "\$\\binom{12}{6}=924\$ column subsets.",
        )
        println(output)
        println(output, "## Definition and exact formula")
        println(output)
        println(output, raw"""
Let $M$ have rank $r$. Define

$$
i=i_{r-1}(M),
\qquad
b=|\mathcal B(M)|,
$$

$$
a=
\#\left\{
A\in\binom{E(M)}r:
\operatorname{rk}_M(A)\geq r-1
\right\},
$$

and

$$
s=
\#\left\{
S\in\binom{E(M)}{r+1}:
\operatorname{rk}_M(S)=r
\right\}.
$$

For $Q=(M+e)\mathbin{\times}f$, the new pair has table

| Membership of $e,f$ | Basis count |
|---|---:|
| neither | $s$ |
| $e$ only | $a$ |
| $f$ only | $b$ |
| both | $i$ |

Therefore

$$
\boxed{
\epsilon(M)=\frac{s\,i}{a\,b}.
}
$$

All threshold decisions below use exact integer cross multiplication.
Floating-point values are used only for descriptive statistics and plots.
""")
        println(output)
        println(output, "The implementation is checked against")
        println(output)
        println(output, raw"""
$$
\epsilon(M^*)=\epsilon(M)
$$

and

$$
\epsilon(U_{r,n})
=
\frac{r(n-r)}{(r+1)(n-r+1)}.
$$
""")
        println(output)
        println(output, "## Population and methods")
        println(output)
        println(
            output,
            "The single-matroid population follows the project convention: connected ",
            "rows with positive stored \$\\alpha_1\$. polyDB rows are isomorphism ",
            "classes; finite-field rows are accepted configurations or draws; ",
            "Johnson rows are labeled random-greedy outputs; and ICARM rows are ",
            "probability samples. The nonredundant stored ranks are used, including ",
            "ranks 2, 3, and 4 in the \$n=9\$ census.",
        )
        println(output)
        println(
            output,
            "The packed basis encoding is scanned directly. For paving matroids ",
            "\$i=\\binom n{r-1}\$ and \$a=\\binom nr\$; for copaving matroids ",
            "\$s=\\binom n{r+1}\$. These are exact shortcuts.",
        )
        println(output)
        println(output, "## Exhaustive results by ensemble cell")
        println(output)
        println(output, raw"| Scope | Ensemble | $N$ | Median $\epsilon$ | 95% | Maximum | $\epsilon\geq\alpha_1$ | $N(\alpha_1>1)$ | $\alpha_1>1\Rightarrow\epsilon>1$ | $N(\epsilon>1,\alpha_1\leq1)$ |")
        println(output, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
        for group in groups
            println(
                output,
                "| ", group.experiment, " | ", group.ensemble, " | ", group.count,
                " | ", fixed(group.median), " | ", fixed(group.p95), " | ",
                fraction_string(group.maximum_exact), " (", fixed(group.maximum), ") | ",
                group.epsilon_ge_alpha, " (",
                percent(group.epsilon_ge_alpha, group.count), ") | ",
                group.alpha_gt_one, " | ",
                implication_cell(
                    group.alpha_gt_one_epsilon_gt_one,
                    group.alpha_gt_one,
                ), " | ", group.epsilon_gt_one_alpha_le_one, " |",
            )
        end
        println(output)
        println(output, "![Stored matroids: \$\\epsilon\$ versus \$\\alpha_1\$](../figures/epsilon_analysis/epsilon_vs_alpha.png)")
        println(output)
        println(
            output,
            "The point cloud uses deterministic display reservoirs. Every table entry ",
            "uses the full eligible stored population.",
        )
        println(output)
        println(output, "### Associations and the uniform reference")
        println(output)
        println(output, raw"| Scope | Ensemble | $\rho_S(\epsilon,\alpha_1)$ | $\rho_S(\epsilon,d_B)$ | Median $\epsilon/\epsilon(U_{r,n})$ | Sparse-paving median | Other median |")
        println(output, "|---|---|---:|---:|---:|---:|---:|")
        for group in groups
            println(
                output,
                "| ", group.experiment, " | ", group.ensemble, " | ",
                fixed(group.alpha_spearman; digits=4), " | ",
                fixed(group.density_spearman; digits=4), " | ",
                fixed(group.median_uniform_multiple; digits=4), " | ",
                fixed(group.sparse_median), " | ",
                fixed(group.nonsparse_median), " |",
            )
        end
        println(output)
        println(output, "### Does \$\\alpha_1>1\$ imply \$\\epsilon>1\$?")
        println(output)
        if isempty(implication_failures)
            println(
                output,
                "No counterexample occurs in the stored data. This is exhaustive for ",
                "the analyzed rows, but it is not by itself a theorem for all matroids.",
            )
        else
            println(
                output,
                "No: the implication fails in the stored data. The lowest-\$\\epsilon\$ ",
                "retained counterexamples are:",
            )
            println(output)
            println(output, raw"| Scope | Ensemble | Source ID | $\alpha_1$ | $\epsilon$ | Bases |")
            println(output, "|---|---|---|---:|---:|---:|")
            for record in first(implication_failures, min(12, length(implication_failures)))
                println(
                    output,
                    "| ", record.experiment, " | ", record.ensemble, " | ",
                    record.source_id, " | ", record.alpha_num, "/", record.alpha_den,
                    " | ", fraction_string(record.epsilon_exact), " | ",
                    record.num_bases, " |",
                )
            end
        end
        println(output)
        println(output, "### When is \$\\epsilon\\geq\\alpha_1\$?")
        println(output)
        if isempty(comparison_failures)
            println(
                output,
                "Every stored observation satisfies \$\\epsilon\\geq\\alpha_1\$. ",
                "The computation does not establish a general inequality.",
            )
        else
            println(
                output,
                total - epsilon_ge_alpha,
                " stored observations have \$\\epsilon<\\alpha_1\$. The strongest ",
                "retained discrepancies are:",
            )
            println(output)
            println(output, raw"| Scope | Ensemble | Source ID | $\alpha_1$ | $\epsilon$ | $\epsilon-\alpha_1$ |")
            println(output, "|---|---|---|---:|---:|---:|")
            for record in first(comparison_failures, min(12, length(comparison_failures)))
                println(
                    output,
                    "| ", record.experiment, " | ", record.ensemble, " | ",
                    record.source_id, " | ", record.alpha_num, "/", record.alpha_den,
                    " | ", fraction_string(record.epsilon_exact), " | ",
                    fixed(record.difference), " |",
                )
            end
        end
        println(output)
        println(output, "### Sparse-paving identity")
        println(output)
        println(output, raw"""
For a sparse-paving matroid,

$$
\epsilon(M)
=
\frac{\binom n{r+1}\binom n{r-1}}
{\binom nr\,|\mathcal B(M)|}
=
\frac{\epsilon(U_{r,n})}{d_B(M)}.
$$

Thus $\epsilon>1$ is exactly a basis-density threshold in this class, while
$\alpha_1\leq1$. None of the stored sparse-paving observations crosses that
threshold, so the observed cases with $\epsilon>1$ and $\alpha_1\leq1$ arise
outside the stored sparse-paving population.
""")
        println(output)
        println(output, "## Direct sums")
        println(output)
        println(output, raw"""
For profiles $(i_j,b_j,a_j,s_j)$,

$$
\begin{aligned}
b&=b_1b_2,\\
i&=i_1b_2+b_1i_2,\\
s&=s_1b_2+b_1s_2,\\
a&=a_1b_2+b_1a_2-b_1b_2+s_1i_2+i_1s_2.
\end{aligned}
$$

No direct-sum matroid needs to be materialized. If
$x_j=i_j/b_j$, $y_j=s_j/b_j$, and $z_j=a_j/b_j$, then

$$
\epsilon(M_1\oplus M_2)
=
\frac{(x_1+x_2)(y_1+y_2)}
{z_1+z_2-1+y_1x_2+x_1y_2}.
$$

Also,

$$
\epsilon(M_1\oplus M_2)>1
\iff
z_1(\epsilon(M_1)-1)+z_2(\epsilon(M_2)-1)+1>0.
$$

For the loopless, coloopless summands analyzed here,

$$
\alpha_1(M_1\oplus M_2)
=
\max\{1,\alpha_1(M_1),\alpha_1(M_2)\}.
$$
""")
        println(
            output,
            "The last identity is recorded by ",
            "[Huh–Schröter–Wang](https://arxiv.org/abs/1806.02675). ",
            "Each scenario draws from deterministic uniform reservoirs of at most ",
            RESERVOIR_SIZE, " rows per ensemble cell. The formulas and comparisons ",
            "inside each draw are exact; the percentages are two-stage empirical ",
            "Monte Carlo estimates, not Cartesian-product enumerations.",
        )
        println(output)
        println(output, raw"| Scenario | Draws | Median $\epsilon$ | 95% | $\epsilon\geq\alpha_1$ | $N(\alpha_1>1)$ | $\alpha_1>1\Rightarrow\epsilon>1$ | $N(\epsilon>1,\alpha_1\leq1)$ | $\epsilon$ exceeds both summands |")
        println(output, "|---|---:|---:|---:|---:|---:|---:|---:|---:|")
        for summary in direct_sums
            println(
                output,
                "| ", summary.label, " | ", summary.draws, " | ",
                fixed(summary.median), " | ", fixed(summary.p95), " | ",
                summary.epsilon_ge_alpha, " (",
                percent(summary.epsilon_ge_alpha, summary.draws), ") | ",
                summary.alpha_gt_one, " | ",
                implication_cell(
                    summary.alpha_gt_one_epsilon_gt_one,
                    summary.alpha_gt_one,
                ), " | ", summary.epsilon_gt_one_alpha_le_one, " | ",
                summary.epsilon_gt_both, " (",
                percent(summary.epsilon_gt_both, summary.draws), ") |",
            )
        end
        println(output)
        println(output, "![Direct sums: \$\\epsilon\$ versus \$\\alpha_1\$](../figures/epsilon_analysis/direct_sum_epsilon_vs_alpha.png)")
        println(output)
        println(output, "## What makes a self-direct sum large?")
        println(output)
        println(output, raw"""
Put

$$
q(M)=\frac{i(M)s(M)}{b(M)^2},
\qquad
z(M)=\frac{a(M)}{b(M)},
$$

It is also useful to write

$$
\beta(M)=\frac{b(M)}{a(M)}=\frac1{z(M)}.
$$

Here $\beta$ is the fraction of rank-$r$ almost-bases that are actual bases;
call it the basis purity among almost-bases. Since every basis is an
almost-basis, $0<\beta\leq1$.

Define also the normalized near-basis defect

$$
\Delta(M)=z(M)-q(M)
=\frac{a(M)b(M)-i(M)s(M)}{b(M)^2}
=z(M)\bigl(1-\epsilon(M)\bigr).
$$

Specializing the direct-sum formulas to two identical summands gives

$$
\boxed{
\epsilon(M\oplus M)
=
\frac{4q(M)}{2z(M)-1+2q(M)}
=
\frac{4\epsilon(M)}
{2\bigl(1+\epsilon(M)\bigr)-\beta(M)}
}
$$

and, since the denominator is positive,

$$
\boxed{
\epsilon(M\oplus M)>1
\iff
\Delta(M)<\frac12.
}
$$

Equivalently,

$$
\boxed{
\epsilon(M\oplus M)>1
\iff
\epsilon(M)>1-\frac{\beta(M)}2.
}
$$

More precisely,

$$
\epsilon(M\oplus M)-1
=
\frac{1-2\Delta(M)}
{4q(M)+2\Delta(M)-1}.
$$

Thus crossing $1$ is controlled exactly by $\Delta$, not by $\epsilon(M)$
or $\alpha_1(M)$ alone. Numerical magnitude has a particularly simple
two-coordinate interpretation: the displayed formula is strictly increasing
in each of $\epsilon(M)$ and $\beta(M)$ when the other is held fixed. A large
self-sum therefore comes from the combination of high original $\epsilon$
and high basis purity. These two coordinates can move in opposite directions,
which is why either one alone can have a misleading empirical association.

Combinatorially, $z=a/b$ measures rank-$r$ almost-bases per basis, while
$q=(i/b)(s/b)$ measures the product of the two adjacent near-basis
reservoirs. In a self-direct sum, the one-unit size deficit and one-unit size
excess can be assigned to opposite copies in two ways. Those cross-copy terms
are the source of the boost.
""")
        println(output)
        println(
            output,
            "Across all **", total, "** eligible database observations, **",
            self_sum_gt_one, "** have \$\\epsilon(M\\oplus M)>1\$ and **",
            self_sum_gt_original, "** have ",
            "\$\\epsilon(M\\oplus M)>\\epsilon(M)\$. The exact observed range is ",
            "\$", fraction_string(minimum_self_sum.self_sum_epsilon_exact),
            "\$ to \$", fraction_string(maximum_self_sum.self_sum_epsilon_exact),
            "\$.",
        )
        println(output)
        println(output, raw"| Scope | Ensemble | $N$ | 5% | Median $\epsilon(M\oplus M)$ | 95% | Minimum | Maximum | $N(>1)$ | Median $\Delta$ | Median $\beta$ | $\rho_S(\epsilon_{\oplus2},\beta)$ | $\rho_S(\epsilon_{\oplus2},\epsilon)$ | $\rho_S(\epsilon_{\oplus2},\alpha_1)$ |")
        println(output, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for group in groups
            println(
                output,
                "| ", group.experiment, " | ", group.ensemble, " | ", group.count,
                " | ", fixed(group.self_sum_p05), " | ",
                fixed(group.self_sum_median), " | ", fixed(group.self_sum_p95),
                " | ", fraction_string(group.self_sum_minimum_exact),
                " | ", fraction_string(group.self_sum_maximum_exact),
                " | ", group.self_sum_gt_one, " | ", fixed(group.defect_median),
                " | ", fixed(group.beta_median),
                " | ", fixed(group.self_sum_beta_spearman; digits=4),
                " | ", fixed(group.self_sum_original_spearman; digits=4),
                " | ", fixed(group.self_sum_alpha_spearman; digits=4), " |",
            )
        end
        println(output)
        println(
            output,
            "Within every finite-field cell the self-sum is positively associated ",
            "with basis purity: the within-cell Spearman correlations range from ",
            fixed(first(finite_beta_correlation_range); digits=4), " to ",
            fixed(last(finite_beta_correlation_range); digits=4),
            ". Ordinary basis density has the same direction in these cells, with ",
            "correlations from ",
            fixed(first(finite_density_correlation_range); digits=4), " to ",
            fixed(last(finite_density_correlation_range); digits=4), ". By contrast, ",
            "its association with the original \$\\epsilon(M)\$ is negative in every ",
            "finite-field cell, ranging from ",
            fixed(first(finite_original_correlation_range); digits=4), " to ",
            fixed(last(finite_original_correlation_range); digits=4), ". ",
            "Its within-cell association with \$\\alpha_1(M)\$ ranges from ",
            fixed(first(finite_alpha_correlation_range); digits=4), " to ",
            fixed(last(finite_alpha_correlation_range); digits=4), ". ",
            "These directions reverse in the Johnson sparse-paving cells, where ",
            "\$\\epsilon(M\\oplus M)\$ and \$\\epsilon(M)\$ are comonotone and basis ",
            "density is antimonotone. Therefore density and the original invariant ",
            "are ensemble-dependent proxies, not structural substitutes for ",
            "\$(q,\\Delta)\$.",
        )
        println(output)
        println(output, "![Self-direct sums: \$\\epsilon\$ versus the normalized defect](../figures/epsilon_analysis/self_sum_epsilon_vs_defect.png)")
        println(output)
        println(output, "### The supplied \$100/81\$ example is not exceptional for its size")
        println(output)
        println(output, raw"""
For the supplied rank-$6$ matroid on $12$ elements,

$$
q(M)=\frac{16129}{12996},
\qquad
z(M)=\frac{77}{57},
\qquad
\beta(M)=\frac{57}{77},
\qquad
\Delta(M)=\frac{1427}{12996}\approx0.109802.
$$

This small defect explains why its self-sum crosses $1$. Nevertheless, the
uniform matroid of the same rank and size has

$$
\epsilon(U_{6,12}\oplus U_{6,12})
=\frac{144}{121}
\approx1.190083,
$$

which is slightly larger than

$$
\epsilon(M\oplus M)
=\frac{32258}{27187}
\approx1.186523.
$$

The supplied matroid combines the high value
$\epsilon(M)=16129/17556$ with moderate basis purity $\beta=57/77$.
The uniform matroid has the smaller value $\epsilon(U_{6,12})=36/49$ but
maximal purity $\beta=1$, which more than compensates. Therefore the large
$\alpha_1(M)=100/81$ is not the cause of the self-sum value.
""")
        println(output)
        println(output, "### Ground-set size: uniform controls")
        println(output)
        println(output, raw"""
Let $c=n-r$. For a uniform matroid,

$$
\epsilon(U_{r,n}\oplus U_{r,n})
=
\frac{4rc}{(r+1)(c+1)+2rc},
$$

so

$$
\epsilon(U_{r,n}\oplus U_{r,n})>1
\iff
(r-1)(c-1)>2.
$$

In the balanced family this becomes

$$
\epsilon(U_{m,2m}\oplus U_{m,2m})
=
\frac{4m^2}{3m^2+2m+1}
\longrightarrow \frac43.
$$

For $m=2,3,4,5,6,10$ the exact values are, respectively,

$$
\frac{16}{17},\quad
\frac{18}{17},\quad
\frac{64}{57},\quad
\frac{50}{43},\quad
\frac{144}{121},\quad
\frac{400}{321}.
$$

Consequently a database restricted to $n\leq12$ cannot display the approach
to $4/3$ even in the most elementary family.
""")
        println(output)
        println(output, "### Nonuniform rank-\$2\$ controls")
        println(output)
        println(output, raw"""
A loopless rank-$2$ matroid is determined by its parallel-class sizes
$c_1,\ldots,c_k$. It is connected exactly when $k\geq3$, and its profile is

$$
i=n,\qquad
b=\frac{n^2-\sum_j c_j^2}{2},\qquad
a=\binom n2,\qquad
s=\binom n3-\sum_j\binom{c_j}{3}.
$$

The following table comes from an exact enumeration of every integer
partition with at least three parts for each $3\leq n\leq30$; selected rows
are displayed.
""")
        println(output)
        println(output, raw"| $n$ | Minimizing class sizes | Minimum self-sum | Maximizing class sizes | Maximum self-sum |")
        println(output, "|---:|---|---:|---|---:|")
        for n in (4, 5, 6, 9, 12, 20, 30)
            row = only(filter(result -> result.n == n, rank_two_families))
            println(
                output,
                "| ", n, " | \$(", join(row.minimum.parts, ","), ")\$ | ",
                fraction_string(row.minimum.self_sum), " | \$(",
                join(row.maximum.parts, ","), ")\$ | ",
                fraction_string(row.maximum.self_sum), " |",
            )
        end
        println(output)
        println(output, raw"""
The small cases genuinely differ: connected examples below, equal to, and
above $1$ all occur at $n\leq5$. Every enumerated connected rank-$2$ type for
$6\leq n\leq30$ is above $1$. Highly unbalanced types $(n-2,1,1)$ approach
$1$ from above, whereas balanced three-class types stay farther above $1$.
This shows that size alone is not enough: balance of the near-basis counts
also matters.
""")
        println(output)
        println(output, "## Known \$\\alpha_1=8/7\$ family")
        println(output)
        println(
            output,
            "[Huh, Schröter, and Wang](https://doi.org/10.4171/JEMS/1119) ",
            "define the rank-\$d\$ finite-field spike \$M_p^d\$ over ",
            "\$\\operatorname{GF}(p)\$ using \$e_1\$, \$e_2+\\cdots+e_d\$, ",
            "and \$ke_1+e_m\$. Its distinguished ratio is ",
            "\$(d-1)^2/(d^2-3d+4)\$, equal to \$8/7\$ at \$d=5\$. ",
            "Here the full unweighted \$\\alpha_1\$ is independently recomputed from ",
            "all bases before evaluating \$\\epsilon\$.",
        )
        println(output)
        println(output, raw"| $p$ | $n$ | Bases | $i_4$ | $a_5$ | $s_6$ | $\alpha_1$ | $\epsilon$ | $\epsilon(M\oplus M)$ | $\epsilon\geq\alpha_1$ |")
        println(output, "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for row in hsw_family
            println(
                output,
                "| ", row.parameter, " | ", row.n, " | ", row.num_bases,
                " | ", row.independent_r_minus_1, " | ",
                row.rank_at_least_r_minus_1, " | ", row.spanning_r_plus_1,
                " | ", fraction_string(row.alpha), " | ",
                fraction_string(row.epsilon), " (", fixed(row.epsilon_value), ") | ",
                fraction_string(row.self_sum_epsilon), " (",
                fixed(row.self_sum_epsilon_value), ") | ",
                row.epsilon_ge_alpha ? "yes" : "no", " |",
            )
        end
        println(output)
        println(
            output,
            "This family cleanly separates the invariants: for the tested primes, ",
            "\$\\epsilon\$ increases from \$1936/2091<1\$ at \$p=2\$ to ",
            "\$119301/116176>1\$ at \$p=7\$, crossing \$1\$ between \$p=3\$ ",
            "and \$p=5\$, while remaining strictly below the fixed value ",
            "\$\\alpha_1=8/7\$.",
        )
        println(output)
        println(output, "## The supplied \$\\alpha_1=100/81\$ benchmark")
        println(output)
        println(output, raw"""
The supplied matrix over $\operatorname{GF}(3)$ defines a rank-$6$ matroid on
$12$ elements. Enumerating all $924$ six-column subsets reproduces $684$
bases and the maximizing pair table

$$
(b_{00},b_{01},b_{10},b_{11})=(180,162,162,180),
$$

so

$$
\alpha_1(M)=\frac{180^2}{162^2}=\frac{100}{81}.
$$

The exact near-basis profile is

$$
(i_5,b_6,a_6,s_7)=(762,684,924,762).
$$

Consequently

$$
\boxed{
\epsilon(M)
=
\frac{762^2}{924\cdot684}
=
\frac{16129}{17556}
\approx0.918717
}
$$

and

$$
\boxed{
\epsilon(M\oplus M)
=
\frac{32258}{27187}
\approx1.186523.
}
$$

The matrix is stored literally in the report generator, so both values are
recomputed from the representation rather than from the aggregate pair
table.
""")
        println(output)
        println(output, "## Artifacts and reproduction")
        println(output)
        println(output, "- [Individual-cell summary](../data/epsilon_analysis/epsilon_summary.csv)")
        println(output, "- [Direct-sum summary](../data/epsilon_analysis/direct_sum_summary.csv)")
        println(output, "- [Known-family values](../data/epsilon_analysis/known_family_summary.csv)")
        println(output, "- [Extrema and implication failures](../data/epsilon_analysis/epsilon_extrema.csv)")
        println(output)
        println(output, "Run:")
        println(output)
        fence = repeat(string(Char(0x60)), 3)
        println(output, fence, "bash")
        println(output, "julia --project=. scripts/make_epsilon_report.jl")
        println(output, fence)
        println(output)
        println(
            output,
            "Unit tests cover \$\\epsilon(U_{4,8})=16/25\$, dual invariance, and ",
            "\$\\epsilon(U_{2,4}\\oplus U_{2,4})=16/17\$.",
        )
    end
    return path
end

function main()
    mkpath(DATA_DIRECTORY)
    mkpath(FIGURE_DIRECTORY)
    groups = NamedTuple[]
    for experiment in experiment_specs()
        append!(groups, analyze_experiment(experiment))
    end
    direct_sums = [
        analyze_direct_sum_scenario(specification)
        for specification in direct_sum_scenarios(groups)
    ]
    family = analyze_known_families()

    write_individual_summary_csv(
        joinpath(DATA_DIRECTORY, "epsilon_summary.csv"),
        groups,
    )
    write_direct_sum_csv(
        joinpath(DATA_DIRECTORY, "direct_sum_summary.csv"),
        direct_sums,
    )
    write_family_csv(
        joinpath(DATA_DIRECTORY, "known_family_summary.csv"),
        family,
    )
    write_extrema_csv(
        joinpath(DATA_DIRECTORY, "epsilon_extrema.csv"),
        groups,
    )
    make_individual_figure(groups)
    make_direct_sum_figure(direct_sums)
    make_self_sum_figure(groups)
    write_report(REPORT_PATH, groups, direct_sums, family)
    @info "epsilon analysis complete" report=REPORT_PATH
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
