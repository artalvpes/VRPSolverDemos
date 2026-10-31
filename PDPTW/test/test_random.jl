# Random tests on small PDPTW instances: compares the demo model, executed with every configuration
# test/PDPTW*.cfg, with the optimum given by a set partitioning MIP over all enumerated routes, solved
# with CPLEX (test/set_partitioning.jl).
#
# Usage (from the PDPTW folder):
#   julia test/test_random.jl [deadline HH:MM (default 07:00)] [seed (default: random)] [time limit per run in seconds (default 1800)]
#
# Each iteration generates a random instance with a few requests (integer coordinates in [1,100], short
# horizon and time windows, so that routes are short and can all be enumerated), in the Li&Lim format
# (vertices in random order; total cost, at most K routes) or in the Ropke format (pickups 1..n and
# deliveries n+1..2n; fixed cost per vehicle), with or without rounded distances. The time windows are
# drawn so that every request can be served alone by a route. The set partitioning MIP is solved first
# and every VRPSolver execution uses the cutoff (upper bound) equal to its optimal value + 1. For the
# Ropke instances, the VRPSolver solves the fixed fleet problem with the optimal number of vehicles k*
# of the set partitioning (as each iteration of the loop over the number of vehicles of the demo).
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

# executions of the demo model: (label, configuration file), one for each test/PDPTW*.cfg
const CONFIG_RUNS = [(splitext(f)[1], joinpath(@__DIR__, f)) for f in sort(readdir(@__DIR__))
                     if startswith(f, "PDPTW") && endswith(f, ".cfg")]
const RUN_KINDS = first.(CONFIG_RUNS)
isempty(RUN_KINDS) && error("No configuration test/PDPTW*.cfg found")

using Pkg
Pkg.activate(DEMO_DIR)
# the VrpSolver.jl (as in src/run.jl) and CPLEX for the set partitioning
haskey(Pkg.project().dependencies, "VrpSolver") ||
    Pkg.add(url="https://github.com/tbulhoes/VrpSolver.jl", rev="update_rcsp_interface")
haskey(Pkg.project().dependencies, "CPLEX") || Pkg.add("CPLEX")

using PDPTWSolverDemo, VrpSolver, JuMP, Dates, Random, Printf
const C = PDPTWSolverDemo

include("set_partitioning.jl")

const NB_REQUESTS = 15:20
const CAPACITIES = [10, 15, 20]
const MAX_DEMAND = 10
const HORIZONS = [600, 800] # time window of the depot: [0, H]; routes with up to about 7 requests
const TW_WIDTHS = [60, 120, 240] # width of the time windows of the pickups and deliveries
const SERVICE_TIMES = [0, 10]
const FIXED_COSTS = [0, 100, 10000] # Ropke instances

function deadline_from(arg::String)
    h, m = parse.(Int, split(arg, ":"))
    dl = DateTime(today()) + Hour(h) + Minute(m)
    return (dl <= now()) ? dl + Day(1) : dl
end

# random instance: vertex v in 0..2n is stored at position v + 1, with the depot 0, the pickups 1..n and
# the delivery n + i of the pickup i
struct RandInstance
    n::Int
    Q::Int
    H::Int
    service::Int
    x::Vector{Int}
    y::Vector{Int}
    dem::Vector{Int}
    tw_l::Vector{Int}
    tw_u::Vector{Int}
end

dist(x1, y1, x2, y2) = sqrt((x1 - x2)^2 + (y1 - y2)^2)

# the route depot -> pickup -> delivery -> depot of each request is feasible (with rounded distances or
# not, since the time windows are computed with the distances rounded up)
function random_instance(rng)
    n, Q, H, s = rand(rng, NB_REQUESTS), rand(rng, CAPACITIES), rand(rng, HORIZONS), rand(rng, SERVICE_TIMES)
    x, y, dem, tw_l, tw_u = (zeros(Int, 2n + 1) for _ in 1:5)
    x[1], y[1], tw_u[1] = rand(rng, 1:100), rand(rng, 1:100), H
    for i in 1:n
        p, d = i + 1, n + i + 1
        while true
            x[p], y[p], x[d], y[d] = (rand(rng, 1:100) for _ in 1:4)
            w = rand(rng, TW_WIDTHS)
            to_p = ceil(Int, dist(x[1], y[1], x[p], y[p]))
            p_to_d = ceil(Int, dist(x[p], y[p], x[d], y[d]))
            d_to_depot = ceil(Int, dist(x[d], y[d], x[1], y[1]))
            latest = H - 2s - p_to_d - d_to_depot - w # latest start of the pickup time window
            (to_p > latest) && continue
            tw_l[p] = rand(rng, to_p:latest)
            tw_u[p] = tw_l[p] + w
            arrival = tw_l[p] + s + p_to_d # at the delivery, leaving the pickup at its earliest time
            tw_l[d] = max(0, arrival - rand(rng, 0:w))
            tw_u[d] = tw_l[d] + w
            break
        end
        dem[p] = rand(rng, 1:min(MAX_DEMAND, Q))
        dem[d] = -dem[p]
    end
    return RandInstance(n, Q, H, s, x, y, dem, tw_l, tw_u)
end

# Ropke format: "K n _ Q _", then "id x y service demand l u" for the vertices 0..2n and the depot again
function write_ropke(path::String, inst::RandInstance, K::Int)
    open(path, "w") do f
        println(f, "$K $(inst.n) $(inst.H) $(inst.Q) $(inst.H)")
        for v in 0:(2*inst.n+1)
            k = (v == 2 * inst.n + 1) ? 1 : v + 1
            s = (k == 1) ? 0 : inst.service
            println(f, "$v $(inst.x[k]) $(inst.y[k]) $s $(inst.dem[k]) $(inst.tw_l[k]) $(inst.tw_u[k])")
        end
    end
end

# Li&Lim format: "K Q speed", then "id x y demand l u service pickup delivery" for the vertices, which
# are renumbered in random order (the depot remains 0)
function write_lilim(path::String, inst::RandInstance, K::Int, rng)
    n = inst.n
    new_id = vcat([0], randperm(rng, 2n)) # new_id[v+1] = new id of the vertex v
    old = zeros(Int, 2n + 1) # old[j+1] = vertex with the new id j
    for v in 0:2n
        old[new_id[v+1]+1] = v
    end
    open(path, "w") do f
        println(f, "$K $(inst.Q) 1")
        for j in 0:2n
            v = old[j+1]
            k = v + 1
            s = (v == 0) ? 0 : inst.service
            pickup = (v > n) ? new_id[v-n+1] : 0
            delivery = (1 <= v <= n) ? new_id[v+n+1] : 0
            println(f, "$j $(inst.x[k]) $(inst.y[k]) $(inst.dem[k]) $(inst.tw_l[k]) $(inst.tw_u[k]) $s $pickup $delivery")
        end
    end
end

# copy of a configuration file with a time limit
function write_cfg(path::String, source::String, time_limit::Int)
    open(path, "w") do f
        write(f, read(source, String))
        println(f, "\nGlobalTimeLimit = $time_limit")
    end
end

# the deadline was reached during an instance, whose results are discarded
struct DeadlineReached <: Exception end

# time limit in seconds for an execution that starts now: the time limit per execution, reduced to the
# time left until the deadline (deadline_t in seconds since the epoch, as time())
function run_time_limit(time_limit::Int, deadline_t::Float64)
    left = floor(Int, deadline_t - time())
    (left < 1) && throw(DeadlineReached())
    return min(time_limit, left)
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

# save the instance and a report in the out folder; args reproduce the VRPSolver executions with src/run.jl
function save_case(kind::String, inst_path::String, name::String, args::Vector{String}, report::String)
    dest = joinpath(DEMO_DIR, "out", "$(kind)_$(name).txt")
    cp(inst_path, dest; force=true)
    open(joinpath(DEMO_DIR, "out", "$(kind)_$(name).report"), "w") do f
        println(f, "Reproduce the demo model with: julia src/run.jl out/$(kind)_$(name).txt $(join(args, " ")) -c test/<configuration>.cfg")
        println(f, report)
    end
    println("  >>> $(uppercase(kind)) saved in $dest")
    flush(stdout)
end

function solution_str(sol)
    sol === nothing && return "  (none)\n"
    return join(["Route #$k: $(join(r, " "))\n" for (k, r) in enumerate(sol.routes)])
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

# demo model with k vehicles (k = -1: between the bounds of the demo, as for the Li&Lim instances)
function solve_demo(data, app, name, k::Int)
    t = time()
    (model, x) = C.build_model(data, app; k=k)
    optimizer = VrpOptimizer(model, app["cfg"], name)
    set_cutoff!(optimizer, app["ub"])
    (st, found) = optimize!(optimizer)
    sol = found ? C.getsolution(data, x, get_objective_value(optimizer), optimizer, app) : nothing
    found && C.checksolution(data, sol, app)
    return RunResult(st, sol, time() - t, nb_nodes(optimizer))
end

parse_app(inst_path, cfg, args) = C.parse_commandline(vcat([inst_path, "-c", cfg], args), joinpath(DEMO_DIR, "src"))
read_data(app) = app["lilim"] ? C.readLiLimData(app["instance"], app["round"]) :
                 C.readRopkeData(app["instance"], app["round"])

# arguments of src/run.jl that reproduce a VRPSolver execution: cutoff opt + 1 and, for the Ropke
# instances, a fleet of exactly k* vehicles
function run_args(args::Vector{String}, lilim::Bool, opt, kstar)
    ub_args = (opt === nothing) ? String[] : ["-u", string(opt + 1)]
    fleet_args = (lilim || kstar === nothing) ? String[] : ["-m", string(kstar), "-M", string(kstar)]
    return vcat(args, ub_args, fleet_args)
end

# set partitioning, then all the VRPSolver executions with the cutoff equal to its optimum + 1; every
# execution has the time limit per execution, reduced to the time left until the deadline, and
# DeadlineReached is thrown if an execution is stopped by the deadline (or there is no time left)
function run_instance(inst_path::String, name::String, args::Vector{String}, tmpdir::String, time_limit::Int,
    deadline_t::Float64, log::IO, term::IO, warnings::Dict{String,Vector{String}})
    app = parse_app(inst_path, last(first(CONFIG_RUNS)), args)
    data = read_data(app)
    limit = run_time_limit(time_limit, deadline_t)
    (st_sp, sol_sp, time_sp, columns_sp) = run_captured(
        () -> solve_set_partitioning(data, app; stop_time=time() + limit),
        "set partitioning", name, log, term, warnings; desc="the set partitioning model (CPLEX)")
    (st_sp != :Optimal && limit < time_limit) && throw(DeadlineReached())
    opt = (st_sp == :Optimal && sol_sp !== nothing) ? sol_sp.cost : nothing
    kstar = (app["lilim"] || sol_sp === nothing) ? nothing : length(sol_sp.routes)
    desc = ((opt === nothing) ? "" : " with cutoff $(opt + 1)") * ((kstar === nothing) ? "" : " and $kstar vehicles")
    results = Dict{String,RunResult}()
    for (k, source) in CONFIG_RUNS
        limit = run_time_limit(time_limit, deadline_t)
        cfg = joinpath(tmpdir, "$k.cfg")
        write_cfg(cfg, source, limit)
        app_k = parse_app(inst_path, cfg, run_args(args, app["lilim"], opt, kstar))
        results[k] = run_captured(() -> solve_demo(data, app_k, name, (kstar === nothing) ? -1 : kstar), k, name,
            log, term, warnings; desc="the $k model$desc")
        (results[k].status != :Optimal && limit < time_limit) && throw(DeadlineReached())
    end
    return (st_sp, sol_sp, time_sp, columns_sp, opt, kstar, results)
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

# tolerance to compare costs, which are not integer when the distances are not rounded
cost_tol(opt) = max(1e-3, 1e-7 * abs(opt))

# true if the execution contradicts the set partitioning: opt is its optimal value, or nothing when it
# proved that the instance is infeasible
function incompatible_with_reference(r::RunResult, opt)
    if opt === nothing # infeasible instance: any (checked) solution contradicts it
        return r.sol !== nothing
    end
    r.sol !== nothing && r.sol.cost < opt - cost_tol(opt) && return true
    return r.status == :Optimal && (r.sol === nothing || abs(r.sol.cost - opt) > cost_tol(opt))
end

function main_test(deadline::DateTime, seed::Int, time_limit::Int)
    println("Random PDPTW tests (seed $seed, time limit $(time_limit)s per run) until $deadline.")
    println("Solver output in out/test_random.log, results in out/test_random.csv")
    println("VRPSolver executions: " * join(["$k ($(relpath(f, DEMO_DIR)))" for (k, f) in CONFIG_RUNS], ", "))
    rng = MersenneTwister(seed)
    st = Stats()
    mkpath(joinpath(DEMO_DIR, "out"))
    log = open(joinpath(DEMO_DIR, "out", "test_random.log"), "a")
    csv_path = joinpath(DEMO_DIR, "out", "test_random.csv")
    header = "name,format,n,Q,H,K,fixed,round,status_sp,cost_sp,routes_sp,time_sp,columns_sp" *
             join(["," * join(["$(c)_$k" for c in ("status", "cost", "time", "nodes")], ",") for k in RUN_KINDS])
    if isfile(csv_path) && readline(csv_path) != header # file written with other executions
        old = joinpath(DEMO_DIR, "out", "test_random_$(Dates.format(now(), "yyyymmdd_HHMMSS")).csv")
        mv(csv_path, old)
        println("Previous results (other columns) moved to $(relpath(old, DEMO_DIR))")
    end
    new_csv = !isfile(csv_path)
    csv = open(csv_path, "a")
    new_csv && println(csv, header)
    tmpdir = mktempdir() # instances and configuration files with the time limit
    deadline_t = time() + Dates.value(deadline - now()) / 1000
    while now() < deadline
        name = "R$(seed)-$(st.total + 1)"
        inst_path = joinpath(tmpdir, "$name.txt")
        inst = random_instance(rng)
        lilim = rand(rng, Bool)
        round_dists = rand(rng, Bool)
        if lilim
            K = rand(rng, [cld(inst.n, 3), cld(inst.n, 2), inst.n])
            fixed = 0
            write_lilim(inst_path, inst, K, rng)
            args = ["-l"]
        else
            K = inst.n
            fixed = rand(rng, FIXED_COSTS)
            write_ropke(inst_path, inst, K)
            args = ["--fixed", string(fixed)]
        end
        round_dists && push!(args, "-r")
        st.total += 1
        warnings = Dict{String,Vector{String}}()
        deadline_reached = false
        try
            println(log, "\n########## $name n=$(inst.n) Q=$(inst.Q) H=$(inst.H) K=$K $(join(args, " "))")
            (st_sp, sol_sp, time_sp, columns_sp, opt, kstar, results) =
                run_instance(inst_path, name, args, tmpdir, time_limit, deadline_t, log, stdout, warnings)
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
                save_case("divergence", inst_path, name, run_args(args, lilim, opt, kstar),
                    "incompatible: $(join(wrong, ", "))\n" *
                    "set partitioning ($st_sp, $(round(time_sp, digits=2))s, $columns_sp columns): " *
                    ((st_sp == :Optimal && sol_sp === nothing) ? "infeasible" : cost_str(sol_sp)) * "\n" *
                    solution_str(sol_sp) * join([run_str(kind, results[kind]) for kind in RUN_KINDS]))
            end
            run_cols = join([",$(results[kind].status),$(cost_str(results[kind])),$(@sprintf("%.2f", results[kind].time)),$(results[kind].nodes)"
                             for kind in RUN_KINDS])
            sp_cost = (st_sp == :Optimal && sol_sp === nothing) ? "infeasible" : cost_str(sol_sp)
            sp_routes = (sol_sp === nothing) ? "-" : string(length(sol_sp.routes))
            @printf(csv, "%s,%s,%d,%d,%d,%d,%d,%s,%s,%s,%s,%.2f,%d%s\n", name, lilim ? "lilim" : "ropke", inst.n,
                inst.Q, inst.H, K, fixed, round_dists, st_sp, sp_cost, sp_routes, time_sp, columns_sp, run_cols)
        catch err
            if err isa DeadlineReached
                st.total -= 1
                deadline_reached = true
                println("  $name: stopped by the deadline (discarded)")
                println(log, "---------- $name: stopped by the deadline (discarded)")
            else
                st.errors += 1
                msg = sprint(showerror, err, catch_backtrace())
                save_case("error", inst_path, name, args, msg)
                println("  $name: ERROR $(first(split(msg, '\n')))")
            end
        end
        flush(log)
        flush(csv)
        deadline_reached || print_stats(st, deadline)
        if any(!isempty, values(warnings))
            summary = warnings_summary(name, warnings)
            save_case("warning", inst_path, name, args, summary)
            println("\nStopping: $summary")
            break
        end
        deadline_reached && break
    end
    close(log)
    close(csv)
    now() >= deadline && println("Deadline reached.")
end

deadline = deadline_from(length(ARGS) >= 1 ? ARGS[1] : "07:00")
seed = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : rand(1:(10^6))
time_limit = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 1800
main_test(deadline, seed, time_limit)
