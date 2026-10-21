# Random tests on small CCVRP instances: compares the VRPSolver models (the demo model with custom
# resource, with several configurations, and the model of Section 6.4.8 of the book "Optimizing with
# Column Generation", test/book_model.jl) with the optimum given by a set partitioning MIP over all
# enumerated routes, solved with CPLEX (test/set_partitioning.jl).
#
# Usage (from the CCVRP folder):
#   julia test/test_book_model.jl [deadline HH:MM (default 07:00)] [seed (default: random)] [time limit per model in seconds (default 1800)]
#
# Each iteration generates a random instance with 30 vertices in the CVRPLIB format of the A set
# (integer coordinates in [1,100]) and unit demands, so that the weighted objective of the demo and
# the unweighted objective of the book coincide. The capacity W (small, so that all routes can be
# enumerated) and the maximum number of routes U are drawn at random. The set partitioning MIP is
# solved first and, as in the CRSP random tests, every VRPSolver execution uses the cutoff (upper
# bound) equal to its optimal value + 1: the demo model with the demo configuration, the book model,
# and the demo model with each configuration test/CCVRP_*.cfg.
#
# When an execution is incompatible with the optimum (optimal with another value, or a solution
# better than the optimum), when the demo and the book models are incompatible, or when an error
# happens, the instance and a report are saved in the out folder. The solvers' output goes to
# out/test_book_model.log, one line per instance goes to out/test_book_model.csv, and a summary is
# printed after each instance. If BaPCod prints a warning in any of the executions, the tests stop
# after that instance with a summary of the warnings of each execution (also saved in out). The
# summary also gives, for each kind of execution, in how many instances BaPCod branched (more than one
# node in the branch-and-bound tree).

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

# executions of the demo model with the configurations test/CCVRP_*.cfg: (label, configuration file)
const CONFIG_RUNS = [("demo " * splitext(f)[1], joinpath(@__DIR__, f)) for f in sort(readdir(@__DIR__))
                     if startswith(f, "CCVRP_") && endswith(f, ".cfg")]
# kinds of VRPSolver executions
const RUN_KINDS = vcat(["demo", "book"], first.(CONFIG_RUNS))

# Copy the custom resource implementation files to the BaPCod/RCSP library and compile it
build_path = splitdir(splitdir(ENV["BAPCOD_RCSP_LIB"])[1])[1]
bapcod_root = splitdir(build_path)[1]
run(`cp -p $DEMO_DIR/src/meta_solver/rcsp_custom_res_impl.hpp $bapcod_root/Tools/rcsp/include_dev`)
run(`cp -p $DEMO_DIR/src/meta_solver/rcsp_custom_res_impl.cpp $bapcod_root/Tools/rcsp/src`)
run(Cmd(`make -j4 bapcod-shared`; dir=build_path))

using Pkg
Pkg.activate(DEMO_DIR)
if !haskey(Pkg.project().dependencies, "VrpSolver")
    Pkg.add(url="https://github.com/tbulhoes/VrpSolver.jl", rev="update_rcsp_interface")
    Pkg.instantiate()
end

using CCVRPSolverDemo, VrpSolver, JuMP, Dates, Random, Printf
const C = CCVRPSolverDemo

include("book_model.jl")
include("set_partitioning.jl")

const NB_VERTICES = 30 # including the depot
const CAPACITIES = [3, 4, 5] # small, so that all routes can be enumerated
const EXTRA_ROUTES = [0, 1, 2] # U = ceil(n / W) + extra

function deadline_from(arg::String)
    h, m = parse.(Int, split(arg, ":"))
    dl = DateTime(today()) + Hour(h) + Minute(m)
    return (dl <= now()) ? dl + Day(1) : dl
end

# random instance in the CVRPLIB format of the A set, with unit demands
function write_instance(path::String, name::String, W::Int, rng)
    open(path, "w") do f
        println(f, "NAME : $name")
        println(f, "COMMENT : (random CCVRP test instance with unit demands)")
        println(f, "TYPE : CVRP")
        println(f, "DIMENSION : $NB_VERTICES")
        println(f, "EDGE_WEIGHT_TYPE : EUC_2D ")
        println(f, "CAPACITY : $W")
        println(f, "NODE_COORD_SECTION ")
        for i in 1:NB_VERTICES
            println(f, " $i $(rand(rng, 1:100)) $(rand(rng, 1:100))")
        end
        println(f, "DEMAND_SECTION ")
        for i in 1:NB_VERTICES
            println(f, "$i $(i == 1 ? 0 : 1) ")
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
    no_reference::Int # instances where the set partitioning did not prove the optimum
    time_sp::Float64
    columns_sp::Int
    agree::Dict{String,Int} # executions of each kind optimal with the value of the set partitioning
    not_optimal::Dict{String,Int} # executions of each kind that stopped without proving the optimum
    time::Dict{String,Float64} # total time of the executions of each kind
    runs::Dict{String,Int} # number of executions of each kind
    branched::Dict{String,Int} # number of executions of each kind with more than one node
end

Stats() = Stats(0, 0, 0, 0, 0, 0.0, 0, (Dict(k => 0 for k in RUN_KINDS) for _ in 1:2)...,
    Dict(k => 0.0 for k in RUN_KINDS), (Dict(k => 0 for k in RUN_KINDS) for _ in 1:2)...)

function print_stats(st::Stats, deadline::DateTime)
    nsp = max(st.sp_optimal + st.no_reference, 1)
    runs = join(["$k $(st.agree[k])/$(st.not_optimal[k]) $(@sprintf("%.2f", st.time[k] / max(st.runs[k], 1)))s"
                 for k in RUN_KINDS], ", ")
    branching = join(["$k $(st.branched[k])/$(st.runs[k])" for k in RUN_KINDS], ", ")
    @printf("[%s] instances: %d | DIVERGE: %d | ERRORS: %d | set partitioning: optimal %d, no reference %d, avg %.2fs, %d columns | VRPSolver (agree/not optimal avg time): %s | branching: %s%s\n",
        Dates.format(now(), "HH:MM:SS"), st.total, st.diverge, st.errors, st.sp_optimal, st.no_reference,
        st.time_sp / nsp, round(Int, st.columns_sp / nsp), runs, branching,
        (st.total % 10 == 0) ? " | deadline $deadline" : "")
    flush(stdout)
end

# counts the execution of the given kind and whether it branched
function count_run!(st::Stats, kind::String, nodes::Int)
    st.runs[kind] += 1
    (nodes > 1) && (st.branched[kind] += 1)
end

# save the instance and a report in the out folder
function save_case(kind::String, inst_path::String, name::String, args::Vector{String}, report::String)
    dest = joinpath(DEMO_DIR, "out", "$(kind)_$(name).vrp")
    cp(inst_path, dest; force=true)
    open(joinpath(DEMO_DIR, "out", "$(kind)_$(name).txt"), "w") do f
        println(f, "Reproduce the demo model with: julia src/run.jl out/$(kind)_$(name).vrp $(join(args, " "))")
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

function solve_demo(data, app, name)
    t = time()
    (model, x, _) = C.build_model(data, app)
    optimizer = VrpOptimizer(model, app["cfg"], name)
    set_cutoff!(optimizer, app["ub"])
    (st, found) = optimize!(optimizer)
    sol = found ? C.getsolution(data, optimizer, x, get_objective_value(optimizer), app) : nothing
    found && C.checksolution(data, sol)
    return RunResult(st, sol, time() - t, nb_nodes(optimizer))
end

function solve_book(data, app, name)
    t = time()
    (model, x, trange) = build_book_model(data, app)
    optimizer = VrpOptimizer(model, app["cfg"], name)
    set_cutoff!(optimizer, app["ub"])
    (st, found) = optimize!(optimizer)
    sol = found ? get_book_solution(data, x, trange, get_objective_value(optimizer), app) : nothing
    found && C.checksolution(data, sol)
    return RunResult(st, sol, time() - t, nb_nodes(optimizer))
end

parse_app(inst_path, cfg, args) = C.parse_commandline(vcat([inst_path, "-c", cfg], args), joinpath(DEMO_DIR, "src"))

# set partitioning, then all the VRPSolver executions with the cutoff equal to its optimum + 1
function run_instance(inst_path::String, name::String, args::Vector{String}, cfgs::Dict{String,String},
    log::IO, term::IO, warnings::Dict{String,Vector{String}})
    app = parse_app(inst_path, cfgs["demo"], args)
    data = C.readCVRPData(app)
    (st_sp, sol_sp, time_sp, columns_sp) = run_captured(() -> solve_set_partitioning(data, app),
        "set partitioning", name, log, term, warnings; desc="the set partitioning model (CPLEX)")
    opt = (st_sp == :Optimal && sol_sp !== nothing) ? sol_sp.cost : nothing
    ub_args = (opt === nothing) ? String[] : ["-u", string(opt + 1)]
    ub_desc = (opt === nothing) ? "" : " with cutoff $(opt + 1)"
    results = Dict{String,RunResult}()
    for k in RUN_KINDS
        app_k = parse_app(inst_path, cfgs[k], vcat(args, ub_args))
        solve = (k == "book") ? solve_book : solve_demo
        results[k] = run_captured(() -> solve(data, app_k, name), k, name, log, term, warnings;
            desc="the $k model$ub_desc")
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

# true if the execution contradicts the optimal value
function incompatible_with_optimum(rc::RunResult, opt)
    rc.sol !== nothing && rc.sol.cost < opt - 0.5 && return true
    return rc.status == :Optimal && (rc.sol === nothing || abs(rc.sol.cost - opt) > 0.5)
end

# true if the "optimal" value of one model is contradicted by the other
function incompatible(st_d, sol_d, st_b, sol_b)
    if st_d == :Optimal && st_b == :Optimal
        return (sol_d === nothing) != (sol_b === nothing) ||
               (sol_d !== nothing && abs(sol_d.cost - sol_b.cost) > 0.5)
    end
    st_d == :Optimal && sol_b !== nothing && (sol_d === nothing || sol_b.cost < sol_d.cost - 0.5) && return true
    st_b == :Optimal && sol_d !== nothing && (sol_b === nothing || sol_d.cost < sol_b.cost - 0.5) && return true
    return false
end

function main_test(deadline::DateTime, seed::Int, time_limit::Int)
    println("Random CCVRP tests (seed $seed, time limit $(time_limit)s per model) until $deadline.")
    println("Solver output in out/test_book_model.log, results in out/test_book_model.csv")
    println("VRPSolver executions: " * join(RUN_KINDS, ", ") *
            (isempty(CONFIG_RUNS) ? "" : " (" * join(["$k: $(relpath(f, DEMO_DIR))" for (k, f) in CONFIG_RUNS], ", ") * ")"))
    rng = MersenneTwister(seed)
    st = Stats()
    mkpath(joinpath(DEMO_DIR, "out"))
    log = open(joinpath(DEMO_DIR, "out", "test_book_model.log"), "a")
    csv_path = joinpath(DEMO_DIR, "out", "test_book_model.csv")
    header = "name,W,U,status_sp,cost_sp,time_sp,columns_sp" *
             join(["," * join(["$(c)_$(replace(k, " " => "_"))" for c in ("status", "cost", "time", "nodes")], ",")
                   for k in RUN_KINDS])
    if isfile(csv_path) && readline(csv_path) != header # file written by a previous version of this script
        old = joinpath(DEMO_DIR, "out", "test_book_model_$(Dates.format(now(), "yyyymmdd_HHMMSS")).csv")
        mv(csv_path, old)
        println("Previous results (other columns) moved to $(relpath(old, DEMO_DIR))")
    end
    new_csv = !isfile(csv_path)
    csv = open(csv_path, "a")
    new_csv && println(csv, header)
    # configuration files with the time limit: the demo configuration for the demo and book models
    tmpdir = mktempdir()
    sources = merge(Dict{String,String}("demo" => joinpath(DEMO_DIR, "config", "CCVRP.cfg"),
            "book" => joinpath(DEMO_DIR, "config", "CCVRP.cfg")), Dict{String,String}(CONFIG_RUNS))
    cfgs = Dict{String,String}()
    for k in RUN_KINDS
        cfgs[k] = joinpath(tmpdir, "$(replace(k, " " => "_")).cfg")
        write_cfg(cfgs[k], sources[k], time_limit)
    end
    n = NB_VERTICES - 1
    while now() < deadline
        name = "R$(seed)-$(st.total + 1)"
        inst_path = joinpath(tmpdir, "$name.vrp")
        W = rand(rng, CAPACITIES)
        U = cld(n, W) + rand(rng, EXTRA_ROUTES)
        write_instance(inst_path, name, W, rng)
        args = ["-M", string(U)]
        st.total += 1
        warnings = Dict{String,Vector{String}}()
        try
            println(log, "\n########## $name W=$W $(join(args, " "))")
            (st_sp, sol_sp, time_sp, columns_sp, opt, results) =
                run_instance(inst_path, name, args, cfgs, log, stdout, warnings)
            st.time_sp += time_sp
            st.columns_sp += columns_sp
            for k in RUN_KINDS
                count_run!(st, k, results[k].nodes)
                st.time[k] += results[k].time
            end
            # checks of the VRPSolver executions against the optimum and of the demo against the book
            wrong = String[]
            if opt === nothing
                st.no_reference += 1
                println("  $name: the set partitioning did not prove the optimum ($st_sp $(cost_str(sol_sp)))")
            else
                st.sp_optimal += 1
                for k in RUN_KINDS
                    r = results[k]
                    if incompatible_with_optimum(r, opt)
                        push!(wrong, k)
                    elseif r.status == :Optimal
                        st.agree[k] += 1
                    else
                        st.not_optimal[k] += 1
                        println("  $name: $k not optimal ($(r.status) $(cost_str(r)))")
                    end
                end
            end
            rd, rb = results["demo"], results["book"]
            incompatible(rd.status, rd.sol, rb.status, rb.sol) && push!(wrong, "demo x book")
            if !isempty(wrong)
                st.diverge += 1
                save_case("divergence", inst_path, name, vcat(args, (opt === nothing) ? String[] : ["-u", string(opt + 1)]),
                    "incompatible: $(join(wrong, ", "))\n" *
                    "set partitioning ($st_sp, $(round(time_sp, digits=2))s, $columns_sp columns): $(cost_str(sol_sp))\n" *
                    solution_str(sol_sp) * join([run_str(k, results[k]) for k in RUN_KINDS]))
            end
            run_cols = join([",$(results[k].status),$(cost_str(results[k])),$(@sprintf("%.2f", results[k].time)),$(results[k].nodes)"
                             for k in RUN_KINDS])
            @printf(csv, "%s,%d,%d,%s,%s,%.2f,%d%s\n", name, W, U, st_sp, cost_str(sol_sp), time_sp, columns_sp, run_cols)
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
seed = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : rand(1:10^6)
time_limit = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 1800
main_test(deadline, seed, time_limit)
