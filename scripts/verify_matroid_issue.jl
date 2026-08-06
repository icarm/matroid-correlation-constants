#!/usr/bin/env julia

using JSON3

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions
include(joinpath(@__DIR__, "..", "src", "MatroidSubmissionVerifier.jl"))
using .MatroidSubmissionVerifier
include(joinpath(@__DIR__, "..", "src", "MatroidIssueIntake.jl"))
using .MatroidIssueIntake
include(joinpath(@__DIR__, "..", "src", "SubmissionEligibility.jl"))
using .SubmissionEligibility

length(ARGS) == 4 || error(
    "usage: verify_matroid_issue.jl EVENT_JSON NORMALIZED_JSON CERTIFICATE_JSON RESULT_JSON",
)

event_path, normalized_path, certificate_path, result_path = ARGS

function write_json(path, value)
    mkpath(dirname(abspath(path)))
    open(path, "w") do output
        JSON3.pretty(output, value)
        println(output)
    end
end

try
    event = JSON3.read(read(event_path, String), Dict{String,Any})
    submission, certificate = verify_issue_event(event)
    eligibility = classify_concrete_certificate(certificate)
    classified_certificate = merge(certificate, (eligibility=eligibility,))
    write_json(normalized_path, submission)
    write_certificate(certificate_path, classified_certificate)
    write_json(result_path, (
        status="verified",
        classification=eligibility.classification,
        eligibility=eligibility,
        exact=certificate.correlation.exact,
        rank=certificate.matroid.rank,
        ground_set_size=certificate.matroid.ground_set_size,
        number_of_bases=certificate.matroid.number_of_bases,
        maximizing_pair_count=certificate.correlation.maximizing_pair_count,
    ))
catch error
    write_json(result_path, (
        status="verification-failed",
        classification="verification-failed",
        message=sprint(showerror, error),
    ))
    rethrow()
end
