__precompile__(false)
module VSBPPSolverDemo
using VrpSolver, JuMP, ArgParse

include("data.jl")
include("model.jl")
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
        default = "$appfolder/../config/VSBPP.cfg"
        "--ub", "-u"
        help = "Upper bound (primal bound). If not given, the heuristic of heuristic.jl gives the upper bound."
        arg_type = Float64
        "--noheur"
        help = "Without --ub, do not run the heuristic (no upper bound)"
        action = :store_true
        "--batch", "-b"
        help = "batch file path"
        "--tentative", "-t", "-T"
        help = "Tentative upper bounds DELTA1 DELTA2: solve the root with the upper bound (from --ub or the heuristic) " *
               "to get its lower bound LB, then solve with the upper bounds LB + DELTA1, LB + DELTA1 + DELTA2, " *
               "LB + DELTA1 + 2 DELTA2, ... (never above the upper bound) until a solution is found"
        nargs = 2
        arg_type = Float64
    end
    return parse_args(args_array, s)
end

# Cutting patterns of the solution: a vector of (stock type, items) and the items not produced
function get_patterns(optimizer::VrpOptimizer, data::DataVSBPP, produce_arc::Vector{Int}, stock_arc::Vector{Int})
    item_of = Dict(produce_arc[j] => j for j in items(data))
    type_of = Dict(stock_arc[k] => k for k in stock_types(data))
    patterns = Tuple{Int,Vector{Int}}[]
    for path_id in 1:get_number_of_positive_paths(optimizer)
        val = round(Int, get_value(optimizer, path_id))
        _, arcs = get_path_arcs(optimizer, path_id)
        arcs = [a.id for a in arcs]
        its = [item_of[a] for a in arcs if haskey(item_of, a)]
        k = only(type_of[a] for a in arcs if haskey(type_of, a))
        for _ in 1:val
            push!(patterns, (k, its))
        end
    end
    return patterns
end

# Checks the solution feasibility and returns its cost
function check_solution(data::DataVSBPP, patterns)
    used = zeros(Int, length(data.W))
    produced = zeros(Int, length(data.w))
    cost = 0
    for (k, its) in patterns
        sum(data.w[its]; init=0) <= data.W[k] || error("Pattern exceeds the length of stock type $k: $its")
        used[k] += 1
        produced[its] .+= 1
        cost += data.c[k]
    end
    all(used .<= data.u) || error("Availability of some stock type exceeded: $used")
    all(produced .<= 1) || error("Some item produced more than once")
    cost += sum(data.p[j] for j in items(data) if produced[j] == 0; init=0)
    return cost
end

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
# and the arcs needed to recover the cutting patterns.
function solve_vsbpp(data::DataVSBPP, app::Dict{String,Any}, instance_name, ub::Float64; root_only::Bool=false)
    (model, x, t, G, produce_arc, stock_arc) = build_model(data)
    cfg = root_only ? cfg_with_params(app["cfg"], ROOT_ONLY_PARAMS) : app["cfg"]
    optimizer = VrpOptimizer(model, cfg, instance_name)
    root_only && rm(cfg) # the parameters are read when the optimizer is created
    set_cutoff!(optimizer, ub)
    (status, solution_found) = optimize!(optimizer)
    return status, solution_found, optimizer, produce_arc, stock_arc
end

# Valid lower bound on the optimal cost after a run with the cutoff ub: if the run ends with the status Optimal, its
# solution is optimal, or there is no solution of cost below ub; otherwise (time limit), the global dual bound of the
# run is valid for the solutions of cost below ub, and it is at most ub.
function run_lower_bound(status, solution_found, optimizer, ub)
    status == :Optimal && return solution_found ? get_objective_value(optimizer) : ub
    return min(optimizer.stats[:bcRecBestDb], ub)
end

# Tentative upper bounds (as in the GAP demo): the root node is first solved with the upper bound ub, giving the
# root lower bound LB. Then the problem is solved with the cutoffs ceil(LB) + delta1, ceil(LB) + delta1 + delta2,
# ceil(LB) + delta1 + 2 delta2, ... (never above ub), until a solution is found. A run that ends without a
# solution but with the status Optimal proves that there is no solution below its cutoff, so the next cutoff
# can be tried.
function solve_vsbpp_tentative(data::DataVSBPP, app::Dict{String,Any}, instance_name, ub_max::Float64)
    delta1, delta2 = app["tentative"]
    delta2 > 0 || error("the second value of --tentative (delta2) must be positive")
    t0 = time()
    println("Tentative upper bounds: solving the root node with ub = $ub_max")
    res = solve_vsbpp(data, app, instance_name, ub_max; root_only=true)
    res[1] == :Optimal && return res # solved (or proved infeasible) at the root
    root_lb = res[3].stats[:bcRecRootDb]
    if !(root_lb > -1e11) # the root lower bound was not computed (time limit): no tentative upper bounds
        println("Tentative upper bounds: the root lower bound is not available; solving with ub = $ub_max")
        return solve_vsbpp(data, app, instance_name, ub_max)
    end
    best_lb = run_lower_bound(res[1], res[2], res[3], ub_max)
    k = 0
    while true
        ub = min(ceil(root_lb - 1e-6) + delta1 + k * delta2, ub_max)
        println("Tentative upper bounds: run $(k + 1) with ub = $ub (root lower bound $root_lb)")
        res = solve_vsbpp(data, app, instance_name, ub)
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

function run_vsbpp(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    instance_name = split(basename(app["instance"]), ".")[1]
    data = readVSBPPData(app["instance"])
    println(data)

    ub = app["ub"]
    if isnothing(ub)
        if app["noheur"]
            ub = 10000000.0
        else
            theur = @elapsed (heur_patterns, heur_cost) = vsbpp_heuristic(data)
            check_solution(data, heur_patterns) == heur_cost || error("Wrong cost of the heuristic solution")
            # ub = heuristic cost + 1: the solver must return a solution, at least as good as the heuristic one
            ub = heur_cost + 1.0
            println("Heuristic solution of cost $heur_cost ($(length(heur_patterns)) stocks, $(round(theur; digits=2)) s): ub = $ub")
        end
    end
    (status, solution_found, optimizer, produce_arc, stock_arc) = if isempty(app["tentative"])
        solve_vsbpp(data, app, instance_name, ub)
    else
        solve_vsbpp_tentative(data, app, instance_name, ub)
    end

    println("########################################################")
    if solution_found
        patterns = get_patterns(optimizer, data, produce_arc, stock_arc)
        sort!(patterns)
        for (n, (k, its)) in enumerate(patterns)
            println("Stock $n of type $k (length $(data.W[k]), cost $(data.c[k])): items $(join(its, " ")) " *
                    "(used length $(sum(data.w[its]; init=0)))")
        end
        produced = Set(j for (_, its) in patterns for j in its)
        not_produced = [j for j in items(data) if !(j in produced)]
        println("Items not produced: $(isempty(not_produced) ? "none" : join(not_produced, " ")) " *
                "(penalties $(sum(data.p[not_produced]; init=0)))")
        cost = check_solution(data, patterns)
        println("Cost $cost (objective value $(get_objective_value(optimizer)))")
        println("Solution checked: feasible, cost $cost")
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
    isnothing(app) && return
    if !isnothing(app["batch"])
        for line in readlines(app["batch"])
            if isempty(strip(line)) || strip(line)[1] == '#'
                continue
            end
            args_array = [String(s) for s in split(line)]
            app_line = parse_commandline(args_array, appfolder)
            run_vsbpp(app_line)
            flush(stdout)
        end
    else
        run_vsbpp(app)
    end
end

export main
end
