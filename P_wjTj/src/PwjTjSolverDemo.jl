__precompile__(false)
module PwjTjSolverDemo
using VrpSolver, JuMP, ArgParse

include("data.jl")
include("model.jl")
include("solution.jl")

function parse_commandline(args_array::Array{String,1}, appfolder::String)
    s = ArgParseSettings(usage="##### VRPSolver #####\n\n" *
                               "  On interactive mode, call main([\"arg1\", ..., \"argn\"])",
        exit_after_help=false)
    @add_arg_table s begin
        "instance"
        help = "Instance file path"
        "--update"
        help = "Update the VrpSolver package"
        action = :store_true
        "--cfg", "-c"
        help = "Configuration file path"
        default = "$appfolder/../config/PwjTj.cfg"
        "--ub", "-u"
        help = "Upper bound (best known solution cost + 1)"
        arg_type = Float64
        default = 10000000.0
        "--out", "-o"
        help = "Path to write the solution found"
        "--nosolve", "-n"
        help = "Does not call the VRPSolver (dry run)"
        action = :store_true
        "--batch", "-b"
        help = "Batch file path"
    end
    return parse_args(args_array, s)
end

function run_pwjtj(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    instance_name = splitext(basename(app["instance"]))[1]

    data = readPwjTjData(app["instance"])

    solution_found = false
    if !app["nosolve"]
        (model, x, A) = build_model(data, app)
        optimizer = VrpOptimizer(model, app["cfg"], instance_name)
        set_cutoff!(optimizer, app["ub"])

        (status, solution_found) = optimize!(optimizer)
        if solution_found
            sol = getsolution(data, x, A, get_objective_value(optimizer), optimizer)
        end
    end

    println("########################################################")
    if solution_found
        print_schedules(data, sol)
        println("Cost $(sol.cost)")
        if app["out"] !== nothing
            writesolution(app["out"], sol)
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
    if app["batch"] !== nothing
        for line in readlines(app["batch"])
            if isempty(strip(line)) || strip(line)[1] == '#'
                continue
            end
            args_array = [String(s) for s in split(line)]
            app_line = parse_commandline(args_array, appfolder)
            run_pwjtj(app_line)
        end
    else
        run_pwjtj(app)
    end
end

export main

end
