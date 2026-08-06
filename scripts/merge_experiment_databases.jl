"""
Merge independently generated experiment shards into one compact database.

Command line:

```text
julia --project=. scripts/merge_experiment_databases.jl \
    DESTINATION SHARD [SHARD ...]
```

Runs with identifiers already present in the destination are replaced
transactionally. Matroid identifiers are reassigned, while run identifiers,
observation indices, compact summaries, and exact-ratio aggregates are
preserved. Sampling shards contain no selected heatmap profiles; those are
generated only after the merge.
"""

using DBInterface
using SQLite

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

"""Quote a trusted SQLite identifier."""
function quoted_identifier(name::AbstractString)
    quote_character = string(Char(34))
    return quote_character *
           replace(name, quote_character => repeat(quote_character, 2)) *
           quote_character
end

"""Return table columns in schema order, optionally omitting named columns."""
function table_columns(database, schema::AbstractString, table::AbstractString; omit=Set{String}())
    query = "PRAGMA $(schema).table_info($(table))"
    return [
        String(row.name) for row in DBInterface.execute(database, query)
        if String(row.name) ∉ omit
    ]
end

"""Merge one attached shard and return its run and matroid counts."""
function merge_shard!(destination, shard_path::AbstractString)
    isfile(shard_path) || throw(ArgumentError("missing shard $(shard_path)"))
    collect(DBInterface.execute(
        destination,
        "ATTACH DATABASE ? AS incoming",
        (abspath(shard_path),),
    ))
    run_ids = [
        String(row.run_id) for row in DBInterface.execute(
            destination,
            "SELECT run_id FROM incoming.runs ORDER BY run_id",
        )
    ]
    isempty(run_ids) && throw(ArgumentError("shard $(shard_path) contains no runs"))
    source_matroids = only(
        Int(row.n) for row in DBInterface.execute(
            destination,
            "SELECT COUNT(*) AS n FROM incoming.matroids",
        )
    )
    matroid_columns = table_columns(
        destination,
        "main",
        "matroids";
        omit=Set(["matroid_id"]),
    )
    column_sql = join(quoted_identifier.(matroid_columns), ", ")

    with_transaction(destination) do
        for run_id in run_ids
            reset_run!(destination, run_id)
        end
        collect(DBInterface.execute(
            destination,
            "INSERT INTO runs SELECT * FROM incoming.runs",
        ))
        collect(DBInterface.execute(
            destination,
            """
            INSERT INTO matroids ($(column_sql))
            SELECT $(column_sql) FROM incoming.matroids
            ORDER BY matroid_id
            """,
        ))
        collect(DBInterface.execute(
            destination,
            """
            INSERT INTO pair_ratio_aggregates
            SELECT * FROM incoming.pair_ratio_aggregates
            """,
        ))
    end
    return (runs=length(run_ids), matroids=source_matroids)
end

function main(args=ARGS)
    length(args) >= 2 || throw(
        ArgumentError(
            "usage: merge_experiment_databases.jl DESTINATION SHARD [SHARD ...]",
        )
    )
    destination_path = args[1]
    total_runs = 0
    total_matroids = 0
    for shard_path in args[2:end]
        destination = init_database(destination_path)
        try
            result = merge_shard!(destination, shard_path)
            total_runs += result.runs
            total_matroids += result.matroids
            println(
                "MERGED ",
                shard_path,
                " runs=",
                result.runs,
                " matroids=",
                result.matroids,
            )
        finally
            DBInterface.close!(destination)
        end
    end
    println(
        "MERGE_COMPLETE destination=",
        destination_path,
        " runs=",
        total_runs,
        " matroids=",
        total_matroids,
    )
    return destination_path
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
