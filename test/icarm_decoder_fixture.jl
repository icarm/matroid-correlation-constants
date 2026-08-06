"""
Exercise the standalone ICARM target decoder on a four-record synthetic
`.sz.xz` fixture. The fixture deliberately uses three-bit delta positions so
the test covers the generic bit reader rather than only the byte-aligned
rank-4 and rank-5 files used by the experiment.
"""

using Test

project_root = normpath(joinpath(@__DIR__, ".."))
source = joinpath(project_root, "tools", "icarm_decode_targets.c")
decoder = joinpath(project_root, "build", "icarm_decode_targets")
mkpath(dirname(decoder))
run(`gcc -O3 -Wall -Wextra -Wpedantic $source -o $decoder`)

mktempdir() do directory
    raw_path = joinpath(directory, "fixture.sz")
    compressed_path = joinpath(directory, "fixture.sz.xz")
    target_path = joinpath(directory, "targets.tsv")
    output_path = joinpath(directory, "decoded.tsv")

    # line_len=6, count=4, first line ******. The packed three-bit deltas are
    # (3,6), (0,5,6), and (6), where 6 is the sentinel.
    open(raw_path, "w") do output
        write(output, UInt32(6))
        write(output, UInt64(4))
        write(output, codeunits("******"))
        write(output, UInt8[0x78, 0x5d, 0x80])
    end
    open(compressed_path, "w") do output
        run(pipeline(`xz -zc $raw_path`; stdout=output))
    end
    open(target_path, "w") do output
        println(output, "1\t100\t0\t100\t0\t-1\t-1")
        println(output, "2\t102\t0\t100\t2\t-1\t-1")
        println(output, "3\t103\t0\t100\t3\t-1\t-1")
    end
    run(
        pipeline(
            `xz -dc $compressed_path`,
            `$decoder 6 4 $target_path $output_path`,
        ),
    )
    @test readlines(output_path) == [
        "1\t100\t0\t100\t0\t-1\t-1\t3f",
        "2\t102\t0\t100\t2\t-1\t-1\t16",
        "3\t103\t0\t100\t3\t-1\t-1\t16",
    ]
end
