__precompile__(false)
module CRSPSolverDemo
using VrpSolver, JuMP, ArgParse, HiGHS, CPLEX

include("data.jl")
include("rcc_separation.jl")
include("model.jl")
include("solution.jl")
include("compact_model.jl")

function parse_commandline(args_array::Vector{String}, appfolder::String)
    s = ArgParseSettings(
        usage="##### VRPSolver #####\n\n" *
              "  On interactive mode, call main([\"arg1\", ..., \"argn\"])", exit_after_help=false)
    @add_arg_table s begin
        "instance"
        help = "Instance file path (CVRPLIB format, converted into a CRSP instance)"
        "--cfg", "-c"
        help = "Configuration file path"
        default = "$appfolder/../config/CRSP.cfg"
        "--ub", "-u"
        help = "Upper bound (primal bound)"
        arg_type = Float64
        default = 10000000.0
        "--steiner_pct", "-p"
        help = "Percentage of the non-root vertices that are Steiner points (the first ones in the instance)"
        arg_type = Float64
        default = 25.0
        "--star_size", "-k"
        help = "Number of closest terminals in each set T(i) of possible star connections"
        arg_type = Int
        default = 3
        "--star_cost_factor", "-a"
        help = "Cost reduction factor of the star connections: b_ij = factor * distance(i,j)"
        arg_type = Float64
        default = 0.5
        "--compact", "-m"
        help = "Solves the set partitioning MIP over all enumerated ring-stars with CPLEX instead of calling the VRPSolver (only for small capacities)"
        action = :store_true
        "--no_capacity_cuts", "-x"
        help = "Does not separate the strengthened rounded capacity cuts (Section 6.4.9)"
        action = :store_true
        "--no_steiner_elem_sets", "-e"
        help = "Does not define the additional elementarity sets for the Steiner points"
        action = :store_true
        "--noround", "-r"
        help = "Does not round the distance matrix"
        action = :store_true
        "--show_complete_form", "-f"
        help = "Show the complete formulation including all feasible paths"
        action = :store_true
        "--update"
        help = "Update the VrpSolver package"
        action = :store_true
        "--out", "-o"
        help = "Path to write the solution found"
        "--tikz", "-t"
        help = "Path to write the TikZ figure of the solution found."
        "--nosolve", "-n"
        help = "Does not call the VRPSolver. Only to build and print the instance."
        action = :store_true
        "--batch", "-b"
        help = "batch file path"
    end
    return parse_args(args_array, s)
end

function run_crsp(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    instance_name = string(split(basename(app["instance"]), ".")[1])

    data = readCRSPData(app)
    print_instance(data)

    solution_found = false
    if !app["nosolve"] && app["compact"]
        (status, solution_found, sol) = solve_compact_model(data, app)
    elseif !app["nosolve"]
        (model, x, z) = build_model(data, app)

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
            sol = getsolution(data, optimizer, x, z, get_objective_value(optimizer), app)
        end
    end

    println("########################################################")
    retval = Inf
    if solution_found
        checksolution(data, sol)
        print_ringstars(sol)
        println("Cost $(sol.cost)")
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
            run_crsp(app_line)
        end
        return 0.0
    else
        return run_crsp(app)
    end
end

export main
end
