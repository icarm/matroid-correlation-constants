"""
Merge a validated ICARM extraction into one canonical compressed sample pack.

Command line:

```text
julia --project=. scripts/pack_icarm_sample.jl PLAN_DIRECTORY N R [OUTPUT]
```

The output defaults to `PLAN_DIRECTORY/sample_basis.tsv.zst`. Rows are sorted
by observation index and contain the seven saved sampling coordinates plus the
packed hexadecimal basis mask. A TOML manifest records the row count, column
contract, encoding convention, compressed hash, and hashes of the plan,
design, and chunk audit. This compact pack replaces the per-chunk decoded and
target fragments after the authoritative SQLite database has been validated.
"""

using SHA
using TOML

"""Return a lowercase SHA-256 digest for a local file."""
sha256_file(path) = open(path, "r") do input
    bytes2hex(sha256(input))
end

"""Read audited decoded paths and expected target counts."""
function audited_outputs(plan_directory)
    audit_path = joinpath(plan_directory, "chunk_audit.tsv")
    outputs = NamedTuple[]
    for (line_number, line) in enumerate(eachline(audit_path))
        line_number == 1 && continue
        fields = split(line, '\t')
        length(fields) == 10 || error("$audit_path:$line_number: expected ten columns")
        push!(outputs, (
            chunk_index=parse(Int, fields[1]),
            target_count=parse(Int, fields[7]),
            decoded_path=joinpath(plan_directory, fields[10]),
        ))
    end
    sort!(outputs; by=row -> row.chunk_index)
    return outputs
end

"""Load and sort the exact decoded rows, checking per-chunk counts."""
function decoded_rows(plan_directory, outputs)
    rows = Vector{Vector{SubString{String}}}()
    for output in outputs
        isfile(output.decoded_path) || error("missing decoded file $(output.decoded_path)")
        count_before = length(rows)
        for (line_number, line) in enumerate(eachline(output.decoded_path))
            fields = split(line, '\t')
            length(fields) == 8 || error(
                "$(output.decoded_path):$line_number: expected eight columns",
            )
            parse(Int, fields[3]) == output.chunk_index || error(
                "$(output.decoded_path):$line_number: wrong chunk index",
            )
            push!(rows, fields)
        end
        length(rows) - count_before == output.target_count || error(
            "$(output.decoded_path): decoded row count disagrees with audit",
        )
    end
    sort!(rows; by=fields -> parse(Int, fields[1]))
    length(unique(parse(Int, fields[1]) for fields in rows)) == length(rows) ||
        error("decoded rows contain duplicate observation indices")
    return rows
end

function main(args=ARGS)
    3 <= length(args) <= 4 || error(
        "usage: pack_icarm_sample.jl PLAN_DIRECTORY N R [OUTPUT]",
    )
    plan_directory = abspath(args[1])
    n = parse(Int, args[2])
    r = parse(Int, args[3])
    output_path = length(args) == 4 ? abspath(args[4]) :
                  joinpath(plan_directory, "sample_basis.tsv.zst")
    design_path = joinpath(plan_directory, "sampling_design.toml")
    plan_path = joinpath(plan_directory, "sample_plan.tsv")
    audit_path = joinpath(plan_directory, "chunk_audit.tsv")
    design = TOML.parsefile(design_path)
    outputs = audited_outputs(plan_directory)
    rows = decoded_rows(plan_directory, outputs)
    length(rows) == Int(design["sample_size"]) || error(
        "decoded sample has $(length(rows)) rows; design requires $(design["sample_size"])",
    )
    mkpath(dirname(output_path))
    uncompressed_bytes = 0
    mktempdir() do temporary_directory
        tsv_path = joinpath(temporary_directory, "sample_basis.tsv")
        open(tsv_path, "w") do output
            println(
                output,
                "observation_index\tglobal_index\tchunk_index\tchunk_first_index\t" *
                "chunk_offset\tcluster_draw_id\twithin_cluster_index\tbasis_hex",
            )
            for fields in rows
                println(output, join(fields, '\t'))
            end
        end
        uncompressed_bytes = filesize(tsv_path)
        run(`zstd -q -T0 -3 -f $tsv_path -o $output_path`)
    end
    run(`zstd -q -t $output_path`)
    manifest_path = replace(output_path, r"\.tsv\.zst$" => "_manifest.toml")
    manifest = Dict{String,Any}(
        "format_version" => 1,
        "n" => n,
        "rank" => r,
        "record_count" => length(rows),
        "columns" => [
            "observation_index",
            "global_index",
            "chunk_index",
            "chunk_first_index",
            "chunk_offset",
            "cluster_draw_id",
            "within_cluster_index",
            "basis_hex",
        ],
        "basis_encoding" => "polyDB REVLEX_BASIS_ENCODING packed little-endian by colex position",
        "compression" => "Zstandard level 3",
        "uncompressed_bytes" => uncompressed_bytes,
        "compressed_bytes" => filesize(output_path),
        "sample_pack_sha256" => sha256_file(output_path),
        "sample_plan_sha256" => sha256_file(plan_path),
        "sampling_design_sha256" => sha256_file(design_path),
        "chunk_audit_sha256" => sha256_file(audit_path),
    )
    open(manifest_path, "w") do output
        TOML.print(output, manifest)
    end
    println(
        "ICARM_SAMPLE_PACK_COMPLETE records=", length(rows),
        " bytes=", filesize(output_path),
        " sha256=", manifest["sample_pack_sha256"],
        " output=", output_path,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
