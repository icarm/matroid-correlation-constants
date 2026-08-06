"""
Trusted validation and exact certification for concrete-matroid submissions.

The verifier accepts finite combinatorial data only. It never evaluates code
from a submission. Every accepted description is normalized to the project's
colex/reverse-lex basis encoding before `matroid_statistics` recomputes every
eligible pair ratio exactly.
"""
module MatroidSubmissionVerifier

using JSON3
using Oscar
using SHA
using ..CorrelationRatiosDistributions

export MAX_GROUND_SET_SIZE,
       MAX_LISTED_SETS,
       SubmissionValidationError,
       VERIFIER_VERSION,
       verify_submission_data,
       verify_submission_file,
       write_certificate

const VERIFIER_VERSION = "1.2.0"
const MAX_GROUND_SET_SIZE = 18
const MAX_LISTED_SETS = 5_000
const MAX_MATRIX_CELLS = 5_000
const MAX_REPRESENTATION_CERTIFICATES = 8

struct SubmissionValidationError <: Exception
    message::String
end

Base.showerror(io::IO, error::SubmissionValidationError) = print(io, error.message)

invalid(message::AbstractString) = throw(SubmissionValidationError(String(message)))

function _reject_unknown_keys(object, allowed, context::String)
    object isa AbstractDict || invalid("$context must be a JSON object")
    allowed_keys = Set(String(key) for key in allowed)
    for key in keys(object)
        key_string = String(key)
        key_string in allowed_keys || invalid(
            "$context contains unknown field '$key_string'",
        )
    end
    return nothing
end

function _required(object, key::String, context::String)
    object isa AbstractDict || invalid("$context must be a JSON object")
    haskey(object, key) || invalid("$context is missing required field '$key'")
    return object[key]
end

function _optional(object, key::String, default=nothing)
    object isa AbstractDict || return default
    return haskey(object, key) ? object[key] : default
end

function _string(value, context::String; allow_empty::Bool=false)
    value isa AbstractString || invalid("$context must be a string")
    result = strip(String(value))
    !allow_empty && isempty(result) && invalid("$context must not be empty")
    return result
end

function _integer(value, context::String)
    value isa Integer && !(value isa Bool) || invalid("$context must be an integer")
    typemin(Int) <= value <= typemax(Int) || invalid("$context is outside the supported range")
    return Int(value)
end

function _array(value, context::String)
    value isa AbstractVector || invalid("$context must be an array")
    return value
end

function _is_prime(value::Int)
    value >= 2 || return false
    value == 2 && return true
    iseven(value) && return false
    divisor = 3
    while divisor^2 <= value
        value % divisor == 0 && return false
        divisor += 2
    end
    return true
end

function _label(value, context::String)
    if value isa AbstractString
        return _string(value, context)
    elseif value isa Integer && !(value isa Bool)
        return string(value)
    end
    invalid("$context must be a string or integer")
end

function _ground_set(data)
    ground = _required(data, "ground_set", "submission")
    _reject_unknown_keys(ground, ("labels",), "ground_set")
    raw_labels = _array(_required(ground, "labels", "ground_set"), "ground_set.labels")
    isempty(raw_labels) && invalid("ground_set.labels must not be empty")
    length(raw_labels) <= MAX_GROUND_SET_SIZE || invalid(
        "ground set has $(length(raw_labels)) elements; the automatic limit is $MAX_GROUND_SET_SIZE",
    )
    labels = [_label(value, "ground_set.labels[$index]") for (index, value) in enumerate(raw_labels)]
    length(unique(labels)) == length(labels) || invalid(
        "ground_set.labels must be distinct (integer and string spellings are identified)",
    )
    index = Dict(label => position - 1 for (position, label) in enumerate(labels))
    return labels, index
end

function _set_mask(raw_set, label_index::Dict{String,Int}, context::String)
    values = _array(raw_set, context)
    mask = UInt64(0)
    for (position, raw_label) in enumerate(values)
        label = _label(raw_label, "$context[$position]")
        haskey(label_index, label) || invalid("$context contains unknown element '$label'")
        bit = UInt64(1) << label_index[label]
        mask & bit == 0 || invalid("$context contains element '$label' more than once")
        mask |= bit
    end
    return mask
end

function _listed_masks(spec, label_index::Dict{String,Int}, noun::String)
    raw_sets = _array(_required(spec, "sets", "input"), "input.sets")
    isempty(raw_sets) && invalid("input.sets must contain at least one $noun")
    length(raw_sets) <= MAX_LISTED_SETS || invalid(
        "submission lists $(length(raw_sets)) sets; the automatic limit is $MAX_LISTED_SETS",
    )
    masks = [
        _set_mask(raw_set, label_index, "input.sets[$index]")
        for (index, raw_set) in enumerate(raw_sets)
    ]
    length(unique(masks)) == length(masks) || invalid("input.sets contains duplicate $noun entries")
    return masks
end

function _declared_rank(spec, actual_rank::Int)
    declared = _optional(spec, "rank")
    declared === nothing && return actual_rank
    declared_rank = _integer(declared, "input.rank")
    declared_rank == actual_rank || invalid(
        "input.rank is $declared_rank, but the supplied data have rank $actual_rank",
    )
    return actual_rank
end

function _encoding_from_basis_masks(bases::Vector{UInt64}, n::Int, rank::Int)
    basis_set = Set(bases)
    return String([
        mask in basis_set ? '*' : '0'
        for mask in colex_masks(n, rank)
    ])
end

function _validate_basis_exchange(bases::Vector{UInt64}, n::Int, rank::Int)
    isempty(bases) && invalid("a basis list must not be empty")
    all(mask -> count_ones(mask) == rank, bases) || invalid(
        "all listed bases must have the same cardinality",
    )
    basis_set = Set(bases)
    full = (UInt64(1) << n) - UInt64(1)
    for left in bases
        exchange_options = Dict{UInt64,UInt64}()
        left_elements = left
        while left_elements != 0
            removed = left_elements & (-left_elements)
            options = UInt64(0)
            outside = full ⊻ left
            while outside != 0
                added = outside & (-outside)
                ((left ⊻ removed) | added) in basis_set && (options |= added)
                outside ⊻= added
            end
            exchange_options[removed] = options
            left_elements ⊻= removed
        end
        for right in bases
            left_only = left & (full ⊻ right)
            right_only = right & (full ⊻ left)
            remaining = left_only
            while remaining != 0
                removed = remaining & (-remaining)
                exchange_options[removed] & right_only != 0 || invalid(
                    "the submitted bases fail the basis-exchange axiom",
                )
                remaining ⊻= removed
            end
        end
    end
    return nothing
end

function _bases_input(spec, label_index::Dict{String,Int}, n::Int)
    bases = _listed_masks(spec, label_index, "basis")
    rank = count_ones(first(bases))
    1 <= rank < n || invalid("automatic correlation verification requires 1 <= rank < n")
    _declared_rank(spec, rank)
    _validate_basis_exchange(bases, n, rank)
    return _encoding_from_basis_masks(bases, n, rank), rank
end

function _dependent_table(circuits::Vector{UInt64}, n::Int)
    full = (UInt64(1) << n) - UInt64(1)
    dependent = falses(Int(full) + 1)
    for circuit in circuits
        outside = full ⊻ circuit
        subset = outside
        while true
            dependent[Int(circuit | subset) + 1] = true
            subset == 0 && break
            subset = (subset - UInt64(1)) & outside
        end
    end
    return dependent
end

function _validate_circuit_axioms(circuits::Vector{UInt64}, n::Int, context::String)
    any(iszero, circuits) && invalid("$context must not contain the empty set")
    ordered = sort(circuits; by=count_ones)
    for small_index in eachindex(ordered)
        small = ordered[small_index]
        for large_index in small_index+1:length(ordered)
            large = ordered[large_index]
            small & large == small && invalid(
                "$context fail the circuit incomparability axiom",
            )
        end
    end
    dependent = _dependent_table(circuits, n)
    for left_index in eachindex(circuits)
        left = circuits[left_index]
        for right_index in left_index+1:length(circuits)
            right = circuits[right_index]
            intersection = left & right
            while intersection != 0
                element = intersection & (-intersection)
                target = (left | right) ⊻ element
                dependent[Int(target) + 1] || invalid(
                    "$context fail circuit elimination",
                )
                intersection ⊻= element
            end
        end
    end
    return dependent
end

function _bases_from_circuits(circuits::Vector{UInt64}, n::Int, context::String)
    dependent = _validate_circuit_axioms(circuits, n, context)
    full = (UInt64(1) << n) - UInt64(1)
    rank = maximum(
        count_ones(mask)
        for mask in UInt64(0):full
        if !dependent[Int(mask) + 1]
    )
    bases = UInt64[
        mask
        for mask in UInt64(0):full
        if count_ones(mask) == rank && !dependent[Int(mask) + 1]
    ]
    return bases, rank
end

function _circuits_input(spec, label_index::Dict{String,Int}, n::Int)
    circuits = _listed_masks(spec, label_index, "circuit")
    bases, rank = _bases_from_circuits(circuits, n, "the submitted circuits")
    1 <= rank < n || invalid("automatic correlation verification requires 1 <= rank < n")
    _declared_rank(spec, rank)
    return _encoding_from_basis_masks(bases, n, rank), rank
end

function _hyperplanes_input(spec, label_index::Dict{String,Int}, n::Int)
    hyperplanes = _listed_masks(spec, label_index, "hyperplane")
    full = (UInt64(1) << n) - UInt64(1)
    any(==(full), hyperplanes) && invalid("a hyperplane must be a proper subset")
    cocircuits = UInt64[full ⊻ hyperplane for hyperplane in hyperplanes]
    dual_bases, dual_rank = _bases_from_circuits(
        cocircuits,
        n,
        "the complements of the submitted hyperplanes",
    )
    rank = n - dual_rank
    1 <= rank < n || invalid("automatic correlation verification requires 1 <= rank < n")
    _declared_rank(spec, rank)
    bases = UInt64[full ⊻ basis for basis in dual_bases]
    return _encoding_from_basis_masks(bases, n, rank), rank
end

function _prime_power(order::Int)
    order >= 2 || return nothing
    for prime in 2:order
        _is_prime(prime) || continue
        remainder = order
        degree = 0
        while remainder % prime == 0
            remainder ÷= prime
            degree += 1
        end
        remainder == 1 && return (prime=prime, degree=degree)
    end
    return nothing
end

function _field_spec(raw_field, context::String)
    raw_field isa AbstractDict || invalid("$context must be a JSON object")
    _reject_unknown_keys(raw_field, ("kind", "order"), context)
    kind_value = _optional(raw_field, "kind")
    kind = kind_value === nothing ? "finite" : lowercase(_string(kind_value, "$context.kind"))
    if kind == "rational"
        haskey(raw_field, "order") && invalid("$context.order is not used for the rational field")
        return (
            kind=:rational,
            label="Q",
            order=nothing,
            characteristic=nothing,
            degree=nothing,
        )
    elseif kind == "finite"
        order = _integer(_required(raw_field, "order", context), "$context.order")
        decomposition = _prime_power(order)
        decomposition === nothing && invalid("$context.order must be a prime power")
        return (
            kind=:finite,
            label="GF($order)",
            order=order,
            characteristic=decomposition.prime,
            degree=decomposition.degree,
        )
    end
    invalid("$context.kind must be 'finite' or 'rational'")
end

function _raw_matrix_rows(spec, n::Int, context::String)
    _reject_unknown_keys(
        spec,
        ("type", "rank", "field", "rows", "columns"),
        context,
    )
    type_value = _optional(spec, "type")
    if type_value !== nothing
        _string(type_value, "$context.type") == "matrix" || invalid(
            "$context.type must be 'matrix'",
        )
    end
    field = _field_spec(_required(spec, "field", context), "$context.field")
    has_rows = haskey(spec, "rows")
    has_columns = haskey(spec, "columns")
    xor(has_rows, has_columns) || invalid("$context must contain exactly one of 'rows' or 'columns'")

    rows = Vector{Vector{Any}}()
    if has_rows
        raw_rows = _array(spec["rows"], "$context.rows")
        isempty(raw_rows) && invalid("$context.rows must not be empty")
        length(raw_rows) * n <= MAX_MATRIX_CELLS || invalid(
            "$context exceeds the automatic matrix-cell limit of $MAX_MATRIX_CELLS",
        )
        for (row_index, raw_row) in enumerate(raw_rows)
            entries = _array(raw_row, "$context.rows[$row_index]")
            length(entries) == n || invalid(
                "$context.rows[$row_index] has $(length(entries)) entries; expected $n",
            )
            push!(rows, Any[entry for entry in entries])
        end
    else
        raw_columns = _array(spec["columns"], "$context.columns")
        length(raw_columns) == n || invalid(
            "$context.columns has $(length(raw_columns)) columns; expected $n",
        )
        isempty(raw_columns) && invalid("$context.columns must not be empty")
        column_length = length(_array(first(raw_columns), "$context.columns[1]"))
        column_length > 0 || invalid("matrix columns must not be empty")
        column_length * n <= MAX_MATRIX_CELLS || invalid(
            "$context exceeds the automatic matrix-cell limit of $MAX_MATRIX_CELLS",
        )
        rows = [Any[] for _ in 1:column_length]
        for (column_index, raw_column) in enumerate(raw_columns)
            entries = _array(raw_column, "$context.columns[$column_index]")
            length(entries) == column_length || invalid("all matrix columns must have equal length")
            for (row_index, entry) in enumerate(entries)
                push!(rows[row_index], entry)
            end
        end
    end
    return rows, field
end

function _rational_entry(value, context::String)
    if value isa Integer && !(value isa Bool)
        return BigInt(value) // BigInt(1)
    elseif value isa AbstractString
        text = strip(String(value))
        matched = match(r"^(-?\d+)(?:/([1-9]\d*))?$", text)
        matched === nothing && invalid(
            "$context must be an integer or a rational string such as '-3/5'",
        )
        numerator_value = parse(BigInt, matched.captures[1])
        denominator_value = matched.captures[2] === nothing ?
                            BigInt(1) : parse(BigInt, matched.captures[2])
        return numerator_value // denominator_value
    end
    invalid("$context must be an integer or a rational string")
end

function _finite_entry(value, field, finite_field_parent, context::String)
    if value isa Integer && !(value isa Bool)
        return finite_field_parent(mod(Int(value), field.characteristic))
    elseif value isa AbstractVector
        field.degree > 1 || invalid(
            "$context uses coefficient-array syntax, which is only needed for extension fields",
        )
        length(value) == field.degree || invalid(
            "$context must have exactly $(field.degree) polynomial-basis coefficients for $(field.label)",
        )
        coefficients = [
            mod(_integer(coefficient, "$context[$index]"), field.characteristic)
            for (index, coefficient) in enumerate(value)
        ]
        return finite_field_parent(coefficients)
    end
    invalid(
        "$context must be an integer or, over an extension field, a coefficient array",
    )
end

# ---------------------------------------------------------------------------
# Basis enumeration by shared-work depth-first search.
#
# Earlier revisions ran an independent Gaussian elimination for every
# C(n, rank) column subset (matrix_rank_mod_p for prime fields; a Matrix{Any}
# eliminator otherwise), allocating per subset. The searches below visit
# every independent column set exactly once, keeping the elimination state of
# the current set on a stack: extending an independent set by one column
# costs a single in-place column reduction. The resulting basis set — and
# therefore the colex encoding rendered from it — is identical.

function _reduce_mod_p!(
    scratch::Vector{Int},
    pivots::Vector{Vector{Int}},
    positions::Vector{Int},
    p::Int,
)
    for k in eachindex(pivots)
        factor = scratch[positions[k]]
        factor == 0 && continue
        pivot = pivots[k]
        @inbounds for idx in eachindex(scratch)
            scratch[idx] = mod(scratch[idx] - factor * pivot[idx], p)
        end
    end
    return findfirst(!=(0), scratch)
end

function _normalize_mod_p!(vector::Vector{Int}, position::Int, p::Int)
    inverse = invmod(vector[position], p)
    @inbounds for idx in eachindex(vector)
        vector[idx] = mod(vector[idx] * inverse, p)
    end
    return vector
end

function _dfs_mod_p!(
    bases::Vector{UInt64},
    columns::Vector{Vector{Int}},
    p::Int,
    rank::Int,
    pivots::Vector{Vector{Int}},
    positions::Vector{Int},
    scratch::Vector{Int},
    start::Int,
    mask::UInt64,
)
    depth = length(pivots)
    if depth == rank
        push!(bases, mask)
        return nothing
    end
    for column in start:(length(columns) - (rank - depth) + 1)
        copyto!(scratch, columns[column])
        position = _reduce_mod_p!(scratch, pivots, positions, p)
        position === nothing && continue
        push!(pivots, _normalize_mod_p!(copy(scratch), position, p))
        push!(positions, position)
        _dfs_mod_p!(
            bases, columns, p, rank, pivots, positions, scratch,
            column + 1, mask | (UInt64(1) << (column - 1)),
        )
        pop!(pivots)
        pop!(positions)
    end
    return nothing
end

function _basis_masks_mod_p(columns::Vector{Vector{Int}}, p::Int)
    pivots = Vector{Vector{Int}}()
    positions = Int[]
    scratch = Vector{Int}(undef, length(first(columns)))
    for column in columns
        copyto!(scratch, column)
        position = _reduce_mod_p!(scratch, pivots, positions, p)
        position === nothing && continue
        push!(pivots, _normalize_mod_p!(copy(scratch), position, p))
        push!(positions, position)
    end
    rank = length(pivots)
    bases = UInt64[]
    if rank > 0
        empty!(pivots)
        empty!(positions)
        _dfs_mod_p!(bases, columns, p, rank, pivots, positions, scratch, 1, UInt64(0))
    end
    return rank, bases
end

function _reduce_field!(
    scratch::Vector{T},
    pivots::Vector{Vector{T}},
    positions::Vector{Int},
) where {T}
    for k in eachindex(pivots)
        factor = scratch[positions[k]]
        iszero(factor) && continue
        pivot = pivots[k]
        for idx in eachindex(scratch)
            scratch[idx] = scratch[idx] - factor * pivot[idx]
        end
    end
    return findfirst(!iszero, scratch)
end

function _normalize_field!(vector::Vector{T}, position::Int) where {T}
    inverse = inv(vector[position])
    for idx in eachindex(vector)
        vector[idx] = vector[idx] * inverse
    end
    return vector
end

function _dfs_field!(
    bases::Vector{UInt64},
    columns::Vector{Vector{T}},
    rank::Int,
    pivots::Vector{Vector{T}},
    positions::Vector{Int},
    start::Int,
    mask::UInt64,
) where {T}
    depth = length(pivots)
    if depth == rank
        push!(bases, mask)
        return nothing
    end
    for column in start:(length(columns) - (rank - depth) + 1)
        scratch = copy(columns[column])
        position = _reduce_field!(scratch, pivots, positions)
        position === nothing && continue
        push!(pivots, _normalize_field!(scratch, position))
        push!(positions, position)
        _dfs_field!(
            bases, columns, rank, pivots, positions,
            column + 1, mask | (UInt64(1) << (column - 1)),
        )
        pop!(pivots)
        pop!(positions)
    end
    return nothing
end

function _basis_masks_field(columns::Vector{Vector{T}}) where {T}
    pivots = Vector{Vector{T}}()
    positions = Int[]
    for column in columns
        scratch = copy(column)
        position = _reduce_field!(scratch, pivots, positions)
        position === nothing && continue
        push!(pivots, _normalize_field!(scratch, position))
        push!(positions, position)
    end
    rank = length(pivots)
    bases = UInt64[]
    if rank > 0
        empty!(pivots)
        empty!(positions)
        _dfs_field!(bases, columns, rank, pivots, positions, 1, UInt64(0))
    end
    return rank, bases
end

function _normalized_rows(raw_rows, field, context::String)
    if field.kind == :rational
        parsed = [
            [
                _rational_entry(entry, "$context.rows[$row][$column]")
                for (column, entry) in enumerate(raw_rows[row])
            ]
            for row in eachindex(raw_rows)
        ]
        normalized = [
            [
                denominator(entry) == 1 ? string(numerator(entry)) :
                "$(numerator(entry))/$(denominator(entry))"
                for entry in row
            ]
            for row in parsed
        ]
        return parsed, normalized
    end

    if field.degree == 1
        parsed = [
            [
                mod(_integer(entry, "$context.rows[$row][$column]"), field.characteristic)
                for (column, entry) in enumerate(raw_rows[row])
            ]
            for row in eachindex(raw_rows)
        ]
        return parsed, parsed
    end

    finite_field_parent, _ = finite_field(
        field.characteristic,
        field.degree,
        "a";
        cached=false,
    )
    parsed = [
        [
            _finite_entry(
                entry,
                field,
                finite_field_parent,
                "$context.rows[$row][$column]",
            )
            for (column, entry) in enumerate(raw_rows[row])
        ]
        for row in eachindex(raw_rows)
    ]
    normalized = [
        [
            entry isa AbstractVector ?
            [mod(Int(coefficient), field.characteristic) for coefficient in entry] :
            mod(Int(entry), field.characteristic)
            for entry in row
        ]
        for row in raw_rows
    ]
    return parsed, normalized
end

function _matrix_encoding(spec, n::Int, context::String)
    raw_rows, field = _raw_matrix_rows(spec, n, context)
    rows, normalized_rows = _normalized_rows(raw_rows, field, context)
    if field.kind == :finite && field.degree == 1 && field.characteristic <= 2_147_483_647
        columns = [
            [rows[row][column] for row in eachindex(rows)]
            for column in 1:n
        ]
        rank, basis_masks = _basis_masks_mod_p(columns, field.characteristic)
    else
        element_rows = rows
        if field.kind == :finite && field.degree == 1
            parent = GF(field.characteristic)
            element_rows = [[parent(entry) for entry in row] for row in rows]
        end
        columns = [
            [element_rows[row][column] for row in eachindex(element_rows)]
            for column in 1:n
        ]
        rank, basis_masks = _basis_masks_field(columns)
    end
    1 <= rank < n || invalid("automatic correlation verification requires 1 <= matrix rank < n")
    encoding = _encoding_from_basis_masks(basis_masks, n, rank)
    _declared_rank(spec, rank)
    representation = (
        field_kind=String(field.kind),
        field_label=field.label,
        field_order=field.order,
        characteristic=field.characteristic,
        extension_degree=field.degree,
        rows=normalized_rows,
    )
    return encoding, rank, representation
end

function _contributors(data)
    raw = _array(_required(data, "contributors", "submission"), "contributors")
    isempty(raw) && invalid("contributors must contain at least one person or project")
    return [
        begin
            contributor isa AbstractDict || invalid("contributors[$index] must be an object")
            _reject_unknown_keys(
                contributor,
                ("display_name", "github"),
                "contributors[$index]",
            )
            display_name = _string(
                _required(contributor, "display_name", "contributors[$index]"),
                "contributors[$index].display_name",
            )
            github_value = _optional(contributor, "github")
            github = github_value === nothing ? nothing : _string(
                github_value,
                "contributors[$index].github",
            )
            (display_name=display_name, github=github)
        end
        for (index, contributor) in enumerate(raw)
    ]
end

function _claimed_ratio(data)
    claim = _required(data, "claimed_alpha_bar", "submission")
    _reject_unknown_keys(
        claim,
        ("numerator", "denominator"),
        "claimed_alpha_bar",
    )
    numerator_value = _integer(
        _required(claim, "numerator", "claimed_alpha_bar"),
        "claimed_alpha_bar.numerator",
    )
    denominator_value = _integer(
        _required(claim, "denominator", "claimed_alpha_bar"),
        "claimed_alpha_bar.denominator",
    )
    numerator_value >= 0 || invalid("claimed_alpha_bar.numerator must be nonnegative")
    denominator_value > 0 || invalid("claimed_alpha_bar.denominator must be positive")
    return BigInt(numerator_value) // BigInt(denominator_value)
end

function _discovery_metadata(data)
    raw = _required(data, "discovery", "submission")
    _reject_unknown_keys(
        raw,
        (
            "date",
            "discoverers",
            "ai_used",
            "ai_model_version",
            "ai_role",
            "ai_chat_url",
        ),
        "discovery",
    )
    date = _string(
        _required(raw, "date", "discovery"),
        "discovery.date",
    )
    occursin(r"^\d{4}-(?:0[1-9]|1[0-2])(?:-(?:0[1-9]|[12]\d|3[01]))?$", date) || invalid(
        "discovery.date must use YYYY-MM or YYYY-MM-DD",
    )
    discoverers = _string(
        _required(raw, "discoverers", "discovery"),
        "discovery.discoverers",
    )
    ai_used = _required(raw, "ai_used", "discovery")
    ai_used isa Bool || invalid("discovery.ai_used must be a boolean")
    ai_model_version = _string(
        _required(raw, "ai_model_version", "discovery"),
        "discovery.ai_model_version",
    )
    ai_role = _string(
        _required(raw, "ai_role", "discovery"),
        "discovery.ai_role",
    )
    ai_chat_value = _optional(raw, "ai_chat_url")
    ai_chat_url = ai_chat_value === nothing ? nothing : _string(
        ai_chat_value,
        "discovery.ai_chat_url",
    )
    ai_chat_url === nothing || occursin(r"^https?://", ai_chat_url) || invalid(
        "discovery.ai_chat_url must begin with http:// or https://",
    )
    return (
        date=date,
        discoverers=discoverers,
        ai_used=ai_used,
        ai_model_version=ai_model_version,
        ai_role=ai_role,
        ai_chat_url=ai_chat_url,
    )
end

function _metadata(data)
    schema_version = _integer(_required(data, "schema_version", "submission"), "schema_version")
    schema_version == 1 || invalid("unsupported schema_version $schema_version; expected 1")
    kind = _string(_required(data, "kind", "submission"), "kind")
    kind == "matroid" || invalid("kind must be 'matroid'")
    id = _string(_required(data, "id", "submission"), "id")
    occursin(r"^[a-z0-9]+(?:-[a-z0-9]+)*$", id) || invalid(
        "id must be a lowercase ASCII slug separated by single hyphens",
    )
    name = _string(_required(data, "proposed_name", "submission"), "proposed_name")
    provenance = _string(_required(data, "provenance", "submission"), "provenance")
    license = _string(_required(data, "license", "submission"), "license")
    citation_value = _optional(data, "citation", "")
    citation = _string(citation_value, "citation"; allow_empty=true)
    notes_value = _optional(data, "notes")
    notes_value === nothing || _string(notes_value, "notes"; allow_empty=true)
    submitted_at = _string(
        _required(data, "submitted_at", "submission"),
        "submitted_at",
    )
    return (
        id=id,
        name=name,
        provenance=provenance,
        license=license,
        citation=citation,
        contributors=_contributors(data),
        discovery=_discovery_metadata(data),
        submitted_at=submitted_at,
    )
end

function _primary_input(data, label_index::Dict{String,Int}, n::Int)
    spec = _required(data, "input", "submission")
    input_type = _string(_required(spec, "type", "input"), "input.type")
    if input_type == "matrix"
        encoding, rank, representation = _matrix_encoding(spec, n, "input")
        return encoding, rank, input_type, [representation]
    elseif input_type == "bases"
        _reject_unknown_keys(spec, ("type", "rank", "sets"), "input")
        encoding, rank = _bases_input(spec, label_index, n)
        return encoding, rank, input_type, NamedTuple[]
    elseif input_type == "circuits"
        _reject_unknown_keys(spec, ("type", "rank", "sets"), "input")
        encoding, rank = _circuits_input(spec, label_index, n)
        return encoding, rank, input_type, NamedTuple[]
    elseif input_type == "hyperplanes"
        _reject_unknown_keys(spec, ("type", "rank", "sets"), "input")
        encoding, rank = _hyperplanes_input(spec, label_index, n)
        return encoding, rank, input_type, NamedTuple[]
    end
    invalid("input.type must be one of: matrix, bases, circuits, hyperplanes")
end

function _verify_extra_representations(data, encoding::String, rank::Int, n::Int)
    raw = _optional(data, "representations", Any[])
    representations = _array(raw, "representations")
    length(representations) <= MAX_REPRESENTATION_CERTIFICATES || invalid(
        "at most $MAX_REPRESENTATION_CERTIFICATES additional representations are accepted automatically",
    )
    verified = NamedTuple[]
    for (index, representation_spec) in enumerate(representations)
        representation_spec isa AbstractDict || invalid("representations[$index] must be an object")
        represented_encoding, represented_rank, normalized = _matrix_encoding(
            representation_spec,
            n,
            "representations[$index]",
        )
        represented_rank == rank || invalid(
            "representations[$index] has rank $represented_rank; expected $rank",
        )
        represented_encoding == encoding || invalid(
            "representations[$index] represents a different labeled matroid",
        )
        push!(verified, normalized)
    end
    return verified
end

_nullable(value) = ismissing(value) ? nothing : value

function _maximizers(statistics, labels::Vector{String})
    return [
        (
            indices=[pair.i, pair.j],
            elements=[labels[pair.i + 1], labels[pair.j + 1]],
            basis_counts=(
                b00=pair.b00,
                b01=pair.b01,
                b10=pair.b10,
                b11=pair.b11,
            ),
            ratio=(
                numerator=pair.ratio_num,
                denominator=pair.ratio_den,
                decimal=pair.ratio_value,
            ),
        )
        for pair in statistics.pairs
        if pair.ratio_num * statistics.alpha_den ==
           statistics.alpha_num * pair.ratio_den
    ]
end

function _check_claimed_pair(data, maximizers, label_index::Dict{String,Int})
    raw = _optional(data, "claimed_maximizing_pair")
    raw === nothing && return
    pair = _array(raw, "claimed_maximizing_pair")
    length(pair) == 2 || invalid("claimed_maximizing_pair must contain exactly two labels")
    left = _label(pair[1], "claimed_maximizing_pair[1]")
    right = _label(pair[2], "claimed_maximizing_pair[2]")
    left != right || invalid("claimed_maximizing_pair must contain distinct elements")
    haskey(label_index, left) || invalid("claimed_maximizing_pair contains unknown element '$left'")
    haskey(label_index, right) || invalid("claimed_maximizing_pair contains unknown element '$right'")
    claimed_indices = sort([label_index[left], label_index[right]])
    any(entry -> entry.indices == claimed_indices, maximizers) || invalid(
        "claimed_maximizing_pair is not a maximizing eligible pair",
    )
    return nothing
end

function _certificate(
    metadata,
    labels,
    encoding,
    input_type,
    statistics,
    maximizers,
    representations,
    input_sha256,
)
    prime_fields = sort!(unique([
        representation.field_order
        for representation in representations
        if representation.field_kind == "finite" &&
           representation.extension_degree == 1
    ]))
    finite_fields = sort!(unique([
        representation.field_order
        for representation in representations
        if representation.field_kind == "finite"
    ]))
    rational = any(
        representation -> representation.field_kind == "rational",
        representations,
    )
    return (
        schema_version=1,
        certificate_type="matroid-correlation-constants/concrete-verification",
        status="verified-as-claimed",
        verifier=(
            name="Matroid Correlation Constants Julia verifier",
            version=VERIFIER_VERSION,
            julia_version=string(VERSION),
        ),
        input=(
            sha256=input_sha256,
            description_type=input_type,
        ),
        matroid=(
            id=metadata.id,
            name=metadata.name,
            ground_set_labels=labels,
            ground_set_size=statistics.n,
            rank=statistics.r,
            corank=statistics.n - statistics.r,
            number_of_bases=statistics.num_bases,
            basis_density=statistics.basis_density,
            basis_encoding_order="colex/reverse-lex",
            basis_encoding=statistics.basis_encoding,
            basis_hex=statistics.basis_hex,
        ),
        correlation=(
            invariant="unweighted alpha-bar",
            definition="max_{i!=j} (b00*b11)/(b01*b10) over nonloop, noncoloop elements",
            exact=(
                numerator=statistics.alpha_num,
                denominator=statistics.alpha_den,
                decimal=statistics.alpha_value,
            ),
            eligible_element_count=statistics.eligible_element_count,
            eligible_pair_count=statistics.eligible_pair_count,
            maximizing_pair_count=statistics.maximizer_count,
            maximizing_pairs=maximizers,
        ),
        structure=(
            loops=statistics.loops_count,
            coloops=statistics.coloops_count,
            components=statistics.component_count,
            connected=statistics.connected,
            three_connected=statistics.three_connected,
            simple=statistics.simple,
            cosimple=statistics.cosimple,
            paving=statistics.paving,
            copaving=statistics.copaving,
            sparse_paving=statistics.sparse_paving,
            girth=_nullable(statistics.girth),
            cogirth=_nullable(statistics.cogirth),
            number_of_circuits=statistics.num_circuits,
            number_of_hyperplanes=statistics.num_hyperplanes,
        ),
        representations=(
            verified_prime_fields=prime_fields,
            verified_finite_fields=finite_fields,
            verified_over_rationals=rational,
            certificates=[
                (
                    field=representation.field_label,
                    field_order=representation.field_order,
                    characteristic=representation.characteristic,
                    extension_degree=representation.extension_degree,
                    polynomial_basis=(
                        representation.extension_degree === nothing ||
                        representation.extension_degree == 1
                    ) ? nothing : "1,a,...,a^(d-1) for Oscar's deterministic defining polynomial",
                    rows=representation.rows,
                )
                for representation in representations
            ],
        ),
        attribution=(
            contributors=metadata.contributors,
            discovery=metadata.discovery,
            submitted_at=metadata.submitted_at,
            provenance=metadata.provenance,
            citation=metadata.citation,
            license=metadata.license,
        ),
    )
end

"""Validate one parsed submission and return its deterministic certificate."""
function verify_submission_data(data; input_sha256::Union{Nothing,String}=nothing)
    data isa AbstractDict || invalid("submission root must be a JSON object")
    _reject_unknown_keys(
        data,
        (
            "schema_version",
            "kind",
            "id",
            "proposed_name",
            "contributors",
            "ground_set",
            "input",
            "representations",
            "claimed_alpha_bar",
            "claimed_maximizing_pair",
            "discovery",
            "submitted_at",
            "provenance",
            "citation",
            "license",
            "notes",
        ),
        "submission",
    )
    metadata = _metadata(data)
    labels, label_index = _ground_set(data)
    n = length(labels)
    encoding, rank, input_type, primary_representations = _primary_input(
        data,
        label_index,
        n,
    )
    extra_representations = _verify_extra_representations(data, encoding, rank, n)
    representations = vcat(primary_representations, extra_representations)
    statistics = matroid_statistics(encoding, n, rank)
    statistics.alpha_defined || invalid(
        "the matroid has fewer than two eligible nonloop, noncoloop elements, so alpha-bar is undefined",
    )
    claim = _claimed_ratio(data)
    computed = BigInt(statistics.alpha_num) // BigInt(statistics.alpha_den)
    claim == computed || invalid(
        "valid matroid, but claimed alpha-bar $(numerator(claim))/$(denominator(claim)) differs from the exact value $(statistics.alpha_num)/$(statistics.alpha_den)",
    )
    maximizers = _maximizers(statistics, labels)
    _check_claimed_pair(data, maximizers, label_index)
    digest = input_sha256 === nothing ? bytes2hex(sha256(JSON3.write(data))) : input_sha256
    return _certificate(
        metadata,
        labels,
        encoding,
        input_type,
        statistics,
        maximizers,
        representations,
        digest,
    )
end

"""Read, validate, and exactly verify one JSON submission file."""
function verify_submission_file(path::AbstractString)
    raw = read(path, String)
    data = try
        JSON3.read(raw, Dict{String,Any})
    catch error
        invalid("invalid JSON in $path: $(sprint(showerror, error))")
    end
    return verify_submission_data(data; input_sha256=bytes2hex(sha256(raw)))
end

"""Write a human-readable JSON certificate with stable content and a final newline."""
function write_certificate(path::AbstractString, certificate)
    mkpath(dirname(abspath(path)))
    open(path, "w") do output
        JSON3.pretty(output, certificate)
        println(output)
    end
    return path
end

end
