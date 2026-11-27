__precompile__(false)
module GAPSolverDemo
using VrpSolver, JuMP, ArgParse

include("data.jl")
include("model.jl")
include("heuristic.jl")

function parse_commandline(args_array::Array{String,1}, appfolder::String)
    s = ArgParseSettings(
        usage="##### VRPSolver #####\n\n" *
              "  On interactive mode, call main([\"arg1\", ..., \"argn\"])", exit_after_help=false)
    @add_arg_table s begin
        "instance"
        help = "Instance file path"
        "--update"
        help = "Update the VrpSolver package"
        action = :store_true
        "--cfg", "-c"
        help = "Configuration file path"
        default = "$appfolder/../config/GAP_Classic.cfg"
        "--ub", "-u"
        help = "Upper bound (primal bound). If not given, the heuristic of heuristic.jl gives it (cost + 1)."
        arg_type = Float64
        "--noheur"
        help = "Without --ub, do not run the heuristic (no upper bound)"
        action = :store_true
        "--batch", "-b"
        help = "batch file path"
        "--tentative", "-t", "-T"
        help = "Tentative upper bounds DELTA1 DELTA2: solve the root without upper bound to get its lower bound " *
               "LB, then solve with the upper bounds LB + DELTA1, LB + DELTA1 + DELTA2, LB + DELTA1 + 2 DELTA2, " *
               "... until a solution is found"
        nargs = 2
        arg_type = Float64
        "--diving", "-d"
        help = "Use the diving heuristic with the parameters of Pessoa et al. (2020) for the GAP " *
               "(DivingHeurUseDepthLimit = 0, MaxLDSdepth = 3, MaxLDSbreadth = 2), " *
               "useful when no good upper bound is known"
        action = :store_true
        "--timelimit"
        help = "Time limit in seconds of each VRPSolver run (GlobalTimeLimit; 0, the default: the one of the " *
               "configuration file, none in the configs of the demo)"
        arg_type = Float64
        default = 0.0
    end
    return parse_args(args_array, s)
end

# Diving heuristic with limited discrepancy search, applied only at the root node (parameters of the GAP
# experiments in Pessoa et al. 2020: chi^div = 0, chi^depth = 3, chi^disc = 2)
const DIVING_PARAMS = ["DivingHeurUseDepthLimit = 0", "MaxLDSdepth = 3", "MaxLDSbreadth = 2"]
# Only the root node is solved (first step of the tentative upper bounds)
const ROOT_ONLY_PARAMS = ["MaxNbOfBBtreeNodeTreated = 1"]

# Returns the path of a temporary copy of the configuration file with the given parameters (the lines of
# the original file that set them are removed, since BaPCod does not accept a parameter twice)
function cfg_with_params(cfg::String, params::Vector{String})
    names = [first(split(p)) for p in params]
    lines = filter(l -> !any(n -> occursin(Regex("^\\s*$n\\b"), l), names), readlines(cfg))
    path = tempname() * ".cfg"
    write(path, join(vcat(lines, params), "\n") * "\n")
    return path
end

# Solves the model once with the cutoff ub. Returns the status, whether a solution was found, the optimizer
# (for the solution and the statistics) and the variables.
function solve_gap(data::DataGap, app::Dict{String,Any}, instance_name, ub::Float64; root_only::Bool=false)
    (model, x) = build_model(data)
    params = vcat(app["diving"] ? DIVING_PARAMS : String[], root_only ? ROOT_ONLY_PARAMS : String[],
                  app["timelimit"] > 0 ? ["GlobalTimeLimit = $(round(Int, app["timelimit"]))"] : String[])
    cfg = isempty(params) ? app["cfg"] : cfg_with_params(app["cfg"], params)
    optimizer = VrpOptimizer(model, cfg, instance_name)
    isempty(params) || rm(cfg) # the parameters are read when the optimizer is created
    set_cutoff!(optimizer, ub)
    (status, solution_found) = optimize!(optimizer)
    return status, solution_found, optimizer, x
end

# Valid lower bound on the optimal cost after a run with the cutoff ub: if the run ends with the status Optimal, its
# solution is optimal, or there is no solution of cost below ub; otherwise (time limit), the global dual bound of the
# run is valid for the solutions of cost below ub, and it is at most ub.
function run_lower_bound(status, solution_found, optimizer, ub)
    status == :Optimal && return solution_found ? get_objective_value(optimizer) : ub
    return min(optimizer.stats[:bcRecBestDb], ub)
end

# Tentative upper bounds: the root node is first solved without upper bound, giving the root lower bound LB.
# Then the problem is solved with the cutoffs ceil(LB) + delta1, ceil(LB) + delta1 + delta2,
# ceil(LB) + delta1 + 2 delta2, ... (never above the upper bound given with -u), until a solution is found.
# A run that ends without a solution but with the status Optimal proves that there is no solution below its
# cutoff, so the next cutoff can be tried.
function solve_gap_tentative(data::DataGap, app::Dict{String,Any}, instance_name)
    delta1, delta2 = app["tentative"]
    delta2 > 0 || error("the second value of --tentative (delta2) must be positive")
    t0 = time()
    println("Tentative upper bounds: solving the root node with ub = $(app["ub"])")
    status, solution_found, optimizer, x = solve_gap(data, app, instance_name, app["ub"]; root_only=true)
    status == :Optimal && return status, solution_found, optimizer, x # solved (or proved infeasible) at the root
    root_lb = optimizer.stats[:bcRecRootDb]
    if !(root_lb > -1e11) # the root lower bound was not computed (time limit): no tentative upper bounds
        println("Tentative upper bounds: the root lower bound is not available; solving with ub = $(app["ub"])")
        return solve_gap(data, app, instance_name, app["ub"])
    end
    best_lb = run_lower_bound(status, solution_found, optimizer, app["ub"])
    k = 0
    while true
        ub = min(ceil(root_lb - 1e-6) + delta1 + k * delta2, app["ub"])
        println("Tentative upper bounds: run $(k + 1) with ub = $ub (root lower bound $root_lb)")
        status, solution_found, optimizer, x = solve_gap(data, app, instance_name, ub)
        best_lb = max(best_lb, run_lower_bound(status, solution_found, optimizer, ub))
        if solution_found || (status != :Optimal) || (ub >= app["ub"])
            println("Tentative upper bounds: finished after $(k + 1) run(s) with ub = $ub, " *
                    "total time $(round(time() - t0; digits=2)) s, valid lower bound $best_lb")
            return status, solution_found, optimizer, x
        end
        println("Tentative upper bounds: no solution with cost below $ub")
        k += 1
    end
end

# Checks the solution x with value z directly against the definition of the GAP, assuming nothing about how
# it was obtained (see Note 6.12 of the book "Optimizing with Column Generation"):
#   x_tk in {0, 1} for all t, k;  sum_k x_tk = 1 for all t;  sum_t w_tk x_tk <= Q_k for all k;  sum_tk c_tk x_tk = z.
# Throws an error otherwise. Returns the machine of each task.
function checksolution(data::DataGap, optimizer, x)
    T, K = tasks(data), machines(data)
    tol = 1e-6
    z = get_objective_value(optimizer)
    xval = Dict((t, k) => get_value(optimizer, x[t, k]) for t in T, k in K)
    for t in T, k in K
        v = xval[t, k]
        (abs(v) > tol && abs(v - 1) > tol) && error("x[$t,$k] = $v is not binary")
    end
    for t in T
        s = sum(xval[t, k] for k in K)
        (abs(s - 1) > tol) && error("Task $t: the sum of x[$t,k] over the machines is $s, not 1")
    end
    for k in K
        load = sum(w(data, t, k) * xval[t, k] for t in T)
        (load > capacity(data)[k] + tol) &&
            error("Machine $k is violating its capacity: the load is $load and the capacity is $(capacity(data)[k])")
    end
    cost = sum(c(data, t, k) * xval[t, k] for t in T, k in K)
    (abs(cost - z) > tol) && error("Cost calculated from x ($cost) is different from the objective value ($z)")
    return [only(k for k in K if xval[t, k] > 0.5) for t in T]
end

function run_gap(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    data = readGAPData(app["instance"])
    instance_name = split(basename(app["instance"]), ".")[1]

    if isnothing(app["ub"])
        app["ub"] = 10000000.0
        if !app["noheur"]
            t = @elapsed (heur_m, heur_cost) = gap_heuristic(data)
            if isnothing(heur_m)
                println("Heuristic: no feasible assignment found")
            else
                # checks the heuristic solution: capacities and cost
                for k in machines(data)
                    sum(w(data, j, k) for j in tasks(data) if heur_m[j] == k; init=0.0) <= capacity(data)[k] ||
                        error("The heuristic solution violates the capacity of machine $k")
                end
                heur_cost == sum(c(data, j, heur_m[j]) for j in tasks(data)) || error("Wrong cost of the heuristic solution")
                # ub = heuristic cost + 1: the solver must return a solution, at least as good as the heuristic one
                app["ub"] = heur_cost + 1.0
                println("Heuristic solution of cost $heur_cost ($(round(t; digits=2)) s): ub = $(app["ub"])")
            end
        end
    end

    status, solution_found, optimizer, x = if isempty(app["tentative"])
        solve_gap(data, app, instance_name, app["ub"])
    else
        solve_gap_tentative(data, app, instance_name)
    end

    println("########################################################")
    if solution_found # Is there a solution?
        println("Objective value : $(get_objective_value(optimizer))")
        machine_of = checksolution(data, optimizer, x) # checks the solution feasibility and cost
        for k in data.machines
            tasks_k = [t for t in data.tasks if machine_of[t] == k]
            isempty(tasks_k) || println("machine $(k):", join(string.(tasks_k) .* " "))
        end
        println("Solution checked: feasible, cost $(get_objective_value(optimizer))")
    elseif status == :Optimal
        println("Problem infeasible")
    else
        println("Solution not found")
    end
end

function main(args)
    appfolder = dirname(@__FILE__)
    app = parse_commandline(args, appfolder)
    isnothing(app) && return
    if !isnothing(app["batch"])
        for line in readlines(app["batch"])
            if isempty(strip(line)) || strip(line)[1] == '#'
                continue
            end
            args_array = [String(s) for s in split(line)]
            app_line = parse_commandline(args_array, appfolder)
            run_gap(app_line)
        end
    else
        run_gap(app)
    end
end

export main
end

