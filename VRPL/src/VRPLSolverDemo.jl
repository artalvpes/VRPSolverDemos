__precompile__(false)
module VRPLSolverDemo
using VrpSolver, JuMP, ArgParse, HiGHS

include("data.jl")
include("model.jl")
include("solution.jl")
include("heuristic.jl")

function parse_commandline(args_array::Vector{String}, appfolder::String)
    s = ArgParseSettings(
        usage="##### VRPSolver #####\n\n" *
              "  On interactive mode, call main([\"arg1\", ..., \"argn\"])", exit_after_help=false)
    @add_arg_table s begin
        "instance"
        help = "Instance file path: CVRPLIB (.vrp, the last l nodes are the lockers) or VRPDA (.vdap)"
        "--lockers", "-l"
        help = "For CVRPLIB instances (.vrp): number of lockers, which are the last l nodes of the instance"
        arg_type = Int
        default = 20
        "--alpha", "-a"
        help = "Assignment cost = alpha x distance between the customer and the locker " *
               "(default: 3 for CVRPLIB instances, 1 for VRPDA instances)"
        arg_type = Float64
        "--nearest", "-k"
        help = "Each customer can only be assigned to one of its k nearest lockers (ties broken by the locker index)"
        arg_type = Int
        default = 3
        "--no_preprocessing", "-P"
        help = "Do not remove the dominated edges (preprocessing of Oliveira et al., 2025)"
        action = :store_true
        "--diving", "-d"
        help = "Use the diving heuristic with the parameters of Pessoa et al. (2020) " *
               "(DivingHeurUseDepthLimit = 0, MaxLDSdepth = 3, MaxLDSbreadth = 2)"
        action = :store_true
        "--rm_heuristic", "-H"
        help = "Call the restricted master IP heuristic at every node, including the root " *
               "(CallFrequencyOfRestrictedMasterIpHeur = 1, MaxTimeForRestrictedMasterIpHeur = 60)"
        action = :store_true
        "--cfg", "-c"
        help = "Configuration file path"
        default = "$appfolder/../config/VRPL.cfg"
        "--ub", "-u"
        help = "Upper bound (primal bound). If not given, the heuristic of heuristic.jl gives it (cost + 0.01), or, " *
               "with --noheur, the trivial solution (one route per customer, to its cheapest covering locker) (cost + 1)."
        arg_type = Float64
        "--noheur"
        help = "Without --ub, do not run the heuristic (the trivial solution gives the upper bound)"
        action = :store_true
        "--tentative", "-T"
        help = "Tentative upper bounds DELTA1 DELTA2: solve the root with the upper bound to get its lower bound LB, " *
               "then solve with the upper bounds LB + DELTA1, LB + DELTA1 + DELTA2, LB + DELTA1 + 2 DELTA2, ... " *
               "(never above the upper bound) until a solution is found"
        nargs = 2
        arg_type = Float64
        "--minr", "-m"
        help = "Minimum number of routes in the solution"
        arg_type = Int
        default = 1
        "--maxr", "-M"
        help = "Maximum number of routes in the solution (by default, the number of customers)"
        arg_type = Int
        default = 999
        "--show_complete_form", "-f"
        help = "Show the complete formulation including all feasible paths"
        action = :store_true
        "--update"
        help = "Update the VrpSolver package"
        action = :store_true
        "--sol", "-s"
        help = "Solution file path (as written with the option --out)"
        "--out", "-o"
        help = "Path to write the solution found"
        "--tikz", "-t"
        help = "Path to write the TikZ figure of the solution found."
        "--nosolve", "-n"
        help = "Does not call the VRPSolver. Only to check or draw a given solution."
        action = :store_true
        "--batch", "-b"
        help = "batch file path"
    end
    return parse_args(args_array, s)
end

# Primal heuristics (useful when no good upper bound is known)
const DIVING_PARAMS = ["DivingHeurUseDepthLimit = 0", "MaxLDSdepth = 3", "MaxLDSbreadth = 2"]
const RM_HEURISTIC_PARAMS = ["CallFrequencyOfRestrictedMasterIpHeur = 1", "MaxTimeForRestrictedMasterIpHeur = 60"]

# Returns the path of a temporary copy of the configuration file with the given parameters (the lines of the original
# file that set them are removed, since BaPCod does not accept a parameter twice)
function cfg_with_params(cfg::String, params::Vector{String})
    names = [first(split(p)) for p in params]
    lines = filter(l -> !any(n -> occursin(Regex("^\\s*$n\\b"), l), names), readlines(cfg))
    path = tempname() * ".cfg"
    write(path, join(vcat(lines, params), "\n") * "\n")
    return path
end

# Only the root node is solved (first step of the tentative upper bounds)
const ROOT_ONLY_PARAMS = ["MaxNbOfBBtreeNodeTreated = 1"]

# Upper bound given by the trivial solution: one route per customer, from the depot to its cheapest covering locker
# and back. Without an upper bound of the scale of the problem, VrpSolver.jl uses a huge cost for the artificial
# variables of the master (the cutoff itself), which causes numerical troubles in the LPs.
function trivial_upper_bound(data::DataVRPL)
    return sum(minimum(2 * d(data, 0, s) + f(data, c, s) for s in covering_lockers(data, c)) for c in customers(data))
end

# Solves the model once with the cutoff ub. Returns the status, whether a solution was found, and the solution.
function solve_vrpl(data::DataVRPL, app::Dict{String,Any}, instance_name, ub::Float64; root_only::Bool=false)
    (model, x, pair) = build_model(data, app)

    if app["show_complete_form"]
        enum_paths, complete_form = get_complete_formulation(model, app["cfg"])
        set_optimizer(complete_form, HiGHS.Optimizer) # set MIP solver
        print_enum_paths(enum_paths)
        println(complete_form)
        optimize!(complete_form)
    end

    params = vcat(app["diving"] ? DIVING_PARAMS : String[], app["rm_heuristic"] ? RM_HEURISTIC_PARAMS : String[],
        root_only ? ROOT_ONLY_PARAMS : String[])
    cfg = isempty(params) ? app["cfg"] : cfg_with_params(app["cfg"], params)
    optimizer = VrpOptimizer(model, cfg, instance_name)
    isempty(params) || rm(cfg) # the parameters are read when the optimizer is created
    set_cutoff!(optimizer, ub)
    (status, solution_found) = optimize!(optimizer)
    sol = nothing
    if solution_found
        sol = getsolution(data, x, pair, get_objective_value(optimizer))
    end
    return status, solution_found, sol, optimizer
end

# Valid lower bound on the optimal cost after a run with the cutoff ub: if the run ends with the status Optimal, its
# solution is optimal, or there is no solution of cost below ub; otherwise (time limit), the global dual bound of the
# run is valid for the solutions of cost below ub, and it is at most ub.
function run_lower_bound(status, solution_found, optimizer, ub)
    status == :Optimal && return solution_found ? get_objective_value(optimizer) : ub
    return min(optimizer.stats[:bcRecBestDb], ub)
end

# Tentative upper bounds (as in the GAP demo): the root node is first solved with the upper bound ub, giving the
# root lower bound LB. Then the problem is solved with the cutoffs LB + delta1, LB + delta1 + delta2,
# LB + delta1 + 2 delta2, ... (never above ub), until a solution is found. A run that ends without a solution but
# with the status Optimal proves that there is no solution of cost below its cutoff, so the next cutoff can be tried.
function solve_vrpl_tentative(data::DataVRPL, app::Dict{String,Any}, instance_name, ub_max::Float64)
    delta1, delta2 = app["tentative"]
    delta2 > 0 || error("the second value of --tentative (delta2) must be positive")
    t0 = time()
    println("Tentative upper bounds: solving the root node with ub = $ub_max")
    res = solve_vrpl(data, app, instance_name, ub_max; root_only=true)
    res[1] == :Optimal && return res # solved (or proved infeasible) at the root
    root_lb = res[4].stats[:bcRecRootDb]
    if !(root_lb > -1e11) # the root lower bound was not computed (time limit): no tentative upper bounds
        println("Tentative upper bounds: the root lower bound is not available; solving with ub = $ub_max")
        return solve_vrpl(data, app, instance_name, ub_max)
    end
    best_lb = run_lower_bound(res[1], res[2], res[4], ub_max)
    k = 0
    while true
        ub = min(root_lb + delta1 + k * delta2, ub_max)
        println("Tentative upper bounds: run $(k + 1) with ub = $ub (root lower bound $root_lb)")
        res = solve_vrpl(data, app, instance_name, ub)
        (status, solution_found) = res
        best_lb = max(best_lb, run_lower_bound(status, solution_found, res[4], ub))
        if solution_found || (status != :Optimal) || (ub >= ub_max)
            println("Tentative upper bounds: finished after $(k + 1) run(s) with ub = $ub, " *
                    "total time $(round(time() - t0; digits=2)) s, valid lower bound $best_lb")
            return res
        end
        println("Tentative upper bounds: no solution with cost below $ub")
        k += 1
    end
end

function run_vrpl(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    instance_name = split(basename(app["instance"]), ".")[1]

    data = readVRPLData(app)
    print_coverage(data)
    ub = app["ub"]
    if isnothing(ub)
        tub = trivial_upper_bound(data)
        ub = tub + 1.0
        println("Trivial solution (one route per customer) of cost $(round(tub, digits=2)): ub = $(round(ub, digits=2))")
        if !app["noheur"] && !app["nosolve"]
            t = @elapsed (heur_routes, heur_cost) = vrpl_heuristic(data)
            if !isnothing(heur_routes) && app["minr"] <= length(heur_routes) <= app["maxr"]
                heur_sol = Solution(heur_cost, heur_routes)
                checksolution(data, heur_sol; minr=app["minr"], maxr=app["maxr"])
                if heur_cost + 0.01 < ub
                    # ub = heuristic cost + 0.01: the solver must return a solution at least as good as the heuristic one
                    ub = heur_cost + 0.01
                end
                println("Heuristic solution of cost $(round(heur_cost, digits=2)) with $(length(heur_routes)) routes " *
                        "($(round(t; digits=2)) s): ub = $(round(ub, digits=2))")
            else
                println("Heuristic: no solution found")
            end
        end
    end
    sol = nothing
    if app["sol"] !== nothing
        sol = readsolution(app)
        checksolution(data, sol; minr=app["minr"], maxr=app["maxr"]) # checks the solution feasibility
        ub = min(ub, sol.cost) # update the upper bound if necessary
    end

    solution_found = false
    status = nothing
    if !app["nosolve"]
        status, solution_found, solved, _ = if isempty(app["tentative"])
            solve_vrpl(data, app, instance_name, ub)
        else
            solve_vrpl_tentative(data, app, instance_name, ub)
        end
        solution_found && (sol = solved)
    end

    println("########################################################")
    retval = Inf
    if !isnothing(sol) # Is there a solution?
        checksolution(data, sol; minr=app["minr"], maxr=app["maxr"])
        print_routes(data, sol)
        println("Cost $(sol.cost)")
        println("Solution checked: feasible, cost $(sol.cost)")
        if app["out"] !== nothing
            writesolution(app["out"], sol)
        end
        if app["tikz"] !== nothing
            drawsolution(app["tikz"], data, sol) # write tikz figure
        end
        retval = sol.cost
    elseif !app["nosolve"]
        if status == :Optimal
            println("Problem infeasible")
        else
            println("Solution not found")
        end
    end
    println("########################################################")
    return retval
end

function main(args)
    appfolder = dirname(@__FILE__)
    app = parse_commandline(args, appfolder)
    isnothing(app) && return
    if app["batch"] !== nothing
        for line in readlines(app["batch"])
            if isempty(strip(line)) || strip(line)[1] == '#'
                continue
            end
            args_array = [String(s) for s in split(line)]
            app_line = parse_commandline(args_array, appfolder)
            run_vrpl(app_line)
        end
        return 0.0
    else
        return run_vrpl(app)
    end
end

export main
end
