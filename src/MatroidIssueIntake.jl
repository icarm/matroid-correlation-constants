"""
Parse GitHub's concrete-matroid Issue Form as inert data and pass the
normalized submission to MatroidSubmissionVerifier.

The form asks for finite matroid data together with a compact discovery and
AI-use disclosure. GitHub supplies the submitter identity, issue URL, and
submission timestamp.
"""
module MatroidIssueIntake

using JSON3
using ..MatroidSubmissionVerifier

export parse_issue_sections,
       submission_from_issue_event,
       verify_issue_event

function intake_invalid(message::AbstractString)
    throw(SubmissionValidationError("issue form: " * String(message)))
end

function _string(value, context::String)
    value isa AbstractString || intake_invalid("$context must be text")
    result = String(strip(String(value)))
    isempty(result) && intake_invalid("$context must not be empty")
    return result
end

function _unwrap_code_fence(value::AbstractString)
    matched = match(
        r"(?s)^\x60\x60\x60[^\r\n]*\r?\n(.*)\r?\n\x60\x60\x60$",
        strip(value),
    )
    return matched === nothing ? strip(value) : strip(matched.captures[1])
end

"""Return a dictionary keyed by the exact visible labels in the Issue Form."""
function parse_issue_sections(body::AbstractString)
    sections = Dict{String,String}()
    pattern = r"(?ms)^###[ \t]+([^\r\n]+)\r?\n(.*?)(?=^###[ \t]+|\z)"
    for matched in eachmatch(pattern, String(body))
        label = strip(matched.captures[1])
        value = _unwrap_code_fence(matched.captures[2])
        value == "_No response_" && (value = "")
        sections[label] = value
    end
    return sections
end

function _required_section(sections, label::String)
    haskey(sections, label) || intake_invalid("missing '$label'")
    return _string(sections[label], label)
end

function _optional_section(sections, label::String)
    value = get(sections, label, "")
    return String(strip(value))
end

function _positive_integer(value::String, label::String)
    matched = match(r"^[1-9]\d*$", strip(value))
    matched === nothing && intake_invalid("$label must be a positive integer")
    parsed = try
        parse(Int, value)
    catch
        intake_invalid("$label is outside the supported integer range")
    end
    return parsed
end

function _ratio(value::String)
    matched = match(r"^(\d+)(?:/([1-9]\d*))?$", strip(value))
    matched === nothing && intake_invalid(
        "Claimed alpha-bar must be a nonnegative integer or fraction",
    )
    numerator_value = try
        parse(Int, matched.captures[1])
    catch
        intake_invalid("the claimed numerator is outside the supported range")
    end
    denominator_value = matched.captures[2] === nothing ? 1 : try
        parse(Int, matched.captures[2])
    catch
        intake_invalid("the claimed denominator is outside the supported range")
    end
    return Dict(
        "numerator" => numerator_value,
        "denominator" => denominator_value,
    )
end

function _yes_no(value::String, label::String)
    normalized = lowercase(strip(value))
    normalized == "yes" && return true
    normalized == "no" && return false
    intake_invalid("$label must be Yes or No")
end

function _field(value::String, label::String)
    normalized = uppercase(replace(strip(value), " " => ""))
    normalized in ("Q", "QQ", "RATIONALS") && return Dict("kind" => "rational")
    matched = match(r"^GF\((\d+)\)$", normalized)
    matched === nothing && intake_invalid("$label must be Q or GF(q)")
    order = try
        parse(Int, matched.captures[1])
    catch
        intake_invalid("$label has an unsupported field order")
    end
    return Dict("kind" => "finite", "order" => order)
end

function _json_array(value::String, label::String)
    parsed = try
        JSON3.read(value)
    catch error
        intake_invalid("$label is not valid JSON: $(sprint(showerror, error))")
    end
    parsed isa AbstractVector || intake_invalid("$label must be a JSON array")
    return parsed
end

function _issue_name(title::String, issue_number::Int)
    name = strip(replace(title, r"^\[Concrete\]\s*" => ""))
    return isempty(name) ? "Concrete matroid submission #$issue_number" : name
end

"""Normalize one GitHub issue event into the verifier's finite-data schema."""
function submission_from_issue_event(event)
    event isa AbstractDict || intake_invalid("GitHub event must be a JSON object")
    haskey(event, "issue") || intake_invalid("GitHub event has no issue")
    issue = event["issue"]
    issue isa AbstractDict || intake_invalid("event.issue must be an object")
    body = _string(get(issue, "body", ""), "issue body")
    sections = parse_issue_sections(body)

    n = _positive_integer(
        _required_section(sections, "Ground-set size n"),
        "Ground-set size n",
    )
    rank = _positive_integer(_required_section(sections, "Rank r"), "Rank r")
    rank < n || intake_invalid("Rank r must be smaller than n")
    n <= MAX_GROUND_SET_SIZE || intake_invalid(
        "n=$n exceeds the automatic limit of $MAX_GROUND_SET_SIZE",
    )

    description_type = lowercase(
        _required_section(sections, "Description type"),
    )
    description_type in ("matrix", "bases", "circuits", "hyperplanes") ||
        intake_invalid("Description type is not recognized")
    data = _json_array(
        _required_section(sections, "Matroid data"),
        "Matroid data",
    )

    input = Dict{String,Any}(
        "type" => description_type,
        "rank" => rank,
    )
    if description_type == "matrix"
        field_text = _required_section(sections, "Matrix field")
        input["field"] = _field(field_text, "Matrix field")
        input["rows"] = data
    else
        input["sets"] = data
    end

    certificate_field = _optional_section(sections, "Optional certificate field")
    certificate_matrix = _optional_section(sections, "Optional certificate matrix")
    xor(isempty(certificate_field), isempty(certificate_matrix)) && intake_invalid(
        "Optional certificate field and matrix must be supplied together",
    )
    representations = Any[]
    if !isempty(certificate_field)
        push!(representations, Dict{String,Any}(
            "type" => "matrix",
            "rank" => rank,
            "field" => _field(certificate_field, "Optional certificate field"),
            "rows" => _json_array(
                certificate_matrix,
                "Optional certificate matrix",
            ),
        ))
    end

    issue_number = Int(get(issue, "number", 0))
    issue_number > 0 || intake_invalid("issue number is missing")
    title = _string(get(issue, "title", ""), "issue title")
    user = get(issue, "user", Dict{String,Any}())
    user isa AbstractDict || intake_invalid("issue user is missing")
    login = _string(get(user, "login", ""), "GitHub login")
    issue_url = _string(get(issue, "html_url", ""), "issue URL")
    submitted_at = _string(get(issue, "created_at", ""), "issue creation timestamp")
    notes = _optional_section(sections, "Optional notes")
    ai_used = _yes_no(
        _required_section(sections, "Was AI used in the discovery?"),
        "Was AI used in the discovery?",
    )
    ai_model_version = _required_section(sections, "AI model and version")
    ai_role = _required_section(sections, "AI role")
    ai_chat_url = _optional_section(sections, "Optional AI chat link")
    if ai_used
        lowercase(ai_model_version) in ("none", "n/a", "not applicable") && intake_invalid(
            "AI model and version must identify the system when AI use is Yes",
        )
        lowercase(ai_role) in ("none", "n/a", "not applicable") && intake_invalid(
            "AI role must describe the assistance when AI use is Yes",
        )
    end

    discovery = Dict{String,Any}(
        "date" => _required_section(sections, "Discovery date"),
        "discoverers" => _required_section(sections, "Discoverers"),
        "ai_used" => ai_used,
        "ai_model_version" => ai_model_version,
        "ai_role" => ai_role,
    )
    isempty(ai_chat_url) || (discovery["ai_chat_url"] = ai_chat_url)

    submission = Dict{String,Any}(
        "schema_version" => 1,
        "kind" => "matroid",
        "id" => "github-issue-$issue_number",
        "proposed_name" => _issue_name(title, issue_number),
        "contributors" => [Dict(
            "github" => login,
            "display_name" => login,
        )],
        "ground_set" => Dict("labels" => collect(0:n-1)),
        "input" => input,
        "claimed_alpha_bar" => _ratio(
            _required_section(sections, "Claimed alpha-bar"),
        ),
        "discovery" => discovery,
        "submitted_at" => submitted_at,
        "provenance" => issue_url,
        "license" => "No separate data license asserted by automated intake.",
        "notes" => notes,
    )
    isempty(representations) || (submission["representations"] = representations)
    return submission
end

"""Normalize and exactly verify one parsed GitHub issue event."""
function verify_issue_event(event)
    submission = submission_from_issue_event(event)
    certificate = verify_submission_data(submission)
    return submission, certificate
end

end
