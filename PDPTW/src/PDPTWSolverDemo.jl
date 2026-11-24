__precompile__(false)
module PDPTWSolverDemo
using VrpSolver, JuMP, ArgParse


include("data.jl")
include("model.jl")
include("solution.jl")
include("heuristic.jl")

function parse_commandline(args_array::Array{String,1}, appfolder::String)
    s = ArgParseSettings(
        usage="##### VRPSolver #####\n\n" *
              "  On interactive mode, call main([\"arg1\", ..., \"argn\"])", exit_after_help=false)
    @add_arg_table s begin
        "instance"
        help = "Instance file path"
        "--cfg", "-c"
        help = "Configuration file path"
        default = "$appfolder/../config/PDPTW.cfg"
        "--minr", "-m"
        help = "Lower bound on the number of vehicles in the solution for the hierarchical objective (to minimize first vehicle costs and second the sum of the route costs)"
        arg_type = Int
        default = 1
        "--maxr", "-M"
        help = "Upper bound on the number of vehicles in the solution for the hierarchical objective."
        arg_type = Int
        default = 999
        "--fixed", "-f"
        help = "Cost by vehicle (or fixed costs) for the hirerarchical objective."
        arg_type = Int
        default = 10000
        "--ub", "-u"
        help = "Upper bound (primal bound). If not given, the heuristic of heuristic.jl gives it (cost + 1, or + 0.1 " *
               "without rounding)."
        arg_type = Float64
        "--noheur"
        help = "Without --ub, do not run the heuristic (no upper bound)"
        action = :store_true
        "--tentative", "-T"
        help = "Li and Lim instances only. Tentative upper bounds DELTA1 DELTA2: solve the root with the upper bound " *
               "to get its lower bound LB, then solve with the upper bounds LB + DELTA1, LB + DELTA1 + DELTA2, ... " *
               "(never above the upper bound) until a solution is found"
        nargs = 2
        arg_type = Float64
        "--round", "-r"
        help = "Round the distance matrix"
        action = :store_true
        "--update"
        help = "Update the VrpSolver package"
        action = :store_true
        "--sol", "-s"
        help = "Solution file path (e.g., see sol/AA30.sol)"
        "--out", "-o"
        help = "Path to write the solution found"
        "--tikz", "-t"
        help = "Path to write the TikZ figure of the solution found."
        "--nosolve", "-n"
        help = "Does not call the VRPSolver. Only to draw a given solution."
        action = :store_true
        "--lilim", "-l"
        help = "Li&Lim instance."
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
function solve_pdptw(data, app::Dict{String,Any}, instance_name, ub::Float64; root_only::Bool=false)
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
# ... (LB rounded up when the costs are integer; never above ub), until a solution is found. A run that ends without a
# solution but with the status Optimal proves that there is no solution of cost below its cutoff.
function solve_pdptw_tentative(data, app::Dict{String,Any}, instance_name, ub_max::Float64)
    delta1, delta2 = app["tentative"]
    delta2 > 0 || error("the second value of --tentative (delta2) must be positive")
    t0 = time()
    println("Tentative upper bounds: solving the root node with ub = $ub_max")
    res = solve_pdptw(data, app, instance_name, ub_max; root_only=true)
    res[1] == :Optimal && return res # solved (or proved infeasible) at the root
    root_lb = res[3].stats[:bcRecRootDb]
    if !(root_lb > -1e11) # the root lower bound was not computed (time limit): no tentative upper bounds
        println("Tentative upper bounds: the root lower bound is not available; solving with ub = $ub_max")
        return solve_pdptw(data, app, instance_name, ub_max)
    end
    base = app["round"] ? ceil(root_lb - 1e-6) : root_lb
    best_lb = run_lower_bound(res[1], res[2], res[3], ub_max)
    k = 0
    while true
        ub = min(base + delta1 + k * delta2, ub_max)
        println("Tentative upper bounds: run $(k + 1) with ub = $ub (root lower bound $root_lb)")
        res = solve_pdptw(data, app, instance_name, ub)
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

function run_pdptw(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        if isnothing(val)
            println("  $arg  =>  nothing")
        else
            println("  $arg  =>  $val")
        end
    end
    flush(stdout)

    instance_name = String(split(basename(app["instance"]), ".")[1])

    if !isnothing(app["sol"])
        sol = readsolution(app["sol"])
        app["ub"] = isnothing(app["ub"]) ? Float64(sol.cost) : min(app["ub"], sol.cost) # update the upper bound
    end
    heuristic_ub!(data) = if isnothing(app["ub"])
        app["ub"] = 10000000.0
        if !app["noheur"] && !app["nosolve"]
            t = @elapsed (heur_routes, heur_cost) = pdptw_heuristic(data, app)
            if isnothing(heur_routes)
                println("Heuristic: no solution found with the number of routes in [$(app["minr"]), $(min(data.K, app["maxr"]))]")
            else
                checkroutes(data, heur_routes, heur_cost, app)
                # ub = heuristic cost + 1 (+ 0.1 if the distances are not rounded): the solver must return a solution at
                # least as good as the heuristic one
                app["ub"] = app["round"] ? round(heur_cost) + 1.0 : heur_cost + 0.1
                println("Heuristic solution of cost $heur_cost with $(length(heur_routes)) routes " *
                        "($(round(t; digits=2)) s): ub = $(app["ub"])")
            end
        end
    end

    if app["lilim"]
        data = readLiLimData(app["instance"], app["round"])
        isnothing(app["sol"]) || checkroutes(data, sol.routes, sol.cost, app) # checks the solution read
        heuristic_ub!(data)
        solution_found = false
        if !app["nosolve"]
            (status, solution_found, optimizer, x) = if isempty(app["tentative"])
                solve_pdptw(data, app, instance_name, app["ub"])
            else
                solve_pdptw_tentative(data, app, instance_name, app["ub"])
            end
            if solution_found
                # checks the values of x against the problem definition, then recovers the routes from them
                checksolution_x(data, Dict(a => get_value(optimizer, x[a]) for a in arcs(data)),
                                get_objective_value(optimizer), app)
                sol = getsolution(data, x, get_objective_value(optimizer), optimizer, app)
            end
        end
    else # Ropke instances
        data = readRopkeData(app["instance"], app["round"])
        isnothing(app["sol"]) || checkroutes(data, sol.routes, sol.cost, app) # checks the solution read
        isempty(app["tentative"]) || println("The tentative upper bounds are not available for the Ropke instances")
        heuristic_ub!(data)
        maxr = min(app["maxr"], n(data))

        solution_found = false
        if !app["nosolve"]
            for k in maxr:-1:app["minr"]
                (model, x) = build_model(data, app, k=k) # problem with fixed fleet with k vehicles
                optimizer = VrpOptimizer(model, app["cfg"], instance_name)
                set_cutoff!(optimizer, app["ub"])
                (status, solution_found_aux) = optimize!(optimizer)
                if solution_found_aux
                    # checks the values of x against the problem definition (fleet of k vehicles)
                    checksolution_x(data, Dict(a => get_value(optimizer, x[a]) for a in arcs(data)),
                                    get_objective_value(optimizer), app; k=k)
                    sol = getsolution(data, x, get_objective_value(optimizer), optimizer, app)
                    solution_found = true
                else
                    break
                end
            end
        end
    end

    println("########################################################")
    if solution_found || !isnothing(app["sol"]) # Is there a solution?
        print_routes(sol)
        println("Cost $(sol.cost)")
        if !isnothing(app["out"])
            writesolution(app["out"], sol)
        end
        if !isnothing(app["tikz"])
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
    flush(stdout)
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
            run_pdptw(app_line)
        end
    else
        run_pdptw(app)
    end
end

export main

end