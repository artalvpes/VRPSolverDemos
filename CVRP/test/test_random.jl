# Random tests on small CVRP instances: compares the demo model, executed with several configurations and
# with Ryan & Foster branching, with the optimum given by a set partitioning MIP over all enumerated
# routes, solved with CPLEX (test/set_partitioning.jl).
#
# Usage (from the CVRP folder):
#   julia test/test_random.jl [deadline HH:MM (default 07:00)] [seed (default: random)] [time limit per run in seconds (default 1800)]
#
# Each iteration generates a random instance with 40 vertices in the CVRPLIB format of the A set (integer
# coordinates in [1,100], demands in [5,15] and capacity Q in {20,25,30}, so that routes are short and
# can all be enumerated), with at most U = L + {1,2} routes (L = ceil(total demand / Q)). The set
# partitioning MIP is solved first and, as in the CRSP random tests, every VRPSolver execution uses the
# cutoff (upper bound) equal to its optimal value + 1 (+ RF_CUTOFF_OFFSET for the Ryan & Foster execution, so that its
# search tree is larger):
#  - the demo model with each configuration test/CVRP_*.cfg (except CVRP_RF.cfg), with the demo defaults;
#  - the demo model with test/CVRP_RF.cfg, Ryan & Foster branching enabled, and edge (x) and cluster
#    branching disabled, so that Ryan & Foster is the only branching.
#
# When an execution is incompatible with the set partitioning (optimal with another value, a solution
# better than the optimum, or a solution when the set partitioning is infeasible), or when an error
# happens, the instance and a report are saved in the out folder. The solvers' output goes to
# out/test_random.log, one line per instance goes to out/test_random.csv, and a summary is printed after
# each instance (for each kind of execution: agree/not optimal, average time, and in how many instances
# BaPCod branched; for the Ryan & Foster execution, also the average tree size when it branched). If BaPCod prints a warning in any of the executions, the tests stop after that
# instance with a summary of the warnings of each execution (also saved in out).

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

const DEMO_DIR = normpath(joinpath(@__DIR__, ".."))

# executions of the demo model: (label, configuration file); the last one uses Ryan & Foster branching
const RF_LABEL = "demo RF"
const RF_CUTOFF_OFFSET = 5 # cutoff of the Ryan & Foster execution = optimum + RF_CUTOFF_OFFSET
const CONFIG_RUNS = vcat(
    [("demo " * splitext(f)[1], joinpath(@__DIR__, f)) for f in sort(readdir(@__DIR__))
                                                           if startswith(f, "CVRP_") && endswith(f, ".cfg") && f != "CVRP_RF.cfg"],
    isfile(joinpath(@__DIR__, "CVRP_RF.cfg")) ? [(RF_LABEL, joinpath(@__DIR__, "CVRP_RF.cfg"))] : [],
)
const RUN_KINDS = first.(CONFIG_RUNS)
isempty(RUN_KINDS) && error("No configuration test/CVRP_*.cfg found")

using Pkg
Pkg.activate(DEMO_DIR)
# the local VrpSolver.jl (with Ryan & Foster branching enabled) and CPLEX for the set partitioning
haskey(Pkg.project().dependencies, "VrpSolver") || Pkg.develop(path=joinpath(homedir(), ".julia", "dev", "VrpSolver.jl"))
haskey(Pkg.project().dependencies, "CPLEX") || Pkg.add("CPLEX")

using CVRPSolverDemo, VrpSolver, JuMP, Dates, Random, Printf
const C = CVRPSolverDemo

include("set_partitioning.jl")

const NB_VERTICES = 40 # including the depot
const DEMANDS = 5:15
const CAPACITIES = [20, 25, 30] # at most 6 customers per route, so that all routes can be enumerated
const EXTRA_ROUTES = [1, 2] # U = L + extra

function deadline_from(arg::String)
    h, m = parse.(Int, split(arg, ":"))
    dl = DateTime(today()) + Hour(h) + Minute(m)
    return (dl <= now()) ? dl + Day(1) : dl
end

# random instance in the CVRPLIB format of the A set
function write_instance(path::String, name::String, Q::Int, rng)
    open(path, "w") do f
        println(f, "NAME : $name")
        println(f, "COMMENT : (random CVRP test instance)")
        println(f, "TYPE : CVRP")
        println(f, "DIMENSION : $NB_VERTICES")
        println(f, "EDGE_WEIGHT_TYPE : EUC_2D ")
        println(f, "CAPACITY : $Q")
        println(f, "NODE_COORD_SECTION ")
        for i in 1:NB_VERTICES
            println(f, " $i $(rand(rng, 1:100)) $(rand(rng, 1:100))")
        end
        println(f, "DEMAND_SECTION ")
        for i in 1:NB_VERTICES
            println(f, "$i $(i == 1 ? 0 : rand(rng, DEMANDS)) ")
        end
        println(f, "DEPOT_SECTION ")
        println(f, " 1  ")
        println(f, " -1  ")
        println(f, "EOF ")
    end
end

# copy of a configuration file with a time limit
function write_cfg(path::String, source::String, time_limit::Int)
    open(path, "w") do f
        write(f, read(source, String))
        println(f, "\nGlobalTimeLimit = $time_limit")
    end
end

mutable struct Stats
    total::Int
    diverge::Int # instances with incompatible values
    errors::Int
    sp_optimal::Int # instances where the set partitioning proved the optimum
    sp_infeasible::Int # instances where the set partitioning proved infeasibility
    no_reference::Int # instances where the set partitioning stopped without a proof
    time_sp::Float64
    columns_sp::Int
    agree::Dict{String,Int} # executions of each kind optimal with the result of the set partitioning
    not_optimal::Dict{String,Int} # executions of each kind that stopped without proving the optimum
    time::Dict{String,Float64} # total time of the executions of each kind
    runs::Dict{String,Int} # number of executions of each kind
    branched::Dict{String,Int} # number of executions of each kind with more than one node
    rf_branched_nodes::Int # total number of nodes of the Ryan & Foster executions that branched
end

Stats() = Stats(0, 0, 0, 0, 0, 0, 0.0, 0, (Dict(k => 0 for k in RUN_KINDS) for _ in 1:2)...,
    Dict(k => 0.0 for k in RUN_KINDS), (Dict(k => 0 for k in RUN_KINDS) for _ in 1:2)..., 0)

function print_stats(st::Stats, deadline::DateTime)
    nsp = max(st.total - st.errors, 1)
    runs = join(["$k $(st.agree[k])/$(st.not_optimal[k]) $(@sprintf("%.2f", st.time[k] / max(st.runs[k], 1)))s"
                 for k in RUN_KINDS], ", ")
    branching = join(["$k $(st.branched[k])/$(st.runs[k])" for k in RUN_KINDS], ", ")
    # average tree size of the Ryan & Foster executions that branched
    rf_tree = haskey(st.branched, RF_LABEL) ?
              " | $RF_LABEL avg tree size when branching: " *
        ((st.branched[RF_LABEL] > 0) ? @sprintf("%.1f nodes", st.rf_branched_nodes / st.branched[RF_LABEL]) : "-") : ""
    @printf("[%s] instances: %d | DIVERGE: %d | ERRORS: %d | set partitioning: optimal %d, infeasible %d, no reference %d, avg %.2fs, %d columns | VRPSolver (agree/not optimal avg time): %s | branching: %s%s%s\n",
        Dates.format(now(), "HH:MM:SS"), st.total, st.diverge, st.errors, st.sp_optimal, st.sp_infeasible,
        st.no_reference, st.time_sp / nsp, round(Int, st.columns_sp / nsp), runs, branching, rf_tree,
        (st.total % 10 == 0) ? " | deadline $deadline" : "")
    flush(stdout)
end

# counts the execution of the given kind and whether it branched
function count_run!(st::Stats, kind::String, nodes::Int)
    st.runs[kind] += 1
    if nodes > 1
        st.branched[kind] += 1
        (kind == RF_LABEL) && (st.rf_branched_nodes += nodes)
    end
end

# save the instance and a report in the out folder
function save_case(kind::String, inst_path::String, name::String, args::Vector{String}, report::String)
    dest = joinpath(DEMO_DIR, "out", "$(kind)_$(name).vrp")
    cp(inst_path, dest; force=true)
    open(joinpath(DEMO_DIR, "out", "$(kind)_$(name).txt"), "w") do f
        println(f, "Reproduce the demo model with: julia src/run.jl out/$(kind)_$(name).vrp $(join(args, " "))")
        println(f, "(the $RF_LABEL execution also uses -B 0, edge branching disabled, Ryan & Foster branching and cutoff optimum + $RF_CUTOFF_OFFSET)")
        println(f, report)
    end
    println("  >>> $(uppercase(kind)) saved in $dest")
    flush(stdout)
end

function solution_str(sol)
    sol === nothing && return "  (none)\n"
    return join(["Route #$k: $(join(r, " "))\n" for (k, r) in enumerate(sol.routes)])
end

# warnings printed by BaPCod (and by its RCSP solver), on stdout or stderr
is_bapcod_warning(line) = occursin(r"(bapcod|rcsp|meta-solver).*warning"i, line)

# runs f() with stdout and stderr (including the C output) captured; the output is appended to the
# log and its BaPCod warnings are stored in warnings[label], even if f() throws
function run_captured(f, label::String, name::String, log::IO, term::IO, warnings::Dict{String,Vector{String}};
    desc::String="the $label model")
    msg = "$name: running $desc"
    println(term, "[$(Dates.format(now(), "HH:MM:SS"))] $msg")
    flush(term)
    println(log, "---------- $msg")
    out_path = tempname()
    try
        return open(out_path, "w") do io
            redirect_stdout(io) do
                redirect_stderr(io) do
                    try
                        f()
                    finally
                        Libc.flush_cstdio()
                    end
                end
            end
        end
    finally
        output = read(out_path, String)
        rm(out_path)
        write(log, output)
        flush(log)
        warnings[label] = filter(is_bapcod_warning, split(output, '\n'))
    end
end

# result of one execution
struct RunResult
    status::Symbol
    sol::Any # Solution or nothing
    time::Float64
    nodes::Int # number of nodes of the branch-and-bound tree
end

nb_nodes(optimizer) = round(Int, get(optimizer.stats, :bcCountNodeProc, 0))

# demo model; with ryan_foster, edge branching is disabled and Ryan & Foster branching is enabled (cluster
# branching is disabled by -B 0 in the arguments)
function solve_demo(data, app, name; ryan_foster::Bool=false)
    t = time()
    (model, x) = C.build_model(data, app)
    if ryan_foster
        set_branching_priority!(model, "x", -1)
        enable_packset_ryanfoster_branching!(model, 1)
    end
    optimizer = VrpOptimizer(model, app["cfg"], name)
    set_cutoff!(optimizer, app["ub"])
    (st, found) = optimize!(optimizer)
    sol = found ? C.getsolution(data, optimizer, x, get_objective_value(optimizer), app) : nothing
    found && C.checksolution(data, sol)
    return RunResult(st, sol, time() - t, nb_nodes(optimizer))
end

parse_app(inst_path, cfg, args) = C.parse_commandline(vcat([inst_path, "-c", cfg], args), joinpath(DEMO_DIR, "src"))

# set partitioning, then all the VRPSolver executions with the cutoff equal to its optimum + 1
function run_instance(inst_path::String, name::String, args::Vector{String}, cfgs::Dict{String,String},
    log::IO, term::IO, warnings::Dict{String,Vector{String}})
    app = parse_app(inst_path, first(values(cfgs)), args)
    data = C.readCVRPData(app)
    (st_sp, sol_sp, time_sp, columns_sp) = run_captured(() -> solve_set_partitioning(data, app),
        "set partitioning", name, log, term, warnings; desc="the set partitioning model (CPLEX)")
    opt = (st_sp == :Optimal && sol_sp !== nothing) ? sol_sp.cost : nothing
    results = Dict{String,RunResult}()
    for k in RUN_KINDS
        rf = (k == RF_LABEL)
        # the Ryan & Foster execution uses a looser cutoff, so that its search tree is larger
        cutoff = (opt === nothing) ? nothing : opt + (rf ? RF_CUTOFF_OFFSET : 1)
        ub_args = (cutoff === nothing) ? String[] : ["-u", string(cutoff)]
        ub_desc = (cutoff === nothing) ? "" : " with cutoff $cutoff"
        app_k = parse_app(inst_path, cfgs[k], vcat(args, ub_args, rf ? ["-B", "0"] : String[]))
        results[k] = run_captured(() -> solve_demo(data, app_k, name; ryan_foster=rf), k, name, log, term,
            warnings; desc="the $k model$ub_desc" * (rf ? " (Ryan & Foster branching)" : ""))
    end
    return (st_sp, sol_sp, time_sp, columns_sp, opt, results)
end

# summary of the BaPCod warnings of each execution, with the number of occurrences of each one
function warnings_summary(name::String, warnings::Dict{String,Vector{String}})
    s = "BaPCod warnings in instance $name:\n"
    for label in RUN_KINDS
        lines = get(warnings, label, String[])
        if !haskey(warnings, label)
            s *= "  $label model: not executed\n"
        elseif isempty(lines)
            s *= "  $label model: no warnings\n"
        else
            s *= "  $label model: $(length(lines)) warning(s)\n"
            for line in unique(lines)
                s *= "    ($(count(==(line), lines))x) $(strip(line))\n"
            end
        end
    end
    return s
end

cost_str(sol) = (sol === nothing) ? "-" : string(sol.cost)
cost_str(r::RunResult) = cost_str(r.sol)
run_str(label, r::RunResult) = "$label ($(r.status), $(round(r.time, digits=2))s, $(r.nodes) nodes): $(cost_str(r))\n$(solution_str(r.sol))"

# true if the execution contradicts the set partitioning: opt is its optimal value, or nothing when it
# proved that the instance is infeasible
function incompatible_with_reference(r::RunResult, opt)
    if opt === nothing # infeasible instance: any (checked) solution contradicts it
        return r.sol !== nothing
    end
    r.sol !== nothing && r.sol.cost < opt - 0.5 && return true
    return r.status == :Optimal && (r.sol === nothing || abs(r.sol.cost - opt) > 0.5)
end

function main_test(deadline::DateTime, seed::Int, time_limit::Int)
    println("Random CVRP tests (seed $seed, time limit $(time_limit)s per run) until $deadline.")
    println("Solver output in out/test_random.log, results in out/test_random.csv")
    println("VRPSolver executions: " * join(["$k ($(relpath(f, DEMO_DIR)))" for (k, f) in CONFIG_RUNS], ", "))
    any(k -> k == RF_LABEL, RUN_KINDS) || println("WARNING: test/CVRP_RF.cfg not found, no Ryan & Foster execution")
    rng = MersenneTwister(seed)
    st = Stats()
    mkpath(joinpath(DEMO_DIR, "out"))
    log = open(joinpath(DEMO_DIR, "out", "test_random.log"), "a")
    csv_path = joinpath(DEMO_DIR, "out", "test_random.csv")
    header = "name,Q,L,U,status_sp,cost_sp,time_sp,columns_sp" *
        join(["," * join(["$(c)_$(replace(k, " " => "_"))" for c in ("status", "cost", "time", "nodes")], ",")
                   for k in RUN_KINDS])
    if isfile(csv_path) && readline(csv_path) != header # file written with other executions
        old = joinpath(DEMO_DIR, "out", "test_random_$(Dates.format(now(), "yyyymmdd_HHMMSS")).csv")
        mv(csv_path, old)
        println("Previous results (other columns) moved to $(relpath(old, DEMO_DIR))")
    end
    new_csv = !isfile(csv_path)
    csv = open(csv_path, "a")
    new_csv && println(csv, header)
    # configuration files with the time limit
    tmpdir = mktempdir()
    cfgs = Dict{String,String}()
    for (k, source) in CONFIG_RUNS
        cfgs[k] = joinpath(tmpdir, "$(replace(k, " " => "_")).cfg")
        write_cfg(cfgs[k], source, time_limit)
    end
    while now() < deadline
        name = "R$(seed)-$(st.total + 1)"
        inst_path = joinpath(tmpdir, "$name.vrp")
        Q = rand(rng, CAPACITIES)
        write_instance(inst_path, name, Q, rng)
        app0 = parse_app(inst_path, first(values(cfgs)), String[])
        L = C.lowerBoundNbVehicles(C.readCVRPData(app0))
        U = L + rand(rng, EXTRA_ROUTES)
        args = ["-M", string(U)]
        st.total += 1
        warnings = Dict{String,Vector{String}}()
        try
            println(log, "\n########## $name Q=$Q L=$L $(join(args, " "))")
            (st_sp, sol_sp, time_sp, columns_sp, opt, results) =
                run_instance(inst_path, name, args, cfgs, log, stdout, warnings)
            st.time_sp += time_sp
            st.columns_sp += columns_sp
            for k in RUN_KINDS
                count_run!(st, k, results[k].nodes)
                st.time[k] += results[k].time
            end
            # checks of the VRPSolver executions against the set partitioning
            wrong = String[]
            if st_sp != :Optimal
                st.no_reference += 1
                println("  $name: the set partitioning stopped without a proof ($st_sp $(cost_str(sol_sp)))")
            else
                (opt === nothing) ? (st.sp_infeasible += 1) : (st.sp_optimal += 1)
                for k in RUN_KINDS
                    r = results[k]
                    if incompatible_with_reference(r, opt)
                        push!(wrong, k)
                    elseif r.status == :Optimal
                        st.agree[k] += 1
                    else
                        st.not_optimal[k] += 1
                        println("  $name: $k not optimal ($(r.status) $(cost_str(r)))")
                    end
                end
            end
            if !isempty(wrong)
                st.diverge += 1
                save_case("divergence", inst_path, name, vcat(args, (opt === nothing) ? String[] : ["-u", string(opt + 1)]),
                    "incompatible: $(join(wrong, ", "))\n" *
                        "set partitioning ($st_sp, $(round(time_sp, digits=2))s, $columns_sp columns): " *
                        ((st_sp == :Optimal && sol_sp === nothing) ? "infeasible" : cost_str(sol_sp)) * "\n" *
                        solution_str(sol_sp) * join([run_str(k, results[k]) for k in RUN_KINDS]))
            end
            run_cols = join([",$(results[k].status),$(cost_str(results[k])),$(@sprintf("%.2f", results[k].time)),$(results[k].nodes)"
                             for k in RUN_KINDS])
            sp_cost = (st_sp == :Optimal && sol_sp === nothing) ? "infeasible" : cost_str(sol_sp)
            @printf(csv, "%s,%d,%d,%d,%s,%s,%.2f,%d%s\n", name, Q, L, U, st_sp, sp_cost, time_sp, columns_sp, run_cols)
        catch err
            st.errors += 1
            msg = sprint(showerror, err, catch_backtrace())
            save_case("error", inst_path, name, args, msg)
            println("  $name: ERROR $(first(split(msg, '\n')))")
        end
        flush(log)
        flush(csv)
        print_stats(st, deadline)
        if any(!isempty, values(warnings))
            summary = warnings_summary(name, warnings)
            save_case("warning", inst_path, name, args, summary)
            println("\nStopping: $summary")
            break
        end
    end
    close(log)
    close(csv)
    now() >= deadline && println("Deadline reached.")
end

deadline = deadline_from(length(ARGS) >= 1 ? ARGS[1] : "07:00")
seed = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : rand(1:(10^6))
time_limit = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 1800
main_test(deadline, seed, time_limit)
