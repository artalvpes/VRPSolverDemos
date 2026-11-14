__precompile__(false)
module CCVRPSolverDemo
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
        help = "Instance file path"
        "--cfg", "-c"
        help = "Configuration file path"
        default = "$appfolder/../config/CCVRP.cfg"
        "--ub", "-u"
        help = "Upper bound (primal bound). If not given, the heuristic of heuristic.jl gives it (cost + 1)."
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
        "--minr", "-m"
        help = "Minimum number of routes in the solution"
        arg_type = Int
        default = 1
        "--maxr", "-M"
        help = "Maximum number of routes in the solution"
        arg_type = Int
        default = 999
        "--noround", "-r"
        help = "Does not round the distance matrix"
        action = :store_true
        "--show_complete_form", "-f"
        help = "Show the complete formulation including all feasible paths"
        action = :store_true
        "--update"
        help = "Update the VrpSolver package"
        action = :store_true
        "--sol", "-s"
        help =
            "Solution file path (CVRPLIB format. " *
            "e.g. http://vrp.atd-lab.inf.puc-rio.br/media/com_vrp/instances/E/E-n13-k4.sol)"
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
function solve_ccvrp(data, app::Dict{String,Any}, instance_name, ub::Float64; root_only::Bool=false)
    (model, x, z) = build_model(data, app)
    if app["show_complete_form"] && !root_only
        enum_paths, complete_form = get_complete_formulation(model, app["cfg"])
        set_optimizer(complete_form, HiGHS.Optimizer) # set MIP solver
        print_enum_paths(enum_paths)
        println(complete_form)
        optimize!(complete_form)
    end
    cfg = root_only ? cfg_with_params(app["cfg"], ROOT_ONLY_PARAMS) : app["cfg"]
    optimizer = VrpOptimizer(model, cfg, instance_name)
    root_only && rm(cfg) # the parameters are read when the optimizer is created
    set_cutoff!(optimizer, ub)
    (status, solution_found) = optimize!(optimizer)
    return status, solution_found, optimizer, x, z
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
function solve_ccvrp_tentative(data, app::Dict{String,Any}, instance_name, ub_max::Float64)
    delta1, delta2 = app["tentative"]
    delta2 > 0 || error("the second value of --tentative (delta2) must be positive")
    t0 = time()
    println("Tentative upper bounds: solving the root node with ub = $ub_max")
    res = solve_ccvrp(data, app, instance_name, ub_max; root_only=true)
    res[1] == :Optimal && return res # solved (or proved infeasible) at the root
    root_lb = res[3].stats[:bcRecRootDb]
    if !(root_lb > -1e11) # the root lower bound was not computed (time limit): no tentative upper bounds
        println("Tentative upper bounds: the root lower bound is not available; solving with ub = $ub_max")
        return solve_ccvrp(data, app, instance_name, ub_max)
    end
    base = !app["noround"] ? ceil(root_lb - 1e-6) : root_lb
    best_lb = run_lower_bound(res[1], res[2], res[3], ub_max)
    k = 0
    while true
        ub = min(base + delta1 + k * delta2, ub_max)
        println("Tentative upper bounds: run $(k + 1) with ub = $ub (root lower bound $root_lb)")
        res = solve_ccvrp(data, app, instance_name, ub)
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

function run_cvrp(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    instance_name = split(basename(app["instance"]), ".")[1]

    data = readCVRPData(app)
    if app["sol"] !== nothing
        sol = readsolution(app)
        checksolution(data, sol, app) # checks the solution feasibility
        app["ub"] = isnothing(app["ub"]) ? Float64(sol.cost) : min(app["ub"], sol.cost) # update the upper bound
    end
    if isnothing(app["ub"])
        app["ub"] = 10000000.0
        if !app["noheur"] && !app["nosolve"]
            t = @elapsed (heur_routes, heur_cost) = ccvrp_heuristic(data, app)
            if isnothing(heur_routes)
                println("Heuristic: no solution found with the number of routes in [$(app["minr"]), $(app["maxr"])]")
            else
                heur_sol = Solution(app["noround"] ? heur_cost : round(Int, heur_cost), heur_routes)
                checksolution(data, heur_sol, app)
                # ub = heuristic cost + 1: the solver must return a solution, at least as good as the heuristic one
                app["ub"] = heur_cost + 1.0
                println("Heuristic solution of cost $(heur_sol.cost) with $(length(heur_routes)) routes " *
                        "($(round(t; digits=2)) s): ub = $(app["ub"])")
            end
        end
    end

    solution_found = false
    if !app["nosolve"]
        (status, solution_found, optimizer, x, z) = if isempty(app["tentative"])
            solve_ccvrp(data, app, instance_name, app["ub"])
        else
            solve_ccvrp_tentative(data, app, instance_name, app["ub"])
        end
        if solution_found
            # checks the values of x against the problem definition, then recovers the routes from them
            checksolution_x(data, Dict(e => get_value(optimizer, x[e]) for e in edges(data)),
                            get_objective_value(optimizer), app)
            sol = getsolution(data, optimizer, x, get_objective_value(optimizer), app)
        end
    end

    println("########################################################")
    retval = Inf
    if solution_found || app["sol"] !== nothing # Is there a solution?
        checksolution(data, sol, app)
        print_routes(sol)
        println("Cost $(sol.cost)")
        if app["out"] !== nothing
            writesolution(app["out"], sol)
        end
        if app["tikz"] !== nothing
            if data.coord
                drawsolution(app["tikz"], data, sol) # write tikz figure
            else
                println(
                    "TikZ figure ($(app["tikz"])) will not be generated, since the instance has no coordinates.",
                )
            end
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
            run_cvrp(app_line)
        end
        return 0.0
    else
        return run_cvrp(app)
    end
end

export main
end
