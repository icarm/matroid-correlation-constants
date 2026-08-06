"""
Classify verified concrete submissions against the public challenge policy.

This module deliberately sits after exact matroid verification. It never
publishes an entry and never treats a threshold comparison as mathematical or
curatorial acceptance. Infinite-family classification is threshold-only: the
claimed limit is screened, but its proof still requires human review.
"""
module SubmissionEligibility

using JSON3

export DEFAULT_ELIGIBILITY_POLICY_PATH,
       EligibilityPolicyError,
       classify_concrete_certificate,
       classify_family_claim,
       load_eligibility_policy

const DEFAULT_ELIGIBILITY_POLICY_PATH = normpath(joinpath(
    @__DIR__,
    "..",
    "matroid_correlation_website",
    "data",
    "submission-eligibility-policy.json",
))

struct EligibilityPolicyError <: Exception
    message::String
end

Base.showerror(io::IO, error::EligibilityPolicyError) = print(io, error.message)

policy_invalid(message::AbstractString) = throw(EligibilityPolicyError(String(message)))

function _required(object, key::String, context::String)
    object isa AbstractDict || policy_invalid("$context must be an object")
    haskey(object, key) || policy_invalid("$context is missing '$key'")
    return object[key]
end

function _positive_integer(value, context::String)
    value isa Integer && !(value isa Bool) || policy_invalid("$context must be an integer")
    value > 0 || policy_invalid("$context must be positive")
    return BigInt(value)
end

function _nonnegative_integer(value, context::String)
    value isa Integer && !(value isa Bool) || policy_invalid("$context must be an integer")
    value >= 0 || policy_invalid("$context must be nonnegative")
    return BigInt(value)
end

function _ratio(object, context::String)
    numerator_value = _nonnegative_integer(
        _required(object, "numerator", context),
        "$context.numerator",
    )
    denominator_value = _positive_integer(
        _required(object, "denominator", context),
        "$context.denominator",
    )
    return numerator_value // denominator_value
end

function _ratio_record(value::Rational{BigInt})
    return (
        numerator=numerator(value),
        denominator=denominator(value),
        decimal=Float64(value),
    )
end

"""Load and validate the single machine-readable publication policy."""
function load_eligibility_policy(path::AbstractString=DEFAULT_ELIGIBILITY_POLICY_PATH)
    data = try
        JSON3.read(read(path, String), Dict{String,Any})
    catch error
        policy_invalid("cannot read eligibility policy at $path: $(sprint(showerror, error))")
    end

    schema_version = _positive_integer(
        _required(data, "schema_version", "policy"),
        "policy.schema_version",
    )
    schema_version == 1 || policy_invalid("unsupported eligibility-policy schema version")
    get(data, "human_review_required", nothing) === true || policy_invalid(
        "policy.human_review_required must be true",
    )

    finite_rule = _required(data, "finite_on_the_nose", "policy")
    _required(finite_rule, "comparison", "finite_on_the_nose") ==
        "greater_than_or_equal" || policy_invalid(
        "finite_on_the_nose comparison must be greater_than_or_equal",
    )
    finite_threshold = _ratio(
        _required(finite_rule, "threshold", "finite_on_the_nose"),
        "finite_on_the_nose.threshold",
    )

    family_rule = _required(data, "family_in_the_limit", "policy")
    _required(family_rule, "comparison", "family_in_the_limit") ==
        "greater_than_or_equal" || policy_invalid(
        "family_in_the_limit comparison must be greater_than_or_equal",
    )
    family_threshold = _ratio(
        _required(family_rule, "threshold", "family_in_the_limit"),
        "family_in_the_limit.threshold",
    )

    raw_records = _required(data, "finite_field_records", "policy")
    raw_records isa AbstractVector || policy_invalid("finite_field_records must be an array")
    field_records = Dict{Int,NamedTuple}()
    for (index, record) in enumerate(raw_records)
        order_value = _positive_integer(
            _required(record, "field_order", "finite_field_records[$index]"),
            "finite_field_records[$index].field_order",
        )
        order_value <= typemax(Int) || policy_invalid("field order is too large")
        order = Int(order_value)
        haskey(field_records, order) && policy_invalid("duplicate record for GF($order)")
        value = _ratio(record, "finite_field_records[$index]")
        source = String(_required(record, "source", "finite_field_records[$index]"))
        isempty(strip(source)) && policy_invalid("finite-field record source must not be empty")
        field_records[order] = (value=value, source=source)
    end

    return (
        schema_version=Int(schema_version),
        updated=String(_required(data, "updated", "policy")),
        finite_threshold=finite_threshold,
        family_threshold=family_threshold,
        field_records=field_records,
    )
end

"""Classify one already verified concrete-matroid certificate."""
function classify_concrete_certificate(
    certificate;
    policy_path::AbstractString=DEFAULT_ELIGIBILITY_POLICY_PATH,
)
    policy = load_eligibility_policy(policy_path)
    exact = certificate.correlation.exact
    candidate = BigInt(exact.numerator) // BigInt(exact.denominator)
    qualifying_challenges = NamedTuple[]

    if candidate >= policy.finite_threshold
        push!(qualifying_challenges, (
            id="finite-on-the-nose",
            comparison="greater-than-or-equal",
            threshold=_ratio_record(policy.finite_threshold),
        ))
    end

    field_comparisons = NamedTuple[]
    verified_fields = sort!(unique(Int.(certificate.representations.verified_finite_fields)))
    for order in verified_fields
        haskey(policy.field_records, order) || continue
        incumbent = policy.field_records[order]
        beats_record = candidate > incumbent.value
        push!(field_comparisons, (
            field_order=order,
            candidate=_ratio_record(candidate),
            incumbent=_ratio_record(incumbent.value),
            incumbent_source=incumbent.source,
            beats_record=beats_record,
        ))
        if beats_record
            push!(qualifying_challenges, (
                id="finite-field-record",
                field_order=order,
                comparison="strictly-greater-than",
                threshold=_ratio_record(incumbent.value),
            ))
        end
    end

    classification = isempty(qualifying_challenges) ?
        "below-publication-thresholds" : "eligible-for-review"
    return (
        classification=classification,
        verification_scope="exact-concrete-matroid",
        human_review_required=true,
        accepted_and_published=false,
        policy_version=policy.schema_version,
        policy_updated=policy.updated,
        candidate=_ratio_record(candidate),
        qualifying_challenges=qualifying_challenges,
        finite_field_comparisons=field_comparisons,
    )
end

"""
Screen an infinite family's claimed limit against the numeric threshold.

This does not verify the construction, curve formula, or proof.
"""
function classify_family_claim(
    numerator_value::Integer,
    denominator_value::Integer;
    policy_path::AbstractString=DEFAULT_ELIGIBILITY_POLICY_PATH,
)
    numerator_value >= 0 || policy_invalid("family numerator must be nonnegative")
    denominator_value > 0 || policy_invalid("family denominator must be positive")
    policy = load_eligibility_policy(policy_path)
    candidate = BigInt(numerator_value) // BigInt(denominator_value)
    qualifies = candidate >= policy.family_threshold
    return (
        classification=qualifies ? "eligible-for-review" : "below-publication-thresholds",
        verification_scope="claimed-family-limit-only",
        mathematical_proof_verified=false,
        human_review_required=true,
        accepted_and_published=false,
        policy_version=policy.schema_version,
        policy_updated=policy.updated,
        candidate=_ratio_record(candidate),
        threshold=_ratio_record(policy.family_threshold),
        qualifying_challenges=qualifies ? [(
            id="family-in-the-limit",
            comparison="greater-than-or-equal",
            threshold=_ratio_record(policy.family_threshold),
        )] : NamedTuple[],
    )
end

end
