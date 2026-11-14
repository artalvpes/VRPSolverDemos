# Arc-flow MIP (adaptation of Valério de Carvalho's model for the BPP) for the variable-sized bin packing
# with penalties, solved by CPLEX.
#
# usage: julia --project=. arcflow.jl [--reduced] [--ub UB] [--threads N] [--timelimit S] [--nolp] instance1 [instance2 ...]
#
# Graph: nodes are positions along a bin. An item arc (j, a, a + w_j) means that item j is cut at position a of
# some bin. A return arc ends a bin of type k and its flow t_k is the number of bins of type k used.
#   basic model : positions 0..Wmax, all item arcs, unit loss arcs (a, a+1), return arcs (W_k, 0).
#   --reduced   : items in decreasing length order; positions reachable by subset sums; arc (j, a, a + w_j) only if
#                 a is reachable with the items before j; loss only after the last item, through a terminal node
#                 T_k per stock type: final loss arcs (v, T_k) for v <= W_k and return arcs (T_k, 0).
# Both models have the same integer optimum and the same LP bound.

using JuMP, CPLEX, ArgParse, Printf

include(joinpath(@__DIR__, "..", "src", "data.jl"))

struct Arc
    tail::Int # node index
    head::Int
    kind::Symbol # :item, :loss or :return
    id::Int # item j for :item arcs, stock type k for :return arcs, 0 for :loss arcs
end

# Builds the arc-flow graph. Nodes 1..Wmax+1 are the positions 0..Wmax; nodes Wmax+1+k are the terminals T_k.
function build_graph(data::DataVSBPP, reduced::Bool)
    J, K = items(data), stock_types(data)
    Wmax = maximum(data.W)
    pos(a) = a + 1
    arcs = Arc[]
    if !reduced
        for j in J, a in 0:Wmax-data.w[j]
            push!(arcs, Arc(pos(a), pos(a + data.w[j]), :item, j))
        end
        for a in 0:Wmax-1
            push!(arcs, Arc(pos(a), pos(a + 1), :loss, 0))
        end
        for k in K
            push!(arcs, Arc(pos(data.W[k]), pos(0), :return, k))
        end
        used = trues(Wmax + 1)
        return arcs, vcat(used, falses(length(K)))
    end
    # Subset-sum reachability with the items in decreasing length order: before processing item j,
    # reach[a+1] is true if position a is the total length of a subset of the previous items.
    order = sortperm(data.w, rev=true)
    reach = falses(Wmax + 1)
    reach[1] = true
    for j in order
        w = data.w[j]
        starts = findall(reach[1:Wmax+1-w]) .- 1 # positions a in R_{j-1} with a + w <= Wmax
        for a in starts
            push!(arcs, Arc(pos(a), pos(a + w), :item, j))
        end
        reach[starts.+(w+1)] .= true
    end
    for k in K, v in findall(reach[1:data.W[k]+1]) .- 1
        push!(arcs, Arc(pos(v), Wmax + 1 + k, :loss, 0)) # final loss W_k - v (zero if v = W_k)
    end
    for k in K
        push!(arcs, Arc(Wmax + 1 + k, pos(0), :return, k))
    end
    return arcs, vcat(reach, trues(length(K)))
end

function build_model(data::DataVSBPP, arcs::Vector{Arc}, used_nodes::BitVector)
    J, K = items(data), stock_types(data)
    A = eachindex(arcs)
    model = Model(CPLEX.Optimizer)
    @variable(model, f[A] >= 0, Int) # flow on each arc
    @variable(model, y[J], Bin) # y[j] = 1 if item j is not produced
    t(k) = only(f[i] for i in A if arcs[i].kind == :return && arcs[i].id == k)
    @objective(model, Min, sum(data.c[k] * t(k) for k in K) + sum(data.p[j] * y[j] for j in J))
    item_arcs = [Int[] for j in J]
    for i in A
        arcs[i].kind == :item && push!(item_arcs[arcs[i].id], i)
    end
    @constraint(model, prod[j in J], sum(f[i] for i in item_arcs[j]; init=0) + y[j] == 1)
    @constraint(model, avail[k in K], t(k) <= data.u[k])
    inflow = [Int[] for _ in used_nodes]
    outflow = [Int[] for _ in used_nodes]
    for i in A
        push!(outflow[arcs[i].tail], i)
        push!(inflow[arcs[i].head], i)
    end
    for v in findall(used_nodes)
        (isempty(inflow[v]) && isempty(outflow[v])) && continue
        @constraint(model, sum(f[i] for i in inflow[v]; init=0) == sum(f[i] for i in outflow[v]; init=0))
    end
    return model, f, y
end

# Decomposes the integer circulation into bins: each cycle from position 0 uses exactly one return arc
function decompose(data::DataVSBPP, arcs::Vector{Arc}, flow::Vector{Int})
    out = Dict{Int,Vector{Int}}()
    for i in eachindex(arcs)
        flow[i] > 0 && push!(get!(out, arcs[i].tail, Int[]), i)
    end
    bins = Tuple{Int,Vector{Int}}[]
    while true
        v, its = 1, Int[]
        first_arc = findfirst(i -> flow[i] > 0, get(out, 1, Int[]))
        isnothing(first_arc) && break
        while true
            i = out[v][findfirst(i -> flow[i] > 0, out[v])]
            flow[i] -= 1
            arcs[i].kind == :item && push!(its, arcs[i].id)
            if arcs[i].kind == :return
                push!(bins, (arcs[i].id, sort(its)))
                break
            end
            v = arcs[i].head
        end
    end
    all(flow .== 0) || error("flow decomposition failed")
    return bins
end

function solve(path::String, opts)
    name = split(basename(path), ".")[1]
    data = readVSBPPData(path)
    t0 = time()
    arcs, used_nodes = build_graph(data, opts["reduced"])
    model, f, y = build_model(data, arcs, used_nodes)
    set_silent(model)
    set_attribute(model, "CPXPARAM_Threads", opts["threads"])
    set_attribute(model, "CPXPARAM_MIP_Tolerances_MIPGap", 0.0) # exact optimality (default relative gap is 1e-4)
    opts["timelimit"] > 0 && set_attribute(model, "CPXPARAM_TimeLimit", opts["timelimit"])
    # Cutoff: only solutions with cost <= ub are searched (same role as -u in the VRPSolver demo)
    isnothing(opts["ub"]) || set_attribute(model, "CPXPARAM_MIP_Tolerances_UpperCutoff", opts["ub"])
    tbuild = time() - t0
    nitem = count(a -> a.kind == :item, arcs)
    nloss = count(a -> a.kind == :loss, arcs)
    @printf("Instance %s, %s model: %d nodes, %d item arcs, %d loss arcs, %d return arcs, %d constraints (built in %.2f s)\n",
            name, opts["reduced"] ? "reduced" : "basic", count(used_nodes), nitem, nloss, length(data.W),
            num_constraints(model; count_variable_in_set_constraints=false), tbuild)
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
        flow = round.(Int, value.(f))
        bins = sort(decompose(data, arcs, flow))
        for (n, (k, its)) in enumerate(bins)
            used = sum(data.w[its]; init=0)
            used <= data.W[k] || error("bin $n exceeds the length of type $k")
            println("Stock $n of type $k (length $(data.W[k]), cost $(data.c[k])): items $(join(its, " ")) (used length $used)")
        end
        produced = sort(vcat(Int[], (its for (_, its) in bins)...))
        allunique(produced) || error("item produced twice")
        not_produced = setdiff(items(data), produced)
        cost = sum(data.c[k] for (k, _) in bins; init=0) + sum(data.p[not_produced]; init=0)
        println("Items not produced: $(isempty(not_produced) ? "none" : join(not_produced, " ")) " *
                "(penalties $(sum(data.p[not_produced]; init=0)))")
        println("Cost $cost (objective value $(objective_value(model)), status $st)")
        inc = string(round(Int, objective_value(model)))
    else
        println("No solution found (status $st)")
        inc = "--"
    end
    println("########################################################")
    # columns: instance & model & LP bound & nodes & best bound & incumbent & MIP time
    @printf("statistics: %s & %s & %.2f & %d & %.2f & %s & %.2f \\\\\n", name, opts["reduced"] ? "reduced" : "basic",
            lp, nodes, bound, inc, tmip)
    flush(stdout)
end

function main(args)
    s = ArgParseSettings(description="Arc-flow MIP for the variable-sized bin packing with penalties (CPLEX)")
    @add_arg_table s begin
        "instances"
        help = "Instance file paths"
        nargs = '+'
        "--reduced", "-r"
        help = "Reduced graph: reachable positions, item arcs in decreasing length order, loss only after the last item"
        action = :store_true
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
