# Random tests: compares the compact MIP (CPLEX) with the VRPSolver on random CRSP instances.
#
# Usage (from the CRSP folder):
#   julia src/test_random.jl [deadline HH:MM (default 07:00)] [seed (default: random)]
#
# Each iteration generates a random CVRP instance with 25 vertices in the CVRPLIB format of the
# A set (integer coordinates in [1,100], capacity 100), draws the CRSP parameters (-p, -k, -a) and
# solves it with both methods. When both claim optimality but the values differ, or when an error
# happens, the instance and a report are saved in the CRSP folder. The solvers' output goes to
# out/test_random.log; a summary is printed every 10 instances.

if haskey(ENV, "JULIA_LOAD_PATH")
    println("Please unset the JULIA_LOAD_PATH environment variable.")
    exit()
end
if !haskey(ENV, "BAPCOD_RCSP_LIB")
    println(
        "Please set the environment variable BAPCOD_RCSP_LIB to the complete file path of the BaPCod/RCSP library.",
    )
    exit(1)
end

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using CRSPSolverDemo, VrpSolver, JuMP, Dates, Random, Printf
const C = CRSPSolverDemo

const DEMO_DIR = normpath(joinpath(@__DIR__, ".."))
const NB_VERTICES = 25 # including the root
const CAPACITY = 100
const STEINER_PCTS = [0.0, 10.0, 25.0, 40.0]
const STAR_SIZES = [2, 3, 4]
const STAR_FACTORS = [0.3, 0.5, 0.8]

function deadline_from(arg::String)
    h, m = parse.(Int, split(arg, ":"))
    dl = DateTime(today()) + Hour(h) + Minute(m)
    return (dl <= now()) ? dl + Day(1) : dl
end

# random instance in the CVRPLIB format of the A set
function write_instance(path::String, name::String, rng)
    open(path, "w") do f
        println(f, "NAME : $name")
        println(f, "COMMENT : (random CRSP test instance)")
        println(f, "TYPE : CVRP")
        println(f, "DIMENSION : $NB_VERTICES")
        println(f, "EDGE_WEIGHT_TYPE : EUC_2D ")
        println(f, "CAPACITY : $CAPACITY")
        println(f, "NODE_COORD_SECTION ")
        for i in 1:NB_VERTICES
            println(f, " $i $(rand(rng, 1:100)) $(rand(rng, 1:100))")
        end
        println(f, "DEMAND_SECTION ")
        for i in 1:NB_VERTICES
            println(f, "$i $(i == 1 ? 0 : rand(rng, 1:24)) ")
        end
        println(f, "DEPOT_SECTION ")
        println(f, " 1  ")
        println(f, " -1  ")
        println(f, "EOF ")
    end
end

mutable struct Stats
    total::Int
    agree::Int # both optimal with the same value
    diverge::Int # both optimal with different values
    not_both_optimal::Int
    errors::Int
    time_compact::Float64
    time_vrpsolver::Float64
end

function print_stats(st::Stats, deadline::DateTime)
    @printf("[%s] instances: %d | agree: %d | DIVERGE: %d | not both optimal: %d | ERRORS: %d | avg time compact: %.2fs, vrpsolver: %.2fs | deadline %s\n",
        Dates.format(now(), "HH:MM:SS"), st.total, st.agree, st.diverge, st.not_both_optimal, st.errors,
        st.time_compact / max(st.total, 1), st.time_vrpsolver / max(st.total, 1), deadline)
    flush(stdout)
end

# save the instance and a report in the CRSP folder
function save_case(kind::String, inst_path::String, name::String, args::Vector{String}, report::String)
    dest = joinpath(DEMO_DIR, "$(kind)_$(name).vrp")
    cp(inst_path, dest; force=true)
    open(joinpath(DEMO_DIR, "$(kind)_$(name).txt"), "w") do f
        println(f, "Reproduce with: julia src/run.jl $(kind)_$(name).vrp $(join(args, " "))")
        println(f, "             or: julia src/run.jl $(kind)_$(name).vrp $(join(args, " ")) -m")
        println(f, report)
    end
    println("  >>> $(uppercase(kind)) saved in $dest")
    flush(stdout)
end

function solution_str(sol)
    sol === nothing && return "  (none)\n"
    return join(["Ring-star #$k: " *
                 join([haskey(rs.stars, i) ? "$i{$(join(rs.stars[i], ","))}" : "$i" for i in rs.ring], " ") * "\n"
                 for (k, rs) in enumerate(sol.ringstars)])
end

function run_instance(inst_path::String, name::String, args::Vector{String})
    app = C.parse_commandline(vcat([inst_path], args), joinpath(DEMO_DIR, "src"))
    data = C.readCRSPData(app)

    t = time()
    (st_c, found_c, sol_c) = C.solve_compact_model(data, app)
    found_c && C.checksolution(data, sol_c)
    time_c = time() - t

    t = time()
    (model, x, z) = C.build_model(data, app)
    optimizer = VrpOptimizer(model, app["cfg"], name)
    set_cutoff!(optimizer, app["ub"])
    (st_v, found_v) = optimize!(optimizer)
    sol_v = found_v ? C.getsolution(data, optimizer, x, z, get_objective_value(optimizer), app) : nothing
    found_v && C.checksolution(data, sol_v)
    time_v = time() - t

    return (st_c, sol_c, time_c, st_v, sol_v, time_v)
end

function main_test(deadline::DateTime, seed::Int)
    println("Random CRSP tests (seed $seed) until $deadline. Solver output in out/test_random.log")
    rng = MersenneTwister(seed)
    st = Stats(0, 0, 0, 0, 0, 0.0, 0.0)
    log = open(joinpath(DEMO_DIR, "out", "test_random.log"), "a")
    tmpdir = mktempdir()
    while now() < deadline
        name = "R$(seed)-$(st.total + 1)"
        inst_path = joinpath(tmpdir, "$name.vrp")
        write_instance(inst_path, name, rng)
        args = ["-p", string(rand(rng, STEINER_PCTS)), "-k", string(rand(rng, STAR_SIZES)),
            "-a", string(rand(rng, STAR_FACTORS))]
        st.total += 1
        try
            res = redirect_stdout(log) do
                println("\n########## $name $(join(args, " "))")
                r = run_instance(inst_path, name, args)
                Libc.flush_cstdio() # flush the C output (CPLEX/BaPCod) into the log
                r
            end
            (st_c, sol_c, time_c, st_v, sol_v, time_v) = res
            st.time_compact += time_c
            st.time_vrpsolver += time_v
            if st_c == :Optimal && st_v == :Optimal
                if (sol_c === nothing) != (sol_v === nothing) ||
                   (sol_c !== nothing && abs(sol_c.cost - sol_v.cost) > 0.5)
                    st.diverge += 1
                    save_case("divergence", inst_path, name, args,
                        "compact: $(sol_c === nothing ? "infeasible" : sol_c.cost)\n$(solution_str(sol_c))" *
                        "vrpsolver: $(sol_v === nothing ? "infeasible" : sol_v.cost)\n$(solution_str(sol_v))")
                else
                    st.agree += 1
                end
            else
                st.not_both_optimal += 1
                println("  $name: not both optimal (compact: $st_c, vrpsolver: $st_v)")
            end
        catch err
            Libc.flush_cstdio()
            st.errors += 1
            msg = sprint(showerror, err, catch_backtrace())
            save_case("error", inst_path, name, args, msg)
            println("  $name: ERROR $(first(split(msg, '\n')))")
        end
        flush(log)
        (st.total % 10 == 0) && print_stats(st, deadline)
    end
    close(log)
    println("Deadline reached.")
    print_stats(st, deadline)
end

deadline = deadline_from(length(ARGS) >= 1 ? ARGS[1] : "07:00")
seed = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : rand(1:10^6)
main_test(deadline, seed)
