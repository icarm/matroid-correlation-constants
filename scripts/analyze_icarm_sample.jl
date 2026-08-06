"""
Validate and analyze one realized probability sample from the ICARM database.

Command line:

```text
julia --project=. scripts/analyze_icarm_sample.jl \
    PLAN_DIRECTORY N R DATABASE RUN_ID [WORKER_PROCESSES]
```

The plan directory must contain `sampling_design.toml`, `sample_plan.tsv`,
`selected_chunks.tsv`, and `chunk_audit.tsv`, plus either the decoded files
produced by `extract_icarm_sample.jl` or the canonical
`sample_basis.tsv.zst`. Before doing mathematical work, this program joins
every decoded observation back to its planned global index and verifies every
chunk count. It then computes the compact correlation-ratio and structural
statistics, together with the OSCAR automorphism-group order, in bounded
batches. Separate Julia worker processes are used because OSCAR's group stack
is not assumed to be thread-safe.

The SQLite database is authoritative. It stores one row per sampled
observation, exact sample coordinates and design weights, per-chunk hashes,
and hashes of the manifest, realized plan, design file, decoder source, and
decoder executable. Complete pair profiles are not retained routinely; only
run-level exact-ratio aggregates are updated by the compact writer.
"""

using DBInterface
using Distributed
using Oscar
using SHA
using SQLite
using TOML

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))
const MODULE_PATH = joinpath(PROJECT_ROOT, "src", "CorrelationRatiosDistributions.jl")
include(MODULE_PATH)
using .CorrelationRatiosDistributions

"""Return the lowercase SHA-256 digest of a local file."""
function sha256_file(path::AbstractString)
    open(path, "r") do input
        return bytes2hex(sha256(input))
    end
end

"""Parse a required integer, reporting its file and line on failure."""
function parse_integer(value, path, line_number, field_name)
    try
        return parse(Int64, value)
    catch
        error("$path:$line_number: invalid $field_name: $value")
    end
end

"""Read the seven sampling coordinates keyed by observation index."""
function read_sample_plan(path::AbstractString)
    plan = Dict{Int,NamedTuple}()
    for (line_number, line) in enumerate(eachline(path))
        line_number == 1 && continue
        fields = split(line, '\t')
        length(fields) == 7 || error("$path:$line_number: expected seven columns")
        observation_index = Int(parse_integer(fields[1], path, line_number, "observation index"))
        haskey(plan, observation_index) &&
            error("$path:$line_number: duplicate observation $observation_index")
        plan[observation_index] = (
            observation_index=observation_index,
            global_index=parse_integer(fields[2], path, line_number, "global index"),
            chunk_index=Int(parse_integer(fields[3], path, line_number, "chunk index")),
            chunk_first_index=parse_integer(fields[4], path, line_number, "chunk first index"),
            chunk_offset=parse_integer(fields[5], path, line_number, "chunk offset"),
            cluster_draw_id=Int(parse_integer(fields[6], path, line_number, "cluster draw")),
            within_cluster_index=Int(parse_integer(fields[7], path, line_number, "within-cluster index")),
        )
    end
    return plan
end

"""Read locally verified chunk metadata from the extraction audit."""
function read_chunk_audit(path::AbstractString)
    rows = NamedTuple[]
    for (line_number, line) in enumerate(eachline(path))
        line_number == 1 && continue
        fields = split(line, '\t')
        length(fields) == 10 || error("$path:$line_number: expected ten columns")
        push!(rows, (
            chunk_index=Int(parse_integer(fields[1], path, line_number, "chunk index")),
            first_index=parse_integer(fields[2], path, line_number, "first index"),
            record_count=parse_integer(fields[3], path, line_number, "record count"),
            compressed_bytes=parse_integer(fields[4], path, line_number, "compressed bytes"),
            compressed_sha256=fields[5],
            cluster_draw_multiplicity=Int(parse_integer(fields[6], path, line_number, "cluster multiplicity")),
            target_count=Int(parse_integer(fields[7], path, line_number, "target count")),
            url=fields[8],
            elapsed_seconds=parse(Float64, fields[9]),
            decoded_path=fields[10],
        ))
    end
    sort!(rows; by=row -> row.chunk_index)
    length(unique(row.chunk_index for row in rows)) == length(rows) ||
        error("$path contains duplicate chunk indices")
    return rows
end

"""
Load decoded basis masks and prove that they realize the exact saved plan.

The decoder copies the first seven sampling fields into every output row. We
compare them field-for-field with `sample_plan.tsv`, validate chunk membership
and target counts, reject duplicate observations, and sort by observation
index. Keeping only this bounded sample in memory makes the later database
transaction shorter and ensures a malformed extraction fails before writes.
"""
function validate_decoded_fields!(records, remaining, fields, source, line_number, audit)
    length(fields) == 8 || error("$source:$line_number: expected eight columns")
    coordinates = (
        observation_index=Int(parse_integer(fields[1], source, line_number, "observation index")),
        global_index=parse_integer(fields[2], source, line_number, "global index"),
        chunk_index=Int(parse_integer(fields[3], source, line_number, "chunk index")),
        chunk_first_index=parse_integer(fields[4], source, line_number, "chunk first index"),
        chunk_offset=parse_integer(fields[5], source, line_number, "chunk offset"),
        cluster_draw_id=Int(parse_integer(fields[6], source, line_number, "cluster draw")),
        within_cluster_index=Int(parse_integer(fields[7], source, line_number, "within-cluster index")),
    )
    expected = pop!(remaining, coordinates.observation_index, nothing)
    isnothing(expected) && error(
        "$source:$line_number: unplanned or duplicate observation " *
        string(coordinates.observation_index),
    )
    coordinates == expected || error(
        "$source:$line_number: sampling coordinates disagree with plan",
    )
    coordinates.chunk_index == audit.chunk_index ||
        error("$source:$line_number: wrong audited chunk")
    coordinates.global_index == coordinates.chunk_first_index + coordinates.chunk_offset ||
        error("$source:$line_number: inconsistent global index")
    0 <= coordinates.chunk_offset < audit.record_count ||
        error("$source:$line_number: chunk offset out of range")
    push!(records, merge(coordinates, (basis_hex=lowercase(fields[8]),)))
    return nothing
end

function load_and_validate_records(plan_directory, audit_rows, expected_sample_size)
    remaining = read_sample_plan(joinpath(plan_directory, "sample_plan.tsv"))
    length(remaining) == expected_sample_size || error(
        "sample plan has $(length(remaining)) rows; expected $expected_sample_size",
    )
    records = NamedTuple[]
    sizehint!(records, expected_sample_size)
    audit_by_chunk = Dict(row.chunk_index => row for row in audit_rows)
    pack_path = joinpath(plan_directory, "sample_basis.tsv.zst")
    decoded_paths_exist = all(
        isfile(joinpath(plan_directory, audit.decoded_path)) for audit in audit_rows
    )
    if decoded_paths_exist
        for audit in audit_rows
            decoded_path = joinpath(plan_directory, audit.decoded_path)
            line_count = 0
            for (line_number, line) in enumerate(eachline(decoded_path))
                validate_decoded_fields!(
                    records,
                    remaining,
                    split(line, '\t'),
                    decoded_path,
                    line_number,
                    audit,
                )
                line_count += 1
            end
            line_count == audit.target_count || error(
                "$decoded_path has $line_count rows; audit requires $(audit.target_count)",
            )
        end
    elseif isfile(pack_path)
        chunk_counts = Dict(row.chunk_index => 0 for row in audit_rows)
        open(`zstd -q -d -c $pack_path`) do input
            for (line_number, line) in enumerate(eachline(input))
                if line_number == 1
                    startswith(line, "observation_index\tglobal_index\t") ||
                        error("$pack_path: unexpected header")
                    continue
                end
                fields = split(line, '\t')
                length(fields) == 8 || error("$pack_path:$line_number: expected eight columns")
                chunk_index = Int(parse_integer(fields[3], pack_path, line_number, "chunk index"))
                audit = get(audit_by_chunk, chunk_index, nothing)
                isnothing(audit) && error("$pack_path:$line_number: unaudited chunk $chunk_index")
                validate_decoded_fields!(
                    records,
                    remaining,
                    fields,
                    pack_path,
                    line_number,
                    audit,
                )
                chunk_counts[chunk_index] += 1
            end
        end
        for audit in audit_rows
            chunk_counts[audit.chunk_index] == audit.target_count || error(
                "$pack_path: chunk $(audit.chunk_index) has $(chunk_counts[audit.chunk_index]) rows; " *
                "audit requires $(audit.target_count)",
            )
        end
    else
        error(
            "neither all audited decoded files nor canonical sample pack exists in $plan_directory",
        )
    end
    isempty(remaining) || error("decoded extraction is missing $(length(remaining)) planned rows")
    length(records) == expected_sample_size || error(
        "decoded extraction has $(length(records)) rows; expected $expected_sample_size",
    )
    sort!(records; by=record -> record.observation_index)
    return records
end

"""Convert a compact basis encoding to the OSCAR base-list convention."""
function oscar_bases(encoding::AbstractString, n::Int, r::Int)
    return [
        findall(
            element -> ((mask >> (element - 1)) & UInt64(1)) == UInt64(1),
            1:n,
        ) for mask in encoding_to_bases(encoding, n, r)
    ]
end

"""Compute all invariant fields for a small block of decoded observations."""
function analyze_record_block(records, n::Int, r::Int)
    result = Vector{Any}(undef, length(records))
    encoding_length = binomial(n, r)
    for index in eachindex(records)
        record = records[index]
        encoding = basis_encoding_from_hex(record.basis_hex, encoding_length)
        stats = matroid_statistics(encoding, n, r)
        matroid = matroid_from_bases(oscar_bases(encoding, n, r), n; check=false)
        group_order = Int(order(automorphism_group(matroid)))
        result[index] = (
            record=record,
            stats=merge(stats, (automorphism_group_order=group_order,)),
        )
    end
    return result
end

"""Load the analysis function and dependencies in isolated worker processes."""
function configure_workers(worker_count::Int)
    worker_count >= 0 || throw(ArgumentError("worker count must be nonnegative"))
    worker_count == 0 && return Int[]
    worker_ids = addprocs(
        worker_count;
        exeflags="--project=$(PROJECT_ROOT)",
    )
    module_path = MODULE_PATH
    expression = quote
        using Oscar
        include($module_path)
        using .CorrelationRatiosDistributions

        function oscar_bases(encoding::AbstractString, n::Int, r::Int)
            return [
                findall(
                    element -> ((mask >> (element - 1)) & UInt64(1)) == UInt64(1),
                    1:n,
                ) for mask in encoding_to_bases(encoding, n, r)
            ]
        end

        function analyze_record_block(records, n::Int, r::Int)
            result = Vector{Any}(undef, length(records))
            encoding_length = binomial(n, r)
            for index in eachindex(records)
                record = records[index]
                encoding = basis_encoding_from_hex(record.basis_hex, encoding_length)
                stats = matroid_statistics(encoding, n, r)
                matroid = matroid_from_bases(oscar_bases(encoding, n, r), n; check=false)
                group_order = Int(order(automorphism_group(matroid)))
                result[index] = (
                    record=record,
                    stats=merge(stats, (automorphism_group_order=group_order,)),
                )
            end
            return result
        end
    end
    Distributed.remotecall_eval(Main, worker_ids, expression)
    return worker_ids
end

"""Analyze one bounded batch locally or across isolated worker processes."""
function analyze_batch(records, n, r, worker_ids)
    isempty(worker_ids) && return analyze_record_block(records, n, r)
    block_size = cld(length(records), length(worker_ids))
    blocks = [records[start:min(start + block_size - 1, end)] for start in 1:block_size:length(records)]
    pool = WorkerPool(worker_ids)
    analyzed_blocks = pmap(
        block -> analyze_record_block(block, n, r),
        pool,
        blocks;
        batch_size=1,
    )
    return reduce(vcat, analyzed_blocks; init=Any[])
end

"""Parse the extraction-audit records into the persistent provenance table."""
function register_chunks!(database, run_id, audit_rows)
    for row in audit_rows
        register_sampled_chunk!(
            database;
            run_id=run_id,
            chunk_index=row.chunk_index,
            first_index=row.first_index,
            record_count=row.record_count,
            compressed_bytes=row.compressed_bytes,
            url=row.url,
            compressed_sha256=row.compressed_sha256,
            cluster_draw_multiplicity=row.cluster_draw_multiplicity,
        )
    end
end

"""Return `missing` for the `-1` sentinel used by non-cluster plans."""
optional_cluster_coordinate(value::Int) = value < 0 ? missing : value

function main(args=ARGS)
    5 <= length(args) <= 6 || error(
        "usage: analyze_icarm_sample.jl PLAN_DIRECTORY N R DATABASE RUN_ID [WORKER_PROCESSES]",
    )
    plan_directory = abspath(args[1])
    n = parse(Int, args[2])
    r = parse(Int, args[3])
    database_path = abspath(args[4])
    run_id = args[5]
    worker_count = length(args) == 6 ? parse(Int, args[6]) : 4
    release_slug = "n$(n)r" * lpad(string(r), 2, '0')
    design_path = joinpath(plan_directory, "sampling_design.toml")
    manifest_path = joinpath(
        plan_directory,
        "..",
        "manifests",
        release_slug * "_manifest.json",
    )
    decoder_source = joinpath(PROJECT_ROOT, "tools", "icarm_decode_targets.c")
    decoder_binary = joinpath(PROJECT_ROOT, "build", "icarm_decode_targets")
    for required_path in (design_path, manifest_path, decoder_source, decoder_binary)
        isfile(required_path) || error("required provenance file is missing: $required_path")
    end

    design = TOML.parsefile(design_path)
    expected_sample_size = Int(design["sample_size"])
    audit_rows = read_chunk_audit(joinpath(plan_directory, "chunk_audit.tsv"))
    records = load_and_validate_records(plan_directory, audit_rows, expected_sample_size)
    println(
        "ICARM_ANALYSIS_VALIDATED run=", run_id,
        " observations=", length(records),
        " chunks=", length(audit_rows),
    )

    worker_ids = Int[]
    database = nothing
    start_time = time()
    try
        worker_ids = configure_workers(worker_count)
        database = init_database(database_path)
        sampling_design = String(design["design"])
        cluster_design = haskey(design, "cluster_draw_count")
        ensemble = cluster_design ?
                   "icarm_isomorphism_classes_pps_cluster" :
                   "icarm_isomorphism_classes_srs"
        with_transaction(database) do
            begin_run!(
                database;
                run_id=run_id,
                source="ICARM_database",
                ensemble=ensemble,
                n=n,
                r=r,
                target_count=expected_sample_size,
                seed=Int(design["seed"]),
                conditioning="none; probability sample of stored isomorphism classes",
                generator="ICARM manifest + saved integer sample plan + selective stream decoder",
                oscar_version=string(Base.pkgversion(Oscar)),
            )
            register_sampling_run!(
                database;
                run_id=run_id,
                release_slug=release_slug,
                manifest_url="https://matroids.icarm.cloud/enumeration/$release_slug",
                manifest_sha256=sha256_file(manifest_path),
                sample_plan_sha256=sha256_file(joinpath(plan_directory, "sample_plan.tsv")),
                sampling_design_sha256=sha256_file(design_path),
                decoder_source_sha256=sha256_file(decoder_source),
                decoder_binary_sha256=sha256_file(decoder_binary),
                population_size=Int64(design["population_size"]),
                sampling_design=sampling_design,
                selection_algorithm=String(design["selection_algorithm"]),
                cluster_draw_count=get(design, "cluster_draw_count", missing),
                draws_per_cluster=get(design, "draws_per_cluster", missing),
                common_selection_probability=Float64(design["common_selection_probability"]),
                common_design_weight=Float64(design["common_design_weight"]),
            )
            register_chunks!(database, run_id, audit_rows)

            writer = prepare_writer(database)
            inserted = 0
            batch_size = 1_000
            for batch_start in 1:batch_size:length(records)
                batch_stop = min(batch_start + batch_size - 1, length(records))
                analyzed = analyze_batch(records[batch_start:batch_stop], n, r, worker_ids)
                for entry in analyzed
                    record = entry.record
                    matroid_id = insert_matroid!(
                        writer;
                        run_id=run_id,
                        observation_index=record.observation_index,
                        source_id="$release_slug:$(record.global_index):$(record.observation_index)",
                        representation="ICARM reverse-lex basis mask",
                        stats=entry.stats,
                    )
                    insert_sampling_observation!(
                        database;
                        matroid_id=matroid_id,
                        global_index=record.global_index,
                        chunk_index=record.chunk_index,
                        chunk_first_index=record.chunk_first_index,
                        chunk_offset=record.chunk_offset,
                        cluster_draw_id=optional_cluster_coordinate(record.cluster_draw_id),
                        within_cluster_index=optional_cluster_coordinate(record.within_cluster_index),
                        selection_probability=Float64(design["common_selection_probability"]),
                        design_weight=Float64(design["common_design_weight"]),
                    )
                    inserted += 1
                end
                println(
                    "ICARM_ANALYSIS_PROGRESS run=", run_id,
                    " inserted=", inserted,
                    " total=", length(records),
                    " elapsed_seconds=", round(time() - start_time; digits=1),
                )
            end
            close_writer!(writer)
            finish_run!(database, run_id; accepted_count=inserted, rejected_count=0)
        end
        result = first(DBInterface.execute(
            database,
            "SELECT COUNT(*) AS n, COUNT(DISTINCT observation_index) AS d FROM matroids WHERE run_id = ?",
            (run_id,),
        ))
        Int(result.n) == expected_sample_size == Int(result.d) ||
            error("post-commit observation count check failed")
        integrity = first(DBInterface.execute(database, "PRAGMA integrity_check"))
        String(integrity.integrity_check) == "ok" || error("SQLite integrity check failed")
        println(
            "ICARM_ANALYSIS_COMPLETE run=", run_id,
            " observations=", result.n,
            " seconds=", round(time() - start_time; digits=1),
            " database=", database_path,
        )
    finally
        !isnothing(database) && SQLite.close(database)
        !isempty(worker_ids) && rmprocs(worker_ids)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
