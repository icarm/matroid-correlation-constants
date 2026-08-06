"""
Verify concrete-matroid JSON submissions and emit deterministic certificates.

Usage:

    julia --project=. scripts/verify_matroid_submissions.jl INPUT.json [CERTIFICATE.json]
    julia --project=. scripts/verify_matroid_submissions.jl --all INPUT_DIR OUTPUT_DIR
"""

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions
include(joinpath(@__DIR__, "..", "src", "MatroidSubmissionVerifier.jl"))
using .MatroidSubmissionVerifier
include(joinpath(@__DIR__, "..", "src", "SubmissionEligibility.jl"))
using .SubmissionEligibility

classify_certificate(certificate) = merge(
    certificate,
    (eligibility=classify_concrete_certificate(certificate),),
)

function usage(io::IO=stdout)
    println(io, "Usage:")
    println(io, "  julia --project=. scripts/verify_matroid_submissions.jl INPUT.json [CERTIFICATE.json]")
    println(io, "  julia --project=. scripts/verify_matroid_submissions.jl --all INPUT_DIR OUTPUT_DIR")
end

function json_files(directory::AbstractString)
    isdir(directory) || throw(ArgumentError("submission directory does not exist: $directory"))
    files = String[]
    for (root, _, names) in walkdir(directory)
        for name in names
            endswith(lowercase(name), ".json") && push!(files, joinpath(root, name))
        end
    end
    return sort!(files)
end

function append_github_summary(rows, failures)
    summary_path = get(ENV, "GITHUB_STEP_SUMMARY", "")
    isempty(summary_path) && return
    open(summary_path, "a") do output
        println(output, "## Concrete-matroid verification")
        println(output)
        if isempty(rows)
            println(output, "No concrete submission JSON files were present.")
        else
            println(output, "| Submission | Verification | Eligibility | Exact value | Bases |")
            println(output, "|---|---|---|---:|---:|")
            for row in rows
                println(
                    output,
                    "| `", row.file, "` | verified as claimed | ",
                    row.classification, " | ",
                    row.numerator, "/", row.denominator, " | ", row.bases, " |",
                )
            end
        end
        if !isempty(failures)
            println(output)
            println(output, "### Rejected inputs")
            for failure in failures
                println(output, "- `", failure.file, "`: ", failure.message)
            end
        end
    end
end

function verify_one(input_path::String, output_path::Union{Nothing,String})
    certificate = classify_certificate(verify_submission_file(input_path))
    output_path === nothing || write_certificate(output_path, certificate)
    exact = certificate.correlation.exact
    println(
        "VERIFIED id=", certificate.matroid.id,
        " alpha_bar=", exact.numerator, "/", exact.denominator,
        " bases=", certificate.matroid.number_of_bases,
        " fields=", join(certificate.representations.verified_prime_fields, ','),
        " eligibility=", certificate.eligibility.classification,
    )
    return certificate
end

function verify_all(input_directory::String, output_directory::String)
    files = json_files(input_directory)
    mkpath(output_directory)
    rows = NamedTuple[]
    failures = NamedTuple[]
    encodings = Dict{Tuple{Int,Int,String},String}()
    for path in files
        relative_path = replace(relpath(path, input_directory), '\\' => '/')
        try
            certificate = classify_certificate(verify_submission_file(path))
            identity = (
                certificate.matroid.ground_set_size,
                certificate.matroid.rank,
                certificate.matroid.basis_hex,
            )
            if haskey(encodings, identity)
                throw(SubmissionValidationError(
                    "exact duplicate of $(encodings[identity])",
                ))
            end
            encodings[identity] = relative_path
            output_path = joinpath(output_directory, certificate.matroid.id * ".certificate.json")
            write_certificate(output_path, certificate)
            exact = certificate.correlation.exact
            push!(rows, (
                file=relative_path,
                numerator=exact.numerator,
                denominator=exact.denominator,
                bases=certificate.matroid.number_of_bases,
                classification=certificate.eligibility.classification,
            ))
            println("VERIFIED file=$relative_path certificate=$output_path")
        catch error
            message = sprint(showerror, error)
            push!(failures, (file=relative_path, message=message))
            println(stderr, "REJECTED file=$relative_path reason=$message")
        end
    end
    append_github_summary(rows, failures)
    isempty(failures) || return false
    println("VERIFICATION_COMPLETE verified=$(length(rows)) rejected=0")
    return true
end

function main(args)
    if isempty(args) || args[1] in ("-h", "--help")
        usage()
        return isempty(args) ? 1 : 0
    end
    if args[1] == "--all"
        length(args) == 3 || (usage(stderr); return 1)
        return verify_all(args[2], args[3]) ? 0 : 1
    end
    1 <= length(args) <= 2 || (usage(stderr); return 1)
    output = length(args) == 2 ? args[2] : nothing
    try
        verify_one(args[1], output)
        return 0
    catch error
        println(stderr, "REJECTED file=$(args[1]) reason=$(sprint(showerror, error))")
        return 1
    end
end

exit(main(ARGS))
