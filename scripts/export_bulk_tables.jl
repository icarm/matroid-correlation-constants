"""
Create temporary lossless bulk CSV exports from an authoritative experiment
database.

Command line:

```text
julia --project=. scripts/export_bulk_tables.jl \
    DATABASE OUTPUT_DIRECTORY N RANK_SCOPE
```

`RANK_SCOPE` is one rank, a comma list, an inclusive `a:b` range, or `all`.
The command writes `matroids.csv.zst` and
`pair_ratio_aggregates.csv.zst`. These files are intentionally absent from
the persistent artifact policy because they duplicate SQLite and can be large.
"""

using DBInterface
using SQLite

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

"""Parse a nonredundant rank scope, with `all` discovered from completed runs."""
function parse_rank_scope(database, n::Int, specification::AbstractString)
    ranks = if lowercase(specification) == "all"
        sort!(unique(Int(row.rank_value) for row in DBInterface.execute(
            database,
            "SELECT rank_value FROM runs WHERE n = ? AND accepted_count > 0",
            (n,),
        )))
    elseif occursin(':', specification)
        endpoints = parse.(Int, split(specification, ':'))
        length(endpoints) == 2 || error("rank range must be a:b")
        collect(endpoints[1]:endpoints[2])
    elseif occursin(',', specification)
        sort!(unique(parse.(Int, split(specification, ','))))
    else
        [parse(Int, specification)]
    end
    isempty(ranks) && error("rank scope is empty")
    all(rank -> 0 <= rank <= fld(n, 2), ranks) || error(
        "by duality, retained ranks must lie between 0 and floor(n/2)",
    )
    return ranks
end

"""Export the two duplicate bulk tables for a requested rank scope."""
function export_bulk_tables(database, output_directory, n::Int, ranks)
    mkpath(output_directory)
    rank_list = join(ranks, ',')
    joined_scope = "r.n = $(n) AND r.rank_value IN ($(rank_list))"
    matroid_path = joinpath(output_directory, "matroids.csv.zst")
    aggregate_path = joinpath(output_directory, "pair_ratio_aggregates.csv.zst")
    export_table_csv_zst(
        database,
        """
        SELECT m.* FROM matroids m JOIN runs r USING(run_id)
        WHERE $(joined_scope)
        ORDER BY m.rank_value, m.run_id, m.observation_index
        """,
        matroid_path,
    )
    export_table_csv_zst(
        database,
        """
        SELECT a.* FROM pair_ratio_aggregates a JOIN runs r USING(run_id)
        WHERE $(joined_scope)
        ORDER BY a.run_id, a.simple, a.connected, a.alpha_positive, a.ratio_value
        """,
        aggregate_path,
    )
    return matroid_path, aggregate_path
end

function main(args=ARGS)
    length(args) == 4 || error(
        "usage: export_bulk_tables.jl DATABASE OUTPUT_DIRECTORY N RANK_SCOPE",
    )
    database_path = abspath(args[1])
    output_directory = abspath(args[2])
    n = parse(Int, args[3])
    database = init_database(database_path)
    try
        ranks = parse_rank_scope(database, n, args[4])
        matroid_path, aggregate_path =
            export_bulk_tables(database, output_directory, n, ranks)
        println(
            "BULK_EXPORT_COMPLETE n=", n,
            " ranks=", join(ranks, ','),
            " matroids=", matroid_path,
            " aggregates=", aggregate_path,
        )
    finally
        SQLite.close(database)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
