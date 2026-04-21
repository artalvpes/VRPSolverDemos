__precompile__(false)
module CVRPSolverDemo
using VrpSolver, JuMP, ArgParse, HiGHS, DataStructures

include("data.jl")
include("branching.jl")
include("model.jl")
include("solution.jl")

function parse_commandline(args_array::Vector{String}, appfolder::String)
    s = ArgParseSettings(
        usage="##### VRPSolver #####\n\n" *
              "  On interactive mode, call main([\"arg1\", ..., \"argn\"])", exit_after_help=false)
    @add_arg_table s begin
        "instance"
        help = "Instance file path"
        "--cfg", "-c"
        help = "Configuration file path"
        default = "$appfolder/../config/CVRP.cfg"
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
        "--edge_cuts", "-e"
        help = "Use edge cuts via cut callback."
        action = :store_true
        "--strong_kpath_cuts", "-k"
        help = "Use strong k-path cuts."
        action = :store_true
        "--cluster_branching", "-B"
        help = "Cluster branching parameter value (0 = disabled)"
        arg_type = Float64
        default = 1.0
        "--single_resource", "-R"
        help = "Use a single resource (omit the capacity resource if distance constrained)"
        action = :store_true
        "--low_edge_priority", "-l"
        help = "Set a low priority to edge branching"
        action = :store_true
    end
    return parse_args(args_array, s)
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
        checksolution(data, sol) # checks the solution feasibility
        app["ub"] = (sol.cost < app["ub"]) ? sol.cost : app["ub"] # update the upper bound if necessary
    end

    solution_found = false
    if !app["nosolve"]
        (model, x) = build_model(data, app)

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
            sol = getsolution(data, optimizer, x, get_objective_value(optimizer), app)
        end
    end

    println("########################################################")
    retval = Inf
    if solution_found || app["sol"] !== nothing # Is there a solution?
        checksolution(data, sol)
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
