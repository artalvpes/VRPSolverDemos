__precompile__(false)
module PDPTWSolverDemo
using ColunaVrpSolver, JuMP, ArgParse


include("data.jl")
include("model.jl")
include("solution.jl")

function parse_commandline(args_array::Array{String, 1}, appfolder::String)
    s = ArgParseSettings(
        usage = "##### VRPSolver #####\n\n" *
                "  On interactive mode, call main([\"arg1\", ..., \"argn\"])", exit_after_help = false)
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
        help = "Upper bound (primal bound) on the route costs. This value must be associated with the number of vehicles defined by --maxr (or -M)."
        arg_type = Float64
        default = 10000000.0
        "--round", "-r"
        help = "Round the distance matrix"
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

function run_pdptw(app::Dict{String, Any})
    println("Application parameters:")
    for (arg, val) in app
        if val == nothing
            println("  $arg  =>  nothing")
        else
            println("  $arg  =>  $val")
        end
    end
    flush(stdout)

    instance_name = String(split(basename(app["instance"]), ".")[1])

    if app["sol"] != nothing
        sol = readsolution(app["sol"])
        app["ub"] = (sol.cost < app["ub"]) ? sol.cost : app["ub"] # update the upper bound if necessary
    end

    if app["lilim"]
        data = readLiLimData(app["instance"], app["round"])
        solution_found = false
        if !app["nosolve"]
            (model, x) = build_model(data, app)
            println("model is built")
            optimizer = VrpOptimizer(model, app["cfg"], instance_name)
            set_cutoff!(optimizer, app["ub"])
            (status, solution_found) = optimize!(optimizer)
            if solution_found
                sol = getsolution(data, x, get_objective_value(optimizer), optimizer, app)
            end
        end
    else # Ropke instances
        data = readRopkeData(app["instance"], app["round"])

        solution_found = false
        if !app["nosolve"]
            for k in app["maxr"]:-1:app["minr"]
                (model, x) = build_model(data, app, k = k) # problem with fixed fleet with k vehicles
                optimizer = VrpOptimizer(model, app["cfg"], instance_name)
                set_cutoff!(optimizer, app["ub"])
                (status, solution_found_aux) = optimize!(optimizer)
                if solution_found_aux
                    sol = getsolution(data, x, get_objective_value(optimizer), optimizer, app)
                    solution_found = true
                else
                    break
                end
            end
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