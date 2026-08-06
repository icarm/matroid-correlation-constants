"""
Plot alpha_1(U_{r,n}) as the rank varies for several fixed ground-set sizes.

Usage:

    julia --project=. scripts/make_uniform_alpha_rank_plot.jl
"""

using CairoMakie

const PROJECT_DIRECTORY = normpath(joinpath(@__DIR__, ".."))
const FIGURE_PATH =
    joinpath(PROJECT_DIRECTORY, "figures", "uniform_alpha1_vs_rank.png")

uniform_alpha_one(n::Int, r::Int) =
    ((r - 1) * (n - r - 1)) // (r * (n - r))

function main()
    ground_set_sizes = (8, 15, 30, 60)
    figure = Figure(size=(1080, 700))
    Label(
        figure[0, 1:2],
        "Uniform matroids: α₁ as rank varies at fixed n";
        fontsize=24,
        font=:bold,
    )

    for (index, n) in enumerate(ground_set_sizes)
        row = (index - 1) ÷ 2 + 1
        column = (index - 1) % 2 + 1
        ranks = collect(1:n-1)
        exact_values = uniform_alpha_one.(n, ranks)
        values = Float64.(exact_values)
        maximum_value = maximum(exact_values)
        maximizing_indices = findall(==(maximum_value), exact_values)
        maximizing_ranks = ranks[maximizing_indices]

        axis = Axis(
            figure[row, column];
            title="n = $n",
            xlabel="rank r",
            ylabel="α₁(Uᵣ,ₙ)",
            limits=(nothing, (0, 1)),
        )
        vlines!(axis, [n / 2]; color=(:gray, 0.65), linestyle=:dash)
        lines!(axis, ranks, values; color=:steelblue, linewidth=2.5)
        scatter!(axis, ranks, values; color=:steelblue, markersize=7)
        scatter!(
            axis,
            maximizing_ranks,
            fill(Float64(maximum_value), length(maximizing_ranks));
            color=:crimson,
            markersize=13,
        )

        rank_text = length(maximizing_ranks) == 1 ?
                    "r = $(only(maximizing_ranks))" :
                    "r = $(first(maximizing_ranks)), $(last(maximizing_ranks))"
        fraction_text = denominator(maximum_value) == 1 ?
                        string(numerator(maximum_value)) :
                        "$(numerator(maximum_value))/$(denominator(maximum_value))"
        text!(
            axis,
            0.04,
            0.92;
            text="maximum at $rank_text\nα₁ = $fraction_text",
            space=:relative,
            align=(:left, :top),
            fontsize=14,
        )
    end

    mkpath(dirname(FIGURE_PATH))
    save(FIGURE_PATH, figure; px_per_unit=2)
    @info "uniform alpha_1 rank plot complete" figure=FIGURE_PATH
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
