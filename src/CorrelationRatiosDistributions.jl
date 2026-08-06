"""
Compute unweighted basis-correlation statistics for small matroids and retain
them in a compact, reproducible SQLite schema.

The module uses polyDB's `REVLEX_BASIS_ENCODING` throughout: rank-sized
subsets occur in colex order, `*` marks a basis, and `0` marks a nonbasis.
Every eligible element pair is evaluated while a matroid is processed, but
routine collections store only a matroid summary and run-level exact-ratio
aggregates. The exact basis indicator is persisted as a packed hexadecimal
mask; complete pair tables and the polyDB-compatible `0`/`*` string are
regenerated only for examples selected for heatmaps or case studies.
"""
module CorrelationRatiosDistributions

using Dates
using DBInterface
using Random
using SHA
using SQLite
using Statistics

export begin_run!,
       basis_hex,
       basis_encoding_from_hex,
       close_writer!,
       colex_masks,
       dual_encoding,
       direct_sum_epsilon_statistics,
       density_adjusted_correlation_excess,
       density_cap_threshold,
       density_discounted_relative_correlation,
       encoding_from_columns,
       encoding_to_bases,
       EpsilonCounter,
       epsilon_statistics,
       export_table_csv,
       export_table_csv_zst,
       finish_run!,
       init_database,
       insert_matroid!,
       insert_sampling_observation!,
       is_johnson_independent_set,
       johnson_greedy_ensemble,
       johnson_greedy_probability,
       johnson_sparse_paving_encoding,
       JohnsonGraphSampler,
       matrix_rank_mod_p,
       matroid_statistics,
       prepare_writer,
       projective_points,
       representation_string,
       reset_run!,
       register_sampled_chunk!,
       register_sampling_run!,
       sample_johnson_independent_set,
       sample_projective_indices,
       store_selected_pair_profile!,
       uniform_correlation_baseline,
       critical_density_penalty_exponent,
       weighted_linear_fit,
       weighted_midranks,
       weighted_pearson,
       weighted_spearman,
       with_transaction

const SCHEMA_VERSION = 5

"""
Return the `r`-subsets of an `n`-element set as bit masks in increasing
integer order. This is the colex/reverse-lex order used by polyDB's
`REVLEX_BASIS_ENCODING`.
"""
function colex_masks(n::Int, r::Int)
    0 <= r <= n <= 63 || throw(ArgumentError("require 0 <= r <= n <= 63"))
    r == 0 && return UInt64[0]
    r == n && return UInt64[(UInt64(1) << n) - UInt64(1)]

    masks = UInt64[]
    sizehint!(masks, binomial(n, r))
    mask = (UInt64(1) << r) - UInt64(1)
    limit = UInt64(1) << n
    while mask < limit
        push!(masks, mask)
        smallest = mask & (-mask)
        ripple = mask + smallest
        mask = ripple | ((xor(ripple, mask) >> 2) ÷ smallest)
    end
    return masks
end

"""
    JohnsonGraphSampler(n, r)

Precompute the vertices and adjacency lists of the Johnson graph `J(n,r)`.
Vertices are the `r`-subsets in the same colex order used by
[`colex_masks`](@ref), and two vertices are adjacent exactly when their masks
intersect in `r-1` elements. An independent vertex set is therefore the set
of circuit-hyperplanes of a rank-`r` sparse paving matroid.
"""
struct JohnsonGraphSampler
    n::Int
    r::Int
    vertices::Vector{UInt64}
    neighbors::Vector{Vector{Int}}
end

function JohnsonGraphSampler(n::Int, r::Int)
    1 <= r < n <= 63 || throw(ArgumentError("require 1 <= r < n <= 63"))
    vertices = colex_masks(n, r)
    vertex_index = Dict(mask => index for (index, mask) in enumerate(vertices))
    full = (UInt64(1) << n) - UInt64(1)
    neighbors = [Int[] for _ in vertices]
    for (index, mask) in enumerate(vertices)
        inside = mask
        while inside != 0
            removed = inside & (-inside)
            outside = full ⊻ mask
            while outside != 0
                added = outside & (-outside)
                push!(neighbors[index], vertex_index[(mask ⊻ removed) | added])
                outside ⊻= added
            end
            inside ⊻= removed
        end
        sort!(neighbors[index])
    end
    return JohnsonGraphSampler(n, r, vertices, neighbors)
end

const JOHNSON_GREEDY_PREFIX = "johnson_random_greedy_p"

"""Return the stable run-ensemble identifier for activation probability `p`."""
function johnson_greedy_ensemble(p::Real)
    isfinite(p) && 0 <= p <= 1 || throw(
        ArgumentError("Johnson activation probability must lie in [0,1]"),
    )
    return JOHNSON_GREEDY_PREFIX * string(round(Float64(p); digits=6))
end

"""Recover the activation probability from a Johnson greedy ensemble name."""
function johnson_greedy_probability(ensemble::AbstractString)
    startswith(ensemble, JOHNSON_GREEDY_PREFIX) || return missing
    probability = tryparse(Float64, ensemble[length(JOHNSON_GREEDY_PREFIX)+1:end])
    probability === nothing && throw(ArgumentError("malformed Johnson ensemble name"))
    0 <= probability <= 1 || throw(ArgumentError("malformed Johnson probability"))
    return probability
end

"""
    sample_johnson_independent_set(rng, sampler, p) -> Vector{Int}

Draw one independent vertex set by a random-priority greedy pass. Traverse a
uniform random permutation of all Johnson vertices. An available vertex is
activated independently with probability `p`; if activated, select it and
block it and all its neighbors. Fresh calls are independent when supplied by
an ordinary pseudorandom stream. At `p=1` the output is maximal. This is an
exactly specified distribution on labeled independent sets, not the uniform
distribution on all independent sets or on matroid isomorphism classes.
"""
function sample_johnson_independent_set(
    rng::AbstractRNG,
    sampler::JohnsonGraphSampler,
    p::Real,
)
    isfinite(p) && 0 <= p <= 1 || throw(
        ArgumentError("Johnson activation probability must lie in [0,1]"),
    )
    p == 0 && return Int[]
    available = trues(length(sampler.vertices))
    selected = Int[]
    for vertex in randperm(rng, length(sampler.vertices))
        available[vertex] || continue
        rand(rng) <= p || continue
        push!(selected, vertex)
        available[vertex] = false
        for neighbor in sampler.neighbors[vertex]
            available[neighbor] = false
        end
    end
    sort!(selected)
    return selected
end

"""Return whether `indices` form an independent set in `sampler`'s Johnson graph."""
function is_johnson_independent_set(
    sampler::JohnsonGraphSampler,
    indices::AbstractVector{<:Integer},
)
    selected = falses(length(sampler.vertices))
    for raw_index in indices
        index = Int(raw_index)
        1 <= index <= length(selected) || return false
        selected[index] && return false
        any(selected[neighbor] for neighbor in sampler.neighbors[index]) && return false
        selected[index] = true
    end
    return true
end

"""
    johnson_sparse_paving_encoding(sampler, independent_set) -> String

Construct the polyDB-compatible basis encoding of the sparse paving matroid
whose circuit-hyperplanes are `independent_set`. Those Johnson vertices are
the rank-sized nonbases (`0`); every other rank-sized subset is a basis (`*`).
"""
function johnson_sparse_paving_encoding(
    sampler::JohnsonGraphSampler,
    independent_set::AbstractVector{<:Integer},
)
    is_johnson_independent_set(sampler, independent_set) || throw(
        ArgumentError("circuit-hyperplanes must be an independent Johnson set"),
    )
    encoding = fill('*', length(sampler.vertices))
    for index in independent_set
        encoding[Int(index)] = '0'
    end
    return String(encoding)
end

"""
    encoding_to_bases(encoding, n, r) -> Vector{UInt64}

Decode a polyDB-compatible reverse-lex basis string into bit masks. Character
`k` corresponds to `colex_masks(n, r)[k]`; only `*` and `0` are accepted.
Element `e` is represented by bit `e`, so public element labels are zero-based.
"""
function encoding_to_bases(encoding::AbstractString, n::Int, r::Int)
    masks = colex_masks(n, r)
    length(encoding) == length(masks) ||
        throw(ArgumentError("encoding has length $(length(encoding)); expected $(length(masks))"))
    chars = collect(encoding)
    all(c -> c == '*' || c == '0', chars) ||
        throw(ArgumentError("basis encoding must contain only '*' and '0'"))
    return masks[chars .== '*']
end

"""
    dual_encoding(encoding, n, r) -> String

Return the polyDB-compatible `REVLEX_BASIS_ENCODING` of the dual matroid.
If `B` is a basis of the input, its ground-set complement is a basis of the
dual. The returned string is ordered by `colex_masks(n, n-r)`, so it can be
fed directly back to [`matroid_statistics`](@ref) or written beside polyDB
records without relabeling the ground set.
"""
function dual_encoding(encoding::AbstractString, n::Int, r::Int)
    full = (UInt64(1) << n) - UInt64(1)
    dual_bases = Set(full ⊻ basis for basis in encoding_to_bases(encoding, n, r))
    return String([
        mask in dual_bases ? '*' : '0' for mask in colex_masks(n, n - r)
    ])
end

"""
    basis_hex(encoding) -> String

Pack a `*`/`0` basis encoding into a zero-padded hexadecimal bit mask. The
first encoding character is the least significant bit. The packed mask is the
authoritative persistent representation; [`basis_encoding_from_hex`](@ref)
recovers the exact polyDB-compatible string when it is needed.
"""
function basis_hex(encoding::AbstractString)
    bytes = codeunits(encoding)
    width = cld(length(bytes), 4)
    digits = fill('0', width)
    alphabet = "0123456789abcdef"
    for nibble_index in 0:width-1
        value = 0
        for offset in 0:3
            encoding_index = 4nibble_index + offset + 1
            encoding_index > length(bytes) && break
            byte = bytes[encoding_index]
            byte == UInt8('*') && (value |= 1 << offset)
            byte in (UInt8('*'), UInt8('0')) || throw(
                ArgumentError("basis encoding must contain only '*' and '0'"),
            )
        end
        digits[width - nibble_index] = alphabet[value + 1]
    end
    return String(digits)
end

"""
    basis_encoding_from_hex(packed, encoding_length) -> String

Unpack a zero-padded hexadecimal basis mask into its exact `*`/`0` encoding.
The first returned character is the least significant bit, matching
polyDB's reverse-lex basis order. Bits above `encoding_length` must be zero.
"""
function basis_encoding_from_hex(packed::AbstractString, encoding_length::Integer)
    encoding_length >= 0 || throw(ArgumentError("encoding length must be nonnegative"))
    bits = isempty(packed) ? BigInt(0) : parse(BigInt, packed; base=16)
    bits >> encoding_length == 0 || throw(
        ArgumentError("packed basis mask has nonzero bits beyond the encoding length"),
    )
    return String([
        isodd(bits >> index) ? '*' : '0' for index in 0:encoding_length-1
    ])
end

"""
    EpsilonCounter(n, r)

Precompute the incidence data needed to evaluate the free-extension/free-
coextension invariant of rank-`r` matroids on an `n`-element ground set.
One counter owns reusable scratch storage and is therefore intended for a
single serial database stream, not simultaneous calls from multiple tasks.
"""
mutable struct EpsilonCounter
    n::Int
    r::Int
    basis_count::Int
    lower_count::Int
    upper_count::Int
    lower_offsets::Vector{Int}
    lower_candidates::Vector{Int32}
    upper_offsets::Vector{Int}
    upper_candidates::Vector{Int32}
    basis_lower_indices::Vector{Int32}
    packed_words::Vector{UInt64}
    lower_independent::BitVector
end

function EpsilonCounter(n::Int, r::Int)
    1 <= r < n <= 63 || throw(ArgumentError("require 1 <= r < n <= 63"))
    basis_masks = colex_masks(n, r)
    lower_masks = colex_masks(n, r - 1)
    upper_masks = colex_masks(n, r + 1)
    basis_index = Dict(mask => Int32(index) for (index, mask) in enumerate(basis_masks))
    lower_index = Dict(mask => Int32(index) for (index, mask) in enumerate(lower_masks))
    full = (UInt64(1) << n) - UInt64(1)

    lower_offsets = Int[1]
    lower_candidates = Int32[]
    sizehint!(lower_candidates, length(lower_masks) * (n - r + 1))
    for mask in lower_masks
        outside = full ⊻ mask
        while outside != 0
            added = outside & (-outside)
            push!(lower_candidates, basis_index[mask | added])
            outside ⊻= added
        end
        push!(lower_offsets, length(lower_candidates) + 1)
    end

    upper_offsets = Int[1]
    upper_candidates = Int32[]
    sizehint!(upper_candidates, length(upper_masks) * (r + 1))
    for mask in upper_masks
        inside = mask
        while inside != 0
            removed = inside & (-inside)
            push!(upper_candidates, basis_index[mask ⊻ removed])
            inside ⊻= removed
        end
        push!(upper_offsets, length(upper_candidates) + 1)
    end

    basis_lower_indices = Int32[]
    sizehint!(basis_lower_indices, length(basis_masks) * r)
    for mask in basis_masks
        inside = mask
        while inside != 0
            removed = inside & (-inside)
            push!(basis_lower_indices, lower_index[mask ⊻ removed])
            inside ⊻= removed
        end
    end

    return EpsilonCounter(
        n,
        r,
        length(basis_masks),
        length(lower_masks),
        length(upper_masks),
        lower_offsets,
        lower_candidates,
        upper_offsets,
        upper_candidates,
        basis_lower_indices,
        zeros(UInt64, cld(length(basis_masks), 64)),
        falses(length(lower_masks)),
    )
end

@inline function _hex_nibble(byte::UInt8)
    UInt8('0') <= byte <= UInt8('9') && return Int(byte - UInt8('0'))
    UInt8('a') <= byte <= UInt8('f') && return Int(byte - UInt8('a')) + 10
    UInt8('A') <= byte <= UInt8('F') && return Int(byte - UInt8('A')) + 10
    throw(ArgumentError("packed basis mask must contain only hexadecimal digits"))
end

function _load_packed_words!(counter::EpsilonCounter, packed::AbstractString)
    bytes = codeunits(packed)
    length(bytes) <= cld(counter.basis_count, 4) || throw(
        ArgumentError("packed basis mask is wider than the basis encoding"),
    )
    fill!(counter.packed_words, 0)
    for byte_index in length(bytes):-1:1
        nibble_index = length(bytes) - byte_index
        nibble = UInt64(_hex_nibble(bytes[byte_index]))
        bit_index = 4nibble_index
        word_index = (bit_index >> 6) + 1
        shift = bit_index & 63
        counter.packed_words[word_index] |= nibble << shift
    end
    final_bits = counter.basis_count & 63
    if final_bits != 0
        valid = (UInt64(1) << final_bits) - UInt64(1)
        counter.packed_words[end] & ~valid == 0 || throw(
            ArgumentError("packed basis mask has nonzero bits beyond the encoding length"),
        )
    end
    return counter.packed_words
end

@inline function _basis_selected(words::Vector{UInt64}, index::Int32)
    zero_based = Int(index) - 1
    return (words[(zero_based >> 6) + 1] >> (zero_based & 63)) & UInt64(1) != 0
end

"""
    epsilon_statistics(counter, packed; num_bases=nothing, paving=false,
                       copaving=false)

For a matroid `M`, let `i` be the number of independent `(r-1)`-sets,
`b` its number of bases, `a` the number of `r`-sets of rank at least
`r-1`, and `s` the number of spanning `(r+1)`-sets. If `e` is freely
extended and then `f` is freely coextended, the pair table of `(e,f)` is
`(b00,b01,b10,b11)=(s,b,a,i)`. Consequently this function returns

```text
epsilon(M) = s*i/(a*b).
```

The exact reduced fraction is returned beside the four integer counts.
`paving=true` and `copaving=true` activate mathematically exact shortcuts.
"""
function epsilon_statistics(
    counter::EpsilonCounter,
    packed::AbstractString;
    num_bases::Union{Nothing,Integer}=nothing,
    paving::Bool=false,
    copaving::Bool=false,
)
    words = _load_packed_words!(counter, packed)
    computed_bases = sum(count_ones, words)
    if num_bases !== nothing && computed_bases != num_bases
        throw(ArgumentError(
            "packed basis mask has $computed_bases bases; expected $num_bases",
        ))
    end
    computed_bases > 0 || throw(ArgumentError("matroid must have at least one basis"))

    if paving
        independent = counter.lower_count
        almost_bases = counter.basis_count
    else
        fill!(counter.lower_independent, false)
        independent = 0
        for lower in 1:counter.lower_count
            found = false
            for position in counter.lower_offsets[lower]:counter.lower_offsets[lower + 1]-1
                if _basis_selected(words, counter.lower_candidates[position])
                    found = true
                    break
                end
            end
            counter.lower_independent[lower] = found
            independent += found
        end

        almost_bases = 0
        for basis_index in 1:counter.basis_count
            start = (basis_index - 1) * counter.r + 1
            for position in start:start + counter.r - 1
                if counter.lower_independent[counter.basis_lower_indices[position]]
                    almost_bases += 1
                    break
                end
            end
        end
    end

    if copaving
        spanning = counter.upper_count
    else
        spanning = 0
        for upper in 1:counter.upper_count
            for position in counter.upper_offsets[upper]:counter.upper_offsets[upper + 1]-1
                if _basis_selected(words, counter.upper_candidates[position])
                    spanning += 1
                    break
                end
            end
        end
    end

    raw_numerator = BigInt(spanning) * BigInt(independent)
    raw_denominator = BigInt(almost_bases) * BigInt(computed_bases)
    raw_denominator > 0 || throw(ArgumentError("epsilon denominator is zero"))
    epsilon = raw_numerator // raw_denominator
    return (
        n=counter.n,
        r=counter.r,
        independent_r_minus_1=independent,
        num_bases=computed_bases,
        rank_at_least_r_minus_1=almost_bases,
        spanning_r_plus_1=spanning,
        epsilon=epsilon,
        epsilon_num=numerator(epsilon),
        epsilon_den=denominator(epsilon),
        epsilon_value=Float64(epsilon),
    )
end

function epsilon_statistics(encoding::AbstractString, n::Int, r::Int)
    counter = EpsilonCounter(n, r)
    return epsilon_statistics(
        counter,
        basis_hex(encoding);
        num_bases=count(==('*'), encoding),
    )
end

"""
    direct_sum_epsilon_statistics(first, second)

Compute the four counts and `epsilon` for a direct sum without constructing
its basis encoding. Each argument is an `epsilon_statistics` result (or any
object exposing the same four count properties).
"""
function direct_sum_epsilon_statistics(first, second)
    i1 = BigInt(first.independent_r_minus_1)
    b1 = BigInt(first.num_bases)
    a1 = BigInt(first.rank_at_least_r_minus_1)
    s1 = BigInt(first.spanning_r_plus_1)
    i2 = BigInt(second.independent_r_minus_1)
    b2 = BigInt(second.num_bases)
    a2 = BigInt(second.rank_at_least_r_minus_1)
    s2 = BigInt(second.spanning_r_plus_1)

    bases = b1 * b2
    independent = i1 * b2 + b1 * i2
    spanning = s1 * b2 + b1 * s2
    almost_bases =
        a1 * b2 + b1 * a2 - b1 * b2 + s1 * i2 + i1 * s2
    epsilon = spanning * independent // (almost_bases * bases)
    return (
        independent_r_minus_1=independent,
        num_bases=bases,
        rank_at_least_r_minus_1=almost_bases,
        spanning_r_plus_1=spanning,
        epsilon=epsilon,
        epsilon_num=numerator(epsilon),
        epsilon_den=denominator(epsilon),
        epsilon_value=Float64(epsilon),
    )
end

"""
    uniform_correlation_baseline(n, r) -> Rational{BigInt}

Return the exact unweighted correlation ratio of the uniform matroid
`U_{r,n}`:

```text
((r - 1) * (n - r - 1)) / (r * (n - r)).
```

The formula is valid for nontrivial ranks `1 <= r < n`; it is symmetric
under replacing `r` by `n-r`.
"""
function uniform_correlation_baseline(n::Integer, r::Integer)
    1 <= r < n || throw(ArgumentError("require 1 <= r < n"))
    numerator = BigInt(r - 1) * BigInt(n - r - 1)
    denominator = BigInt(r) * BigInt(n - r)
    return numerator // denominator
end

"""
    density_cap_threshold(n, r) -> Rational{BigInt}

Return the exact density boundary

```text
1 - r(n-r) / (n(n-1)).
```

Above this boundary, the elementary deletion-budget argument bounds the
relative unweighted correlation ratio `alpha_1(M) / alpha_1(U_{r,n})` by

```text
1 / (1 - (1 - d_B(M)) / (r(n-r)/(n(n-1)))).
```

The nondegenerate range `2 <= r <= n-2` is required because the associated
uniform correlation baseline must be positive.
"""
function density_cap_threshold(n::Integer, r::Integer)
    2 <= r <= n - 2 || throw(ArgumentError("require 2 <= r <= n - 2"))
    capacity = BigInt(r) * BigInt(n - r) // (BigInt(n) * BigInt(n - 1))
    return 1 - capacity
end

"""
    density_discounted_relative_correlation(
        n, r, num_bases, alpha_num, alpha_den; density_exponent=1,
    ) -> Float64

Return the density-discounted relative correlation score

```text
J_gamma(M) = d_B(M)^gamma * alpha_1(M) / alpha_1(U_{r,n}).
```

The exponent may be any finite nonnegative real number. Exact stored counts
and the exact uniform baseline are converted only after input validation;
the result is floating point because nonintegral exponents are supported.
"""
function density_discounted_relative_correlation(
    n::Integer,
    r::Integer,
    num_bases::Integer,
    alpha_num::Integer,
    alpha_den::Integer;
    density_exponent::Real=1,
)
    2 <= r <= n - 2 || throw(ArgumentError("require 2 <= r <= n - 2"))
    basis_total = binomial(BigInt(n), r)
    0 < num_bases <= basis_total ||
        throw(ArgumentError("num_bases must lie between 1 and binomial(n, r)"))
    alpha_num >= 0 || throw(ArgumentError("alpha_num must be nonnegative"))
    alpha_den > 0 || throw(ArgumentError("alpha_den must be positive"))
    isfinite(density_exponent) && density_exponent >= 0 ||
        throw(ArgumentError("density_exponent must be finite and nonnegative"))
    density = Float64(BigInt(num_bases) // basis_total)
    alpha = Float64(BigInt(alpha_num) // BigInt(alpha_den))
    baseline = Float64(uniform_correlation_baseline(n, r))
    return density^Float64(density_exponent) * alpha / baseline
end

"""
    critical_density_penalty_exponent(
        n, r, num_bases, alpha_num, alpha_den,
    ) -> Float64

Return the break-even exponent

```text
gamma_star = log(alpha_1(M) / alpha_1(U_{r,n})) / log(1 / d_B(M)).
```

It is defined only for a nonuniform basis support (`0 < d_B < 1`) and a
positive correlation ratio. The value may be negative when the correlation
ratio is below the uniform baseline.
"""
function critical_density_penalty_exponent(
    n::Integer,
    r::Integer,
    num_bases::Integer,
    alpha_num::Integer,
    alpha_den::Integer,
)
    2 <= r <= n - 2 || throw(ArgumentError("require 2 <= r <= n - 2"))
    basis_total = binomial(BigInt(n), r)
    0 < num_bases < basis_total ||
        throw(ArgumentError("require 0 < num_bases < binomial(n, r)"))
    alpha_num > 0 || throw(ArgumentError("alpha_num must be positive"))
    alpha_den > 0 || throw(ArgumentError("alpha_den must be positive"))
    density = Float64(BigInt(num_bases) // basis_total)
    alpha = Float64(BigInt(alpha_num) // BigInt(alpha_den))
    baseline = Float64(uniform_correlation_baseline(n, r))
    return log(alpha / baseline) / log(inv(density))
end

"""
    density_adjusted_correlation_excess(
        n, r, num_bases, alpha_num, alpha_den; density_exponent=1,
    ) -> Rational{BigInt}

Return the exact uniform-baseline invariant

```text
Theta_lambda(M) = d_B(M)^lambda *
                  (alpha_1(M) - c_{r,n}) / (1 - c_{r,n}),
```

where `d_B(M) = num_bases / binomial(n, r)` and `c_{r,n}` is the
uniform-matroid baseline. The nonnegative integer `density_exponent` is
`lambda`; its default `1` is the project's primary invariant, while `2`
supplies the second-density-factor comparison. The result is reduced
automatically and uses arbitrary-precision integers, so report calculations
do not lose the exact rational value stored for `alpha_1`.
"""
function density_adjusted_correlation_excess(
    n::Integer,
    r::Integer,
    num_bases::Integer,
    alpha_num::Integer,
    alpha_den::Integer,
    ;
    density_exponent::Integer=1,
)
    1 <= r < n || throw(ArgumentError("require 1 <= r < n"))
    0 <= num_bases <= binomial(n, r) ||
        throw(ArgumentError("num_bases must lie between 0 and binomial(n, r)"))
    alpha_den > 0 || throw(ArgumentError("alpha_den must be positive"))
    density_exponent >= 0 ||
        throw(ArgumentError("density_exponent must be nonnegative"))
    density = BigInt(num_bases) // binomial(BigInt(n), r)
    alpha = BigInt(alpha_num) // BigInt(alpha_den)
    baseline = uniform_correlation_baseline(n, r)
    return density^density_exponent * (alpha - baseline) / (1 - baseline)
end

"""
    weighted_pearson(x, y, weights)

Return the Pearson correlation after treating each observation as having the
given nonnegative frequency weight. Return `missing` when either variable is
constant on the positive-weight observations.
"""
function weighted_pearson(x, y, weights)
    length(x) == length(y) == length(weights) ||
        throw(DimensionMismatch("x, y, and weights must have equal lengths"))
    isempty(x) && return missing
    any(weight -> weight < 0, weights) &&
        throw(ArgumentError("correlation weights must be nonnegative"))
    total_weight = sum(Float64(weight) for weight in weights)
    total_weight > 0 || throw(ArgumentError("at least one weight must be positive"))
    mean_x = sum(Float64(weight) * Float64(value) for (value, weight) in zip(x, weights)) /
             total_weight
    mean_y = sum(Float64(weight) * Float64(value) for (value, weight) in zip(y, weights)) /
             total_weight
    covariance = 0.0
    variance_x = 0.0
    variance_y = 0.0
    for (value_x, value_y, weight) in zip(x, y, weights)
        centered_x = Float64(value_x) - mean_x
        centered_y = Float64(value_y) - mean_y
        numeric_weight = Float64(weight)
        covariance += numeric_weight * centered_x * centered_y
        variance_x += numeric_weight * centered_x^2
        variance_y += numeric_weight * centered_y^2
    end
    (variance_x > 0 && variance_y > 0) || return missing
    return clamp(covariance / sqrt(variance_x * variance_y), -1.0, 1.0)
end

"""
    weighted_midranks(values, weights)

Return midranks with ties and frequency weights. A row of integer weight `w`
is treated exactly as `w` repeated observations at the same value, without
materializing those repetitions.
"""
function weighted_midranks(values, weights)
    length(values) == length(weights) ||
        throw(DimensionMismatch("values and weights must have equal lengths"))
    any(weight -> weight < 0, weights) &&
        throw(ArgumentError("rank weights must be nonnegative"))
    order = sortperm(values)
    ranks = zeros(Float64, length(values))
    cumulative_weight = 0.0
    position = 1
    while position <= length(order)
        stop = position
        value = values[order[position]]
        while stop < length(order) && values[order[stop + 1]] == value
            stop += 1
        end
        group_weight = sum(Float64(weights[order[index]]) for index in position:stop)
        midpoint = cumulative_weight + (group_weight + 1) / 2
        for index in position:stop
            ranks[order[index]] = midpoint
        end
        cumulative_weight += group_weight
        position = stop + 1
    end
    return ranks
end

"""
    weighted_spearman(x, y, weights)

Return Spearman's rank correlation using weighted midranks for tied values.
"""
function weighted_spearman(x, y, weights)
    length(x) == length(y) == length(weights) ||
        throw(DimensionMismatch("x, y, and weights must have equal lengths"))
    isempty(x) && return missing
    return weighted_pearson(
        weighted_midranks(x, weights),
        weighted_midranks(y, weights),
        weights,
    )
end

"""
    weighted_linear_fit(x, y, weights)

Return the weighted least-squares intercept and slope for `y = intercept +
slope*x`. Return `missing` when `x` is constant on the positive-weight rows.
"""
function weighted_linear_fit(x, y, weights)
    length(x) == length(y) == length(weights) ||
        throw(DimensionMismatch("x, y, and weights must have equal lengths"))
    isempty(x) && return missing
    any(weight -> weight < 0, weights) &&
        throw(ArgumentError("regression weights must be nonnegative"))
    total_weight = sum(Float64(weight) for weight in weights)
    total_weight > 0 || throw(ArgumentError("at least one weight must be positive"))
    mean_x = sum(Float64(weight) * Float64(value) for (value, weight) in zip(x, weights)) /
             total_weight
    mean_y = sum(Float64(weight) * Float64(value) for (value, weight) in zip(y, weights)) /
             total_weight
    covariance = 0.0
    variance_x = 0.0
    for (value_x, value_y, weight) in zip(x, y, weights)
        centered_x = Float64(value_x) - mean_x
        numeric_weight = Float64(weight)
        covariance += numeric_weight * centered_x * (Float64(value_y) - mean_y)
        variance_x += numeric_weight * centered_x^2
    end
    variance_x > 0 || return missing
    slope = covariance / variance_x
    return (intercept=mean_y - slope * mean_x, slope=slope)
end

function _subset_ranks(bases::Vector{UInt64}, n::Int)
    full = (UInt64(1) << n) - UInt64(1)
    ranks = zeros(Int, Int(full) + 1)

    # A set is independent exactly when it is contained in a basis. Mark every
    # such subset with its cardinality; repeated appearances are harmless.
    for basis in bases
        subset = basis
        while true
            ranks[Int(subset) + 1] = count_ones(subset)
            subset == 0 && break
            subset = (subset - UInt64(1)) & basis
        end
    end

    # The rank of S is the largest cardinality of an independent subset of S.
    # This max-over-subsets transform costs O(n 2^n), replacing the former
    # O(2^n |B|) scan while producing the identical rank table.
    for element in 0:n-1
        bit = UInt64(1) << element
        for subset in UInt64(0):full
            subset & bit == 0 && continue
            without_bit = subset ⊻ bit
            ranks[Int(subset) + 1] = max(
                ranks[Int(subset) + 1],
                ranks[Int(without_bit) + 1],
            )
        end
    end
    return ranks
end

function _dual_ranks(ranks::Vector{Int}, n::Int, r::Int)
    full = (UInt64(1) << n) - UInt64(1)
    dual = similar(ranks)
    for subset in UInt64(0):full
        complement = full ⊻ subset
        dual[Int(subset) + 1] =
            count_ones(subset) - r + ranks[Int(complement) + 1]
    end
    return dual
end

function _is_circuit(subset::UInt64, ranks::Vector{Int})
    size = count_ones(subset)
    size == 0 && return false
    ranks[Int(subset) + 1] == size - 1 || return false
    remaining = subset
    while remaining != 0
        bit = remaining & (-remaining)
        ranks[Int(subset ⊻ bit) + 1] == size - 1 || return false
        remaining ⊻= bit
    end
    return true
end

function _girth(ranks::Vector{Int}, n::Int)
    full = (UInt64(1) << n) - UInt64(1)
    answer = typemax(Int)
    for subset in UInt64(1):full
        size = count_ones(subset)
        size >= answer && continue
        _is_circuit(subset, ranks) && (answer = size)
    end
    return answer == typemax(Int) ? missing : answer
end

function _is_connected(ranks::Vector{Int}, n::Int, r::Int)
    n <= 1 && return true
    full = (UInt64(1) << n) - UInt64(1)
    for subset in UInt64(1):(full - UInt64(1))
        complement = full ⊻ subset
        lambda = ranks[Int(subset) + 1] + ranks[Int(complement) + 1] - r
        lambda == 0 && return false
    end
    return true
end

function _is_three_connected(ranks::Vector{Int}, n::Int, r::Int)
    n >= 4 || return false
    _is_connected(ranks, n, r) || return false
    full = (UInt64(1) << n) - UInt64(1)
    for subset in UInt64(1):(full - UInt64(1))
        size = count_ones(subset)
        2 <= size <= n - 2 || continue
        complement = full ⊻ subset
        lambda = ranks[Int(subset) + 1] + ranks[Int(complement) + 1] - r
        lambda < 2 && return false
    end
    return true
end

function _circuit_hyperplane_count(ranks::Vector{Int}, n::Int, r::Int)
    full = (UInt64(1) << n) - UInt64(1)
    result = 0
    for subset in colex_masks(n, r)
        subset == full && continue
        _is_circuit(subset, ranks) || continue
        is_hyperplane = true
        outside = full ⊻ subset
        remaining = outside
        while remaining != 0
            bit = remaining & (-remaining)
            if ranks[Int(subset | bit) + 1] != r
                is_hyperplane = false
                break
            end
            remaining ⊻= bit
        end
        is_hyperplane && (result += 1)
    end
    return result
end

"""Return whether `subset` is a hyperplane from a complete subset-rank table."""
function _is_hyperplane(subset::UInt64, ranks::Vector{Int}, n::Int, r::Int)
    ranks[Int(subset) + 1] == r - 1 || return false
    full = (UInt64(1) << n) - UInt64(1)
    remaining = full ⊻ subset
    while remaining != 0
        bit = remaining & (-remaining)
        ranks[Int(subset | bit) + 1] == r || return false
        remaining ⊻= bit
    end
    return true
end

"""
Compute counts and classical invariants that require a complete subset scan.

The beta invariant uses Crapo's subset-rank formula, while `mobius_signed` is
the constant coefficient of the characteristic polynomial. Its absolute value
is returned as `mobius_invariant`. Connected components are the equivalence
classes generated by elements lying in a common circuit; loops and coloops
therefore correctly remain singleton components.
"""
function _extended_structural_statistics(ranks::Vector{Int}, n::Int, r::Int)
    full = (UInt64(1) << n) - UInt64(1)
    parent = collect(1:n)

    function find_root(element::Int)
        while parent[element] != element
            parent[element] = parent[parent[element]]
            element = parent[element]
        end
        return element
    end

    function union_elements(left::Int, right::Int)
        left_root = find_root(left)
        right_root = find_root(right)
        left_root == right_root || (parent[right_root] = left_root)
        return nothing
    end

    num_circuits = 0
    num_hyperplanes = 0
    beta_sum = 0
    mobius_signed = 0
    for subset in UInt64(0):full
        subset_rank = ranks[Int(subset) + 1]
        sign = isodd(count_ones(subset)) ? -1 : 1
        beta_sum += sign * subset_rank
        subset_rank == r && (mobius_signed += sign)

        if subset != 0 && _is_circuit(subset, ranks)
            num_circuits += 1
            first_element = trailing_zeros(subset) + 1
            remaining = subset ⊻ (UInt64(1) << (first_element - 1))
            while remaining != 0
                bit = remaining & (-remaining)
                union_elements(first_element, trailing_zeros(bit) + 1)
                remaining ⊻= bit
            end
        end

        subset != full && _is_hyperplane(subset, ranks, n, r) &&
            (num_hyperplanes += 1)
    end

    component_count = length(Set(find_root(element) for element in 1:n))
    beta_invariant = (isodd(r) ? -1 : 1) * beta_sum
    return (
        component_count=component_count,
        num_circuits=num_circuits,
        num_hyperplanes=num_hyperplanes,
        beta_invariant=beta_invariant,
        mobius_signed=mobius_signed,
        mobius_invariant=abs(mobius_signed),
    )
end

function _structural_statistics(bases::Vector{UInt64}, n::Int, r::Int)
    isempty(bases) && throw(ArgumentError("a matroid encoding must contain at least one basis"))
    ranks = _subset_ranks(bases, n)
    dual_ranks = _dual_ranks(ranks, n, r)
    girth = _girth(ranks, n)
    cogirth = _girth(dual_ranks, n)
    loops = Bool[ranks[Int(UInt64(1) << e) + 1] == 0 for e in 0:n-1]
    coloops = Bool[dual_ranks[Int(UInt64(1) << e) + 1] == 0 for e in 0:n-1]
    simple = ismissing(girth) || girth >= 3
    cosimple = ismissing(cogirth) || cogirth >= 3
    paving = ismissing(girth) || girth >= r
    dual_rank = n - r
    dual_paving = ismissing(cogirth) || cogirth >= dual_rank
    extended = _extended_structural_statistics(ranks, n, r)
    connected = _is_connected(ranks, n, r)
    connected == (extended.component_count == 1) ||
        error("connectivity and circuit-component calculations disagree")
    return (
        ranks=ranks,
        dual_ranks=dual_ranks,
        loops=loops,
        coloops=coloops,
        loops_count=count(identity, loops),
        coloops_count=count(identity, coloops),
        simple=simple,
        cosimple=cosimple,
        component_count=extended.component_count,
        connected=connected,
        three_connected=_is_three_connected(ranks, n, r),
        paving=paving,
        copaving=dual_paving,
        sparse_paving=paving && dual_paving,
        girth=girth,
        cogirth=cogirth,
        circuit_hyperplanes=_circuit_hyperplane_count(ranks, n, r),
        num_circuits=extended.num_circuits,
        num_hyperplanes=extended.num_hyperplanes,
        beta_invariant=extended.beta_invariant,
        mobius_signed=extended.mobius_signed,
        mobius_invariant=extended.mobius_invariant,
    )
end

function _reduced_fraction(numerator::Int, denominator::Int)
    denominator > 0 || throw(ArgumentError("denominator must be positive"))
    divisor = gcd(abs(numerator), denominator)
    return (div(numerator, divisor), div(denominator, divisor))
end

function _pair_statistics(
    bases::Vector{UInt64},
    n::Int,
    loops::Vector{Bool},
    coloops::Vector{Bool},
)
    result = NamedTuple[]
    number_of_bases = length(bases)
    eligible = [e for e in 0:n-1 if !loops[e + 1] && !coloops[e + 1]]
    for left_index in 1:length(eligible)-1
        i = eligible[left_index]
        for right_index in left_index+1:length(eligible)
            j = eligible[right_index]
            counts = zeros(Int, 4)
            for basis in bases
                xi = Int((basis >> i) & UInt64(1))
                xj = Int((basis >> j) & UInt64(1))
                counts[xi + 2xj + 1] += 1
            end
            b00 = counts[1]
            b10 = counts[2]
            b01 = counts[3]
            b11 = counts[4]
            b01 > 0 && b10 > 0 ||
                error("eligible pair ($i,$j) unexpectedly has a zero mixed cell")

            cross_numerator = b00 * b11
            cross_denominator = b01 * b10
            ratio_numerator, ratio_denominator =
                _reduced_fraction(cross_numerator, cross_denominator)
            ratio_value = cross_numerator / cross_denominator
            log_ratio = cross_numerator == 0 ? missing : log(ratio_value)

            p_i = (b10 + b11) / number_of_bases
            p_j = (b01 + b11) / number_of_bases
            p_ij = b11 / number_of_bases
            covariance_numerator = cross_numerator - cross_denominator
            covariance_denominator = number_of_bases^2
            covariance_num, covariance_den =
                _reduced_fraction(covariance_numerator, covariance_denominator)
            covariance = covariance_numerator / covariance_denominator
            pearson = covariance / sqrt(p_i * (1 - p_i) * p_j * (1 - p_j))
            yules_q =
                (cross_numerator - cross_denominator) /
                (cross_numerator + cross_denominator)

            push!(result, (
                i=i,
                j=j,
                b00=b00,
                b01=b01,
                b10=b10,
                b11=b11,
                ratio_num=ratio_numerator,
                ratio_den=ratio_denominator,
                ratio_value=ratio_value,
                log_ratio=log_ratio,
                yules_q=yules_q,
                p_i=p_i,
                p_j=p_j,
                p_ij=p_ij,
                covariance_num=covariance_num,
                covariance_den=covariance_den,
                covariance=covariance,
                pearson=pearson,
                minimum_cell_count=minimum(counts),
            ))
        end
    end
    return result
end

_ratio_less(a, b) = a.ratio_num * b.ratio_den < b.ratio_num * a.ratio_den
_ratio_equal(a, b) = a.ratio_num * b.ratio_den == b.ratio_num * a.ratio_den

function _positive_graph_statistics(pairs, eligible::Vector{Int})
    isempty(eligible) && return (component_count=0, largest_component=0, max_degree=0)
    adjacency = Dict(vertex => Int[] for vertex in eligible)
    for pair in pairs
        pair.ratio_num > pair.ratio_den || continue
        push!(adjacency[pair.i], pair.j)
        push!(adjacency[pair.j], pair.i)
    end

    seen = Set{Int}()
    component_count = 0
    largest_component = 0
    for root in eligible
        root in seen && continue
        component_count += 1
        component_size = 0
        stack = [root]
        push!(seen, root)
        while !isempty(stack)
            vertex = pop!(stack)
            component_size += 1
            for neighbor in adjacency[vertex]
                neighbor in seen && continue
                push!(seen, neighbor)
                push!(stack, neighbor)
            end
        end
        largest_component = max(largest_component, component_size)
    end
    max_degree = maximum(length(adjacency[vertex]) for vertex in eligible)
    return (
        component_count=component_count,
        largest_component=largest_component,
        max_degree=max_degree,
    )
end

function _pair_distribution_statistics(pairs, eligible::Vector{Int})
    graph = _positive_graph_statistics(pairs, eligible)
    if isempty(pairs)
        return (
            zero_count=0,
            minimum_num=missing,
            minimum_den=missing,
            minimum_value=missing,
            mean=missing,
            standard_deviation=missing,
            q10=missing,
            q25=missing,
            median=missing,
            q75=missing,
            q90=missing,
            positive_component_count=graph.component_count,
            largest_positive_component=graph.largest_component,
            max_positive_degree=graph.max_degree,
        )
    end

    values = Float64[pair.ratio_value for pair in pairs]
    ordered = sort(pairs; lt=_ratio_less)
    minimum_pair = first(ordered)
    return (
        zero_count=count(iszero, values),
        minimum_num=minimum_pair.ratio_num,
        minimum_den=minimum_pair.ratio_den,
        minimum_value=minimum_pair.ratio_value,
        mean=mean(values),
        standard_deviation=std(values; corrected=false),
        q10=quantile(values, 0.10),
        q25=quantile(values, 0.25),
        median=median(values),
        q75=quantile(values, 0.75),
        q90=quantile(values, 0.90),
        positive_component_count=graph.component_count,
        largest_positive_component=graph.largest_component,
        max_positive_degree=graph.max_degree,
    )
end

"""
    matroid_statistics(encoding, n, r) -> NamedTuple

Compute structural and unweighted pair-correlation statistics from a basis
encoding. For each pair of elements that is neither a loop nor a coloop, let
`b_ab` count bases with the two incidence indicators equal to `a,b`. The pair
ratio is

```text
R_ij = (b00 * b11) / (b01 * b10),
```

and `alpha_value` is the maximum `R_ij`. Exact reduced numerators and
denominators are returned beside floating-point values. The result also
contains connectivity, paving data, pair-distribution summaries, and a
temporary `pairs` vector used by the compact database writer. Pair element
labels are zero-based.
"""
function matroid_statistics(encoding::AbstractString, n::Int, r::Int)
    bases = encoding_to_bases(encoding, n, r)
    structural = _structural_statistics(bases, n, r)
    pairs = _pair_statistics(bases, n, structural.loops, structural.coloops)
    eligible_elements = [
        element for element in 0:n-1 if
        !structural.loops[element + 1] && !structural.coloops[element + 1]
    ]
    pair_distribution = _pair_distribution_statistics(pairs, eligible_elements)

    if isempty(pairs)
        alpha_num = 0
        alpha_den = 1
        alpha_value = 0.0
        log_alpha = missing
        best_i = missing
        best_j = missing
        maximizer_count = 0
        second_num = missing
        second_den = missing
        second_value = missing
        max_pearson = missing
    else
        ordered = sort(pairs; lt=(a, b) -> _ratio_less(b, a))
        best = ordered[1]
        alpha_num = best.ratio_num
        alpha_den = best.ratio_den
        alpha_value = best.ratio_value
        log_alpha = ismissing(best.log_ratio) ? missing : best.log_ratio
        best_i = best.i
        best_j = best.j
        maximizer_count = count(pair -> _ratio_equal(pair, best), pairs)
        if length(ordered) >= 2
            second_num = ordered[2].ratio_num
            second_den = ordered[2].ratio_den
            second_value = ordered[2].ratio_value
        else
            second_num = missing
            second_den = missing
            second_value = missing
        end
        max_pearson = maximum(pair.pearson for pair in pairs)
    end

    positive_pair_count = count(pair -> pair.ratio_num > pair.ratio_den, pairs)
    eligible_pair_count = length(pairs)
    positive_pair_fraction =
        eligible_pair_count == 0 ? missing : positive_pair_count / eligible_pair_count

    return (
        n=n,
        r=r,
        num_bases=length(bases),
        basis_density=length(bases) / binomial(n, r),
        basis_encoding=String(encoding),
        basis_hex=basis_hex(encoding),
        loops_count=structural.loops_count,
        coloops_count=structural.coloops_count,
        simple=structural.simple,
        cosimple=structural.cosimple,
        component_count=structural.component_count,
        connected=structural.connected,
        three_connected=structural.three_connected,
        paving=structural.paving,
        copaving=structural.copaving,
        sparse_paving=structural.sparse_paving,
        girth=structural.girth,
        cogirth=structural.cogirth,
        circuit_hyperplanes=structural.circuit_hyperplanes,
        num_circuits=structural.num_circuits,
        num_hyperplanes=structural.num_hyperplanes,
        beta_invariant=structural.beta_invariant,
        mobius_signed=structural.mobius_signed,
        mobius_invariant=structural.mobius_invariant,
        alpha_defined=!isempty(pairs),
        alpha_num=alpha_num,
        alpha_den=alpha_den,
        alpha_value=alpha_value,
        log_alpha=log_alpha,
        best_i=best_i,
        best_j=best_j,
        maximizer_count=maximizer_count,
        second_num=second_num,
        second_den=second_den,
        second_value=second_value,
        alpha_gap=ismissing(second_value) ? missing : alpha_value - second_value,
        positive_pair_count=positive_pair_count,
        eligible_element_count=length(eligible_elements),
        eligible_pair_count=eligible_pair_count,
        positive_pair_fraction=positive_pair_fraction,
        max_pearson=max_pearson,
        zero_pair_count=pair_distribution.zero_count,
        minimum_ratio_num=pair_distribution.minimum_num,
        minimum_ratio_den=pair_distribution.minimum_den,
        minimum_ratio_value=pair_distribution.minimum_value,
        mean_pair_ratio=pair_distribution.mean,
        pair_ratio_std=pair_distribution.standard_deviation,
        pair_ratio_q10=pair_distribution.q10,
        pair_ratio_q25=pair_distribution.q25,
        pair_ratio_median=pair_distribution.median,
        pair_ratio_q75=pair_distribution.q75,
        pair_ratio_q90=pair_distribution.q90,
        positive_component_count=pair_distribution.positive_component_count,
        largest_positive_component=pair_distribution.largest_positive_component,
        max_positive_degree=pair_distribution.max_positive_degree,
        pairs=pairs,
    )
end

function _table_exists(db::SQLite.DB, name::AbstractString)
    row = first(
        DBInterface.execute(
            db,
            "SELECT COUNT(*) AS n FROM sqlite_master WHERE type = 'table' AND name = ?",
            (name,),
        ),
    )
    return row.n == 1
end

function _column_exists(db::SQLite.DB, table::AbstractString, column::AbstractString)
    return any(
        row -> row.name == column,
        DBInterface.execute(db, "PRAGMA table_info($(table))"),
    )
end

function _ensure_column!(
    db::SQLite.DB,
    table::AbstractString,
    column::AbstractString,
    definition::AbstractString,
)
    _column_exists(db, table, column) && return
    DBInterface.execute(db, "ALTER TABLE $(table) ADD COLUMN $(column) $(definition)")
end

function _ensure_compact_matroid_columns!(db::SQLite.DB)
    definitions = [
        ("census_multiplicity", "INTEGER NOT NULL DEFAULT 1"),
        ("component_count", "INTEGER"),
        ("copaving", "INTEGER"),
        ("num_circuits", "INTEGER"),
        ("num_hyperplanes", "INTEGER"),
        ("beta_invariant", "INTEGER"),
        ("mobius_signed", "INTEGER"),
        ("mobius_invariant", "INTEGER"),
        ("automorphism_group_order", "INTEGER"),
        ("alpha_defined", "INTEGER"),
        ("eligible_element_count", "INTEGER"),
        ("zero_pair_count", "INTEGER"),
        ("minimum_ratio_num", "INTEGER"),
        ("minimum_ratio_den", "INTEGER"),
        ("minimum_ratio_value", "REAL"),
        ("mean_pair_ratio", "REAL"),
        ("pair_ratio_std", "REAL"),
        ("pair_ratio_q10", "REAL"),
        ("pair_ratio_q25", "REAL"),
        ("pair_ratio_median", "REAL"),
        ("pair_ratio_q75", "REAL"),
        ("pair_ratio_q90", "REAL"),
        ("positive_component_count", "INTEGER"),
        ("largest_positive_component", "INTEGER"),
        ("max_positive_degree", "INTEGER"),
    ]
    for (column, definition) in definitions
        _ensure_column!(db, "matroids", column, definition)
    end
end

function _backfill_legacy_pair_aggregates!(db::SQLite.DB)
    _table_exists(db, "pairs") || return
    DBInterface.execute(
        db,
        """
        INSERT INTO pair_ratio_aggregates (
            run_id, simple, connected, alpha_positive, ratio_num, ratio_den,
            ratio_value, log_ratio, pair_count, census_pair_count,
            matroid_weight, census_maximizer_count
        )
        SELECT m.run_id, m.simple, m.connected, m.alpha_num > 0,
               p.ratio_num, p.ratio_den, MIN(p.ratio_value), MIN(p.log_ratio),
               COUNT(*),
               SUM(m.census_multiplicity),
               SUM(
                   CAST(m.census_multiplicity AS REAL) /
                   CAST(m.eligible_pair_count AS REAL)
               ),
               SUM(m.census_multiplicity * p.is_maximizer)
        FROM pairs p
        JOIN matroids m USING(matroid_id)
        WHERE NOT EXISTS (
            SELECT 1
            FROM pair_ratio_aggregates a
            WHERE a.run_id = m.run_id
        )
        GROUP BY m.run_id, m.simple, m.connected, m.alpha_num > 0,
                 p.ratio_num, p.ratio_den
        """,
    )
end

"""
    init_database(path) -> SQLite.DB

Open or create the experiment database, enable foreign keys and WAL mode,
create the compact schema, and return the live connection. Legacy matroid
columns are added non-destructively when absent. New collections do not create
one persistent row per pair; `pair_ratio_aggregates` and selected profiles are
used instead.
"""
function init_database(path::AbstractString)
    mkpath(dirname(path))
    db = SQLite.DB(path)
    DBInterface.execute(db, "PRAGMA foreign_keys = ON")
    DBInterface.execute(db, "PRAGMA busy_timeout = 60000")
    collect(DBInterface.execute(db, "PRAGMA journal_mode = WAL"))
    DBInterface.execute(db, "PRAGMA synchronous = NORMAL")
    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """,
    )
    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS runs (
            run_id TEXT PRIMARY KEY,
            source TEXT NOT NULL,
            ensemble TEXT NOT NULL,
            n INTEGER NOT NULL,
            rank_value INTEGER NOT NULL,
            field_size INTEGER,
            target_count INTEGER,
            accepted_count INTEGER NOT NULL DEFAULT 0,
            rejected_count INTEGER NOT NULL DEFAULT 0,
            seed INTEGER,
            conditioning TEXT NOT NULL,
            polydb_collection TEXT,
            polydb_filter TEXT,
            generator TEXT NOT NULL,
            created_at TEXT NOT NULL,
            julia_version TEXT NOT NULL,
            oscar_version TEXT
        )
        """,
    )
    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS matroids (
            matroid_id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
            observation_index INTEGER NOT NULL,
            source_id TEXT NOT NULL,
            field_size INTEGER,
            census_multiplicity INTEGER NOT NULL DEFAULT 1,
            n INTEGER NOT NULL,
            rank_value INTEGER NOT NULL,
            representation TEXT,
            num_bases INTEGER NOT NULL,
            basis_density REAL NOT NULL,
            basis_encoding TEXT NOT NULL,
            basis_hex TEXT NOT NULL,
            loops_count INTEGER NOT NULL,
            coloops_count INTEGER NOT NULL,
            simple INTEGER NOT NULL,
            cosimple INTEGER NOT NULL,
            component_count INTEGER,
            connected INTEGER NOT NULL,
            three_connected INTEGER NOT NULL,
            paving INTEGER NOT NULL,
            copaving INTEGER,
            sparse_paving INTEGER NOT NULL,
            girth INTEGER,
            cogirth INTEGER,
            circuit_hyperplanes INTEGER NOT NULL,
            num_circuits INTEGER,
            num_hyperplanes INTEGER,
            beta_invariant INTEGER,
            mobius_signed INTEGER,
            mobius_invariant INTEGER,
            automorphism_group_order INTEGER,
            alpha_defined INTEGER,
            alpha_num INTEGER NOT NULL,
            alpha_den INTEGER NOT NULL,
            alpha_value REAL NOT NULL,
            log_alpha REAL,
            best_i INTEGER,
            best_j INTEGER,
            maximizer_count INTEGER NOT NULL,
            second_num INTEGER,
            second_den INTEGER,
            second_value REAL,
            alpha_gap REAL,
            positive_pair_count INTEGER NOT NULL,
            eligible_element_count INTEGER,
            eligible_pair_count INTEGER NOT NULL,
            positive_pair_fraction REAL,
            max_pearson REAL,
            zero_pair_count INTEGER,
            minimum_ratio_num INTEGER,
            minimum_ratio_den INTEGER,
            minimum_ratio_value REAL,
            mean_pair_ratio REAL,
            pair_ratio_std REAL,
            pair_ratio_q10 REAL,
            pair_ratio_q25 REAL,
            pair_ratio_median REAL,
            pair_ratio_q75 REAL,
            pair_ratio_q90 REAL,
            positive_component_count INTEGER,
            largest_positive_component INTEGER,
            max_positive_degree INTEGER,
            UNIQUE(run_id, observation_index)
        )
        """,
    )
    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS sampling_runs (
            run_id TEXT PRIMARY KEY REFERENCES runs(run_id) ON DELETE CASCADE,
            release_slug TEXT NOT NULL,
            manifest_url TEXT NOT NULL,
            manifest_sha256 TEXT NOT NULL,
            sample_plan_sha256 TEXT NOT NULL,
            sampling_design_sha256 TEXT NOT NULL,
            decoder_source_sha256 TEXT NOT NULL,
            decoder_binary_sha256 TEXT NOT NULL,
            population_size INTEGER NOT NULL,
            sampling_design TEXT NOT NULL,
            selection_algorithm TEXT NOT NULL,
            cluster_draw_count INTEGER,
            draws_per_cluster INTEGER,
            common_selection_probability REAL NOT NULL,
            common_design_weight REAL NOT NULL
        )
        """,
    )
    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS sampled_chunks (
            run_id TEXT NOT NULL REFERENCES sampling_runs(run_id) ON DELETE CASCADE,
            chunk_index INTEGER NOT NULL,
            first_index INTEGER NOT NULL,
            record_count INTEGER NOT NULL,
            compressed_bytes INTEGER NOT NULL,
            url TEXT NOT NULL,
            compressed_sha256 TEXT NOT NULL,
            cluster_draw_multiplicity INTEGER NOT NULL,
            PRIMARY KEY(run_id, chunk_index)
        )
        """,
    )
    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS sampling_observations (
            matroid_id INTEGER PRIMARY KEY REFERENCES matroids(matroid_id) ON DELETE CASCADE,
            global_index INTEGER NOT NULL,
            chunk_index INTEGER NOT NULL,
            chunk_first_index INTEGER NOT NULL,
            chunk_offset INTEGER NOT NULL,
            cluster_draw_id INTEGER,
            within_cluster_index INTEGER,
            selection_probability REAL NOT NULL,
            design_weight REAL NOT NULL
        )
        """,
    )
    _ensure_compact_matroid_columns!(db)
    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS pair_ratio_aggregates (
            run_id TEXT NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
            simple INTEGER NOT NULL,
            connected INTEGER NOT NULL,
            alpha_positive INTEGER NOT NULL,
            ratio_num INTEGER NOT NULL,
            ratio_den INTEGER NOT NULL,
            ratio_value REAL NOT NULL,
            log_ratio REAL,
            pair_count INTEGER NOT NULL,
            census_pair_count INTEGER NOT NULL,
            matroid_weight REAL NOT NULL,
            census_maximizer_count INTEGER NOT NULL,
            PRIMARY KEY(
                run_id, simple, connected, alpha_positive, ratio_num, ratio_den
            )
        )
        """,
    )
    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS selected_matroids (
            matroid_id INTEGER NOT NULL REFERENCES matroids(matroid_id) ON DELETE CASCADE,
            selection_reason TEXT NOT NULL,
            selection_group TEXT NOT NULL DEFAULT '',
            selected_at TEXT NOT NULL,
            PRIMARY KEY(matroid_id, selection_reason, selection_group)
        )
        """,
    )
    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS selected_pairs (
            matroid_id INTEGER NOT NULL REFERENCES matroids(matroid_id) ON DELETE CASCADE,
            i INTEGER NOT NULL,
            j INTEGER NOT NULL,
            b00 INTEGER NOT NULL,
            b01 INTEGER NOT NULL,
            b10 INTEGER NOT NULL,
            b11 INTEGER NOT NULL,
            ratio_num INTEGER NOT NULL,
            ratio_den INTEGER NOT NULL,
            ratio_value REAL NOT NULL,
            log_ratio REAL,
            yules_q REAL NOT NULL,
            p_i REAL NOT NULL,
            p_j REAL NOT NULL,
            p_ij REAL NOT NULL,
            covariance_num INTEGER NOT NULL,
            covariance_den INTEGER NOT NULL,
            covariance REAL NOT NULL,
            pearson REAL NOT NULL,
            minimum_cell_count INTEGER NOT NULL,
            is_maximizer INTEGER NOT NULL,
            PRIMARY KEY(matroid_id, i, j)
        )
        """,
    )
    DBInterface.execute(db, "CREATE INDEX IF NOT EXISTS idx_matroids_run ON matroids(run_id)")
    DBInterface.execute(
        db,
        "CREATE INDEX IF NOT EXISTS idx_matroids_alpha ON matroids(alpha_value)",
    )
    DBInterface.execute(
        db,
        "CREATE INDEX IF NOT EXISTS idx_selected_pairs_ratio ON selected_pairs(ratio_value)",
    )
    _backfill_legacy_pair_aggregates!(db)
    DBInterface.execute(
        db,
        "INSERT OR REPLACE INTO metadata(key, value) VALUES ('schema_version', ?)",
        (string(SCHEMA_VERSION),),
    )
    DBInterface.execute(
        db,
        """
        INSERT OR REPLACE INTO metadata(key, value)
        SELECT 'packed_basis_compacted', '1'
        WHERE NOT EXISTS (
            SELECT 1 FROM matroids WHERE length(basis_encoding) > 0
        )
        """,
    )
    return db
end

"""
    reset_run!(db, run_id)

Delete one run and all of its dependent matroid, aggregate, and selected-pair
records. Other runs are untouched. Collection scripts call this before
reusing a run identifier, making a rerun deterministic.
"""
function reset_run!(db::SQLite.DB, run_id::AbstractString)
    if _table_exists(db, "pairs")
        DBInterface.execute(
            db,
            "DELETE FROM pairs WHERE matroid_id IN (SELECT matroid_id FROM matroids WHERE run_id = ?)",
            (run_id,),
        )
    end
    DBInterface.execute(db, "DELETE FROM pair_ratio_aggregates WHERE run_id = ?", (run_id,))
    DBInterface.execute(db, "DELETE FROM matroids WHERE run_id = ?", (run_id,))
    DBInterface.execute(db, "DELETE FROM runs WHERE run_id = ?", (run_id,))
    return nothing
end

"""
    begin_run!(db; run_id, source, ensemble, n, r, conditioning, generator, ...)

Reset `run_id` and insert its provenance record. Optional fields capture the
finite field, target size, seed, polyDB query, and OSCAR version. Call this and
the corresponding inserts inside one [`with_transaction`](@ref) block.
"""
function begin_run!(
    db::SQLite.DB;
    run_id::AbstractString,
    source::AbstractString,
    ensemble::AbstractString,
    n::Int,
    r::Int,
    field_size=missing,
    target_count=missing,
    seed=missing,
    conditioning::AbstractString,
    polydb_collection=missing,
    polydb_filter=missing,
    generator::AbstractString,
    oscar_version=missing,
)
    reset_run!(db, run_id)
    created_at = Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    DBInterface.execute(
        db,
        """
        INSERT INTO runs (
            run_id, source, ensemble, n, rank_value, field_size, target_count,
            seed, conditioning, polydb_collection, polydb_filter, generator,
            created_at, julia_version, oscar_version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            run_id,
            source,
            ensemble,
            n,
            r,
            field_size,
            target_count,
            seed,
            conditioning,
            polydb_collection,
            polydb_filter,
            generator,
            created_at,
            string(VERSION),
            oscar_version,
        ),
    )
    return nothing
end

"""
    finish_run!(db, run_id; accepted_count, rejected_count)

Finalize the observed acceptance and rejection counts for a registered run.
"""
function finish_run!(
    db::SQLite.DB,
    run_id::AbstractString;
    accepted_count::Int,
    rejected_count::Int,
)
    DBInterface.execute(
        db,
        "UPDATE runs SET accepted_count = ?, rejected_count = ? WHERE run_id = ?",
        (accepted_count, rejected_count, run_id),
    )
    return nothing
end

"""
    register_sampling_run!(db; run_id, release_slug, manifest_url, ...)

Attach the population and probability-sampling contract to an already
registered run. The four file hashes pin the remote manifest, realized sample
plan, design manifest, and exact decoder source/binary. The binary hash is an
audit aid rather than a substitute for the portable source hash.

`common_selection_probability` is the first-order inclusion probability for
a without-replacement design and the probability of one recorded draw for a
with-replacement design. The corresponding inverse is stored explicitly as
`common_design_weight`.
"""
function register_sampling_run!(
    db::SQLite.DB;
    run_id::AbstractString,
    release_slug::AbstractString,
    manifest_url::AbstractString,
    manifest_sha256::AbstractString,
    sample_plan_sha256::AbstractString,
    sampling_design_sha256::AbstractString,
    decoder_source_sha256::AbstractString,
    decoder_binary_sha256::AbstractString,
    population_size::Integer,
    sampling_design::AbstractString,
    selection_algorithm::AbstractString,
    cluster_draw_count=missing,
    draws_per_cluster=missing,
    common_selection_probability::Real,
    common_design_weight::Real,
)
    population_size > 0 || throw(ArgumentError("population size must be positive"))
    0 < common_selection_probability <= 1 ||
        throw(ArgumentError("selection probability must lie in (0,1]"))
    common_design_weight > 0 || throw(ArgumentError("design weight must be positive"))
    DBInterface.execute(
        db,
        """
        INSERT INTO sampling_runs (
            run_id, release_slug, manifest_url, manifest_sha256,
            sample_plan_sha256, sampling_design_sha256,
            decoder_source_sha256, decoder_binary_sha256,
            population_size, sampling_design, selection_algorithm,
            cluster_draw_count, draws_per_cluster,
            common_selection_probability, common_design_weight
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            run_id,
            release_slug,
            manifest_url,
            lowercase(manifest_sha256),
            lowercase(sample_plan_sha256),
            lowercase(sampling_design_sha256),
            lowercase(decoder_source_sha256),
            lowercase(decoder_binary_sha256),
            population_size,
            sampling_design,
            selection_algorithm,
            cluster_draw_count,
            draws_per_cluster,
            Float64(common_selection_probability),
            Float64(common_design_weight),
        ),
    )
    return nothing
end

"""
    register_sampled_chunk!(db; run_id, chunk_index, first_index, ...)

Record the exact remote object used during extraction, including the SHA-256
computed locally from its compressed bytes. `cluster_draw_multiplicity` is
one for an ordinary simple-random-sample extraction and counts how often the
chunk was selected by a with-replacement cluster design.
"""
function register_sampled_chunk!(
    db::SQLite.DB;
    run_id::AbstractString,
    chunk_index::Integer,
    first_index::Integer,
    record_count::Integer,
    compressed_bytes::Integer,
    url::AbstractString,
    compressed_sha256::AbstractString,
    cluster_draw_multiplicity::Integer,
)
    chunk_index >= 0 || throw(ArgumentError("chunk index must be nonnegative"))
    first_index >= 0 || throw(ArgumentError("first index must be nonnegative"))
    record_count > 0 || throw(ArgumentError("record count must be positive"))
    compressed_bytes > 0 || throw(ArgumentError("compressed size must be positive"))
    cluster_draw_multiplicity > 0 ||
        throw(ArgumentError("cluster multiplicity must be positive"))
    DBInterface.execute(
        db,
        """
        INSERT INTO sampled_chunks (
            run_id, chunk_index, first_index, record_count, compressed_bytes,
            url, compressed_sha256, cluster_draw_multiplicity
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            run_id,
            chunk_index,
            first_index,
            record_count,
            compressed_bytes,
            url,
            lowercase(compressed_sha256),
            cluster_draw_multiplicity,
        ),
    )
    return nothing
end

"""
    insert_sampling_observation!(db; matroid_id, global_index, ...)

Attach a stored matroid row to its global database index and probability-
sampling coordinates. Cluster identifiers are missing for an ordinary simple
random sample. They remain draw identifiers, rather than merely chunk IDs, so
repeated selections under a with-replacement design are retained faithfully.
"""
function insert_sampling_observation!(
    db::SQLite.DB;
    matroid_id::Integer,
    global_index::Integer,
    chunk_index::Integer,
    chunk_first_index::Integer,
    chunk_offset::Integer,
    cluster_draw_id=missing,
    within_cluster_index=missing,
    selection_probability::Real,
    design_weight::Real,
)
    global_index >= 0 || throw(ArgumentError("global index must be nonnegative"))
    chunk_index >= 0 || throw(ArgumentError("chunk index must be nonnegative"))
    chunk_offset >= 0 || throw(ArgumentError("chunk offset must be nonnegative"))
    global_index == chunk_first_index + chunk_offset ||
        throw(ArgumentError("global index must equal chunk first index plus offset"))
    0 < selection_probability <= 1 ||
        throw(ArgumentError("selection probability must lie in (0,1]"))
    design_weight > 0 || throw(ArgumentError("design weight must be positive"))
    DBInterface.execute(
        db,
        """
        INSERT INTO sampling_observations (
            matroid_id, global_index, chunk_index, chunk_first_index,
            chunk_offset, cluster_draw_id, within_cluster_index,
            selection_probability, design_weight
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            matroid_id,
            global_index,
            chunk_index,
            chunk_first_index,
            chunk_offset,
            cluster_draw_id,
            within_cluster_index,
            Float64(selection_probability),
            Float64(design_weight),
        ),
    )
    return nothing
end

"""In-memory totals for one exact pair ratio within one run/filter stratum."""
mutable struct PairRatioAccumulator
    ratio_value::Float64
    log_ratio::Union{Missing,Float64}
    pair_count::Int
    census_pair_count::Int
    matroid_weight::Float64
    census_maximizer_count::Int
end

"""
Prepared statements and in-memory exact-ratio aggregates for compact inserts.
Construct with [`prepare_writer`](@ref) and always release with
[`close_writer!`](@ref), which flushes the aggregate dictionary.
"""
struct DatabaseWriter
    db::SQLite.DB
    matroid_statement::SQLite.Stmt
    aggregate_statement::SQLite.Stmt
    pair_aggregates::Dict{Tuple{String,Int,Int,Int,Int,Int},PairRatioAccumulator}
end

"""
    prepare_writer(db) -> DatabaseWriter

Prepare reusable matroid and aggregate insert statements. Pair aggregates are
buffered in memory until [`close_writer!`](@ref); keep a writer inside the same
transaction as its run registration and matroid inserts.
"""
function prepare_writer(db::SQLite.DB)
    columns = """
        run_id, observation_index, source_id, field_size, census_multiplicity,
        n, rank_value, representation, num_bases, basis_density,
        basis_encoding, basis_hex, loops_count, coloops_count, simple,
        cosimple, component_count, connected, three_connected, paving,
        copaving, sparse_paving, girth, cogirth, circuit_hyperplanes,
        num_circuits, num_hyperplanes, beta_invariant, mobius_signed,
        mobius_invariant, automorphism_group_order, alpha_defined, alpha_num,
        alpha_den, alpha_value, log_alpha, best_i, best_j, maximizer_count,
        second_num, second_den,
        second_value, alpha_gap, positive_pair_count, eligible_element_count,
        eligible_pair_count, positive_pair_fraction, max_pearson,
        zero_pair_count, minimum_ratio_num, minimum_ratio_den,
        minimum_ratio_value, mean_pair_ratio, pair_ratio_std, pair_ratio_q10,
        pair_ratio_q25, pair_ratio_median, pair_ratio_q75, pair_ratio_q90,
        positive_component_count, largest_positive_component,
        max_positive_degree
    """
    placeholders = join(fill("?", 62), ", ")
    matroid_statement = SQLite.Stmt(
        db,
        "INSERT INTO matroids ($(columns)) VALUES ($(placeholders))",
    )
    aggregate_statement = SQLite.Stmt(
        db,
        """
        INSERT INTO pair_ratio_aggregates (
            run_id, simple, connected, alpha_positive, ratio_num, ratio_den,
            ratio_value, log_ratio, pair_count, census_pair_count,
            matroid_weight, census_maximizer_count
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(
            run_id, simple, connected, alpha_positive, ratio_num, ratio_den
        ) DO UPDATE SET
            pair_count = pair_count + excluded.pair_count,
            census_pair_count = census_pair_count + excluded.census_pair_count,
            matroid_weight = matroid_weight + excluded.matroid_weight,
            census_maximizer_count =
                census_maximizer_count + excluded.census_maximizer_count
        """,
    )
    return DatabaseWriter(
        db,
        matroid_statement,
        aggregate_statement,
        Dict{Tuple{String,Int,Int,Int,Int,Int},PairRatioAccumulator}(),
    )
end

function _flush_pair_aggregates!(writer::DatabaseWriter)
    for key in sort!(collect(keys(writer.pair_aggregates)))
        run_id, simple, connected, alpha_positive, ratio_num, ratio_den = key
        aggregate = writer.pair_aggregates[key]
        SQLite.execute(
            writer.aggregate_statement,
            (
                run_id,
                simple,
                connected,
                alpha_positive,
                ratio_num,
                ratio_den,
                aggregate.ratio_value,
                aggregate.log_ratio,
                aggregate.pair_count,
                aggregate.census_pair_count,
                aggregate.matroid_weight,
                aggregate.census_maximizer_count,
            ),
        )
    end
    empty!(writer.pair_aggregates)
    return nothing
end

"""
    close_writer!(writer)

Flush all exact-ratio aggregate totals and close both prepared statements.
"""
function close_writer!(writer::DatabaseWriter)
    _flush_pair_aggregates!(writer)
    DBInterface.close!(writer.matroid_statement)
    DBInterface.close!(writer.aggregate_statement)
    return nothing
end

"""
    insert_matroid!(writer; run_id, observation_index, source_id, stats, ...)

Insert one compact matroid row from [`matroid_statistics`](@ref) and update
in-memory exact-ratio aggregates. `census_multiplicity` defaults to one and is
the weight represented by this encoding. Complete pair rows are deliberately
not written here. Returns the SQLite `matroid_id`.
"""
function insert_matroid!(
    writer::DatabaseWriter;
    run_id::AbstractString,
    observation_index::Int,
    source_id::AbstractString,
    field_size=missing,
    representation=missing,
    census_multiplicity::Int=1,
    stats,
)
    census_multiplicity > 0 || throw(ArgumentError("census multiplicity must be positive"))
    SQLite.execute(
        writer.matroid_statement,
        (
            run_id,
            observation_index,
            source_id,
            field_size,
            census_multiplicity,
            stats.n,
            stats.r,
            representation,
            stats.num_bases,
            stats.basis_density,
            "",
            stats.basis_hex,
            stats.loops_count,
            stats.coloops_count,
            stats.simple,
            stats.cosimple,
            stats.component_count,
            stats.connected,
            stats.three_connected,
            stats.paving,
            stats.copaving,
            stats.sparse_paving,
            stats.girth,
            stats.cogirth,
            stats.circuit_hyperplanes,
            stats.num_circuits,
            stats.num_hyperplanes,
            stats.beta_invariant,
            stats.mobius_signed,
            stats.mobius_invariant,
            hasproperty(stats, :automorphism_group_order) ?
                stats.automorphism_group_order : missing,
            stats.alpha_defined,
            stats.alpha_num,
            stats.alpha_den,
            stats.alpha_value,
            stats.log_alpha,
            stats.best_i,
            stats.best_j,
            stats.maximizer_count,
            stats.second_num,
            stats.second_den,
            stats.second_value,
            stats.alpha_gap,
            stats.positive_pair_count,
            stats.eligible_element_count,
            stats.eligible_pair_count,
            stats.positive_pair_fraction,
            stats.max_pearson,
            stats.zero_pair_count,
            stats.minimum_ratio_num,
            stats.minimum_ratio_den,
            stats.minimum_ratio_value,
            stats.mean_pair_ratio,
            stats.pair_ratio_std,
            stats.pair_ratio_q10,
            stats.pair_ratio_q25,
            stats.pair_ratio_median,
            stats.pair_ratio_q75,
            stats.pair_ratio_q90,
            stats.positive_component_count,
            stats.largest_positive_component,
            stats.max_positive_degree,
        ),
    )
    matroid_id = SQLite.last_insert_rowid(writer.db)
    for pair in stats.pairs
        is_maximizer =
            pair.ratio_num * stats.alpha_den == stats.alpha_num * pair.ratio_den
        key = (
            String(run_id),
            Int(stats.simple),
            Int(stats.connected),
            Int(stats.alpha_num > 0),
            pair.ratio_num,
            pair.ratio_den,
        )
        aggregate = get!(writer.pair_aggregates, key) do
            PairRatioAccumulator(pair.ratio_value, pair.log_ratio, 0, 0, 0.0, 0)
        end
        aggregate.pair_count += 1
        aggregate.census_pair_count += census_multiplicity
        aggregate.matroid_weight += census_multiplicity / stats.eligible_pair_count
        aggregate.census_maximizer_count += is_maximizer ? census_multiplicity : 0
    end
    return matroid_id
end

"""
    with_transaction(db) do
        ...
    end

Run `action` inside `BEGIN IMMEDIATE`. Commit its return value on success and
roll back before rethrowing on failure. Both argument orders are supported so
Julia's `do`-block syntax reads naturally.
"""
function with_transaction(action::Function, db::SQLite.DB)
    DBInterface.execute(db, "BEGIN IMMEDIATE")
    try
        result = action()
        DBInterface.execute(db, "COMMIT")
        return result
    catch
        DBInterface.execute(db, "ROLLBACK")
        rethrow()
    end
end

with_transaction(db::SQLite.DB, action::Function) = with_transaction(action, db)

"""
Mark one stored matroid for detailed inspection and cache its complete pair
profile in `selected_pairs`. The packed basis mask is authoritative: the exact
polyDB-compatible basis encoding and pair data are reconstructed on demand
rather than retained redundantly for every observation.
"""
function store_selected_pair_profile!(
    db::SQLite.DB,
    matroid_id::Integer;
    reason::AbstractString,
    selection_group::AbstractString="",
    refresh::Bool=false,
)
    rows = [
        (
            n=row.n,
            rank_value=row.rank_value,
            basis_encoding=isempty(String(row.basis_encoding)) ?
                           basis_encoding_from_hex(
                String(row.basis_hex),
                binomial(Int(row.n), Int(row.rank_value)),
            ) : String(row.basis_encoding),
            alpha_num=row.alpha_num,
            alpha_den=row.alpha_den,
            eligible_pair_count=row.eligible_pair_count,
        ) for row in DBInterface.execute(
            db,
            """
            SELECT n, rank_value, basis_encoding, basis_hex, alpha_num, alpha_den,
                   eligible_pair_count
            FROM matroids
            WHERE matroid_id = ?
            """,
            (matroid_id,),
        )
    ]
    isempty(rows) && throw(ArgumentError("unknown matroid_id $(matroid_id)"))
    row = only(rows)
    selected_at = Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    DBInterface.execute(
        db,
        """
        INSERT INTO selected_matroids (
            matroid_id, selection_reason, selection_group, selected_at
        ) VALUES (?, ?, ?, ?)
        ON CONFLICT(matroid_id, selection_reason, selection_group)
        DO UPDATE SET selected_at = excluded.selected_at
        """,
        (matroid_id, reason, selection_group, selected_at),
    )

    cached_count = first(
        DBInterface.execute(
            db,
            "SELECT COUNT(*) AS n FROM selected_pairs WHERE matroid_id = ?",
            (matroid_id,),
        ),
    ).n
    !refresh && cached_count == row.eligible_pair_count && return matroid_id

    stats = matroid_statistics(
        row.basis_encoding,
        Int(row.n),
        Int(row.rank_value),
    )
    stats.alpha_num * row.alpha_den == row.alpha_num * stats.alpha_den ||
        error("recomputed alpha disagrees for matroid_id $(matroid_id)")

    with_transaction(db) do
        DBInterface.execute(
            db,
            "DELETE FROM selected_pairs WHERE matroid_id = ?",
            (matroid_id,),
        )
        statement = SQLite.Stmt(
            db,
            """
            INSERT INTO selected_pairs (
                matroid_id, i, j, b00, b01, b10, b11, ratio_num, ratio_den,
                ratio_value, log_ratio, yules_q, p_i, p_j, p_ij,
                covariance_num, covariance_den, covariance, pearson,
                minimum_cell_count, is_maximizer
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
        )
        try
            for pair in stats.pairs
                is_maximizer =
                    pair.ratio_num * stats.alpha_den ==
                    stats.alpha_num * pair.ratio_den
                SQLite.execute(
                    statement,
                    (
                        matroid_id,
                        pair.i,
                        pair.j,
                        pair.b00,
                        pair.b01,
                        pair.b10,
                        pair.b11,
                        pair.ratio_num,
                        pair.ratio_den,
                        pair.ratio_value,
                        pair.log_ratio,
                        pair.yules_q,
                        pair.p_i,
                        pair.p_j,
                        pair.p_ij,
                        pair.covariance_num,
                        pair.covariance_den,
                        pair.covariance,
                        pair.pearson,
                        pair.minimum_cell_count,
                        is_maximizer,
                    ),
                )
            end
        finally
            DBInterface.close!(statement)
        end
    end
    return matroid_id
end

"""
    matrix_rank_mod_p(columns, p) -> Int

Return the column rank over the prime field GF(`p`) by modular Gaussian
elimination. Columns must all have the same length. Primality is checked by
[`projective_points`](@ref), the normal caller.
"""
function matrix_rank_mod_p(columns::Vector{Vector{Int}}, p::Int)
    isempty(columns) && return 0
    rows = length(columns[1])
    all(column -> length(column) == rows, columns) ||
        throw(ArgumentError("all columns must have the same length"))
    matrix = Matrix{Int}(undef, rows, length(columns))
    for column_index in eachindex(columns), row_index in 1:rows
        matrix[row_index, column_index] = mod(columns[column_index][row_index], p)
    end

    pivot_row = 1
    rank = 0
    for column_index in axes(matrix, 2)
        pivot = findfirst(
            row_index -> matrix[row_index, column_index] != 0,
            pivot_row:rows,
        )
        isnothing(pivot) && continue
        pivot = first(pivot_row:rows) + pivot - 1
        if pivot != pivot_row
            matrix[pivot_row, :], matrix[pivot, :] =
                copy(matrix[pivot, :]), copy(matrix[pivot_row, :])
        end
        inverse = invmod(matrix[pivot_row, column_index], p)
        for entry in column_index:size(matrix, 2)
            matrix[pivot_row, entry] = mod(matrix[pivot_row, entry] * inverse, p)
        end
        for row_index in pivot_row+1:rows
            factor = matrix[row_index, column_index]
            factor == 0 && continue
            for entry in column_index:size(matrix, 2)
                matrix[row_index, entry] =
                    mod(matrix[row_index, entry] - factor * matrix[pivot_row, entry], p)
            end
        end
        rank += 1
        pivot_row += 1
        pivot_row > rows && break
    end
    return rank
end

function _is_prime(p::Int)
    p >= 2 || return false
    p == 2 && return true
    iseven(p) && return false
    divisor = 3
    while divisor^2 <= p
        p % divisor == 0 && return false
        divisor += 2
    end
    return true
end

"""
    projective_points(r, p) -> Vector{Vector{Int}}

Enumerate the points of `PG(r-1,p)` for prime `p`. Each one-dimensional
subspace is represented uniquely by scaling its first nonzero coordinate to
one. The deterministic order supports reproducible exhaustive subsets and
seeded random samples.
"""
function projective_points(r::Int, p::Int)
    _is_prime(p) || throw(ArgumentError("field size must be prime"))
    points = Vector{Vector{Int}}()
    for leading_index in 1:r
        tail_length = r - leading_index
        for code in 0:p^tail_length-1
            point = zeros(Int, r)
            point[leading_index] = 1
            remaining = code
            for coordinate in leading_index+1:r
                point[coordinate] = remaining % p
                remaining = div(remaining, p)
            end
            push!(points, point)
        end
    end
    expected = div(p^r - 1, p - 1)
    length(points) == expected || error("projective-point enumeration failed")
    return points
end

"""
    sample_projective_indices(rng, point_count, n; replacement=false)

Draw indices for a finite-field projective configuration. Without replacement,
return a uniformly sampled, sorted `n`-subset of `1:point_count`. With
replacement, return an ordered sequence of `n` independent uniform indices;
repeated indices represent parallel matroid elements. The replacement model
does not draw the zero vector, so it produces loopless representations before
the later spanning and connectedness filters.
"""
function sample_projective_indices(
    rng::Random.AbstractRNG,
    point_count::Int,
    n::Int;
    replacement::Bool=false,
)
    point_count > 0 || throw(ArgumentError("point_count must be positive"))
    n >= 0 || throw(ArgumentError("n must be nonnegative"))
    if replacement
        return rand(rng, 1:point_count, n)
    end
    n <= point_count || throw(
        ArgumentError("cannot sample $n distinct points from $point_count projective points"),
    )
    return sort!(randperm(rng, point_count)[1:n])
end
"""
    encoding_from_columns(columns, p, r) -> String

Construct the polyDB-compatible reverse-lex basis encoding of a represented
matroid over GF(`p`). Each rank-sized column subset is marked `*` exactly when
it has modular rank `r`.
"""
function encoding_from_columns(columns::Vector{Vector{Int}}, p::Int, r::Int)
    n = length(columns)
    characters = Vector{Char}(undef, binomial(n, r))
    for (index, mask) in enumerate(colex_masks(n, r))
        selected = Vector{Vector{Int}}()
        for element in 0:n-1
            ((mask >> element) & UInt64(1)) == 1 && push!(selected, columns[element + 1])
        end
        characters[index] = matrix_rank_mod_p(selected, p) == r ? '*' : '0'
    end
    return String(characters)
end

"""
    representation_string(columns) -> String

Serialize normalized finite-field columns as semicolon-separated columns with
comma-separated coordinates. This human-readable field is provenance; the
basis encoding is the canonical matroid representation.
"""
function representation_string(columns::Vector{Vector{Int}})
    return join((join(column, ',') for column in columns), ';')
end

function _csv_cell(value)
    value === missing && return ""
    value === nothing && return ""
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

function _write_table_csv(output::IO, rows)
    wrote_header = false
    for row in rows
        names = propertynames(row)
        if !wrote_header
            println(output, join(string.(names), ','))
            wrote_header = true
        end
        println(output, join((_csv_cell(getproperty(row, name)) for name in names), ','))
    end
    return nothing
end

"""
    export_table_csv(db, query, path) -> path

Stream an arbitrary read-only SQL query to RFC-style CSV, writing the header
from the first returned row and quoting commas, quotes, and newlines. Missing
values become empty cells. The query is supplied by trusted project code.
"""
function export_table_csv(
    db::SQLite.DB,
    query::AbstractString,
    path::AbstractString,
)
    mkpath(dirname(path))
    rows = DBInterface.execute(db, query)
    open(path, "w") do output
        _write_table_csv(output, rows)
    end
    return path
end

"""
    export_table_csv_zst(db, query, path; compression_level=6) -> path

Stream a query directly to a Zstandard-compressed RFC-style CSV without
materializing an uncompressed copy. `path` conventionally ends in `.csv.zst`.
The output is written atomically, and `zstd` must be available on `PATH`.
"""
function export_table_csv_zst(
    db::SQLite.DB,
    query::AbstractString,
    path::AbstractString;
    compression_level::Int=6,
)
    1 <= compression_level <= 19 || throw(
        ArgumentError("zstd compression level must lie between 1 and 19"),
    )
    compressor = Sys.which("zstd")
    compressor === nothing && throw(ArgumentError("zstd is required for compressed CSV export"))
    mkpath(dirname(path))
    temporary_path = path * ".tmp"
    isfile(temporary_path) && rm(temporary_path; force=true)
    level_argument = "-$(compression_level)"
    command = `$compressor --quiet --threads=0 $level_argument --stdout`
    try
        rows = DBInterface.execute(db, query)
        open(pipeline(command; stdout=temporary_path), "w") do output
            _write_table_csv(output, rows)
        end
        mv(temporary_path, path; force=true)
    catch
        isfile(temporary_path) && rm(temporary_path; force=true)
        rethrow()
    end
    return path
end

end
