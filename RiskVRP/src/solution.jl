mutable struct Solution
    cost::Union{Int,Float64}
    routes::Vector{Vector{Int}} # customers of each route, in order (the depot is not included)
end

route_distance(data::DataRiskVRP, r::Vector{Int}) = sum(distance(data, p, q) for (p, q) in zip([0; r], [r; 0]))

# risk of a route: each customer carries its demand from its position to the depot
function route_risk(data::DataRiskVRP, r::Vector{Int})
    path = [0; r; 0]
    risk = 0.0
    for k in eachindex(r)
        remaining = sum(distance(data, path[j], path[j+1]) for j in k+1:length(path)-1)
        risk += d(data, r[k]) * remaining
    end
    return risk
end

# Checks the feasibility and the cost of a solution by the definition of the problem
function checksolution(data::DataRiskVRP, sol::Solution)
    visits = zeros(Int, nb_customers(data))
    cost = 0.0
    for r in sol.routes
        for i in r
            visits[i] += 1
        end
        route_risk(data, r) > risk_threshold(data) + 1e-5 &&
            error("Route $r has risk $(route_risk(data, r)), the maximum is $(risk_threshold(data))")
        cost += route_distance(data, r)
    end
    all(visits .== 1) || error("Each customer must be visited once: $(findall(!=(1), visits)) are not")
    abs(cost - sol.cost) <= 1e-6 * max(1.0, abs(cost)) ||
        error("The cost of the solution is $(sol.cost), but its routes cost $cost")
end

# build Solution from the variables x
function getsolution(data::DataRiskVRP, optimizer, x, objval, app::Dict{String,Any})
    n = nb_customers(data)
    next, starts = Dict{Int,Int}(), Int[]
    for a in arcs(data)
        if value(x[a]) > 0.5
            a[1] == 0 ? push!(starts, a[2]) : (next[a[1]] = a[2])
        end
    end
    routes = Vector{Int}[]
    for first in starts
        r = [first]
        while length(r) <= n && get(next, r[end], 0) != 0
            push!(r, next[r[end]])
        end
        push!(routes, r)
    end
    return Solution(objval, routes)
end

function print_routes(sol::Solution)
    for (k, r) in enumerate(sol.routes)
        print("Route #$k: ")
        println(join(r, " "))
    end
end

# write solution in a file with the same format as the ones of CVRPLIB
function writesolution(solpath::String, sol::Solution)
    open(solpath, "w") do f
        for (k, r) in enumerate(sol.routes)
            write(f, "Route #$k: ", join(r, " "), "\n")
        end
        write(f, "Cost $(sol.cost)\n")
    end
end
