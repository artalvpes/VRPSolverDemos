module TOPSolverDemo

using VrpSolver, JuMP, ArgParse, HiGHS

include("data.jl")
include("model.jl")
include("solution.jl")
include("heuristic.jl")

function parse_commandline(args_array::Array{String,1}, appfolder::String)
    s = ArgParseSettings(;
        usage="##### VRPSolver #####\n\n" *
              "  On interactive mode, call main([\"arg1\", ..., \"argn\"])",
        exit_after_help=false,
    )
    @add_arg_table s begin
        "instance"
        help = "Instance file path"
        "--cfg", "-c"
        help = "Configuration file path"
        default = "$appfolder/../config/TOP.cfg"
        "--ub", "-u"
        help = "Upper bound (primal bound) on the cost (minus the total profit). If not given, the heuristic of " *
               "heuristic.jl gives it (- profit + 1)."
        arg_type = Float64
        "--noheur"
        help = "Without --ub, do not run the heuristic (the empty solution gives the upper bound 1)"
        action = :store_true
        "--tentative", "-t", "-T"
        help = "Tentative upper bounds DELTA1 DELTA2: solve the root with the upper bound to get its lower bound LB, " *
               "then solve with the upper bounds LB + DELTA1, LB + DELTA1 + DELTA2, LB + DELTA1 + 2 DELTA2, ... " *
               "(never above the upper bound) until a solution is found"
        nargs = 2
        arg_type = Float64
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
function solve_top(data, app::Dict{String,Any}, instance_name, ub::Float64; root_only::Bool=false)
    (model, x, y) = build_model(data)
    cfg = root_only ? cfg_with_params(app["cfg"], ROOT_ONLY_PARAMS) : app["cfg"]
    optimizer = VrpOptimizer(model, cfg, instance_name)
    root_only && rm(cfg) # the parameters are read when the optimizer is created
    set_cutoff!(optimizer, ub)
    (status, solution_found) = optimize!(optimizer)
    return status, solution_found, optimizer, x, y
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
function solve_top_tentative(data, app::Dict{String,Any}, instance_name, ub_max::Float64)
    delta1, delta2 = app["tentative"]
    delta2 > 0 || error("the second value of --tentative (delta2) must be positive")
    t0 = time()
    println("Tentative upper bounds: solving the root node with ub = $ub_max")
    res = solve_top(data, app, instance_name, ub_max; root_only=true)
    res[1] == :Optimal && return res # solved (or proved infeasible) at the root
    root_lb = res[3].stats[:bcRecRootDb]
    if !(root_lb > -1e11) # the root lower bound was not computed (time limit): no tentative upper bounds
        println("Tentative upper bounds: the root lower bound is not available; solving with ub = $ub_max")
        return solve_top(data, app, instance_name, ub_max)
    end
    base = true ? ceil(root_lb - 1e-6) : root_lb
    best_lb = run_lower_bound(res[1], res[2], res[3], ub_max)
    k = 0
    while true
        ub = min(base + delta1 + k * delta2, ub_max)
        println("Tentative upper bounds: run $(k + 1) with ub = $ub (root lower bound $root_lb)")
        res = solve_top(data, app, instance_name, ub)
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

function run_top(app)
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    instance_name = split(
        split(app["instance"], dirname(app["instance"]) * "/")[2], ".txt"
    )[1]

    data = readTOPData(app["instance"])

    if isnothing(app["ub"])
        # the empty solution has cost 0, so 1 is a valid upper bound of the scale of the problem
        app["ub"] = 1.0
        if !app["noheur"]
            t = @elapsed (heur_routes, heur_profit) = top_heuristic(data)
            # checks the heuristic solution: at most F routes, each customer at most once, route times at most T
            visited = vcat(heur_routes...)
            (length(heur_routes) <= data.F && allunique(visited) && all(1 <= i <= data.n for i in visited) &&
             all(top_route_time(data, r) <= data.T + 1e-6 for r in heur_routes)) || error("Invalid heuristic solution")
            # ub = - profit + 1: the solver must return a solution at least as good as the heuristic one
            app["ub"] = -heur_profit + 1.0
            println("Heuristic solution of profit $heur_profit with $(length(heur_routes)) routes " *
                    "($(round(t; digits=2)) s): ub = $(app["ub"])")
        end
    end

    (status, solution_found, optimizer, x, y) = if isempty(app["tentative"])
        solve_top(data, app, instance_name, app["ub"])
    else
        solve_top_tentative(data, app, instance_name, app["ub"])
    end

    println("########################################################")
    if solution_found # Is there a solution?
        for a in arcs(data)
            if get_value(optimizer, x[a]) > 0.0
                println("x[$a] = $(get_value(optimizer, x[a]))")
            end
        end
        # checks the values of x and y against the problem definition, then recovers the routes from them
        checksolution_x(data, Dict(a => get_value(optimizer, x[a]) for a in arcs(data)),
                        Dict(i => get_value(optimizer, y[i]) for i in 1:num_customers(data)), get_objective_value(optimizer))
        sol = getsolution(data, x, get_objective_value(optimizer), optimizer)
        print_routes(sol)
        println("Cost $(sol.cost)")
    elseif status == :Optimal
        println("Problem infeasible")
    else
        println("Solution not found")
    end
    println("########################################################")
end

function main(args)
    appfolder = dirname(@__FILE__)
    app = parse_commandline(args, appfolder)
    isnothing(app) && return nothing
    if !isnothing(app["batch"])
        for line in readlines(app["batch"])
            if isempty(strip(line)) || strip(line)[1] == '#'
                continue
            end
            args_array = [String(s) for s in split(line)]
            app_line = parse_commandline(args_array, appfolder)
            run_top(app_line)
        end
    else
        run_top(app)
    end
end

export main

end # module TOPSolverDemo
