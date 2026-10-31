# Set partitioning MIP for the PDPTW over all feasible routes, solved with CPLEX.
# It is meant to validate the VRPSolver model on small instances whose routes are short (so that all
# routes can be enumerated), and it models the same problem as the demo (src/model.jl): every request is
# served by exactly one route, which visits its pickup and then its delivery; a route leaves the depot
# to a pickup and returns from a delivery, uses only the arcs of the graph, respects the capacity and
# the time windows (waiting is allowed), and its cost is the sum of the costs of its arcs. Li&Lim
# instances use at most K routes and minimize the total cost; Ropke instances also pay the fixed cost
# per vehicle (--fixed), with the number of routes in [minr, min(maxr, n)].
#
# The routes are enumerated by a forward labeling from the depot: a label (visited vertices, last
# vertex, time, cost, load) is extended to every vertex that keeps the route feasible, and a label is
# discarded when another one with the same visited vertices and last vertex is not later and not more
# expensive (the load is the same). For each set of requests, the cheapest route that serves exactly
# these requests and returns to the depot in time is a column.

using CPLEX

struct PDLabel
    visited::UInt64 # bit v for each visited vertex v in 1..2n
    last::Int
    time::Float64 # start of service at the last vertex
    cost::Float64
    load::Int
    path::Vector{Int}
end

vbit(v::Int) = UInt64(1) << (v - 1)

# inserts the label in the list of labels with the same visited vertices and last vertex, unless it is
# dominated; removes the labels it dominates
function insert_label!(labels::Vector{PDLabel}, lab::PDLabel)
    for other in labels
        (other.time <= lab.time + 1e-9 && other.cost <= lab.cost + 1e-9) && return false
    end
    filter!(other -> !(lab.time <= other.time + 1e-9 && lab.cost <= other.cost + 1e-9), labels)
    push!(labels, lab)
    return true
end

# cheapest feasible route for each set of requests (bitmask of the pickups): Dict mask => (cost, path),
# or nothing if the enumeration does not finish before stop_time (seconds since the epoch, as time())
function enumerate_routes(data; stop_time::Float64=Inf)
    nb = C.n(data)
    (nb > 32) && error("The set partitioning model supports at most 32 requests")
    Q = C.veh_capacity(data)
    arc_exists(a) = haskey(data.G′.cost, a)
    best = Dict{UInt64,Tuple{Float64,Vector{Int}}}()
    level = Dict{Tuple{UInt64,Int},Vector{PDLabel}}()
    nb_labels = 0
    for p in 1:2nb
        (C.d(data, p) > 0 && arc_exists((0, p))) || continue
        time = max(C.l(data, p), C.l(data, 0) + C.t(data, (0, p)))
        (time > C.u(data, p) + 1e-9 || C.d(data, p) > Q) && continue
        level[(vbit(p), p)] = [PDLabel(vbit(p), p, time, C.c(data, (0, p)), C.d(data, p), [p])]
    end
    while !isempty(level)
        next_level = Dict{Tuple{UInt64,Int},Vector{PDLabel}}()
        for labels in values(level), lab in labels
            nb_labels += 1
            (nb_labels % 10000 == 0 && time() > stop_time) && return nothing
            i = lab.last
            # route closed at the depot: no request on board
            if lab.load == 0 && C.d(data, i) < 0 && arc_exists((i, 0)) &&
               lab.time + C.t(data, (i, 0)) <= C.u(data, 0) + 1e-9
                cost = lab.cost + C.c(data, (i, 0))
                mask = reduce(|, [vbit(v) for v in lab.path if C.d(data, v) > 0])
                if !haskey(best, mask) || cost < best[mask][1] - 1e-9
                    best[mask] = (cost, lab.path)
                end
            end
            for j in 1:2nb
                ((lab.visited & vbit(j)) != 0 || !arc_exists((i, j))) && continue
                # a delivery only after its pickup
                (C.d(data, j) < 0 && (lab.visited & vbit(C.sibling(data, j))) == 0) && continue
                load = lab.load + C.d(data, j)
                (load > Q) && continue
                time = max(C.l(data, j), lab.time + C.t(data, (i, j)))
                (time > C.u(data, j) + 1e-9) && continue
                new_lab = PDLabel(lab.visited | vbit(j), j, time, lab.cost + C.c(data, (i, j)), load,
                    vcat(lab.path, [j]))
                insert_label!(get!(next_level, (new_lab.visited, j), PDLabel[]), new_lab)
            end
        end
        level = next_level
    end
    println("Enumeration: $nb_labels labels, $(length(best)) routes")
    return best
end

# solve the set partitioning model; return (status, solution or nothing, time, number of columns),
# where status is :Optimal (with or without a solution, the latter meaning infeasible) or another symbol;
# the enumeration and CPLEX stop at stop_time (seconds since the epoch, as time()) with :TIME_LIMIT
function solve_set_partitioning(data, app::Dict{String,Any}; stop_time::Float64=Inf)
    t0 = time()
    best = enumerate_routes(data; stop_time=stop_time)
    if best === nothing
        println("Enumeration stopped by the time limit")
        return (:TIME_LIMIT, nothing, time() - t0, 0)
    end
    masks = collect(keys(best))
    nb = C.n(data)
    pickups = [p for p in 1:2nb if C.d(data, p) > 0]
    fixed = app["lilim"] ? 0.0 : Float64(app["fixed"])
    # same bounds on the number of routes as the demo
    L, U = app["lilim"] ? (C.lowerBoundNbVehicles(data), C.upperBoundNbVehicles(data)) :
           (app["minr"], min(app["maxr"], nb))
    covering = Dict(p => Int[] for p in pickups)
    for (k, mask) in enumerate(masks), p in pickups
        ((mask & vbit(p)) != 0) && push!(covering[p], k)
    end

    m = Model(CPLEX.Optimizer)
    isfinite(stop_time) && set_time_limit_sec(m, max(stop_time - time(), 0.0))
    @variable(m, λ[k in 1:length(masks)], Bin)
    @objective(m, Min, sum((best[masks[k]][1] + fixed) * λ[k] for k in 1:length(masks)))
    @constraint(m, cover[p in pickups], sum(λ[k] for k in covering[p]) == 1)
    @constraint(m, nb_routes, L <= sum(λ) <= U)
    println("Set partitioning model: $(length(masks)) columns, routes in [$L, $U]")
    optimize!(m)

    term = termination_status(m)
    # the objective is bounded, so INFEASIBLE_OR_UNBOUNDED means infeasible
    status = (term in (MOI.OPTIMAL, MOI.INFEASIBLE, MOI.INFEASIBLE_OR_UNBOUNDED)) ? :Optimal : Symbol(term)
    sol = nothing
    if primal_status(m) == MOI.FEASIBLE_POINT
        routes = [best[masks[k]][2] for k in 1:length(masks) if value(λ[k]) > 0.5]
        objval = objective_value(m)
        if app["round"]
            objval = trunc(Int, round(objval))
        end
        sol = C.Solution(objval, routes)
        C.checksolution(data, sol, app) # the cost of the routes is recomputed by the demo code
    end
    println("statistics_set_partitioning: $(basename(app["instance"])) & $term & " *
            "$((sol === nothing) ? "--" : sol.cost) & $(round(time() - t0, digits=2)) \\\\")
    return (status, sol, time() - t0, length(masks))
end
