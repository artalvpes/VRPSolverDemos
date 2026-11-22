__precompile__(false)
module VRPSPDSolverDemo
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
        default = "$appfolder/../config/VRPSPD.cfg"
        "--ub", "-u"
        help = "Upper bound (primal bound)"
        arg_type = Float64
        default = 10000000.0
        "--minr", "-m"
        help = "Minimum number of routes in the solution"
        arg_type = Int
        default = 1
        "--maxr", "-M"
        help = "Maximum number of routes in the solution"
        arg_type = Int
        default = 999
        "--noheur"
        help = "Does not call GenericILS to compute an upper bound"
        action = :store_true
        "--heurtime"
        help = "Time (in seconds) of the GenericILS heuristic that computes the upper bound"
        arg_type = Float64
        default = 20.0
        "--seed"
        help = "Seed of the GenericILS heuristic"
        arg_type = Int
        default = 1
        "--show_complete_form", "-f"
        help = "Show the complete formulation including all feasible paths"
        action = :store_true
        "--update"
        help = "Update the VrpSolver and GenericILS packages"
        action = :store_true
        "--out", "-o"
        help = "Path to write the solution found"
        "--nosolve", "-n"
        help = "Does not call the VRPSolver. Only the heuristic (if it is not disabled by --noheur)."
        action = :store_true
        "--batch", "-b"
        help = "batch file path"
    end
    return parse_args(args_array, s)
end

# Upper bound from GenericILS: solves the VRPSolver model with the NILS heuristic. It returns a checked Solution, or
# nothing if the heuristic fails or finds no feasible solution (the BCP does not depend on it).
function heuristic_solution(data::DataVRPSPD, model::VrpModel, app::Dict{String,Any})
    try
        println("Computing an upper bound with GenericILS ($(app["heurtime"]) s)")
        flush(stdout)
        routes = Heuristic.solve(model; cppDir=joinpath(@__DIR__, "meta_solver"), time=app["heurtime"], seed=app["seed"])
        if routes === nothing
            println("GenericILS found no feasible solution")
            return nothing
        end
        sol = Solution(0.0, routes)
        sol.cost = sum(route_distance(data, r) for r in routes)
        checksolution(data, sol) # the heuristic only provides routes: the cost and the feasibility are checked here
        println("GenericILS upper bound: $(sol.cost)")
        return sol
    catch e
        println("GenericILS failed, the VRPSolver will run without its upper bound:")
        showerror(stdout, e)
        println()
        return nothing
    end
end

function run_vrpspd(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    instance_name = split(basename(app["instance"]), ".")[1]

    data = readVRPSPDData(app)

    (model, x) = build_model(data, app)

    sol = nothing # best solution known
    if !app["noheur"]
        sol = heuristic_solution(data, model, app)
        if sol !== nothing
            # the VRPSolver looks for solutions with cost up to the cutoff, so the solution of the heuristic is kept
            # (and found again) if it is optimal
            app["ub"] = min(app["ub"], sol.cost + max(1e-4, 1e-9 * abs(sol.cost)))
        end
    end

    if !app["nosolve"]
        if app["show_complete_form"]
            enum_paths, complete_form = get_complete_formulation(model, app["cfg"])
            set_optimizer(complete_form, HiGHS.Optimizer) # set MIP solver
            print_enum_paths(enum_paths)
            println(complete_form)
            optimize!(complete_form)
        end

        optimizer = VrpOptimizer(model, app["cfg"], instance_name)
        set_cutoff!(optimizer, app["ub"])
        (status, solution_found) = optimize!(optimizer)
        if solution_found
            found = getsolution(data, optimizer, x, get_objective_value(optimizer), app)
            checksolution(data, found)
            if sol === nothing || found.cost < sol.cost
                sol = found
            end
        end
    end

    println("########################################################")
    retval = Inf
    if sol !== nothing
        print_routes(sol)
        println("Cost $(sol.cost)")
        if app["out"] !== nothing
            writesolution(app["out"], sol)
        end
        retval = sol.cost
    elseif !app["nosolve"]
        println("Solution not found")
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
            run_vrpspd(app_line)
        end
        return 0.0
    else
        return run_vrpspd(app)
    end
end

export main
end
