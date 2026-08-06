"""
Inspect the exact defect

    Delta(M) = (a(M)b(M) - i(M)s(M)) / b(M)^2

for connected matroids of size at most nine.  Smaller connected matroids are
recovered from the complete n=9 census by deleting the padded loops.

Usage:

    julia --project=. scripts/analyze_connected_epsilon_defect.jl
"""

using DBInterface
using SQLite

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

const PROJECT_DIRECTORY = normpath(joinpath(@__DIR__, ".."))
const DATABASE_PATH =
    joinpath(PROJECT_DIRECTORY, "data", "n9_census", "results.sqlite")

function loop_deleted_encoding(packed::AbstractString, rank::Int, core_size::Int)
    padded_encoding =
        basis_encoding_from_hex(packed, binomial(9, rank))
    padded_bases = encoding_to_bases(padded_encoding, 9, rank)
    support = foldl(|, padded_bases; init=UInt64(0))
    count_ones(support) == core_size ||
        error("expected $core_size nonloops, found $(count_ones(support))")
    nonloops = [element for element in 0:8 if support & (UInt64(1) << element) != 0]

    core_bases = Set{UInt64}()
    for basis in padded_bases
        core_basis = UInt64(0)
        for (new_element, old_element) in enumerate(nonloops)
            basis & (UInt64(1) << old_element) == 0 && continue
            core_basis |= UInt64(1) << (new_element - 1)
        end
        push!(core_bases, core_basis)
    end
    return String([
        mask in core_bases ? '*' : '0'
        for mask in colex_masks(core_size, rank)
    ])
end

function defect(statistics)
    independent = BigInt(statistics.independent_r_minus_1)
    bases = BigInt(statistics.num_bases)
    almost_bases = BigInt(statistics.rank_at_least_r_minus_1)
    spanning = BigInt(statistics.spanning_r_plus_1)
    return (almost_bases * bases - independent * spanning) // bases^2
end

function main()
    database = SQLite.DB(DATABASE_PATH)
    maxima = Dict{Tuple{Int,Int},NamedTuple}()
    counts = Dict{Tuple{Int,Int},Int}()
    try
        for core_size in 2:9
            @info "connected defect census" core_size
            query = if core_size == 9
                """
                SELECT source_id, rank_value, basis_hex, num_bases,
                       paving, sparse_paving, three_connected
                FROM matroids
                WHERE connected = 1
                """
            else
                """
                SELECT source_id, rank_value, basis_hex, num_bases,
                       paving, sparse_paving, three_connected
                FROM matroids
                WHERE loops_count = $(9 - core_size) AND coloops_count = 0
                """
            end

            counters = Dict{Int,EpsilonCounter}()
            for row in DBInterface.execute(database, query)
                rank = Int(row.rank_value)
                0 < rank < core_size || continue
                encoding = core_size == 9 ?
                           basis_encoding_from_hex(
                               String(row.basis_hex),
                               binomial(core_size, rank),
                           ) :
                           loop_deleted_encoding(
                               String(row.basis_hex), rank, core_size,
                           )

                structural = core_size == 9 ? nothing :
                             matroid_statistics(encoding, core_size, rank)
                core_size < 9 && !structural.connected && continue
                counter = get!(counters, rank) do
                    EpsilonCounter(core_size, rank)
                end
                statistics = epsilon_statistics(
                    counter,
                    basis_hex(encoding);
                    num_bases=Int(row.num_bases),
                    paving=core_size == 9 ? row.paving == 1 : structural.paving,
                    copaving=core_size == 9 ? row.sparse_paving == 1 :
                              structural.copaving,
                )
                value = defect(statistics)
                key = (core_size, rank)
                counts[key] = get(counts, key, 0) + 1
                record = (
                    source_id=String(row.source_id),
                    defect=value,
                    epsilon=statistics.epsilon,
                    bases=statistics.num_bases,
                    three_connected=core_size == 9 ? row.three_connected == 1 :
                                    structural.three_connected,
                )
                if !haskey(maxima, key) || value > maxima[key].defect
                    maxima[key] = record
                end
            end
        end
    finally
        close(database)
    end

    println("n,rank,count,max_defect,epsilon_at_max,bases,three_connected,source_id")
    for key in sort(collect(keys(maxima)))
        record = maxima[key]
        println(
            key[1], ',', key[2], ',', counts[key], ',', record.defect, ',',
            record.epsilon, ',', record.bases, ',', record.three_connected,
            ',', record.source_id,
        )
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
