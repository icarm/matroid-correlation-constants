"""
Run one finite-field sampling cell with deterministic replicate seeds.

Command line:

```text
julia --project=. scripts/run_finite_field_cell.jl \
    DATABASE N RANK Q MODE [TARGET_PER_SEED] [REPLICATES]
```

`MODE` is `random` (distinct projective points) or `replacement`
(independent projective points, allowing parallel elements). The default is
20,000 accepted spanning configurations for each of five seeds. Giving each
field/mode cell its own database permits safe process-level parallelism; use
`merge_experiment_databases.jl` afterward.
"""

include(joinpath(@__DIR__, "sample_finite_fields.jl"))

"""Return a stable seed determined by all experiment coordinates."""
function cell_seed(
    n::Int,
    rank::Int,
    q::Int,
    mode::AbstractString,
    replicate::Int,
)
    mode_code = mode == "replacement" ? 70 : 30
    return 202_600_000 + 1_000_000n + 10_000rank + 100q + mode_code + replicate
end

"""Run all deterministic replicates for one field and sampling model."""
function run_cell(
    database_path::AbstractString,
    n::Int,
    rank::Int,
    q::Int,
    mode::AbstractString,
    target_per_seed::Int,
    replicates::Int,
)
    0 < rank <= fld(n, 2) || throw(
        ArgumentError("require 0 < rank <= floor(n/2)"),
    )
    q in (2, 3, 5, 7) || throw(ArgumentError("supported fields are 2, 3, 5, and 7"))
    mode in ("random", "replacement") || throw(
        ArgumentError("MODE must be 'random' or 'replacement'"),
    )
    target_per_seed > 0 || throw(ArgumentError("TARGET_PER_SEED must be positive"))
    replicates > 0 || throw(ArgumentError("REPLICATES must be positive"))

    for replicate in 1:replicates
        seed = cell_seed(n, rank, q, mode, replicate)
        run_id = "n$(n)_r$(rank)_q$(q)_$(mode)_rep$(replicate)"
        main(String[
            database_path,
            string(q),
            string(target_per_seed),
            string(seed),
            mode,
            run_id,
            string(n),
            string(rank),
        ])
    end
    return database_path
end

function cell_main(args=ARGS)
    length(args) in 5:7 || throw(
        ArgumentError(
            "usage: run_finite_field_cell.jl DATABASE N RANK Q MODE " *
            "[TARGET_PER_SEED] [REPLICATES]",
        ),
    )
    database_path = args[1]
    n = parse(Int, args[2])
    rank = parse(Int, args[3])
    q = parse(Int, args[4])
    mode = args[5]
    target_per_seed = length(args) >= 6 ? parse(Int, args[6]) : 20_000
    replicates = length(args) >= 7 ? parse(Int, args[7]) : 5
    return run_cell(
        database_path,
        n,
        rank,
        q,
        mode,
        target_per_seed,
        replicates,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    cell_main()
end
