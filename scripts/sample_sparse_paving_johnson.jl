"""
Sample labeled sparse paving matroids from independent sets of a Johnson graph.

Command line:

```text
julia --project=. scripts/sample_sparse_paving_johnson.jl \
    DATABASE N RANK ACTIVITY TARGET SEED RUN_ID
```

For every observation, the vertices of `J(N,RANK)` receive a fresh uniform
random order. During one pass, an available vertex is activated independently
with probability `ACTIVITY`; an activated vertex is selected and blocks all
of its Johnson neighbors. The selected stable set becomes the collection of
circuit-hyperplanes, and every other rank-sized subset is a basis. Thus every
output is sparse paving. Draws are independent labeled matroids from this
specified random-greedy law, not uniform independent sets and not uniform
matroid isomorphism classes.
"""

using DBInterface
using Random

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

"""Collect one reproducible Johnson random-greedy run into `writer`."""
function collect_johnson!(writer, run_id, n, rank, activity, target, seed)
    target > 0 || throw(ArgumentError("TARGET must be positive"))
    sampler = JohnsonGraphSampler(n, rank)
    rng = MersenneTwister(seed)
    stable_size_sum = 0
    stable_size_minimum = typemax(Int)
    stable_size_maximum = 0
    for observation in 1:target
        independent_set = sample_johnson_independent_set(rng, sampler, activity)
        encoding = johnson_sparse_paving_encoding(sampler, independent_set)
        statistics = matroid_statistics(encoding, n, rank)
        statistics.sparse_paving || error("Johnson construction was not sparse paving")
        statistics.circuit_hyperplanes == length(independent_set) || error(
            "circuit-hyperplane count disagrees with the selected Johnson set",
        )
        stable_size = length(independent_set)
        stable_size_sum += stable_size
        stable_size_minimum = min(stable_size_minimum, stable_size)
        stable_size_maximum = max(stable_size_maximum, stable_size)
        source_id = string(
            "J", n, "_", rank,
            "_p", lpad(round(Int, 1_000activity), 4, '0'),
            "_s", lpad(mod(seed, 1_000), 3, '0'),
            "_h", stable_size,
            "_", lpad(observation, 8, '0'),
        )
        insert_matroid!(
            writer;
            run_id=run_id,
            observation_index=observation,
            source_id=source_id,
            stats=statistics,
        )
        observation % 5_000 == 0 && println(
            "JOHNSON_PROGRESS run_id=", run_id,
            " accepted=", observation,
            " mean_circuit_hyperplanes=", round(stable_size_sum / observation; digits=3),
        )
    end
    return (
        accepted=target,
        minimum=stable_size_minimum,
        maximum=stable_size_maximum,
        mean=stable_size_sum / target,
    )
end

"""Parse the CLI, record the exact sampling law, and collect one run."""
function main(args=ARGS)
    length(args) == 7 || throw(
        ArgumentError(
            "usage: sample_sparse_paving_johnson.jl " *
            "DATABASE N RANK ACTIVITY TARGET SEED RUN_ID",
        ),
    )
    database_path = args[1]
    n = parse(Int, args[2])
    rank = parse(Int, args[3])
    activity = parse(Float64, args[4])
    target = parse(Int, args[5])
    seed = parse(Int, args[6])
    run_id = args[7]
    1 <= rank <= fld(n, 2) || throw(
        ArgumentError("by duality, require 1 <= rank <= floor(n/2)"),
    )
    ensemble = johnson_greedy_ensemble(activity)

    database = init_database(database_path)
    result = Ref{Any}()
    with_transaction(database) do
        begin_run!(
            database;
            run_id=run_id,
            source="johnson_graph",
            ensemble=ensemble,
            n=n,
            r=rank,
            target_count=target,
            seed=seed,
            conditioning=string(
                "independent vertex set of J(", n, ",", rank,
                ") from one random-priority greedy pass with activation probability ",
                activity,
            ),
            generator=string(
                "fresh uniform vertex permutation per draw; each available vertex is ",
                "activated independently with probability ", activity,
                "; selected vertices block their Johnson neighbors; selected vertices ",
                "are circuit-hyperplanes",
            ),
        )
        writer = prepare_writer(database)
        try
            result[] = collect_johnson!(
                writer,
                run_id,
                n,
                rank,
                activity,
                target,
                seed,
            )
        finally
            close_writer!(writer)
        end
        finish_run!(
            database,
            run_id;
            accepted_count=result[].accepted,
            rejected_count=0,
        )
    end
    DBInterface.close!(database)
    println(
        "JOHNSON_COMPLETE run_id=", run_id,
        " accepted=", result[].accepted,
        " activity=", activity,
        " circuit_hyperplanes_min=", result[].minimum,
        " mean=", round(result[].mean; digits=4),
        " max=", result[].maximum,
    )
    return database_path
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
