# Profiling driver for the P_wjTj demo.
#
# Usage (from the demo root):
#     julia src/profile.jl
#
# It first runs a toy instance WITHOUT profiling to warm up / compile the Julia
# code, then profiles the 75-job instance with PProf (served in the browser at
# http://localhost:<webport>).

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Profile, PProf
using PwjTjSolverDemo

const WEBPORT = 58599

const TOY_INSTANCE = normpath(joinpath(@__DIR__, "..", "instances", "toy", "wt10-2m-1.txt"))
const INSTANCE_75 = normpath(joinpath(@__DIR__, "..", "instances", "WT75-2m", "wt75-2m-1.txt"))

function run_profile()
    Profile.init(; n=10^10, delay=0.00005)

    # --- Warm-up: run a toy instance without profiling so Julia compiles all
    #     the code paths before we measure anything. ---
    println(">>> Warm-up run on toy instance (no profiling): $TOY_INSTANCE")
    PwjTjSolverDemo.main([TOY_INSTANCE])

    # --- Profiling with PProf, served in the browser. ---
    Profile.clear()
    println(">>> Profiling 75-job instance with PProf")
    @profile PwjTjSolverDemo.main([INSTANCE_75])
    pprof(; webport=WEBPORT)

    println("PProf server running at http://localhost:$WEBPORT")
    println("Press Enter to stop the server and exit...")
    readline()

    return nothing
end

run_profile()
