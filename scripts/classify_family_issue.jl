#!/usr/bin/env julia

"""
Threshold-screen one infinite-family GitHub Issue Form.

This script does not verify the family construction, curve formula, or proof.
It only parses the exact claimed supremum and applies the public eligibility
threshold before human mathematical review.
"""

using JSON3

include(joinpath(@__DIR__, "..", "src", "SubmissionEligibility.jl"))
using .SubmissionEligibility

length(ARGS) == 2 || error(
    "usage: classify_family_issue.jl EVENT_JSON RESULT_JSON",
)

event_path, result_path = ARGS

function write_json(path, value)
    mkpath(dirname(abspath(path)))
    open(path, "w") do output
        JSON3.pretty(output, value)
        println(output)
    end
end

function form_sections(body::AbstractString)
    sections = Dict{String,String}()
    pattern = r"(?ms)^###[ \t]+([^\r\n]+)\r?\n(.*?)(?=^###[ \t]+|\z)"
    for matched in eachmatch(pattern, String(body))
        value = strip(matched.captures[2])
        value == "_No response_" && (value = "")
        sections[strip(matched.captures[1])] = value
    end
    return sections
end

function required_section(sections, label::String)
    haskey(sections, label) || error("family issue is missing '$label'")
    value = strip(sections[label])
    isempty(value) && error("family issue field '$label' must not be empty")
    return value
end

function nonnegative_integer(value::AbstractString, label::String)
    occursin(r"^\d+$", value) || error("$label must be a nonnegative integer")
    return try
        parse(BigInt, value)
    catch
        error("$label is outside the supported integer range")
    end
end

function positive_integer(value::AbstractString, label::String)
    result = nonnegative_integer(value, label)
    result > 0 || error("$label must be positive")
    return result
end

try
    event = JSON3.read(read(event_path, String), Dict{String,Any})
    issue = get(event, "issue", nothing)
    issue isa AbstractDict || error("GitHub event has no issue object")
    sections = form_sections(String(get(issue, "body", "")))
    numerator_value = nonnegative_integer(
        required_section(sections, "Claimed supremum numerator"),
        "Claimed supremum numerator",
    )
    denominator_value = positive_integer(
        required_section(sections, "Claimed supremum denominator"),
        "Claimed supremum denominator",
    )
    numerator_value <= typemax(Int) || error("claimed numerator is too large")
    denominator_value <= typemax(Int) || error("claimed denominator is too large")
    eligibility = classify_family_claim(Int(numerator_value), Int(denominator_value))
    write_json(result_path, (
        status="threshold-screened",
        classification=eligibility.classification,
        family_name=required_section(sections, "Family name"),
        eligibility=eligibility,
    ))
catch error
    write_json(result_path, (
        status="verification-failed",
        classification="verification-failed",
        message=sprint(showerror, error),
    ))
    rethrow()
end
