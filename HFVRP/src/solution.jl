mutable struct Solution
    cost::Union{Int,Float64}
    routes::Vector{Vector{Int}} # customers of each route, in order (the depot is not included)
end

route_load(data::DataHFVRP, r::Vector{Int}) = sum(d(data, i) for i in r)
route_distance(data::DataHFVRP, r::Vector{Int}) = sum(distance(data, p, q) for (p, q) in zip([0; r], [r; 0]))

# cost of a route: fixed cost + cost per unit of distance of the cheapest type that carries its load
function route_cost(data::DataHFVRP, r::Vector{Int})
    k = route_type(data, route_load(data, r))
    k === nothing && error("Route $r has load $(route_load(data, r)), larger than the capacity of every vehicle type")
    return data.vehTypes[k].fixed + data.vehTypes[k].factor * route_distance(data, r)
end

# Checks the feasibility and the cost of a solution by the definition of the problem
function checksolution(data::DataHFVRP, sol::Solution)
    visits = zeros(Int, nb_customers(data))
    cost = 0.0
    for r in sol.routes
        for i in r
            visits[i] += 1
        end
        cost += route_cost(data, r)
    end
    all(visits .== 1) || error("Each customer must be visited once: $(findall(!=(1), visits)) are not")
    abs(cost - sol.cost) <= 1e-6 * max(1.0, abs(cost)) ||
        error("The cost of the solution is $(sol.cost), but its routes cost $cost")
end

# build Solution from the variables x of the edges
function getsolution(data::DataHFVRP, optimizer, x, objval, app::Dict{String,Any})
    n = nb_customers(data)
    adj_list = [Int[] for i in 0:n]
    for e in edges(data)
        val = round(Int, value(x[e]))
        for _ in 1:val
            push!(adj_list[e[1]+1], e[2])
            push!(adj_list[e[2]+1], e[1])
        end
    end
    visited, routes = falses(n), Vector{Int}[]
    for i in adj_list[1]
        visited[i] && continue
        r, prev, cur = [i], 0, i
        visited[i] = true
        while true
            length(adj_list[cur+1]) != 2 && error(
                "Problem trying to recover the route from the x values. " *
                "Customer $cur has $(length(adj_list[cur+1])) incident edges.",
            )
            next = (adj_list[cur+1][1] == prev) ? adj_list[cur+1][2] : adj_list[cur+1][1]
            next == 0 && break
            visited[next] && error("Problem trying to recover the route from the x values: customer $next is repeated")
            push!(r, next)
            visited[next] = true
            prev, cur = cur, next
        end
        push!(routes, r)
    end
    all(visited) || error(
        "Problem trying to recover the route from the x values. " *
        "At least one customer was not visited or there are subtours in the solution x.",
    )
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
