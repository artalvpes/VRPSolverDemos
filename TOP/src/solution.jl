mutable struct Solution
    cost::Float64
    routes::Array{Array{Int}}
end

# build Solution from the variables x
function getsolution(data::DataTOP, x, objval, optimizer)
    A, dim = arcs(data), num_customers(data) + 2
    adj_list = [[] for i in 1:dim]
    for a in A
        val = get_value(optimizer, x[a])
        if val > 0.5
            push!(adj_list[a[1] + 1], a[2])
        end
    end
    visited, routes = [false for i in 2:dim], []
    for i in adj_list[1]
        if !visited[i]
            r, prev = [], 0
            next, prev = i, 0
            maxit, it = dim - 2, 0
            while next != dim - 1 && it < maxit
                length(adj_list[next + 1]) != 1 && error(
                    "Problem trying to recover the route from the x values. " *
                    "Customer $next has $(length(adj_list[next+1])) outcoming arcs.",
                )
                visited[next] && error("Customer $next is visited more than once")
                visited[next] = true
                push!(r, next)
                aux = next
                next, prev = adj_list[next + 1][1], aux
                it += 1
            end
            (next != dim - 1) && error(
                "Problem trying to recover the route from the x values. " *
                "Route cannot be recovered because the return to depot is never reached",
            )
            push!(routes, r)
        elseif i != dim - 1
            error("Customer $i is visited more than once")
        end
    end

    return Solution(objval, routes)
end

# Checks the solution (x, y) of the model with value z directly against the definition of the team orienteering
# problem, computing the travel times from the vertex coordinates (assuming nothing about how the solution was
# obtained, see Note 6.12 of the book "Optimizing with Column Generation"): x_a and y_i binary; at every customer
# the in-degree and the out-degree are y_i; the routes, from the origin 0 to the destination n + 1, are at most F,
# visit every customer with y_i = 1 exactly once (no subtours) and have a duration of at most T; and z is minus
# the total profit of the visited customers. xval maps each arc to x, yval each customer to y. Throws an error
# otherwise. Returns the routes.
function checksolution_x(data::DataTOP, xval::Dict, yval::Dict, z::Float64)
    n, V, tol = num_customers(data), data.G.V, 1e-6
    for (key, v) in vcat(collect(xval), collect(yval))
        (abs(v) > tol && abs(v - 1) > tol) && error("The value $v of $key is not binary")
    end
    used = [a for (a, v) in xval if v > 0.5]
    succ = Dict{Int,Vector{Int}}()
    indeg = zeros(Int, n + 2)
    for (i, j) in used
        push!(get!(succ, i, Int[]), j)
        indeg[j+1] += 1
    end
    for i in 1:n
        yi = round(Int, yval[i])
        (indeg[i+1] != yi) && error("Customer $i has in-degree $(indeg[i+1]), but y = $yi")
        (length(get(succ, i, Int[])) != yi) && error("Customer $i has out-degree $(length(get(succ, i, Int[]))), but y = $yi")
    end
    (indeg[1] != 0 || haskey(succ, n + 1)) && error("An arc enters the origin 0 or leaves the destination $(n + 1)")
    routes = Vector{Int}[]
    for first in get(succ, 0, Int[])
        r, j, dur = Int[], first, distance(V[1], V[first+1])
        while j != n + 1
            (1 <= j <= n) || error("A route visits $j, which is not a customer")
            (length(r) > n) && error("A route starting with customer $first does not reach the destination")
            push!(r, j)
            nxt = succ[j][1]
            dur += distance(V[j+1], V[nxt+1])
            j = nxt
        end
        (dur > max_duration(data) + tol) && error("The route $r has duration $dur > T = $(max_duration(data))")
        push!(routes, r)
    end
    (length(routes) > fleet_size(data)) && error("The solution has $(length(routes)) routes, more than F = $(fleet_size(data))")
    visited = vcat(routes...)
    allunique(visited) || error("A customer is visited more than once")
    in_subtours = [i for i in 1:n if round(Int, yval[i]) == 1 && !(i in visited)]
    isempty(in_subtours) || error("The customers $in_subtours are in subtours (not on a route from 0 to $(n + 1))")
    profit = sum(V[i+1].profit for i in visited; init=0)
    (abs(-profit - z) > 1e-6 * max(1, abs(z))) && error("Minus the profit of the routes ($(-profit)) is different from the objective value ($z)")
    return routes
end

function print_routes(solution)
    for (i, r) in enumerate(solution.routes)
        print("Route #$i: ")
        for j in r
            print("$j ")
        end
        println()
    end
end
