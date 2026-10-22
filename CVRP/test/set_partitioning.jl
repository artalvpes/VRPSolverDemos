# Set partitioning MIP for the CVRP over all feasible routes, solved with CPLEX.
# It is meant to validate the VRPSolver model on small instances whose routes are short (so that all
# routes can be enumerated), and it models the same problem as the demo (src/model.jl): every customer
# is visited by exactly one route, the demand of a route does not exceed the capacity Q, the number of
# routes is in [L, U], and the cost of a route is its length as computed by checksolution
# (src/solution.jl).
#
# A route is a set S of customers with demand <= Q. Its cost is the cost of the shortest cycle through
# the depot and S, computed by a memoized Held-Karp dynamic program shared by all sets:
#   path(S, l) = cheapest path from the depot visiting S and ending at l in S
#              = min_{k in S \ l} path(S \ l, k) + c(k, l),   path({l}, l) = c(0, l)
#   cost(S)    = min_{l in S} path(S, l) + c(l, 0)

using CPLEX

struct RouteDP
    dist::Matrix{Float64} # dist[i+1, j+1] = distance between vertices i and j (0 is the depot)
    dem::Vector{Float64} # dem[i] = demand of customer i
    memo::Dict{Tuple{UInt64,Int},Float64} # (S, l) => path(S, l)
end

function RouteDP(data)
    n = C.nb_customers(data)
    dist = [(i == j) ? 0.0 : C.distance(data, (i, j)) for i in 0:n, j in 0:n]
    return RouteDP(dist, [C.d(data, i) for i in 1:n], Dict{Tuple{UInt64,Int},Float64}())
end

cust_bit(i::Int) = UInt64(1) << (i - 1)
customers_in(mask::UInt64) = [i for i in 1:64 if (mask & cust_bit(i)) != 0]

function path_cost(dp::RouteDP, mask::UInt64, last::Int)
    rest = mask & ~cust_bit(last)
    (rest == 0) && return dp.dist[1, last+1]
    return get!(dp.memo, (mask, last)) do
        minimum(path_cost(dp, rest, k) + dp.dist[k+1, last+1] for k in customers_in(rest))
    end
end

route_cost(dp::RouteDP, mask::UInt64) =
    minimum(path_cost(dp, mask, l) + dp.dist[l+1, 1] for l in customers_in(mask))

# best visiting order of the customers in mask
function route_order(dp::RouteDP, mask::UInt64)
    cost = route_cost(dp, mask)
    last = first(l for l in customers_in(mask) if isapprox(path_cost(dp, mask, l) + dp.dist[l+1, 1], cost))
    order = [last]
    while mask != cust_bit(last)
        cost = path_cost(dp, mask, last)
        mask &= ~cust_bit(last)
        last = first(k for k in customers_in(mask) if isapprox(path_cost(dp, mask, k) + dp.dist[k+1, last+1], cost))
        pushfirst!(order, last)
    end
    return order
end

# all sets of customers with demand <= Q, with their costs
function enumerate_routes(data)
    n = C.nb_customers(data)
    (n > 64) && error("The set partitioning model supports at most 64 customers")
    Q = C.veh_capacity(data)
    dp = RouteDP(data)
    masks, costs = UInt64[], Float64[]
    function dfs(first_c::Int, mask::UInt64, load::Float64)
        for i in first_c:n
            load + dp.dem[i] > Q + 1e-6 && continue
            new_mask = mask | cust_bit(i)
            push!(masks, new_mask)
            push!(costs, route_cost(dp, new_mask))
            dfs(i + 1, new_mask, load + dp.dem[i])
        end
    end
    dfs(1, UInt64(0), 0.0)
    println("Enumeration: $(length(masks)) routes, $(length(dp.memo)) dynamic programming states")
    return dp, masks, costs
end

# solve the set partitioning model; return (status, solution or nothing, time, number of columns),
# where status is :Optimal (with or without a solution, the latter meaning infeasible) or another symbol
function solve_set_partitioning(data, app::Dict{String,Any})
    t = time()
    dp, masks, costs = enumerate_routes(data)
    n = C.nb_customers(data)
    L = max(app["minr"], C.lowerBoundNbVehicles(data)) # same bounds on the number of routes as build_model
    U = min(app["maxr"], n)
    covering = [Int[] for _ in 1:n]
    for (k, mask) in enumerate(masks), i in customers_in(mask)
        push!(covering[i], k)
    end

    m = Model(CPLEX.Optimizer)
    @variable(m, λ[k in 1:length(masks)], Bin)
    @objective(m, Min, sum(costs[k] * λ[k] for k in 1:length(masks)))
    @constraint(m, cover[i in 1:n], sum(λ[k] for k in covering[i]) == 1)
    @constraint(m, nb_routes, L <= sum(λ) <= U)
    println("Set partitioning model: $(length(masks)) columns, routes in [$L, $U]")
    optimize!(m)

    term = termination_status(m)
    # the objective is bounded, so INFEASIBLE_OR_UNBOUNDED means infeasible
    status = (term in (MOI.OPTIMAL, MOI.INFEASIBLE, MOI.INFEASIBLE_OR_UNBOUNDED)) ? :Optimal : Symbol(term)
    sol = nothing
    if primal_status(m) == MOI.FEASIBLE_POINT
        routes = [route_order(dp, masks[k]) for k in 1:length(masks) if value(λ[k]) > 0.5]
        objval = objective_value(m)
        if !app["noround"]
            objval = trunc(Int, round(objval))
        end
        sol = C.Solution(objval, routes)
        C.checksolution(data, sol) # the cost of the routes is recomputed by the demo code
    end
    println("statistics_set_partitioning: $(basename(app["instance"])) & $term & " *
            "$((sol === nothing) ? "--" : sol.cost) & $(round(time() - t, digits=2)) \\\\")
    return (status, sol, time() - t, length(masks))
end
