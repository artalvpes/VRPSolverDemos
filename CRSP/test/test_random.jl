# Random tests on small CRSP instances: compares the demo model, executed with every configuration
# test/CRSP*.cfg, with the optimum given by a set partitioning MIP over all enumerated ring-stars, solved
# with CPLEX (test/set_partitioning.jl).
#
# Usage (from the CRSP folder):
#   julia test/test_random.jl [deadline HH:MM (default 07:00)] [seed (default: random)] [time limit per run in seconds (default 1800)]
#
# Each iteration generates a random CVRP instance with 25 vertices in the CVRPLIB format of the A set
# (integer coordinates in [1,100], demands in [1,24] and capacity 50, small enough for the set
# partitioning MIP to enumerate all ring-stars) and draws the CRSP parameters (-p, -k, -a). The set
# partitioning MIP is solved first and every VRPSolver execution uses the cutoff (upper bound) equal to
# its optimal value + 1.
#
# When an execution is incompatible with the set partitioning (optimal with another value, a solution
# better than the optimum, or a solution when the set partitioning is infeasible), or when an error
# happens, the instance and a report are saved in the out folder. The solvers' output goes to
# out/test_random.log, one line per instance goes to out/test_random.csv, and a summary is printed after
# each instance (for each configuration: agree/not optimal, average time, and in how many instances
# BaPCod branched). If BaPCod prints a warning in any of the executions, the tests stop after that
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

# executions of the demo model: (label, configuration file), one for each test/CRSP*.cfg
const CONFIG_RUNS = [(splitext(f)[1], joinpath(@__DIR__, f)) for f in sort(readdir(@__DIR__))
                     if startswith(f, "CRSP") && endswith(f, ".cfg")]
const RUN_KINDS = first.(CONFIG_RUNS)
isempty(RUN_KINDS) && error("No configuration test/CRSP*.cfg found")

using Pkg
Pkg.activate(DEMO_DIR)
# the local VrpSolver.jl and CPLEX for the set partitioning
haskey(Pkg.project().dependencies, "VrpSolver") || Pkg.develop(path=joinpath(homedir(), ".julia", "dev", "VrpSolver.jl"))
haskey(Pkg.project().dependencies, "CPLEX") || Pkg.add("CPLEX")

using CRSPSolverDemo, VrpSolver, JuMP, Dates, Random, Printf
const C = CRSPSolverDemo

include("set_partitioning.jl")

const NB_VERTICES = 25 # including the root
const DEMANDS = 1:24
const CAPACITY = 50 # small enough to enumerate all ring-stars
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
end

Stats() = Stats(0, 0, 0, 0, 0, 0, 0.0, 0, (Dict(k => 0 for k in RUN_KINDS) for _ in 1:2)...,
    Dict(k => 0.0 for k in RUN_KINDS), (Dict(k => 0 for k in RUN_KINDS) for _ in 1:2)...)

function print_stats(st::Stats, deadline::DateTime)
    nsp = max(st.total - st.errors, 1)
    runs = join(["$k $(st.agree[k])/$(st.not_optimal[k]) $(@sprintf("%.2f", st.time[k] / max(st.runs[k], 1)))s"
                 for k in RUN_KINDS], ", ")
    branching = join(["$k $(st.branched[k])/$(st.runs[k])" for k in RUN_KINDS], ", ")
    @printf("[%s] instances: %d | DIVERGE: %d | ERRORS: %d | set partitioning: optimal %d, infeasible %d, no reference %d, avg %.2fs, %d columns | VRPSolver (agree/not optimal avg time): %s | branching: %s%s\n",
        Dates.format(now(), "HH:MM:SS"), st.total, st.diverge, st.errors, st.sp_optimal, st.sp_infeasible,
        st.no_reference, st.time_sp / nsp, round(Int, st.columns_sp / nsp), runs, branching,
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
        println(f, "Reproduce the demo model with: julia src/run.jl out/$(kind)_$(name).vrp $(join(args, " ")) -c test/<configuration>.cfg")
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

# warnings printed by BaPCod (and by its RCSP solver), on stdout or stderr; the warning about the
# pricing objective value not matching the cost of the best column is ignored when the difference
# between them is at most WARNING_TOLERANCE
const WARNING_TOLERANCE = 1e-5
const OBJVAL_WARNING = r"objVal = (\S+) does not correspond to the cost of the best column = (\S+)"
function is_bapcod_warning(line)
    occursin(r"(bapcod|rcsp|meta-solver).*warning"i, line) || return false
    m = match(OBJVAL_WARNING, line)
    m === nothing && return true
    objval, best = tryparse(Float64, m[1]), tryparse(Float64, m[2])
    return objval === nothing || best === nothing || abs(objval - best) > WARNING_TOLERANCE
end

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
    (model, x, z) = C.build_model(data, app)
    optimizer = VrpOptimizer(model, app["cfg"], name)
    set_cutoff!(optimizer, app["ub"])
    (st, found) = optimize!(optimizer)
    sol = found ? C.getsolution(data, optimizer, x, z, get_objective_value(optimizer), app) : nothing
    found && C.checksolution(data, sol)
    return RunResult(st, sol, time() - t, nb_nodes(optimizer))
end

parse_app(inst_path, cfg, args) = C.parse_commandline(vcat([inst_path, "-c", cfg], args), joinpath(DEMO_DIR, "src"))

# set partitioning, then all the VRPSolver executions with the cutoff equal to its optimum + 1
function run_instance(inst_path::String, name::String, args::Vector{String}, cfgs::Dict{String,String},
    log::IO, term::IO, warnings::Dict{String,Vector{String}})
    app = parse_app(inst_path, first(values(cfgs)), args)
    data = C.readCRSPData(app)
    (st_sp, sol_sp, time_sp, columns_sp) = run_captured(() -> solve_set_partitioning(data, app),
        "set partitioning", name, log, term, warnings; desc="the set partitioning model (CPLEX)")
    opt = (st_sp == :Optimal && sol_sp !== nothing) ? sol_sp.cost : nothing
    ub_args = (opt === nothing) ? String[] : ["-u", string(opt + 1)]
    ub_desc = (opt === nothing) ? "" : " with cutoff $(opt + 1)"
    results = Dict{String,RunResult}()
    for k in RUN_KINDS
        app_k = parse_app(inst_path, cfgs[k], vcat(args, ub_args))
        results[k] = run_captured(() -> solve_demo(data, app_k, name), k, name, log, term, warnings;
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
    println("Random CRSP tests (seed $seed, time limit $(time_limit)s per run) until $deadline.")
    println("Solver output in out/test_random.log, results in out/test_random.csv")
    println("VRPSolver executions: " * join(["$k ($(relpath(f, DEMO_DIR)))" for (k, f) in CONFIG_RUNS], ", "))
    rng = MersenneTwister(seed)
    st = Stats()
    mkpath(joinpath(DEMO_DIR, "out"))
    log = open(joinpath(DEMO_DIR, "out", "test_random.log"), "a")
    csv_path = joinpath(DEMO_DIR, "out", "test_random.csv")
    header = "name,p,k,a,status_sp,cost_sp,time_sp,columns_sp" *
             join(["," * join(["$(c)_$k" for c in ("status", "cost", "time", "nodes")], ",") for k in RUN_KINDS])
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
        cfgs[k] = joinpath(tmpdir, "$k.cfg")
        write_cfg(cfgs[k], source, time_limit)
    end
    while now() < deadline
        name = "R$(seed)-$(st.total + 1)"
        inst_path = joinpath(tmpdir, "$name.vrp")
        write_instance(inst_path, name, rng)
        p, k, a = rand(rng, STEINER_PCTS), rand(rng, STAR_SIZES), rand(rng, STAR_FACTORS)
        args = ["-p", string(p), "-k", string(k), "-a", string(a)]
        st.total += 1
        warnings = Dict{String,Vector{String}}()
        try
            println(log, "\n########## $name $(join(args, " "))")
            (st_sp, sol_sp, time_sp, columns_sp, opt, results) =
                run_instance(inst_path, name, args, cfgs, log, stdout, warnings)
            st.time_sp += time_sp
            st.columns_sp += columns_sp
            for kind in RUN_KINDS
                count_run!(st, kind, results[kind].nodes)
                st.time[kind] += results[kind].time
            end
            # checks of the VRPSolver executions against the set partitioning
            wrong = String[]
            if st_sp != :Optimal
                st.no_reference += 1
                println("  $name: the set partitioning stopped without a proof ($st_sp $(cost_str(sol_sp)))")
            else
                (opt === nothing) ? (st.sp_infeasible += 1) : (st.sp_optimal += 1)
                for kind in RUN_KINDS
                    r = results[kind]
                    if incompatible_with_reference(r, opt)
                        push!(wrong, kind)
                    elseif r.status == :Optimal
                        st.agree[kind] += 1
                    else
                        st.not_optimal[kind] += 1
                        println("  $name: $kind not optimal ($(r.status) $(cost_str(r)))")
                    end
                end
            end
            if !isempty(wrong)
                st.diverge += 1
                save_case("divergence", inst_path, name, vcat(args, (opt === nothing) ? String[] : ["-u", string(opt + 1)]),
                    "incompatible: $(join(wrong, ", "))\n" *
                    "set partitioning ($st_sp, $(round(time_sp, digits=2))s, $columns_sp columns): " *
                    ((st_sp == :Optimal && sol_sp === nothing) ? "infeasible" : cost_str(sol_sp)) * "\n" *
                    solution_str(sol_sp) * join([run_str(kind, results[kind]) for kind in RUN_KINDS]))
            end
            run_cols = join([",$(results[kind].status),$(cost_str(results[kind])),$(@sprintf("%.2f", results[kind].time)),$(results[kind].nodes)"
                             for kind in RUN_KINDS])
            sp_cost = (st_sp == :Optimal && sol_sp === nothing) ? "infeasible" : cost_str(sol_sp)
            @printf(csv, "%s,%g,%d,%g,%s,%s,%.2f,%d%s\n", name, p, k, a, st_sp, sp_cost, time_sp, columns_sp, run_cols)
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
