using DBInterface
using Random
using Test

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions
include(joinpath(@__DIR__, "..", "src", "MatroidSubmissionVerifier.jl"))
using .MatroidSubmissionVerifier
include(joinpath(@__DIR__, "..", "src", "MatroidIssueIntake.jl"))
using .MatroidIssueIntake
include(joinpath(@__DIR__, "..", "src", "SubmissionEligibility.jl"))
using .SubmissionEligibility
using JSON3
using SHA

@testset "concrete submission verifier" begin
    function submission(input; claim=(1, 4))
        return Dict{String,Any}(
            "schema_version" => 1,
            "kind" => "matroid",
            "id" => "uniform-u2-4-test",
            "proposed_name" => "Uniform test matroid U(2,4)",
            "contributors" => [Dict(
                "github" => "example-contributor",
                "display_name" => "Example Contributor",
            )],
            "ground_set" => Dict("labels" => [0, 1, 2, 3]),
            "input" => input,
            "claimed_alpha_bar" => Dict(
                "numerator" => claim[1],
                "denominator" => claim[2],
            ),
            "claimed_maximizing_pair" => [0, 1],
            "discovery" => Dict(
                "date" => "2026-08",
                "discoverers" => "Example Contributor",
                "ai_used" => false,
                "ai_model_version" => "None",
                "ai_role" => "None",
            ),
            "submitted_at" => "2026-08-04T12:00:00Z",
            "provenance" => "Verifier regression fixture.",
            "citation" => "",
            "license" => "CC0-1.0",
        )
    end

    matrix_input = Dict{String,Any}(
        "type" => "matrix",
        "rank" => 2,
        "field" => Dict("order" => 3),
        "rows" => [[1, 0, 1, 1], [0, 1, 1, 2]],
    )
    bases_input = Dict{String,Any}(
        "type" => "bases",
        "rank" => 2,
        "sets" => [[0, 1], [0, 2], [1, 2], [0, 3], [1, 3], [2, 3]],
    )
    circuits_input = Dict{String,Any}(
        "type" => "circuits",
        "rank" => 2,
        "sets" => [[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]],
    )
    hyperplanes_input = Dict{String,Any}(
        "type" => "hyperplanes",
        "rank" => 2,
        "sets" => [[0], [1], [2], [3]],
    )

    certificates = [
        verify_submission_data(submission(input))
        for input in (matrix_input, bases_input, circuits_input, hyperplanes_input)
    ]
    @test all(certificate.status == "verified-as-claimed" for certificate in certificates)
    @test all(certificate.matroid.number_of_bases == 6 for certificate in certificates)
    @test all(certificate.correlation.exact.numerator == 1 for certificate in certificates)
    @test all(certificate.correlation.exact.denominator == 4 for certificate in certificates)
    @test all(certificate.correlation.maximizing_pair_count == 6 for certificate in certificates)
    @test all(
        certificate.matroid.basis_encoding == certificates[1].matroid.basis_encoding
        for certificate in certificates
    )
    @test certificates[1].representations.verified_prime_fields == [3]
    @test isempty(certificates[2].representations.verified_prime_fields)

    bases_with_representation = submission(bases_input)
    bases_with_representation["representations"] = [Dict(
        "field" => Dict("order" => 3),
        "rows" => [[1, 0, 1, 1], [0, 1, 1, 2]],
    )]
    represented = verify_submission_data(bases_with_representation)
    @test represented.representations.verified_prime_fields == [3]

    rational_input = Dict{String,Any}(
        "type" => "matrix",
        "rank" => 2,
        "field" => Dict("kind" => "rational"),
        "rows" => [[1, 0, 1, 1], [0, 1, 1, "3/2"]],
    )
    rational_certificate = verify_submission_data(submission(rational_input))
    @test rational_certificate.representations.verified_over_rationals
    @test isempty(rational_certificate.representations.verified_finite_fields)

    gf4_input = Dict{String,Any}(
        "type" => "matrix",
        "rank" => 2,
        "field" => Dict("kind" => "finite", "order" => 4),
        "rows" => [[1, 0, 1, 1], [0, 1, 1, [0, 1]]],
    )
    gf4_certificate = verify_submission_data(submission(gf4_input))
    @test gf4_certificate.representations.verified_finite_fields == [4]
    @test isempty(gf4_certificate.representations.verified_prime_fields)

    fence = repeat(Char(96), 3)
    issue_body = """
### Ground-set size n

4

### Rank r

2

### Claimed alpha-bar

1/4

### Discoverers

Example Contributor

### Discovery date

2026-08

### Was AI used in the discovery?

Yes

### AI model and version

ExampleAI 2.1

### AI role

Suggested candidates; the submitter checked the result independently.

### Optional AI chat link

https://example.test/chat/42

### Description type

Matrix

### Matroid data

$(fence)json
[[1,0,1,1],[0,1,1,2]]
$(fence)

### Matrix field

GF(3)

### Optional certificate field

_No response_

### Optional certificate matrix

_No response_

### Optional notes

Regression fixture.
"""
    issue_event = Dict{String,Any}(
        "issue" => Dict{String,Any}(
            "number" => 42,
            "title" => "[Concrete] Uniform matroid U(2,4)",
            "body" => issue_body,
            "html_url" => "https://github.test/example/issues/42",
            "created_at" => "2026-08-04T16:30:00Z",
            "user" => Dict("login" => "example-user"),
        ),
    )
    normalized_issue, issue_certificate = verify_issue_event(issue_event)
    @test normalized_issue["id"] == "github-issue-42"
    @test normalized_issue["contributors"][1]["github"] == "example-user"
    @test normalized_issue["submitted_at"] == "2026-08-04T16:30:00Z"
    @test normalized_issue["discovery"]["ai_used"]
    @test issue_certificate.attribution.discovery.date == "2026-08"
    @test issue_certificate.attribution.discovery.ai_model_version == "ExampleAI 2.1"
    @test issue_certificate.attribution.submitted_at == "2026-08-04T16:30:00Z"
    @test issue_certificate.correlation.exact.numerator == 1
    @test issue_certificate.correlation.exact.denominator == 4

    wrong_claim = submission(matrix_input; claim=(1, 1))
    @test_throws SubmissionValidationError verify_submission_data(wrong_claim)

    unknown_field = submission(matrix_input)
    unknown_field["executable"] = "println(\"not allowed\")"
    @test_throws SubmissionValidationError verify_submission_data(unknown_field)

    malformed_notes = submission(matrix_input)
    malformed_notes["notes"] = ["must", "be", "a", "string"]
    @test_throws SubmissionValidationError verify_submission_data(malformed_notes)

    missing_discovery = submission(matrix_input)
    delete!(missing_discovery, "discovery")
    @test_throws SubmissionValidationError verify_submission_data(missing_discovery)

    missing_submission_date = submission(matrix_input)
    delete!(missing_submission_date, "submitted_at")
    @test_throws SubmissionValidationError verify_submission_data(missing_submission_date)

    malformed_discovery_date = submission(matrix_input)
    malformed_discovery_date["discovery"]["date"] = "August 2026"
    @test_throws SubmissionValidationError verify_submission_data(malformed_discovery_date)

    unknown_matrix_field = submission(copy(matrix_input))
    unknown_matrix_field["input"]["extension_degree"] = 2
    @test_throws SubmissionValidationError verify_submission_data(unknown_matrix_field)

    mistyped_representation = submission(bases_input)
    mistyped_representation["representations"] = [Dict(
        "type" => "bases",
        "field" => Dict("order" => 3),
        "rows" => [[1, 0, 1, 1], [0, 1, 1, 2]],
    )]
    @test_throws SubmissionValidationError verify_submission_data(mistyped_representation)

    invalid_bases = submission(Dict{String,Any}(
        "type" => "bases",
        "rank" => 2,
        "sets" => [[0, 1], [2, 3]],
    ))
    @test_throws SubmissionValidationError verify_submission_data(invalid_bases)

    wrong_representation = submission(bases_input)
    wrong_representation["representations"] = [Dict(
        "field" => Dict("order" => 3),
        "rows" => [[1, 0, 1, 1], [0, 1, 1, 1]],
    )]
    @test_throws SubmissionValidationError verify_submission_data(wrong_representation)

    mktempdir() do directory
        input_path = joinpath(directory, "submission.json")
        certificate_path = joinpath(directory, "certificate.json")
        open(input_path, "w") do output
            JSON3.pretty(output, submission(matrix_input))
            println(output)
        end
        certificate = verify_submission_file(input_path)
        write_certificate(certificate_path, certificate)
        parsed = JSON3.read(read(certificate_path, String))
        @test parsed.status == "verified-as-claimed"
        @test parsed.input.sha256 == bytes2hex(open(sha256, input_path))
    end
end

@testset "submission eligibility policy" begin
    function mock_certificate(numerator_value, denominator_value; fields=Int[])
        return (
            correlation=(exact=(
                numerator=numerator_value,
                denominator=denominator_value,
            ),),
            representations=(verified_finite_fields=fields,),
        )
    end

    policy = load_eligibility_policy()
    @test policy.finite_threshold == 4 // 3
    @test policy.family_threshold == 4 // 3
    @test policy.field_records[2].value == 8 // 7
    @test policy.field_records[3].value == 100 // 81

    finite_equal = classify_concrete_certificate(mock_certificate(4, 3))
    @test finite_equal.classification == "eligible-for-review"
    @test only(finite_equal.qualifying_challenges).id == "finite-on-the-nose"

    field_equal = classify_concrete_certificate(mock_certificate(8, 7; fields=[2]))
    @test field_equal.classification == "below-publication-thresholds"
    @test !only(field_equal.finite_field_comparisons).beats_record

    field_improvement = classify_concrete_certificate(mock_certificate(9, 7; fields=[2]))
    @test field_improvement.classification == "eligible-for-review"
    @test only(field_improvement.qualifying_challenges).id == "finite-field-record"
    @test only(field_improvement.finite_field_comparisons).beats_record

    unsupported_field = classify_concrete_certificate(mock_certificate(9, 7; fields=[11]))
    @test unsupported_field.classification == "below-publication-thresholds"
    @test isempty(unsupported_field.finite_field_comparisons)

    family_equal = classify_family_claim(4, 3)
    @test family_equal.classification == "eligible-for-review"
    @test family_equal.verification_scope == "claimed-family-limit-only"
    @test !family_equal.mathematical_proof_verified

    family_below = classify_family_claim(5, 4)
    @test family_below.classification == "below-publication-thresholds"
    @test isempty(family_below.qualifying_challenges)
end

@testset "density-adjusted correlation excess" begin
    @test uniform_correlation_baseline(8, 4) == 9 // 16
    @test uniform_correlation_baseline(10, 4) == 5 // 8
    @test uniform_correlation_baseline(10, 5) == 16 // 25
    @test uniform_correlation_baseline(10, 4) ==
          uniform_correlation_baseline(10, 6)

    @test density_adjusted_correlation_excess(8, 4, 70, 9, 16) == 0
    @test density_adjusted_correlation_excess(8, 4, 35, 1, 1) == 1 // 2
    @test density_adjusted_correlation_excess(10, 5, 186, 256, 225) ==
          1736 // 1701
    @test density_adjusted_correlation_excess(
        10,
        5,
        186,
        256,
        225;
        density_exponent=2,
    ) == 31 // 42 * (1736 // 1701)
    @test density_adjusted_correlation_excess(
        12,
        6,
        684,
        100,
        81;
        density_exponent=2,
    ) == 9025 // 9317
    @test_throws ArgumentError uniform_correlation_baseline(8, 0)
    @test_throws ArgumentError density_adjusted_correlation_excess(8, 4, 71, 1, 1)
    @test_throws ArgumentError density_adjusted_correlation_excess(8, 4, 35, 1, 0)
    @test_throws ArgumentError density_adjusted_correlation_excess(
        8,
        4,
        35,
        1,
        1;
        density_exponent=-1,
    )
end

@testset "density-discounted relative correlation" begin
    @test density_cap_threshold(8, 4) == 5 // 7
    @test density_cap_threshold(10, 4) == 11 // 15
    @test density_cap_threshold(12, 6) == 8 // 11
    @test density_cap_threshold(10, 4) == density_cap_threshold(10, 6)

    # The rank-6, 12-element 100/81 benchmark has 684 of 924 bases.
    @test isapprox(
        density_discounted_relative_correlation(12, 6, 684, 100, 81),
        304 / 231;
        atol=1e-14,
    )
    @test isapprox(
        density_discounted_relative_correlation(
            12,
            6,
            684,
            100,
            81;
            density_exponent=2,
        ),
        5776 / 5929;
        atol=1e-14,
    )
    @test isapprox(
        critical_density_penalty_exponent(12, 6, 684, 100, 81),
        log(16 / 9) / log(77 / 57);
        atol=1e-14,
    )
    @test_throws ArgumentError density_cap_threshold(8, 1)
    @test_throws ArgumentError density_discounted_relative_correlation(
        8,
        4,
        0,
        1,
        1,
    )
    @test_throws ArgumentError critical_density_penalty_exponent(
        8,
        4,
        70,
        9,
        16,
    )
end

@testset "compact and on-demand export contracts" begin
    source = read(joinpath(@__DIR__, "..", "scripts", "make_report.jl"), String)
    normalized = replace(source, r"\s+" => " ")
    @test occursin(
        "export_table_csv( database, \"SELECT * FROM runs WHERE",
        normalized,
    )
    @test !occursin(
        "export_table_csv_zst( database, \"\"\" SELECT m.* FROM matroids",
        normalized,
    )
    bulk_source = read(
        joinpath(@__DIR__, "..", "scripts", "export_bulk_tables.jl"),
        String,
    )
    bulk_normalized = replace(bulk_source, r"\s+" => " ")
    @test occursin(
        "export_table_csv_zst( database, \"\"\" SELECT m.* FROM matroids",
        bulk_normalized,
    )
end

@testset "packed basis encoding" begin
    encoding = "*00**000*0"
    packed = basis_hex(encoding)
    @test packed == "119"
    @test basis_encoding_from_hex(packed, length(encoding)) == encoding
    @test basis_hex(basis_encoding_from_hex("000f", 12)) == "00f"
    @test_throws ArgumentError basis_hex("*x0")
    @test_throws ArgumentError basis_encoding_from_hex("10", 4)
end

@testset "free-extension/free-coextension epsilon invariant" begin
    uniform = repeat("*", binomial(8, 4))
    counter = EpsilonCounter(8, 4)
    statistics = epsilon_statistics(
        counter,
        basis_hex(uniform);
        num_bases=70,
        paving=true,
        copaving=true,
    )
    @test statistics.independent_r_minus_1 == 56
    @test statistics.num_bases == 70
    @test statistics.rank_at_least_r_minus_1 == 70
    @test statistics.spanning_r_plus_1 == 56
    @test statistics.epsilon == 16 // 25
    @test epsilon_statistics(uniform, 8, 4).epsilon == 16 // 25

    columns = [[1, 0], [0, 1], [1, 1], [1, 0]]
    encoding = encoding_from_columns(columns, 2, 2)
    dual = dual_encoding(encoding, 4, 2)
    primal_epsilon = epsilon_statistics(encoding, 4, 2)
    dual_epsilon = epsilon_statistics(dual, 4, 2)
    @test primal_epsilon.epsilon == dual_epsilon.epsilon
    @test primal_epsilon.independent_r_minus_1 ==
          dual_epsilon.spanning_r_plus_1
    @test primal_epsilon.spanning_r_plus_1 ==
          dual_epsilon.independent_r_minus_1

    bases = encoding_to_bases(encoding, 4, 2)
    ranks = CorrelationRatiosDistributions._subset_ranks(bases, 4)
    direct_independent = count(
        mask -> count_ones(mask) == 1 && ranks[Int(mask) + 1] == 1,
        UInt64(0):UInt64(15),
    )
    direct_almost_bases = count(
        mask -> count_ones(mask) == 2 && ranks[Int(mask) + 1] >= 1,
        UInt64(0):UInt64(15),
    )
    direct_spanning = count(
        mask -> count_ones(mask) == 3 && ranks[Int(mask) + 1] == 2,
        UInt64(0):UInt64(15),
    )
    @test primal_epsilon.independent_r_minus_1 == direct_independent
    @test primal_epsilon.rank_at_least_r_minus_1 == direct_almost_bases
    @test primal_epsilon.spanning_r_plus_1 == direct_spanning

    uniform_two_four = epsilon_statistics(repeat("*", binomial(4, 2)), 4, 2)
    direct_sum = direct_sum_epsilon_statistics(uniform_two_four, uniform_two_four)
    @test direct_sum.independent_r_minus_1 == 48
    @test direct_sum.num_bases == 36
    @test direct_sum.rank_at_least_r_minus_1 == 68
    @test direct_sum.spanning_r_plus_1 == 48
    @test direct_sum.epsilon == 16 // 17

    block_columns = vcat(
        [vcat(column, [0, 0]) for column in columns],
        [vcat([0, 0], column) for column in columns],
    )
    block_encoding = encoding_from_columns(block_columns, 2, 4)
    constructed_sum = epsilon_statistics(block_encoding, 8, 4)
    profile_sum = direct_sum_epsilon_statistics(primal_epsilon, primal_epsilon)
    @test profile_sum.independent_r_minus_1 ==
          constructed_sum.independent_r_minus_1
    @test profile_sum.num_bases == constructed_sum.num_bases
    @test profile_sum.rank_at_least_r_minus_1 ==
          constructed_sum.rank_at_least_r_minus_1
    @test profile_sum.spanning_r_plus_1 == constructed_sum.spanning_r_plus_1
    @test profile_sum.epsilon == constructed_sum.epsilon

    benchmark_rows = [
        [1, 2, 1, 2, 2, 2, 1, 1, 0, 0, 1, 2],
        [0, 0, 2, 0, 0, 0, 0, 0, 2, 1, 1, 1],
        [0, 1, 1, 1, 0, 1, 1, 2, 1, 1, 1, 2],
        [1, 1, 1, 2, 2, 1, 1, 2, 1, 1, 0, 1],
        [0, 1, 0, 1, 2, 1, 1, 0, 2, 0, 1, 0],
        [0, 1, 1, 1, 1, 0, 2, 0, 0, 1, 0, 0],
    ]
    benchmark_columns = [
        [benchmark_rows[row][column] for row in 1:6]
        for column in 1:12
    ]
    benchmark_encoding = encoding_from_columns(benchmark_columns, 3, 6)
    benchmark_structure = matroid_statistics(benchmark_encoding, 12, 6)
    benchmark_epsilon = epsilon_statistics(benchmark_encoding, 12, 6)
    benchmark_self_sum =
        direct_sum_epsilon_statistics(benchmark_epsilon, benchmark_epsilon)
    @test benchmark_structure.num_bases == 684
    @test benchmark_structure.alpha_num // benchmark_structure.alpha_den ==
          100 // 81
    @test benchmark_epsilon.independent_r_minus_1 == 762
    @test benchmark_epsilon.rank_at_least_r_minus_1 == 924
    @test benchmark_epsilon.spanning_r_plus_1 == 762
    @test benchmark_epsilon.epsilon == 16129 // 17556
    @test benchmark_self_sum.epsilon == 32258 // 27187
end

@testset "Johnson graph sparse paving sampler" begin
    small = JohnsonGraphSampler(4, 2)
    @test length(small.vertices) == 6
    @test all(length(neighbors) == 4 for neighbors in small.neighbors)
    @test all(
        index in small.neighbors[neighbor]
        for index in eachindex(small.neighbors)
        for neighbor in small.neighbors[index]
    )

    sampler = JohnsonGraphSampler(6, 3)
    empty_set = sample_johnson_independent_set(MersenneTwister(1), sampler, 0.0)
    @test isempty(empty_set)
    selected = sample_johnson_independent_set(MersenneTwister(2), sampler, 1.0)
    @test is_johnson_independent_set(sampler, selected)
    @test all(
        vertex in selected || any(neighbor in selected for neighbor in sampler.neighbors[vertex])
        for vertex in eachindex(sampler.vertices)
    )
    @test !is_johnson_independent_set(sampler, [1, first(sampler.neighbors[1])])

    encoding = johnson_sparse_paving_encoding(sampler, selected)
    statistics = matroid_statistics(encoding, 6, 3)
    @test statistics.num_bases == binomial(6, 3) - length(selected)
    @test statistics.sparse_paving
    @test statistics.circuit_hyperplanes == length(selected)
    @test johnson_greedy_probability(johnson_greedy_ensemble(0.05)) == 0.05
    @test ismissing(johnson_greedy_probability("projective_subsets_random"))
    @test_throws ArgumentError sample_johnson_independent_set(
        MersenneTwister(3),
        sampler,
        1.1,
    )
end

@testset "weighted correlation helpers" begin
    x = [1.0, 2.0, 3.0]
    y = [2.0, 4.0, 6.0]
    weights = [1, 2, 1]
    @test weighted_pearson(x, y, weights) ≈ 1.0
    @test weighted_spearman(x, y, weights) ≈ 1.0
    @test weighted_midranks(x, weights) == [1.0, 2.5, 4.0]
    fit = weighted_linear_fit(x, y, weights)
    @test fit.intercept ≈ 0.0
    @test fit.slope ≈ 2.0

    tied_x = [1.0, 1.0, 2.0]
    tied_weights = [1, 2, 1]
    @test weighted_midranks(tied_x, tied_weights) == [2.0, 2.0, 4.0]
    @test ismissing(weighted_pearson(fill(1.0, 3), y, weights))
    @test ismissing(weighted_linear_fit(fill(1.0, 3), y, weights))
    @test_throws DimensionMismatch weighted_pearson([1.0], [1.0, 2.0], [1])
    @test_throws ArgumentError weighted_spearman(x, y, [1, -1, 1])
end

@testset "basis encoding and unweighted correlation statistics" begin
    uniform_encoding = repeat("*", binomial(8, 4))
    stats = matroid_statistics(uniform_encoding, 8, 4)

    @test stats.num_bases == 70
    @test stats.basis_density == 1.0
    @test stats.simple
    @test stats.cosimple
    @test stats.component_count == 1
    @test stats.connected
    @test stats.three_connected
    @test stats.paving
    @test stats.copaving
    @test stats.sparse_paving
    @test stats.girth == 5
    @test stats.cogirth == 5
    @test stats.circuit_hyperplanes == 0
    @test stats.num_circuits == 56
    @test stats.num_hyperplanes == 56
    @test stats.beta_invariant == 20
    @test stats.mobius_signed == 35
    @test stats.mobius_invariant == 35
    @test stats.alpha_defined
    @test stats.alpha_num == 9
    @test stats.alpha_den == 16
    @test stats.maximizer_count == 28
    @test stats.eligible_element_count == 8
    @test stats.zero_pair_count == 0
    @test stats.minimum_ratio_num == 9
    @test stats.minimum_ratio_den == 16
    @test stats.mean_pair_ratio == 9 / 16
    @test stats.pair_ratio_median == 9 / 16
    @test stats.positive_component_count == 8
    @test stats.largest_positive_component == 1
    @test stats.max_positive_degree == 0

    pair = stats.pairs[1]
    @test (pair.b00, pair.b01, pair.b10, pair.b11) == (15, 20, 20, 15)
    @test pair.p_ij == pair.b11 / 70
    @test pair.covariance < 0
end

@testset "optimized subset ranks agree with direct basis scan" begin
    function direct_subset_ranks(bases, n)
        full = (UInt64(1) << n) - UInt64(1)
        return [
            maximum(count_ones(basis & subset) for basis in bases) for
            subset in UInt64(0):full
        ]
    end

    basis_families = [
        UInt64[0x07, 0x0b, 0x0d, 0x0e],
        UInt64[0x13, 0x15, 0x19, 0x16, 0x1a, 0x1c],
        encoding_to_bases(repeat("*", binomial(6, 3)), 6, 3),
    ]
    ground_set_sizes = [4, 5, 6]
    for (bases, n) in zip(basis_families, ground_set_sizes)
        @test CorrelationRatiosDistributions._subset_ranks(bases, n) ==
              direct_subset_ranks(bases, n)
    end
end

@testset "polyDB reverse-lex basis encoding order" begin
    @test colex_masks(4, 2) == UInt64[0x03, 0x05, 0x06, 0x09, 0x0a, 0x0c]
    columns = [[1, 0], [0, 1], [1, 1], [1, 0]]
    encoding = encoding_from_columns(columns, 2, 2)
    @test encoding == "***0**"
    @test CorrelationRatiosDistributions.encoding_to_bases(encoding, 4, 2) ==
          UInt64[0x03, 0x05, 0x06, 0x0a, 0x0c]
    dual = dual_encoding(encoding, 4, 2)
    @test length(dual) == length(encoding)
    @test dual_encoding(dual, 4, 2) == encoding
    @test matroid_statistics(dual, 4, 2).alpha_value ==
          matroid_statistics(encoding, 4, 2).alpha_value
end

@testset "finite-field projective configurations" begin
    points = projective_points(4, 2)
    @test length(points) == 15
    @test all(point -> findfirst(!iszero, point) !== nothing, points)
    @test all(point -> point[findfirst(!iszero, point)] == 1, points)

    columns = [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
        [1, 1, 0, 0],
        [0, 1, 1, 0],
        [0, 0, 1, 1],
        [1, 0, 0, 1],
    ]
    @test matrix_rank_mod_p(columns, 2) == 4
    encoding = encoding_from_columns(columns, 2, 4)
    @test length(encoding) == 70
    @test count(==('*'), encoding) > 0
end
@testset "finite-field replacement index sampling" begin
    without_replacement = sample_projective_indices(
        MersenneTwister(11),
        15,
        10;
        replacement=false,
    )
    @test length(without_replacement) == 10
    @test issorted(without_replacement)
    @test allunique(without_replacement)

    with_replacement = sample_projective_indices(
        MersenneTwister(11),
        2,
        10;
        replacement=true,
    )
    @test length(with_replacement) == 10
    @test all(index -> 1 <= index <= 2, with_replacement)
    @test !allunique(with_replacement)

    @test_throws ArgumentError sample_projective_indices(
        MersenneTwister(11),
        7,
        10;
        replacement=false,
    )
end


@testset "SQLite schema and round trip" begin
    mktempdir() do directory
        path = joinpath(directory, "test.sqlite")
        database = init_database(path)
        with_transaction(database) do
            begin_run!(
                database;
                run_id="test",
                source="unit_test",
                ensemble="uniform",
                n=8,
                r=4,
                conditioning="none",
                generator="unit test",
            )
            register_sampling_run!(
                database;
                run_id="test",
                release_slug="fixture",
                manifest_url="https://example.invalid/manifest.json",
                manifest_sha256=repeat("a", 64),
                sample_plan_sha256=repeat("b", 64),
                sampling_design_sha256=repeat("c", 64),
                decoder_source_sha256=repeat("d", 64),
                decoder_binary_sha256=repeat("e", 64),
                population_size=100,
                sampling_design="simple random sample without replacement",
                selection_algorithm="unit-test fixture",
                common_selection_probability=0.01,
                common_design_weight=100.0,
            )
            register_sampled_chunk!(
                database;
                run_id="test",
                chunk_index=0,
                first_index=0,
                record_count=100,
                compressed_bytes=1000,
                url="https://example.invalid/chunk.sz.xz",
                compressed_sha256=repeat("b", 64),
                cluster_draw_multiplicity=1,
            )
            writer = prepare_writer(database)
            stats = matroid_statistics(repeat("*", 70), 8, 4)
            matroid_id = insert_matroid!(
                writer;
                run_id="test",
                observation_index=1,
                source_id="U_4_8",
                stats=stats,
            )
            insert_sampling_observation!(
                database;
                matroid_id=matroid_id,
                global_index=17,
                chunk_index=0,
                chunk_first_index=0,
                chunk_offset=17,
                selection_probability=0.01,
                design_weight=100.0,
            )
            close_writer!(writer)
            finish_run!(database, "test"; accepted_count=1, rejected_count=0)
        end
        matroid_count =
            first(DBInterface.execute(database, "SELECT COUNT(*) AS n FROM matroids")).n
        legacy_pair_tables = first(
            DBInterface.execute(
                database,
                "SELECT COUNT(*) AS n FROM sqlite_master WHERE type = 'table' AND name = 'pairs'",
            ),
        ).n
        aggregate = only([
            (
                ratio_num=row.ratio_num,
                ratio_den=row.ratio_den,
                pair_count=row.pair_count,
                census_pair_count=row.census_pair_count,
                matroid_weight=row.matroid_weight,
                census_maximizer_count=row.census_maximizer_count,
            ) for row in DBInterface.execute(database, "SELECT * FROM pair_ratio_aggregates")
        ])
        selected_before =
            first(DBInterface.execute(database, "SELECT COUNT(*) AS n FROM selected_pairs")).n
        @test matroid_count == 1
        @test first(
            DBInterface.execute(database, "SELECT COUNT(*) AS n FROM sampling_runs"),
        ).n == 1
        @test first(
            DBInterface.execute(database, "SELECT COUNT(*) AS n FROM sampled_chunks"),
        ).n == 1
        provenance = first(DBInterface.execute(database, "SELECT * FROM sampling_observations"))
        @test provenance.global_index == 17
        @test provenance.chunk_offset == 17
        @test provenance.design_weight == 100.0
        @test legacy_pair_tables == 0
        @test aggregate.ratio_num == 9
        @test aggregate.ratio_den == 16
        @test aggregate.pair_count == 28
        @test aggregate.census_pair_count == 28
        @test aggregate.matroid_weight ≈ 1.0
        @test aggregate.census_maximizer_count == 28
        @test selected_before == 0

        matroid_id = first(DBInterface.execute(database, "SELECT matroid_id FROM matroids")).matroid_id
        store_selected_pair_profile!(
            database,
            matroid_id;
            reason="unit_test_heatmap",
            selection_group="test",
        )
        selected_matroids = first(
            DBInterface.execute(database, "SELECT COUNT(*) AS n FROM selected_matroids"),
        ).n
        selected_pairs =
            first(DBInterface.execute(database, "SELECT COUNT(*) AS n FROM selected_pairs")).n
        @test selected_matroids == 1
        @test selected_pairs == 28

        plain_export = joinpath(directory, "runs.csv")
        compressed_export = joinpath(directory, "runs.csv.zst")
        export_table_csv(database, "SELECT run_id, accepted_count FROM runs", plain_export)
        export_table_csv_zst(
            database,
            "SELECT run_id, accepted_count FROM runs",
            compressed_export,
        )
        @test read(plain_export, String) == read(
            `zstd --quiet --decompress --stdout $compressed_export`,
            String,
        )
    end
end
