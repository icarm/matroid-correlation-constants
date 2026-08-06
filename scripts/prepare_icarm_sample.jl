"""
Create a deterministic probability-sampling plan for an ICARM enumeration.

The input chunk TSV is produced from the public JSON manifest and has columns

```text
chunk_index  first_index  last_index  record_count  compressed_bytes  url  filename
```

Command line:

```text
julia --project=. scripts/prepare_icarm_sample.jl \
    CHUNKS.tsv OUTPUT_DIR srs SAMPLE_SIZE SEED

julia --project=. scripts/prepare_icarm_sample.jl \
    CHUNKS.tsv OUTPUT_DIR cluster CLUSTER_DRAWS DRAWS_PER_CLUSTER SEED
```

`srs` uses Floyd's algorithm to draw a simple random sample without
replacement from all global record indices. `cluster` independently selects
chunks with replacement and probability proportional to their record count,
then draws distinct offsets uniformly within each selected chunk. Every
recorded cluster-sample slot is therefore marginally uniform over database
records, although slots sharing a cluster draw are dependent.

The script writes one authoritative `sample_plan.tsv`, decoder target shards
grouped by chunk, a selected-chunk table, and a TOML design manifest. Julia's
MersenneTwister, the Julia version, and the seed are recorded explicitly.
"""

using Random
using TOML

struct ICARMChunk
    index::Int
    first_index::Int64
    last_index::Int64
    record_count::Int64
    compressed_bytes::Int64
    url::String
    filename::String
end

function read_chunks(path::AbstractString)
    chunks = ICARMChunk[]
    for (line_number, line) in enumerate(eachline(path))
        isempty(strip(line)) && continue
        fields = split(line, '\t')
        length(fields) == 7 || error("$path:$line_number: expected seven columns")
        push!(
            chunks,
            ICARMChunk(
                parse(Int, fields[1]),
                parse(Int64, fields[2]),
                parse(Int64, fields[3]),
                parse(Int64, fields[4]),
                parse(Int64, fields[5]),
                fields[6],
                fields[7],
            ),
        )
    end
    isempty(chunks) && error("chunk table is empty")
    sort!(chunks; by=chunk -> chunk.first_index)
    expected_first = Int64(0)
    for chunk in chunks
        chunk.first_index == expected_first ||
            error("chunk ranges are not contiguous at chunk $(chunk.index)")
        chunk.last_index == chunk.first_index + chunk.record_count - 1 ||
            error("chunk $(chunk.index) has inconsistent range and count")
        expected_first = chunk.last_index + 1
    end
    return chunks
end

"""Floyd's O(k)-memory exact sample of `k` distinct integers from `0:n-1`."""
function floyd_sample(rng::AbstractRNG, n::Int64, k::Int)
    0 <= k <= n || throw(ArgumentError("require 0 <= k <= population size"))
    selected = Set{Int64}()
    for upper in n-Int64(k):n-1
        proposal = rand(rng, Int64(0):upper)
        push!(selected, proposal in selected ? upper : proposal)
    end
    result = collect(selected)
    length(result) == k || error("Floyd sampler produced the wrong sample size")
    sort!(result)
    return result
end

function locate_chunk(chunks, global_index::Int64)
    position = searchsortedlast(
        [chunk.first_index for chunk in chunks],
        global_index,
    )
    position >= 1 || error("global index precedes the first chunk")
    chunk = chunks[position]
    global_index <= chunk.last_index || error("global index lies in a manifest gap")
    return chunk
end

function write_outputs(output_directory, chunks, records, design_metadata)
    mkpath(output_directory)
    target_directory = joinpath(output_directory, "targets")
    mkpath(target_directory)

    plan_path = joinpath(output_directory, "sample_plan.tsv")
    open(plan_path, "w") do output
        println(
            output,
            "observation_index\tglobal_index\tchunk_index\tchunk_first_index\t" *
            "chunk_offset\tcluster_draw_id\twithin_cluster_index",
        )
        for record in sort(records; by=record -> record.observation_index)
            println(
                output,
                join(
                    (
                        record.observation_index,
                        record.global_index,
                        record.chunk_index,
                        record.chunk_first_index,
                        record.chunk_offset,
                        record.cluster_draw_id,
                        record.within_cluster_index,
                    ),
                    '\t',
                ),
            )
        end
    end

    by_chunk = Dict{Int,Vector{eltype(records)}}()
    for record in records
        push!(get!(by_chunk, record.chunk_index, eltype(records)[]), record)
    end
    chunk_lookup = Dict(chunk.index => chunk for chunk in chunks)
    selected_chunks_path = joinpath(output_directory, "selected_chunks.tsv")
    open(selected_chunks_path, "w") do output
        println(
            output,
            "chunk_index\tfirst_index\trecord_count\tcompressed_bytes\t" *
            "cluster_draw_multiplicity\ttarget_count\turl\tfilename",
        )
        for chunk_index in sort!(collect(keys(by_chunk)))
            chunk = chunk_lookup[chunk_index]
            chunk_records = by_chunk[chunk_index]
            sort!(chunk_records; by=record -> (record.chunk_offset, record.observation_index))
            target_path = joinpath(
                target_directory,
                "chunk_" * lpad(string(chunk_index), 5, '0') * ".tsv",
            )
            open(target_path, "w") do target_output
                for record in chunk_records
                    println(
                        target_output,
                        join(
                            (
                                record.observation_index,
                                record.global_index,
                                record.chunk_index,
                                record.chunk_first_index,
                                record.chunk_offset,
                                record.cluster_draw_id,
                                record.within_cluster_index,
                            ),
                            '\t',
                        ),
                    )
                end
            end
            multiplicity = length(unique(
                record.cluster_draw_id for record in chunk_records if
                record.cluster_draw_id >= 0
            ))
            multiplicity == 0 && (multiplicity = 1)
            println(
                output,
                join(
                    (
                        chunk.index,
                        chunk.first_index,
                        chunk.record_count,
                        chunk.compressed_bytes,
                        multiplicity,
                        length(chunk_records),
                        chunk.url,
                        chunk.filename,
                    ),
                    '\t',
                ),
            )
        end
    end

    open(joinpath(output_directory, "sampling_design.toml"), "w") do output
        TOML.print(output, design_metadata; sorted=true)
    end
    println(
        "ICARM_SAMPLE_PLAN_COMPLETE observations=",
        length(records),
        " selected_chunks=",
        length(by_chunk),
        " output=",
        output_directory,
    )
end

function main(args=ARGS)
    length(args) in (5, 6) || error(
        "usage: prepare_icarm_sample.jl CHUNKS.tsv OUTPUT_DIR " *
        "srs SAMPLE_SIZE SEED | cluster CLUSTERS DRAWS_PER_CLUSTER SEED",
    )
    chunks_path, output_directory, design = args[1:3]
    chunks = read_chunks(chunks_path)
    population_size = sum(chunk.record_count for chunk in chunks)

    if design == "srs"
        length(args) == 5 || error("srs requires SAMPLE_SIZE and SEED")
        sample_size = parse(Int, args[4])
        seed = parse(Int, args[5])
        rng = MersenneTwister(seed)
        global_indices = floyd_sample(rng, population_size, sample_size)
        records = NamedTuple[]
        for (observation_index, global_index) in enumerate(global_indices)
            chunk = locate_chunk(chunks, global_index)
            push!(records, (
                observation_index=observation_index,
                global_index=global_index,
                chunk_index=chunk.index,
                chunk_first_index=chunk.first_index,
                chunk_offset=global_index - chunk.first_index,
                cluster_draw_id=-1,
                within_cluster_index=-1,
            ))
        end
        metadata = Dict(
            "design" => "simple random sample without replacement",
            "population_size" => population_size,
            "sample_size" => sample_size,
            "seed" => seed,
            "rng" => "Julia Random.MersenneTwister",
            "julia_version" => string(VERSION),
            "selection_algorithm" => "Floyd exact integer sampling without replacement",
            "common_selection_probability" => sample_size / population_size,
            "common_design_weight" => population_size / sample_size,
        )
        write_outputs(output_directory, chunks, records, metadata)
    elseif design == "cluster"
        length(args) == 6 || error(
            "cluster requires CLUSTER_DRAWS, DRAWS_PER_CLUSTER, and SEED",
        )
        cluster_draws = parse(Int, args[4])
        draws_per_cluster = parse(Int, args[5])
        seed = parse(Int, args[6])
        cluster_draws > 0 || error("cluster draw count must be positive")
        draws_per_cluster > 0 || error("draws per cluster must be positive")
        rng = MersenneTwister(seed)
        records = NamedTuple[]
        observation_index = 0
        for cluster_draw_id in 1:cluster_draws
            chunk_probe = rand(rng, Int64(0):population_size-1)
            chunk = locate_chunk(chunks, chunk_probe)
            offsets = floyd_sample(rng, chunk.record_count, draws_per_cluster)
            for (within_cluster_index, offset) in enumerate(offsets)
                observation_index += 1
                push!(records, (
                    observation_index=observation_index,
                    global_index=chunk.first_index + offset,
                    chunk_index=chunk.index,
                    chunk_first_index=chunk.first_index,
                    chunk_offset=offset,
                    cluster_draw_id=cluster_draw_id,
                    within_cluster_index=within_cluster_index,
                ))
            end
        end
        metadata = Dict(
            "design" => "PPS chunk sampling with replacement; uniform offsets without replacement within each draw",
            "population_size" => population_size,
            "sample_size" => length(records),
            "cluster_draw_count" => cluster_draws,
            "draws_per_cluster" => draws_per_cluster,
            "seed" => seed,
            "rng" => "Julia Random.MersenneTwister",
            "julia_version" => string(VERSION),
            "selection_algorithm" => "uniform global probe selects PPS chunk; Floyd samples distinct within-chunk offsets",
            "common_selection_probability" => 1 / population_size,
            "common_design_weight" => Float64(population_size),
        )
        write_outputs(output_directory, chunks, records, metadata)
    else
        error("design must be srs or cluster")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
