"""
Migrate generated artifacts to the project's compact storage policy.

Command line:

```text
julia --project=. scripts/compact_storage.jl [PROJECT_ROOT]
```

The migration is lossless:

1. Large `matroids.csv` and `pair_ratio_aggregates.csv` files are compressed
   atomically with Zstandard and verified before their originals are removed.
2. Dense SVG point clouds are removed only when the corresponding PNG exists.
3. Every nonempty legacy `basis_encoding` is checked against `basis_hex`;
   verified text is then cleared and SQLite `VACUUM` reclaims its pages. The
   packed mask reconstructs the exact polyDB-compatible `0`/`*` encoding.

Running the script again is safe.
"""

using DBInterface
using SQLite

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

const LARGE_EXPORT_NAMES = Set(["matroids.csv", "pair_ratio_aggregates.csv"])
const DENSE_FIGURE_STEMS = Set([
    "matroid_scatterplots",
    "basis_density_vs_alpha_non_sparse_paving",
    "basis_density_vs_alpha_sparse_paving",
    "odds_ratio_vs_pearson",
])

"""Return the apparent bytes beneath a directory."""
function tree_bytes(path::AbstractString)
    isdir(path) || return 0
    total = 0
    for (root, _, files) in walkdir(path), file in files
        total += filesize(joinpath(root, file))
    end
    return total
end

"""Format a byte count using binary units."""
function readable_bytes(bytes::Integer)
    units = ("B", "KiB", "MiB", "GiB", "TiB")
    value = Float64(bytes)
    unit = 1
    while value >= 1024 && unit < length(units)
        value /= 1024
        unit += 1
    end
    return unit == 1 ? "$(bytes) B" : string(round(value; digits=2), " ", units[unit])
end

"""Compress one CSV atomically and remove it only after checksum verification."""
function compress_export!(path::AbstractString)
    compressor = Sys.which("zstd")
    compressor === nothing && throw(ArgumentError("zstd is required"))
    destination = path * ".zst"
    temporary = destination * ".tmp"
    isfile(temporary) && rm(temporary; force=true)
    try
        run(pipeline(
            `$compressor --quiet --threads=0 -6 --stdout $path`;
            stdout=temporary,
        ))
        run(`$compressor --quiet --test $temporary`)
        mv(temporary, destination; force=true)
        rm(path)
    catch
        isfile(temporary) && rm(temporary; force=true)
        rethrow()
    end
    return destination
end

"""Compress every generated large-table CSV under `data`."""
function compress_exports!(project_root::AbstractString)
    data_directory = joinpath(project_root, "data")
    isdir(data_directory) || return 0
    compressed = 0
    for (root, _, files) in walkdir(data_directory), file in files
        file in LARGE_EXPORT_NAMES || continue
        path = joinpath(root, file)
        destination = compress_export!(path)
        compressed += 1
        println("COMPRESSED ", path, " -> ", destination)
    end
    return compressed
end

"""Identify dense point-cloud SVGs that are intentionally raster-only."""
function is_dense_svg(file::AbstractString)
    endswith(file, ".svg") || return false
    stem = first(splitext(file))
    return stem in DENSE_FIGURE_STEMS ||
           endswith(stem, "_density_vs_theta") ||
           endswith(stem, "_density_vs_theta_lambda2")
end

"""Remove a dense SVG only when its rendered PNG counterpart exists."""
function remove_dense_svgs!(project_root::AbstractString)
    figure_directory = joinpath(project_root, "figures")
    isdir(figure_directory) || return (count=0, bytes=0)
    removed = 0
    reclaimed = 0
    for (root, _, files) in walkdir(figure_directory), file in files
        is_dense_svg(file) || continue
        svg_path = joinpath(root, file)
        png_path = joinpath(root, first(splitext(file)) * ".png")
        isfile(png_path) || error("refusing to remove $(svg_path): paired PNG is missing")
        reclaimed += filesize(svg_path)
        rm(svg_path)
        removed += 1
    end
    return (count=removed, bytes=reclaimed)
end

"""Return every experiment database below the project's data directory."""
function experiment_databases(project_root::AbstractString)
    paths = String[]
    data_directory = joinpath(project_root, "data")
    isdir(data_directory) || return paths
    for (root, _, files) in walkdir(data_directory), file in files
        file == "results.sqlite" && push!(paths, joinpath(root, file))
    end
    return sort!(paths)
end

"""Verify packed masks, clear redundant text, and vacuum one database."""
function compact_database!(path::AbstractString)
    before = filesize(path)
    database = SQLite.DB(path)
    expanded = only(
        Int(row.n) for row in DBInterface.execute(
            database,
            "SELECT COUNT(*) AS n FROM matroids WHERE length(basis_encoding) > 0",
        )
    )
    already_compacted = only(
        Int(row.n) for row in DBInterface.execute(
            database,
            """
            SELECT COUNT(*) AS n FROM metadata
            WHERE key = 'packed_basis_compacted' AND value = '1'
            """,
        )
    ) == 1
    verified = 0
    if expanded > 0
        for row in DBInterface.execute(
            database,
            """
            SELECT matroid_id, n, rank_value, basis_encoding, basis_hex
            FROM matroids
            WHERE length(basis_encoding) > 0
            ORDER BY matroid_id
            """,
        )
            encoding = String(row.basis_encoding)
            expected_length = binomial(Int(row.n), Int(row.rank_value))
            length(encoding) == expected_length || error(
                "basis length mismatch for $(path), matroid_id $(row.matroid_id)",
            )
            basis_hex(encoding) == lowercase(String(row.basis_hex)) || error(
                "packed basis mismatch for $(path), matroid_id $(row.matroid_id)",
            )
            verified += 1
        end
        verified == expanded || error("verification count changed while reading $(path)")
        DBInterface.execute(database, "BEGIN IMMEDIATE")
        try
            DBInterface.execute(
                database,
                "UPDATE matroids SET basis_encoding = '' WHERE length(basis_encoding) > 0",
            )
            DBInterface.execute(
                database,
                "INSERT OR REPLACE INTO metadata(key, value) VALUES ('schema_version', '4')",
            )
            DBInterface.execute(database, "COMMIT")
        catch
            DBInterface.execute(database, "ROLLBACK")
            rethrow()
        end
    end
    DBInterface.close!(database)

    if expanded > 0 || !already_compacted
        vacuum_database = SQLite.DB(path)
        collect(DBInterface.execute(vacuum_database, "PRAGMA wal_checkpoint(TRUNCATE)"))
        collect(DBInterface.execute(vacuum_database, "VACUUM"))
        DBInterface.execute(
            vacuum_database,
            """
            INSERT OR REPLACE INTO metadata(key, value)
            VALUES ('packed_basis_compacted', '1')
            """,
        )
        DBInterface.close!(vacuum_database)
    end
    after = filesize(path)
    println(
        "COMPACTED ",
        path,
        " verified=",
        verified,
        " before=",
        readable_bytes(before),
        " after=",
        readable_bytes(after),
    )
    return before - after
end

function main(args=ARGS)
    length(args) <= 1 || throw(
        ArgumentError("usage: compact_storage.jl [PROJECT_ROOT]"),
    )
    project_root = isempty(args) ? normpath(joinpath(@__DIR__, "..")) : abspath(args[1])
    before = tree_bytes(project_root)
    compressed = compress_exports!(project_root)
    dense = remove_dense_svgs!(project_root)
    database_reclaimed = sum(compact_database!(path) for path in experiment_databases(project_root))
    after = tree_bytes(project_root)
    println(
        "STORAGE_COMPACTION_COMPLETE compressed_exports=",
        compressed,
        " removed_dense_svgs=",
        dense.count,
        " dense_svg_bytes=",
        dense.bytes,
        " database_bytes=",
        database_reclaimed,
        " before=",
        before,
        " after=",
        after,
        " reclaimed=",
        before - after,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
