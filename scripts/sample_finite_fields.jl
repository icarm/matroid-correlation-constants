"""
Collect exhaustive or random projective-point finite-field ensembles.

Command line:

```text
julia --project=. scripts/sample_finite_fields.jl \
    DATABASE Q TARGET SEED MODE RUN_ID [N] [RANK]
```

`MODE` is `random`, `replacement`, or `exhaustive`. `random` draws a uniform
subset of distinct projective points. `replacement` draws an ordered sequence
of independent projective points and therefore permits parallel elements but
not loops. Both random modes accept exactly `TARGET` spanning configurations
after rank-deficient draws are rejected. Exhaustive mode treats a positive
target as an optional accepted-record limit. Every accepted configuration is
encoded in polyDB reverse-lex order before compact statistics are stored. By
matroid duality, experiments are restricted to `RANK <= floor(N/2)`.
"""

using Oscar
using DBInterface
using Random

include(joinpath(@__DIR__, "..", "src", "CorrelationRatiosDistributions.jl"))
using .CorrelationRatiosDistributions

"""Return projective points at the given one-based indices."""
selected_columns(points, indices) = [points[index] for index in indices]

"""Enumerate all `n`-point subsets when the projective space is small enough."""
function collect_exhaustive!(
    writer,
    run_id,
    points,
    q,
    n,
    r,
    accepted_limit,
)
    accepted = 0
    rejected = 0
    full = (UInt64(1) << length(points)) - UInt64(1)
    for subset in UInt64(0):full
        count_ones(subset) == n || continue
        indices =
            [index for index in 1:length(points) if ((subset >> (index - 1)) & 1) == 1]
        columns = selected_columns(points, indices)
        if matrix_rank_mod_p(columns, q) != r
            rejected += 1
            continue
        end
        accepted += 1
        encoding = encoding_from_columns(columns, q, r)
        stats = matroid_statistics(encoding, n, r)
        source_id =
            "pg$(q)_subset_" *
            lpad(string(subset; base=16), cld(length(points), 4), '0')
        insert_matroid!(
            writer;
            run_id=run_id,
            observation_index=accepted,
            source_id=source_id,
            field_size=q,
            representation=representation_string(columns),
            stats=stats,
        )
        accepted % 250 == 0 && println("GF(", q, ") exhaustive: accepted ", accepted)
        accepted_limit > 0 && accepted >= accepted_limit && break
    end
    return accepted, rejected
end

"""
Draw projective configurations uniformly under the requested replacement
model and condition on spanning rank `r`.

Without replacement, each `n`-subset of `PG(r-1,q)` has equal probability.
With replacement, the ordered columns are independent uniform projective
points; repeated points produce parallel elements. These are distributions on
representations, not uniform distributions on matroid isomorphism classes.
"""
function collect_random!(
    writer,
    run_id,
    points,
    q,
    n,
    r,
    target,
    seed,
    replacement,
)
    target > 0 || throw(ArgumentError("random mode requires a positive target"))
    rng = MersenneTwister(seed)
    accepted = 0
    rejected = 0
    draws = 0
    while accepted < target
        draws += 1
        indices = sample_projective_indices(
            rng,
            length(points),
            n;
            replacement=replacement,
        )
        columns = selected_columns(points, indices)
        if matrix_rank_mod_p(columns, q) != r
            rejected += 1
            continue
        end
        accepted += 1
        encoding = encoding_from_columns(columns, q, r)
        stats = matroid_statistics(encoding, n, r)
        source_prefix =
            replacement ? "pg$(q)_replacement_seed$(seed)_draw_" :
            "pg$(q)_seed$(seed)_draw_"
        source_id = source_prefix * lpad(string(draws), 8, '0')
        insert_matroid!(
            writer;
            run_id=run_id,
            observation_index=accepted,
            source_id=source_id,
            field_size=q,
            representation=representation_string(columns),
            stats=stats,
        )
        accepted % 5000 == 0 && println(
            "GF(",
            q,
            ") ",
            replacement ? "replacement" : "random",
            ": accepted ",
            accepted,
        )
    end
    return accepted, rejected
end

"""Parse the finite-field CLI, register run metadata, and collect one ensemble."""
function main(args=ARGS)
    database_path =
        length(args) >= 1 ? args[1] : joinpath(@__DIR__, "..", "data", "n8_r4_compact", "results.sqlite")
    q = length(args) >= 2 ? parse(Int, args[2]) : 3
    target = length(args) >= 3 ? parse(Int, args[3]) : 100
    seed = length(args) >= 4 ? parse(Int, args[4]) : 20260730 + q
    mode = length(args) >= 5 ? args[5] : (q == 2 ? "exhaustive" : "random")
    run_id =
        length(args) >= 6 ? args[6] :
        (
            mode == "exhaustive" ? "pg_q$(q)_exhaustive" :
            mode == "replacement" ? "pg_q$(q)_replacement" :
            "pg_q$(q)_random"
        )

    n = length(args) >= 7 ? parse(Int, args[7]) : 8
    r = length(args) >= 8 ? parse(Int, args[8]) : 4
    0 <= r <= fld(n, 2) || throw(
        ArgumentError("by duality, require 0 <= rank <= floor(n/2) = $(fld(n, 2))"),
    )
    points = projective_points(r, q)
    length(points) >= n ||
        throw(ArgumentError("PG($(r - 1),$q) has fewer than $n points"))

    database = init_database(database_path)
    accepted = Ref(0)
    rejected = Ref(0)
    with_transaction(database) do
        begin_run!(
            database;
            run_id=run_id,
            source="finite_field",
            ensemble=mode == "exhaustive" ?
                     "projective_subsets_exhaustive" :
                     mode == "replacement" ?
                     "projective_points_with_replacement_random" :
                     "projective_subsets_random",
            n=n,
            r=r,
            field_size=q,
            target_count=mode == "exhaustive" ? missing : target,
            seed=mode == "exhaustive" ? missing : seed,
            conditioning=mode == "replacement" ?
                         "$(n) independent nonzero projective points with replacement, spanning rank $(r)" :
                         "$(n) distinct projective points spanning rank $(r)",
            generator=mode == "replacement" ?
                      "ordered iid points of PG($(r - 1),$q), normalized by first nonzero coordinate; parallel elements allowed" :
                      "uniform subsets of PG($(r - 1),$q), normalized by first nonzero coordinate",
            oscar_version=string(Base.pkgversion(Oscar)),
        )
        writer = prepare_writer(database)
        if mode == "exhaustive"
            accepted[], rejected[] = collect_exhaustive!(
                writer,
                run_id,
                points,
                q,
                n,
                r,
                target,
            )
        elseif mode == "random" || mode == "replacement"
            accepted[], rejected[] = collect_random!(
                writer,
                run_id,
                points,
                q,
                n,
                r,
                target,
                seed,
                mode == "replacement",
            )
        else
            throw(
                ArgumentError("mode must be 'exhaustive', 'random', or 'replacement'"),
            )
        end
        close_writer!(writer)
        finish_run!(
            database,
            run_id;
            accepted_count=accepted[],
            rejected_count=rejected[],
        )
    end
    DBInterface.close!(database)

    println(
        "FINITE_FIELD_COMPLETE run_id=",
        run_id,
        " accepted=",
        accepted[],
        " rejected=",
        rejected[],
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
