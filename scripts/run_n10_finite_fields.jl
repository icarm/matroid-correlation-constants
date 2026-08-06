"""
Run the documented n=10 finite-field experiment suite for one rank.

Command line:

```text
julia --project=. scripts/run_n10_finite_fields.jl DATABASE RANK [TARGET_PER_SEED]
```

Ranks 4 and 5 are supported. Random ensembles use five deterministic seeds
and pool `TARGET_PER_SEED` accepted spanning configurations per seed. Rank 4
also includes the exhaustive GF(2) projective-subset population.
"""

include(joinpath(@__DIR__, "sample_finite_fields.jl"))

"""Return the prime fields and modes included in the requested rank suite."""
function experiment_cells(rank::Int)
    rank in (4, 5) || throw(ArgumentError("rank must be 4 or 5"))
    cells = Tuple{Int,String}[]
    rank == 4 && push!(cells, (2, "exhaustive"))
    for q in (2, 3, 5, 7)
        !(rank == 4 && q == 2) && push!(cells, (q, "random"))
        push!(cells, (q, "replacement"))
    end
    return cells
end

"""Stable seed for one rank, field, mode, and one-based replicate."""
function experiment_seed(rank::Int, q::Int, mode::AbstractString, replicate::Int)
    mode_code = mode == "replacement" ? 70 : 30
    return 202600000 + 10_000 * rank + 100 * q + mode_code + replicate
end

"""Execute one rank suite, reusing the already-loaded Julia environment."""
function run_suite(database_path::AbstractString, rank::Int, target_per_seed::Int)
    target_per_seed > 0 || throw(ArgumentError("TARGET_PER_SEED must be positive"))
    for (q, mode) in experiment_cells(rank)
        if mode == "exhaustive"
            run_id = "n10_r$(rank)_q$(q)_exhaustive"
            main(String[
                database_path,
                string(q),
                "0",
                "0",
                mode,
                run_id,
                "10",
                string(rank),
            ])
            continue
        end
        for replicate in 1:5
            seed = experiment_seed(rank, q, mode, replicate)
            run_id = "n10_r$(rank)_q$(q)_$(mode)_rep$(replicate)"
            main(String[
                database_path,
                string(q),
                string(target_per_seed),
                string(seed),
                mode,
                run_id,
                "10",
                string(rank),
            ])
        end
    end
end

function suite_main(args=ARGS)
    length(args) in (2, 3) || throw(
        ArgumentError("usage: run_n10_finite_fields.jl DATABASE RANK [TARGET_PER_SEED]"),
    )
    database_path = args[1]
    rank = parse(Int, args[2])
    target_per_seed = length(args) == 3 ? parse(Int, args[3]) : 20_000
    run_suite(database_path, rank, target_per_seed)
end

if abspath(PROGRAM_FILE) == @__FILE__
    suite_main()
end
