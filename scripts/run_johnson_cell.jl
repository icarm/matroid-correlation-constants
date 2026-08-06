"""
Run one Johnson-graph sparse-paving activity cell with deterministic seeds.

Command line:

```text
julia --project=. scripts/run_johnson_cell.jl \
    DATABASE N RANK ACTIVITY [TARGET_PER_SEED] [REPLICATES]
```

The defaults are 5,000 independent labeled stable-set draws for each of five
seeds. Giving each activity cell its own database permits safe process-level
parallelism; merge the completed cell databases with
`merge_experiment_databases.jl`.
"""

include(joinpath(@__DIR__, "sample_sparse_paving_johnson.jl"))

"""Return a stable seed from the experiment coordinates and activity."""
function johnson_cell_seed(n::Int, rank::Int, activity::Real, replicate::Int)
    activity_code = round(Int, 1_000_000activity)
    return 303_000_000 + 1_000_000n + 10_000rank + activity_code + replicate
end

"""Return a filesystem- and run-id-safe fixed-width activity token."""
activity_token(activity::Real) = lpad(string(round(Int, 1_000activity)), 4, '0')

"""Collect every replicate belonging to one fixed activity value."""
function run_cell(database_path, n, rank, activity, target_per_seed, replicates)
    1 <= rank <= fld(n, 2) || throw(
        ArgumentError("require 1 <= rank <= floor(n/2)"),
    )
    isfinite(activity) && 0 <= activity <= 1 || throw(
        ArgumentError("ACTIVITY must lie in [0,1]"),
    )
    target_per_seed > 0 || throw(ArgumentError("TARGET_PER_SEED must be positive"))
    replicates > 0 || throw(ArgumentError("REPLICATES must be positive"))
    token = activity_token(activity)
    for replicate in 1:replicates
        seed = johnson_cell_seed(n, rank, activity, replicate)
        run_id = "n$(n)_r$(rank)_johnson_p$(token)_rep$(replicate)"
        main(String[
            database_path,
            string(n),
            string(rank),
            string(activity),
            string(target_per_seed),
            string(seed),
            run_id,
        ])
    end
    return database_path
end

function cell_main(args=ARGS)
    length(args) in 4:6 || throw(
        ArgumentError(
            "usage: run_johnson_cell.jl DATABASE N RANK ACTIVITY " *
            "[TARGET_PER_SEED] [REPLICATES]",
        ),
    )
    database_path = args[1]
    n = parse(Int, args[2])
    rank = parse(Int, args[3])
    activity = parse(Float64, args[4])
    target_per_seed = length(args) >= 5 ? parse(Int, args[5]) : 5_000
    replicates = length(args) >= 6 ? parse(Int, args[6]) : 5
    return run_cell(
        database_path,
        n,
        rank,
        activity,
        target_per_seed,
        replicates,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    cell_main()
end
