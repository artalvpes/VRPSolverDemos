# Compact MIP formulation of the generalized assignment problem, solved by CPLEX. It gives reference values
# (optima, bounds) for the GAP demo and helps to choose instances that are within the reach of the tools.
#
# usage: julia --project=. gap_mip.jl [--threads N] [--timelimit S] [--ub UB] [--nolp] instance1 [instance2 ...]
#
#   min  sum_{t,k} c_tk x_tk
#   s.t. sum_k x_tk = 1               t in T  (each task is assigned to one machine)
#        sum_t w_tk x_tk <= Q_k       k in K  (capacity of machine k)
#        x_tk in {0, 1}

using JuMP, CPLEX, ArgParse, Printf

include(joinpath(@__DIR__, "..", "src", "data.jl"))

function build_model(data::DataGap)
    T, K = tasks(data), machines(data)
    model = Model(CPLEX.Optimizer)
    @variable(model, x[t in T, k in K], Bin)
    @objective(model, Min, sum(c(data, t, k) * x[t, k] for t in T, k in K))
    @constraint(model, assign[t in T], sum(x[t, k] for k in K) == 1)
    @constraint(model, cap[k in K], sum(w(data, t, k) * x[t, k] for t in T) <= capacity(data)[k])
    return model, x
end

# Checks the solution x with value z directly against the definition of the GAP, assuming nothing about how it
# was obtained (see Note 6.12 of the book "Optimizing with Column Generation"). The MIP tolerances of CPLEX are
# 1e-5 on integrality and 1e-6 on feasibility, hence the tolerance 1e-4. Throws an error otherwise.
function checksolution(data::DataGap, xval::Dict, z::Float64)
    T, K, tol = tasks(data), machines(data), 1e-4
    for t in T, k in K
        v = xval[t, k]
        (abs(v) > tol && abs(v - 1) > tol) && error("x[$t,$k] = $v is not binary")
    end
    for t in T
        s = sum(xval[t, k] for k in K)
        (abs(s - 1) > tol) && error("Task $t: the sum of x[$t,k] over the machines is $s, not 1")
    end
    for k in K
        load = sum(w(data, t, k) * xval[t, k] for t in T)
        (load > capacity(data)[k] + tol) && error("Machine $k: load $load exceeds the capacity $(capacity(data)[k])")
    end
    cost = sum(c(data, t, k) * xval[t, k] for t in T, k in K)
    (abs(cost - z) > tol * max(1, abs(z))) && error("Cost calculated from x ($cost) is different from the objective value ($z)")
end

function solve(path::String, opts)
    name = split(basename(path), ".")[1]
    data = readGAPData(path)
    T, K = tasks(data), machines(data)
    model, x = build_model(data)
    set_silent(model)
    set_attribute(model, "CPXPARAM_Threads", opts["threads"])
    set_attribute(model, "CPXPARAM_MIP_Tolerances_MIPGap", 0.0) # exact optimality (default relative gap is 1e-4)
    opts["timelimit"] > 0 && set_attribute(model, "CPXPARAM_TimeLimit", opts["timelimit"])
    # Cutoff: only solutions with cost <= ub are searched (same role as -u in the VRPSolver demo)
    isnothing(opts["ub"]) || set_attribute(model, "CPXPARAM_MIP_Tolerances_UpperCutoff", opts["ub"])
    println("Instance $name: $(length(K)) machines, $(length(T)) tasks")
    lp = NaN
    if !opts["nolp"]
        undo = relax_integrality(model)
        t1 = time()
        optimize!(model)
        lp = objective_value(model)
        @printf("LP relaxation: %.4f (%.2f s)\n", lp, time() - t1)
        undo()
    end
    unset_silent(model)
    t1 = time()
    optimize!(model)
    tmip = time() - t1
    st = termination_status(model)
    nodes = MOI.get(model, MOI.NodeCount())
    bound = objective_bound(model)
    println("########################################################")
    if primal_status(model) == FEASIBLE_POINT
        z = objective_value(model)
        xval = Dict((t, k) => value(x[t, k]) for t in T, k in K)
        checksolution(data, xval, z)
        machine_of = [only(k for k in K if xval[t, k] > 0.5) for t in T]
        for k in K
            tasks_k = [t for t in T if machine_of[t] == k]
            load = sum(data.weight[t, k] for t in tasks_k; init=0)
            println("machine $k: $(join(tasks_k, " ")) (load $load of $(capacity(data)[k]))")
        end
        println("Cost $(round(Int, z)) (status $st, solution checked)")
        inc = string(round(Int, z))
    else
        println("No solution found (status $st)")
        inc = "--"
    end
    println("########################################################")
    # columns: instance & LP bound & nodes & best bound & incumbent & MIP time
    @printf("statistics: %s & %.2f & %d & %.2f & %s & %.2f \\\\\n", name, lp, nodes, bound, inc, tmip)
    flush(stdout)
end

function main(args)
    s = ArgParseSettings(description="Compact MIP for the generalized assignment problem (CPLEX)")
    @add_arg_table s begin
        "instances"
        help = "Instance file paths"
        nargs = '+'
        "--threads"
        help = "Number of CPLEX threads"
        arg_type = Int
        default = 1
        "--timelimit"
        help = "CPLEX time limit in seconds (0 = no limit)"
        arg_type = Float64
        default = 0.0
        "--ub", "-u"
        help = "Upper bound (cutoff): CPLEX only looks for solutions with cost <= ub"
        arg_type = Float64
        "--nolp"
        help = "Do not solve the LP relaxation first"
        action = :store_true
    end
    opts = parse_args(args, s)
    for path in opts["instances"]
        solve(path, opts)
    end
end

main(ARGS)
