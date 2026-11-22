mutable struct Solution
    cost::Union{Int,Float64}
    routes::Vector{Vector{Int}} # customers of each route, in order (the depot is not included)
end

route_distance(data::DataVRPSPD, r::Vector{Int}) = sum(distance(data, p, q) for (p, q) in zip([0; r], [r; 0]))

# largest load of the vehicle along the route: it leaves the depot with the deliveries and, at each customer, delivers
# and then picks up
function route_max_load(data::DataVRPSPD, r::Vector{Int})
    load = sum(delivery(data, i) for i in r)
    max_load = load
    for i in r
        load += pickup(data, i) - delivery(data, i)
        max_load = max(max_load, load)
    end
    return max_load
end

# Checks the feasibility and the cost of a solution by the definition of the problem
function checksolution(data::DataVRPSPD, sol::Solution)
    visits = zeros(Int, nb_customers(data))
    cost = 0.0
    for r in sol.routes
        for i in r
            visits[i] += 1
        end
        route_max_load(data, r) > veh_capacity(data) + 1e-5 &&
            error("Route $r has load $(route_max_load(data, r)), the capacity is $(veh_capacity(data))")
        cost += route_distance(data, r)
    end
    all(visits .== 1) || error("Each customer must be visited once: $(findall(!=(1), visits)) are not")
    abs(cost - sol.cost) <= 1e-6 * max(1.0, abs(cost)) ||
        error("The cost of the solution is $(sol.cost), but its routes cost $cost")
end

# build Solution from the variables x
function getsolution(data::DataVRPSPD, optimizer, x, objval, app::Dict{String,Any})
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
