__precompile__(false)
module VRPTWSolverDemo
using VrpSolver, JuMP, ArgParse


include("data.jl")
include("model.jl")
include("solution.jl")
include("heuristic.jl")

function parse_commandline(args_array::Array{String,1}, appfolder::String)
    s = ArgParseSettings(usage="##### VRPSolver #####\n\n" *
                               "  On interactive mode, call main([\"arg1\", ..., \"argn\"])", exit_after_help=false)
    @add_arg_table s begin
        "instance"
        help = "Instance file path"
        "--update"
        help = "Update the VrpSolver package"
        action = :store_true
        "--cfg", "-c"
        help = "Configuration file path"
        default = "$appfolder/../config/VRPTW_set_1.cfg"
        "--ub", "-u"
        help = "Upper bound (primal bound). If not given, the heuristic of heuristic.jl gives it (cost + 0.1)."
        arg_type = Float64
        "--noheur"
        help = "Without --ub, do not run the heuristic (no upper bound)"
        action = :store_true
        "--tentative", "-T"
        help = "Tentative upper bounds DELTA1 DELTA2: solve the root with the upper bound to get its lower bound LB, " *
               "then solve with the upper bounds LB + DELTA1, LB + DELTA1 + DELTA2, LB + DELTA1 + 2 DELTA2, ... " *
               "(never above the upper bound) until a solution is found"
        nargs = 2
        arg_type = Float64
        "--enable_cap_res", "-e"
        help = "Enable capacity resource"
        action = :store_true
        "--sol", "-s"
        help = "Solution file path (e.g., see sol/C203.sol)"
        "--out", "-o"
        help = "Path to write the solution found"
        "--tikz", "-t"
        help = "Path to write the TikZ figure of the solution found."
        "--nosolve", "-n"
        help = "Does not call the VRPSolver. Only to draw a given solution."
        action = :store_true
        "--batch", "-b"
        help = "batch file path"
    end
    return parse_args(args_array, s)
end

# Only the root node is solved (first step of the tentative upper bounds)
const ROOT_ONLY_PARAMS = ["MaxNbOfBBtreeNodeTreated = 1"]

# Returns the path of a temporary copy of the configuration file with the given parameters (the lines of the original
# file that set them are removed, since BaPCod does not accept a parameter twice)
function cfg_with_params(cfg::String, params::Vector{String})
    names = [first(split(p)) for p in params]
    lines = filter(l -> !any(n -> occursin(Regex("^\\s*$n\\b"), l), names), readlines(cfg))
    path = tempname() * ".cfg"
    write(path, join(vcat(lines, params), "\n") * "\n")
    return path
end

# Solves the model once with the cutoff ub. Returns the status, whether a solution was found, the optimizer and the
# model variables.
function solve_vrptw(data, app::Dict{String,Any}, instance_name, ub::Float64; root_only::Bool=false)
    (model, x) = build_model(data, app)
    cfg = root_only ? cfg_with_params(app["cfg"], ROOT_ONLY_PARAMS) : app["cfg"]
    optimizer = VrpOptimizer(model, cfg, instance_name)
    root_only && rm(cfg) # the parameters are read when the optimizer is created
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

# Tentative upper bounds (as in the GAP demo): the root node is first solved with the upper bound ub, giving the root
# lower bound LB. Then the problem is solved with the cutoffs LB + delta1, LB + delta1 + delta2, LB + delta1 + 2 delta2,
# ... (never above ub), until a solution is found. A run that ends without a
# solution but with the status Optimal proves that there is no solution of cost below its cutoff.
function solve_vrptw_tentative(data, app::Dict{String,Any}, instance_name, ub_max::Float64)
    delta1, delta2 = app["tentative"]
    delta2 > 0 || error("the second value of --tentative (delta2) must be positive")
    t0 = time()
    println("Tentative upper bounds: solving the root node with ub = $ub_max")
    res = solve_vrptw(data, app, instance_name, ub_max; root_only=true)
    res[1] == :Optimal && return res # solved (or proved infeasible) at the root
    root_lb = res[3].stats[:bcRecRootDb]
    if !(root_lb > -1e11) # the root lower bound was not computed (time limit): no tentative upper bounds
        println("Tentative upper bounds: the root lower bound is not available; solving with ub = $ub_max")
        return solve_vrptw(data, app, instance_name, ub_max)
    end
    base = root_lb # the costs are multiples of 0.1, not integers: no rounding
    best_lb = run_lower_bound(res[1], res[2], res[3], ub_max)
    k = 0
    while true
        ub = min(base + delta1 + k * delta2, ub_max)
        println("Tentative upper bounds: run $(k + 1) with ub = $ub (root lower bound $root_lb)")
        res = solve_vrptw(data, app, instance_name, ub)
        (status, solution_found) = res
        best_lb = max(best_lb, run_lower_bound(status, solution_found, res[3], ub))
        if solution_found || (status != :Optimal) || (ub >= ub_max)
            println("Tentative upper bounds: finished after $(k + 1) run(s) with ub = $ub, " *
                    "total time $(round(time() - t0; digits=2)) s, valid lower bound $best_lb")
            return res
        end
        println("Tentative upper bounds: no solution with cost below $ub")
        k += 1
    end
end

function run_vrptw(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    instance_name = split(basename(app["instance"]), ".")[1]

    data = readVRPTWData(app["instance"])

    if app["sol"] != nothing
        sol = readsolution(app["sol"])
        checkroutes(data, sol.routes, sol.cost) # checks the solution feasibility
        app["ub"] = isnothing(app["ub"]) ? Float64(sol.cost) : min(app["ub"], sol.cost) # update the upper bound
    end
    if isnothing(app["ub"])
        app["ub"] = 10000000.0
        if !app["noheur"] && !app["nosolve"]
            t = @elapsed (heur_routes, heur_cost) = vrptw_heuristic(data)
            if isnothing(heur_routes)
                println("Heuristic: no solution found with at most K = $(data.K) routes")
            else
                heur_cost = round(heur_cost; digits=1)
                checkroutes(data, heur_routes, heur_cost)
                # ub = heuristic cost + 0.1 (costs are multiples of 0.1): the solver must return a solution at least as good
                app["ub"] = round(heur_cost + 0.1; digits=1)
                println("Heuristic solution of cost $heur_cost with $(length(heur_routes)) routes " *
                        "($(round(t; digits=2)) s): ub = $(app["ub"])")
            end
        end
    end

    solution_found = false
    if !app["nosolve"]
        (status, solution_found, optimizer, x) = if isempty(app["tentative"])
            solve_vrptw(data, app, instance_name, app["ub"])
        else
            solve_vrptw_tentative(data, app, instance_name, app["ub"])
        end
        if solution_found
            # checks the values of x against the problem definition, then recovers the routes from them
            checksolution_x(data, Dict(a => get_value(optimizer, x[a]) for a in arcs(data)), get_objective_value(optimizer))
            sol = getsolution(data, x, get_objective_value(optimizer), optimizer)
        end
    end

    println("########################################################")
    if solution_found || app["sol"] != nothing # Is there a solution?
        print_routes(sol)
        println("Cost $(sol.cost)")
        if app["out"] != nothing
            writesolution(app["out"], sol)
        end
        if app["tikz"] != nothing
            drawsolution(app["tikz"], data, sol) # write tikz figure
        end
    elseif !app["nosolve"]
        if status == :Optimal
            println("Problem infeasible")
        else
            println("Solution not found")
        end
    end
    println("########################################################")
end

function main(args)
    appfolder = dirname(@__FILE__)
    app = parse_commandline(args, appfolder)
    isnothing(app) && return
    if app["batch"] != nothing
        for line in readlines(app["batch"])
            if isempty(strip(line)) || strip(line)[1] == '#'
                continue
            end
            args_array = [String(s) for s in split(line)]
            app_line = parse_commandline(args_array, appfolder)
            run_vrptw(app_line)
        end
    else
        run_vrptw(app)
    end
end

export main

end