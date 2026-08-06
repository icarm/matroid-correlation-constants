"""
Download, verify, and decode the chunks selected by an ICARM sampling plan.

Command line:

```text
julia --threads=WORKERS --project=. scripts/extract_icarm_sample.jl \
    PLAN_DIR LINE_LENGTH DECODER [MAX_NEW_CHUNKS]
```

`PLAN_DIR` must contain `selected_chunks.tsv` and the `targets/` directory
created by `prepare_icarm_sample.jl`. Each compressed object is downloaded to
an isolated temporary directory, checked against the manifest byte size,
hashed with SHA-256, piped through `xz`, and scanned by the standalone target
decoder. Compressed chunks are deleted immediately after successful decoding.

One decoded TSV and one audit fragment are retained per selected chunk. Runs
are resumable: a chunk with both validated files is skipped. The optional
`MAX_NEW_CHUNKS` is useful for a one-chunk benchmark. At completion, audit
fragments are combined into `chunk_audit.tsv` in chunk-index order.
"""

using SHA

struct SelectedChunk
    index::Int
    first_index::Int64
    record_count::Int64
    compressed_bytes::Int64
    cluster_draw_multiplicity::Int
    target_count::Int
    url::String
    filename::String
end

function read_selected_chunks(path::AbstractString)
    chunks = SelectedChunk[]
    for (line_number, line) in enumerate(eachline(path))
        line_number == 1 && continue
        fields = split(line, '\t')
        length(fields) == 8 || error("$path:$line_number: expected eight columns")
        push!(
            chunks,
            SelectedChunk(
                parse(Int, fields[1]),
                parse(Int64, fields[2]),
                parse(Int64, fields[3]),
                parse(Int64, fields[4]),
                parse(Int, fields[5]),
                parse(Int, fields[6]),
                fields[7],
                fields[8],
            ),
        )
    end
    sort!(chunks; by=chunk -> chunk.index)
    return chunks
end

function sha256_file(path::AbstractString)
    open(path, "r") do input
        return bytes2hex(sha256(input))
    end
end

function validate_completed(output_path, audit_path, expected_lines)
    isfile(output_path) && isfile(audit_path) || return false
    countlines(output_path) == expected_lines || return false
    fields = split(strip(read(audit_path, String)), '\t')
    return length(fields) == 10
end

function process_chunk(plan_directory, decoder, line_length, chunk)
    target_path = joinpath(
        plan_directory,
        "targets",
        "chunk_" * lpad(string(chunk.index), 5, '0') * ".tsv",
    )
    decoded_directory = joinpath(plan_directory, "decoded")
    audit_directory = joinpath(plan_directory, "chunk_audit")
    mkpath(decoded_directory)
    mkpath(audit_directory)
    output_path = joinpath(
        decoded_directory,
        "chunk_" * lpad(string(chunk.index), 5, '0') * ".tsv",
    )
    audit_path = joinpath(
        audit_directory,
        "chunk_" * lpad(string(chunk.index), 5, '0') * ".tsv",
    )
    validate_completed(output_path, audit_path, chunk.target_count) &&
        return (status=:skipped, chunk=chunk, elapsed=0.0)

    start_time = time()
    mktempdir() do temporary_directory
        compressed_path = joinpath(temporary_directory, chunk.filename)
        temporary_output = joinpath(temporary_directory, "decoded.tsv")
        run(
            `curl -fsSL --retry 4 --retry-delay 2 $(chunk.url) -o $compressed_path`,
        )
        actual_bytes = filesize(compressed_path)
        actual_bytes == chunk.compressed_bytes || error(
            "chunk $(chunk.index) size mismatch: got $actual_bytes, " *
            "expected $(chunk.compressed_bytes)",
        )
        digest = sha256_file(compressed_path)
        run(
            pipeline(
                `xz -dc $compressed_path`,
                `$decoder $line_length $(chunk.record_count) $target_path $temporary_output`,
            ),
        )
        countlines(temporary_output) == chunk.target_count || error(
            "chunk $(chunk.index) emitted the wrong number of targets",
        )
        mv(temporary_output, output_path; force=true)
        elapsed = time() - start_time
        open(audit_path, "w") do output
            println(
                output,
                join(
                    (
                        chunk.index,
                        chunk.first_index,
                        chunk.record_count,
                        chunk.compressed_bytes,
                        digest,
                        chunk.cluster_draw_multiplicity,
                        chunk.target_count,
                        chunk.url,
                        round(elapsed; digits=6),
                        relpath(output_path, plan_directory),
                    ),
                    '\t',
                ),
            )
        end
        return (status=:decoded, chunk=chunk, elapsed=elapsed)
    end
end

function combine_audits(plan_directory, chunks)
    output_path = joinpath(plan_directory, "chunk_audit.tsv")
    open(output_path, "w") do output
        println(
            output,
            "chunk_index\tfirst_index\trecord_count\tcompressed_bytes\t" *
            "compressed_sha256\tcluster_draw_multiplicity\ttarget_count\t" *
            "url\telapsed_seconds\tdecoded_path",
        )
        for chunk in chunks
            audit_path = joinpath(
                plan_directory,
                "chunk_audit",
                "chunk_" * lpad(string(chunk.index), 5, '0') * ".tsv",
            )
            isfile(audit_path) || continue
            print(output, read(audit_path, String))
        end
    end
    return output_path
end

function main(args=ARGS)
    3 <= length(args) <= 4 || error(
        "usage: extract_icarm_sample.jl PLAN_DIR LINE_LENGTH DECODER [MAX_NEW_CHUNKS]",
    )
    plan_directory = abspath(args[1])
    line_length = parse(Int, args[2])
    decoder = abspath(args[3])
    max_new_chunks = length(args) == 4 ? parse(Int, args[4]) : typemax(Int)
    isfile(decoder) || error("decoder does not exist: $decoder")
    chunks = read_selected_chunks(joinpath(plan_directory, "selected_chunks.tsv"))

    pending = SelectedChunk[]
    for chunk in chunks
        output_path = joinpath(
            plan_directory,
            "decoded",
            "chunk_" * lpad(string(chunk.index), 5, '0') * ".tsv",
        )
        audit_path = joinpath(
            plan_directory,
            "chunk_audit",
            "chunk_" * lpad(string(chunk.index), 5, '0') * ".tsv",
        )
        validate_completed(output_path, audit_path, chunk.target_count) ||
            push!(pending, chunk)
    end
    pending = pending[1:min(length(pending), max_new_chunks)]
    println(
        "ICARM_EXTRACTION_START selected_chunks=",
        length(chunks),
        " pending_now=",
        length(pending),
        " julia_threads=",
        Threads.nthreads(),
    )

    print_lock = ReentrantLock()
    Threads.@threads for position in eachindex(pending)
        chunk = pending[position]
        result = process_chunk(plan_directory, decoder, line_length, chunk)
        lock(print_lock) do
            println(
                "ICARM_CHUNK_COMPLETE chunk=",
                chunk.index,
                " targets=",
                chunk.target_count,
                " seconds=",
                round(result.elapsed; digits=3),
            )
        end
    end

    audit_path = combine_audits(plan_directory, chunks)
    completed = count(
        chunk -> begin
            output_path = joinpath(
                plan_directory,
                "decoded",
                "chunk_" * lpad(string(chunk.index), 5, '0') * ".tsv",
            )
            audit_fragment = joinpath(
                plan_directory,
                "chunk_audit",
                "chunk_" * lpad(string(chunk.index), 5, '0') * ".tsv",
            )
            validate_completed(output_path, audit_fragment, chunk.target_count)
        end,
        chunks,
    )
    println(
        "ICARM_EXTRACTION_COMPLETE completed_chunks=",
        completed,
        " selected_chunks=",
        length(chunks),
        " audit=",
        audit_path,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
