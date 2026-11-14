mutable struct Solution
    cost::Union{Int,Float64}
    routes::Vector{Vector{Int}}
end

function fix_route_sense(data::DataCVRP, r::Vector{Int})
    i = 0
    cost = 0.0
    w = sum(d(data, j) for j in r)
    for j in r
        cost += w * distance(data, (i, j))
        w -= d(data, j)
        i = j
    end
    rev_cost = 0.0
    w = sum(d(data, j) for j in r)
    i = 0
    for j in reverse(r)
        rev_cost += w * distance(data, (i, j))
        w -= d(data, j)
        i = j
    end
    return (rev_cost < cost) ? reverse(r) : r
end

# build Solution from the variables x
function getsolution(data::DataCVRP, optimizer::VrpOptimizer, x, objval, app::Dict{String,Any})
    E, dim = edges(data), dimension(data)
    adj_list = [Int[] for i in 1:dim]
    for e in E
        val = value(x[e])
        if val > 0.5
            push!(adj_list[e[1]+1], e[2])
            push!(adj_list[e[2]+1], e[1])
            if val > 1.5
                push!(adj_list[e[1]+1], e[2])
                push!(adj_list[e[2]+1], e[1])
            end
        end
    end
    # @show adj_list
    visited, routes = [false for i in 2:dim], Vector{Int}[]
    for i in adj_list[1]
        if !visited[i]
            r, prev = Int[], 0
            push!(r, i)
            visited[i] = true
            length(adj_list[i+1]) != 2 && error(
                "Problem trying to recover the route from the x values. " *
                "Customer $i has $(length(adj_list[i+1])) incident edges.",
            )
            next, prev = (adj_list[i+1][1] == prev) ? adj_list[i+1][2] : adj_list[i+1][1], i
            maxit, it = dim, 0
            while next != 0 && it < maxit
                length(adj_list[next+1]) != 2 && error(
                    "Problem trying to recover the route from the x values. " *
                    "Customer $next has $(length(adj_list[next+1])) incident edges.",
                )
                push!(r, next)
                visited[next] = true
                aux = next
                next, prev = (adj_list[next+1][1] == prev) ? adj_list[next+1][2] : adj_list[next+1][1], aux
                it += 1
            end
            (it == maxit) && error(
                "Problem trying to recover the route from the x values. " *
                "Some route can not be recovered because the return to depot is never reached",
            )
            push!(routes, fix_route_sense(data, r))
        end
    end
    !isempty(filter(a -> a == false, visited)) && error(
        "Problem trying to recover the route from the x values. " *
        "At least one customer was not visited or there are subtours in the solution x.",
    )
    if !app["noround"]
        objval = trunc(Int, round(objval))
    end
    return Solution(objval, routes)
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

# cumulative cost of a route in the given order: every arc costs its distance times the load on board (the vehicle
# leaves the depot with the whole demand of the route and returns empty, so the last arc costs nothing)
function cumulative_cost(data::DataCVRP, r::Vector{Int})
    w, prev, cost = sum(d(data, j) for j in r), 0, 0.0
    for j in r
        cost += w * distance(data, (prev, j))
        w -= d(data, j)
        prev = j
    end
    return cost
end

# Checks the solution x of the model with value z directly against the definition of the cumulative CVRP, assuming
# nothing about how it was obtained (see Note 6.12 of the book "Optimizing with Column Generation"): x_e integer, in
# {0, 1} for an edge between two customers and in {0, 1, 2} for an edge incident to the depot; degree 2 for every
# customer; every route is linked to the depot by exactly two edges (no subtour) and has demand at most Q; the
# number of routes is within [minr, maxr]; and z is the sum over the routes of their cumulative cost in the best
# sense (the sense of a route is free). xval maps each edge (i, j), i < j, to x. Throws an error otherwise.
function checksolution_x(data::DataCVRP, xval::Dict, z::Float64, app::Dict{String,Any})
    E, n, Q, tol = edges(data), nb_customers(data), veh_capacity(data), 1e-6
    for e in E
        v = xval[e]
        (abs(v - round(v)) > tol) && error("x[$e] = $v is not integer")
        ub = (e[1] == 0) ? 2 : 1
        (round(v) < 0 || round(v) > ub) && error("x[$e] = $v is not in {0, ..., $ub}")
    end
    xint = Dict(e => Int(round(xval[e])) for e in E)
    adj = [Int[] for _ in 0:n]
    for (e, v) in xint, _ in 1:v
        push!(adj[e[1]+1], e[2]); push!(adj[e[2]+1], e[1])
    end
    for i in 1:n
        (length(adj[i+1]) != 2) && error("Customer $i has degree $(length(adj[i+1])), not 2")
    end
    routes, seen = Vector{Int}[], falses(n)
    for first in unique(adj[1])
        seen[first] && continue
        r, prev, cur = Int[], 0, first
        while cur != 0
            (length(r) > n) && error("A route starting with customer $first does not return to the depot")
            push!(r, cur); seen[cur] = true
            nb = adj[cur+1]
            nxt = (nb[1] == prev) ? nb[2] : nb[1]
            prev, cur = cur, nxt
        end
        push!(routes, r)
    end
    in_subtours = findall(.!seen)
    isempty(in_subtours) || error("The customers $in_subtours are in subtours (not linked to the depot)")
    for r in routes
        demand = sum(d(data, i) for i in r)
        (demand > Q + tol) && error("The route $r has demand $demand > Q = $Q")
    end
    (length(routes) < app["minr"] || length(routes) > app["maxr"]) &&
        error("The solution has $(length(routes)) routes, not in [$(app["minr"]), $(app["maxr"])]")
    cost = sum(min(cumulative_cost(data, r), cumulative_cost(data, reverse(r))) for r in routes; init=0.0)
    (abs(cost - z) > 1e-6 * max(1, abs(z))) && error("Cumulative cost calculated from x ($cost) is different from the objective value ($z)")
end

# Checks a solution given by its routes, in their order (e.g. read from a file), against the definition of the
# cumulative CVRP: every route is non-empty and made of customers, every customer is visited exactly once, the demand
# of each route is at most Q, the number of routes is within [minr, maxr], and the sum of the cumulative costs of the
# routes is the cost of the solution. Throws an error otherwise.
function checksolution(data::DataCVRP, solution, app::Dict{String,Any})
    n, Q = nb_customers(data), veh_capacity(data)
    visits = zeros(Int, n)
    sum_cost = 0.0
    for (i, r) in enumerate(solution.routes)
        isempty(r) && error("Route #$i is empty")
        for j in r
            (1 <= j <= n) || error("Route #$i visits $j, which is not a customer")
            visits[j] += 1
            (visits[j] > 1) && error("Customer $j is visited more than once")
        end
        sum_demand = sum(d(data, j) for j in r)
        (sum_demand > Q) && error("Route #$i is violating the capacity constraint. Sum of the demands is $(sum_demand) and Q is $Q")
        sum_cost += cumulative_cost(data, r)
    end
    not_visited = findall(==(0), visits)
    isempty(not_visited) || error("The following customers were not visited: $not_visited")
    nroutes = length(solution.routes)
    (nroutes < app["minr"] || nroutes > app["maxr"]) &&
        error("The solution has $nroutes routes, not in [$(app["minr"]), $(app["maxr"])]")
    (abs(solution.cost - sum_cost) > 0.001) && error(
        "Cost calculated from the routes ($sum_cost) is different from that passed as argument ($(solution.cost)).",
    )
end

# read solution from file (CVRPLIB format)
function readsolution(app::Dict{String,Any})
    str = read(app["sol"], String)
    breaks_in = [' '; ':'; '\n'; '\t'; '\r']
    aux = split(str, breaks_in; limit=0, keepempty=false)
    sol = Solution(0, [])
    j = 3
    while j <= length(aux)
        r = []
        while j <= length(aux)
            push!(r, parse(Int, aux[j]))
            j += 1
            if contains(lowercase(aux[j]), "cost") || contains(lowercase(aux[j]), "route")
                break
            end
        end
        push!(sol.routes, r)
        if contains(lowercase(aux[j]), "cost")
            if app["noround"]
                sol.cost = parse(Float64, aux[j+1])
            else
                sol.cost = parse(Int, aux[j+1])
            end
            return sol
        end
        j += 2 # skip "Route" and "#j:" elements
    end
    error("The solution file was not read successfully. The file must be in the CVRPLIB format.")
    return sol
end

# write solution in a file
function writesolution(solpath, solution)
    open(solpath, "w") do f
        for (i, r) in enumerate(solution.routes)
            write(f, "Route #$i: ")
            for j in r
                write(f, "$j ")
            end
            write(f, "\n")
        end
        write(f, "Cost $(solution.cost)\n")
    end
end

# write solution as TikZ figure (.tex) 
# Writes a TikZ figure of the solution, one colour per route. The routes are in their best direction (the one whose
# cumulative cost is counted): the arrows give that direction, and the return to the depot, which adds nothing to the
# cumulative cost, is dashed.
function drawsolution(tikzpath, data, solution)
    colors = ["blue", "red!80!black", "green!50!black", "orange!90!black", "violet", "teal", "brown", "magenta",
        "olive", "cyan!60!black"]
    xs, ys = [v.pos_x for v in data.G′.V′], [v.pos_y for v in data.G′.V′]
    xmin, xmax = extrema(xs)
    ymin, ymax = extrema(ys)
    scale = 12 / max(xmax - xmin, ymax - ymin, 1e-9) # the figure is at most 12cm wide/high
    pos(v) = (round(scale * (v.pos_x - xmin), digits=3), round(scale * (v.pos_y - ymin), digits=3))
    open(tikzpath, "w") do f
        write(f, "\\documentclass[crop,tikz]{standalone}\n\\begin{document}\n")
        write(f, "\\begin{tikzpicture}[every node/.style={font=\\tiny, inner sep=1pt}]\n")
        for v in data.G′.V′
            x, y = pos(v)
            write(f, "\t\\coordinate (v$(v.id_vertex)) at ($x,$y);\n")
        end
        for (k, r) in enumerate(solution.routes)
            col = colors[mod1(k, length(colors))]
            path = vcat([0], r)
            for (i, j) in zip(path[1:end-1], path[2:end])
                write(f, "\t\\draw[$col, ->, shorten >=3pt, line width=0.9pt] (v$i) -- (v$j);\n")
            end
            write(f, "\t\\draw[$col, dashed, line width=0.5pt, opacity=.5] (v$(r[end])) -- (v0);\n")
        end
        for v in data.G′.V′
            i = v.id_vertex
            style = (i == 0) ? "draw, rectangle, fill=yellow, minimum size=8pt" : "draw, circle, fill=white, minimum size=6pt"
            write(f, "\t\\node[$style] at (v$i) {$i};\n")
        end
        write(f, "\\end{tikzpicture}\n\\end{document}\n")
    end
end
