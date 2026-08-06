"""
Collect complete polyDB isomorphism-class censuses into the compact SQLite
schema.

Command line:

```text
julia --project=. scripts/collect_polydb.jl \
    DATABASE N RANK_SPEC [LIMIT_PER_RANK] [RUN_PREFIX] [INCLUDE_DUALS]
```

`RANK_SPEC` accepts one rank (`4`), a comma-separated list (`3,4`), or an
inclusive range (`0:4`). By duality, source ranks must not exceed
`floor(N/2)`. A zero limit means no limit. Routine experiments should leave
`INCLUDE_DUALS` false. Setting it to true stores explicit duals solely for
validation; those redundant ranks are not included by `all` in the analysis
scripts.
"""

using Oscar

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

"""Parse a single rank, comma list, or inclusive `a:b` range."""
function parse_rank_specification(specification::AbstractString)
    ranks = if occursin(':', specification)
        endpoints = parse.(Int, split(specification, ':'))
        length(endpoints) == 2 || throw(ArgumentError("rank range must be a:b"))
        collect(endpoints[1]:endpoints[2])
    elseif occursin(',', specification)
        parse.(Int, split(specification, ','))
    else
        [parse(Int, specification)]
    end
    return sort!(unique(ranks))
end

"""Interpret common command-line spellings of a Boolean value."""
parse_boolean(value::AbstractString) = lowercase(value) in ("1", "true", "yes", "y")

"""
Collect one stored polyDB rank and, optionally, its dual rank in a single
transaction. Pair ratios are aggregated by the compact writer; detailed pair
rows are not persisted.
"""
function collect_rank!(
    database,
    collection,
    polydb_module,
    n::Int,
    r::Int,
    limit::Int,
    run_prefix::AbstractString,
    include_duals::Bool,
)
    run_id = "$(run_prefix)_r$(r)"
    dual_rank = n - r
    store_dual = include_duals && dual_rank != r
    dual_run_id = "$(run_prefix)_r$(dual_rank)_dual"
    filter_text = "N_ELEMENTS=$(n),RANK=$(r)"
    filter = polydb_module.BSON(Dict("N_ELEMENTS" => n, "RANK" => r))
    options = polydb_module.BSON(
        Dict("projection" => Dict("REVLEX_BASIS_ENCODING" => 1)),
    )
    accepted = Ref(0)

    with_transaction(database) do
        begin_run!(
            database;
            run_id=run_id,
            source="polyDB",
            ensemble="polydb_isomorphism_classes",
            n=n,
            r=r,
            target_count=limit == 0 ? missing : limit,
            conditioning="all stored rank-$(r) matroid isomorphism classes on $(n) elements",
            polydb_collection="Matroids.Small",
            polydb_filter=filter_text,
            generator="polyDB REVLEX_BASIS_ENCODING census",
            oscar_version=string(Base.pkgversion(Oscar)),
        )
        if store_dual
            begin_run!(
                database;
                run_id=dual_run_id,
                source="polyDB",
                ensemble="polydb_isomorphism_classes",
                n=n,
                r=dual_rank,
                target_count=limit == 0 ? missing : limit,
                conditioning="duals of all stored rank-$(r) matroid isomorphism classes on $(n) elements",
                polydb_collection="Matroids.Small",
                polydb_filter=filter_text,
                generator="duals of polyDB REVLEX_BASIS_ENCODING census",
                oscar_version=string(Base.pkgversion(Oscar)),
            )
        end

        writer = prepare_writer(database)
        cursor = polydb_module.find(collection.mcol, filter; options=options)
        try
            for document in cursor
                accepted[] += 1
                source_id = string(document["_id"])
                encoding = String(document["REVLEX_BASIS_ENCODING"])
                stats = matroid_statistics(encoding, n, r)
                insert_matroid!(
                    writer;
                    run_id=run_id,
                    observation_index=accepted[],
                    source_id=source_id,
                    stats=stats,
                )
                if store_dual
                    dual_stats = matroid_statistics(
                        dual_encoding(encoding, n, r),
                        n,
                        dual_rank,
                    )
                    insert_matroid!(
                        writer;
                        run_id=dual_run_id,
                        observation_index=accepted[],
                        source_id=source_id * "_dual",
                        stats=dual_stats,
                    )
                end
                accepted[] % 1000 == 0 &&
                    println("polyDB n=", n, " r=", r, ": processed ", accepted[])
                limit > 0 && accepted[] >= limit && break
            end
        finally
            # Avoid a libmongoc finalizer race at Julia shutdown after a large
            # streaming query.
            polydb_module.destroy!(cursor)
        end
        close_writer!(writer)
        finish_run!(database, run_id; accepted_count=accepted[], rejected_count=0)
        store_dual && finish_run!(
            database,
            dual_run_id;
            accepted_count=accepted[],
            rejected_count=0,
        )
    end

    println(
        "POLYDB_RANK_COMPLETE n=",
        n,
        " rank=",
        r,
        " accepted=",
        accepted[],
        " dual_rank=",
        store_dual ? dual_rank : "none",
    )
    return accepted[]
end

"""Parse CLI arguments, connect to polyDB once, and collect all requested ranks."""
function main()
    database_path = length(ARGS) >= 1 ? ARGS[1] :
                    joinpath(@__DIR__, "..", "data", "n8_r4_compact", "results.sqlite")
    n = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 8
    rank_specification = length(ARGS) >= 3 ? ARGS[3] : "4"
    limit = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 0
    run_prefix = length(ARGS) >= 5 ? ARGS[5] : "polydb_n$(n)"
    include_duals = length(ARGS) >= 6 ? parse_boolean(ARGS[6]) : false
    ranks = parse_rank_specification(rank_specification)
    maximum_rank = fld(n, 2)
    all(rank -> 0 <= rank <= maximum_rank, ranks) || throw(
        ArgumentError("by duality, source ranks must lie between 0 and floor(n/2) = $(maximum_rank)"),
    )
    limit >= 0 || throw(ArgumentError("limit must be nonnegative"))

    database = init_database(database_path)
    polydb_module = Polymake.Polydb.Mongoc
    polydb = Polymake.Polydb.get_db()
    collection = polydb["Matroids.Small"]
    client = polydb.mdb.client
    total = 0
    try
        for rank in ranks
            total += collect_rank!(
                database,
                collection,
                polydb_module,
                n,
                rank,
                limit,
                run_prefix,
                include_duals,
            )
        end
        println("POLYDB_COMPLETE n=", n, " stored_source_records=", total)
    finally
        # Destroy dependent handles from the leaves inward. Their registered
        # finalizers subsequently see null handles and become no-ops.
        polydb_module.destroy!(collection.mcol)
        polydb_module.destroy!(polydb.mdb)
        polydb_module.destroy!(client)
    end
end

main()
