# Set partitioning MIP for the CCVRP over all feasible routes, solved with CPLEX.
# It is meant to validate the VRPSolver models on small instances with a small capacity W (so that all
# routes can be enumerated), and it models the same problem as the demo (src/model.jl): every customer
# is visited by exactly one route, the number of routes is in [L, U], and the cost of a route is the
# cost used by checksolution (src/solution.jl): each edge into a customer j costs its length times the
# demand of the customers from j to the end of the route (the return to the depot is free).
#
# A route is a set S of customers with demand <= W. Its cost is the cost of the best visiting order,
# computed backwards by a memoized dynamic program shared by all sets:
#   tail(S, f) = cheapest cost of visiting S starting at f in S (without the edge into f)
#              = min_{k in S \ f} c(f, k) * D(S \ f) + tail(S \ f, k),   tail({f}, f) = 0
#   cost(S)    = min_{f in S} c(0, f) * D(S) + tail(S, f)

using CPLEX

struct RouteDP
    dist::Matrix{Float64} # dist[i+1, j+1] = distance between vertices i and j (0 is the depot)
    dem::Vector{Float64} # dem[i] = demand of customer i
    memo::Dict{Tuple{UInt64,Int},Float64} # (S, f) => tail(S, f)
end

function RouteDP(data)
    n = C.nb_customers(data)
    dist = [(i == j) ? 0.0 : C.distance(data, (i, j)) for i in 0:n, j in 0:n]
    return RouteDP(dist, [C.d(data, i) for i in 1:n], Dict{Tuple{UInt64,Int},Float64}())
end

cust_bit(i::Int) = UInt64(1) << (i - 1)
customers_in(mask::UInt64) = [i for i in 1:64 if (mask & cust_bit(i)) != 0]
demand(dp::RouteDP, mask::UInt64) = sum(dp.dem[i] for i in customers_in(mask); init=0.0)

function tail_cost(dp::RouteDP, mask::UInt64, f::Int)
    rest = mask & ~cust_bit(f)
    (rest == 0) && return 0.0
    return get!(dp.memo, (mask, f)) do
        D = demand(dp, rest)
        minimum(dp.dist[f+1, k+1] * D + tail_cost(dp, rest, k) for k in customers_in(rest))
    end
end

function route_cost(dp::RouteDP, mask::UInt64)
    D = demand(dp, mask)
    return minimum(dp.dist[1, f+1] * D + tail_cost(dp, mask, f) for f in customers_in(mask))
end

# best visiting order of the customers in mask
function route_order(dp::RouteDP, mask::UInt64)
    D = demand(dp, mask)
    cost = route_cost(dp, mask)
    f = first(f for f in customers_in(mask) if isapprox(dp.dist[1, f+1] * D + tail_cost(dp, mask, f), cost))
    order = [f]
    while mask != cust_bit(f)
        cost = tail_cost(dp, mask, f)
        rest = mask & ~cust_bit(f)
        Dr = demand(dp, rest)
        k = first(k for k in customers_in(rest) if isapprox(dp.dist[f+1, k+1] * Dr + tail_cost(dp, rest, k), cost))
        push!(order, k)
        mask, f = rest, k
    end
    return order
end

# all sets of customers with demand <= W, with their costs
function enumerate_routes(data)
    n = C.nb_customers(data)
    (n > 64) && error("The set partitioning model supports at most 64 customers")
    W = C.veh_capacity(data)
    dp = RouteDP(data)
    masks, costs = UInt64[], Float64[]
    function dfs(first_c::Int, mask::UInt64, load::Float64)
        for i in first_c:n
            load + dp.dem[i] > W + 1e-6 && continue
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

# solve the set partitioning model; return (status, solution or nothing, time, number of columns)
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

    status = (termination_status(m) == MOI.OPTIMAL) ? :Optimal : Symbol(termination_status(m))
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
    println("statistics_set_partitioning: $(basename(app["instance"])) & $status & " *
            "$((sol === nothing) ? "--" : sol.cost) & $(round(time() - t, digits=2)) \\\\")
    return (status, sol, time() - t, length(masks))
end
