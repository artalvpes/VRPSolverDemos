mutable struct Solution
    cost::Union{Int, Float64}
    routes::Vector{Vector{Int}}
end

# build Solution from the variables x
function getsolution(data::DataCVRP, optimizer::VrpOptimizer, x, objval, app::Dict{String, Any})
    E, dim = edges(data), dimension(data)
    adj_list = [[] for i in 1:dim]
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
    visited, routes = [false for i in 2:dim], []
    for i in adj_list[1]
        if !visited[i]
            r, prev = [], 0
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
            push!(routes, r)
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

# Checks the solution x of the model with value z directly against the definition of the (distance-constrained)
# CVRP, assuming nothing about how it was obtained (see Note 6.12 of the book "Optimizing with Column Generation"):
# x_e integer, in {0, 1} for an edge between two customers and in {0, 1, 2} for an edge incident to the depot (2 is a
# route with a single customer); degree 2 for every customer; every connected set of customers (a route) is linked
# to the depot by exactly two edges (no subtour); the demand of each route is at most Q; with a distance limit D, the
# length of each route plus the service times of its customers is at most D; the number of routes is within
# [minr, maxr]; and the sum of c_e x_e is z. xval maps each edge (i, j), i < j, to the value of x. Throws an error
# otherwise.
function checksolution_x(data::DataCVRP, xval::Dict, z::Float64, app::Dict{String,Any})
    E, n, Q, D = edges(data), nb_customers(data), veh_capacity(data), max_dist(data)
    tol = 1e-6
    for e in E
        v = xval[e]
        (abs(v - round(v)) > tol) && error("x[$e] = $v is not integer")
        ub = (e[1] == 0) ? 2 : 1
        (round(v) < 0 || round(v) > ub) && error("x[$e] = $v is not in {0, ..., $ub}")
    end
    xint = Dict(e => Int(round(xval[e])) for e in E)
    degree = zeros(Int, n)
    for (e, v) in xint, i in e
        i > 0 && (degree[i] += v)
    end
    for i in 1:n
        (degree[i] != 2) && error("Customer $i has degree $(degree[i]), not 2")
    end
    # routes = connected components of the customers through the edges between customers
    parent = collect(0:n)
    find(i) = (parent[i+1] == i) ? i : (parent[i+1] = find(parent[i+1]))
    for (e, v) in xint
        (v > 0 && e[1] > 0) && (parent[find(e[1])+1] = find(e[2]))
    end
    comps = Dict{Int,Vector{Int}}()
    for i in 1:n
        push!(get!(comps, find(i), Int[]), i)
    end
    for r in values(comps)
        depot_edges = sum(xint[(0, i)] for i in r)
        (depot_edges != 2) && error("The customers $r are linked to the depot by $depot_edges edges, not 2 (subtour)")
        demand = sum(d(data, i) for i in r)
        (demand > Q + tol) && error("The route with the customers $r has demand $demand > Q = $Q")
        if D > 0
            inr = Set(r)
            len = sum(c(data, e) * v for (e, v) in xint if (e[1] in inr || e[1] == 0) && e[2] in inr)
            dur = len + service_time(data) * length(r)
            (dur > D + tol) && error("The route with the customers $r has duration $dur > D = $D")
        end
    end
    nroutes = length(comps)
    (nroutes < app["minr"] || nroutes > app["maxr"]) &&
        error("The solution has $nroutes routes, not in [$(app["minr"]), $(app["maxr"])]")
    cost = sum(c(data, e) * v for (e, v) in xint)
    (abs(cost - z) > 1e-6 * max(1, abs(z))) && error("Cost calculated from x ($cost) is different from the objective value ($z)")
end

# Checks a solution given by its routes (e.g. read from a file) against the definition of the CVRP: every route is
# non-empty and made of customers, every customer is visited exactly once, the demand of each route is at most Q,
# with a distance limit D the length of each route plus the service times of its customers is at most D, the number
# of routes is within [minr, maxr], and the cost of the routes is the cost of the solution. Throws an error otherwise.
function checksolution(data::DataCVRP, solution, app::Dict{String,Any})
    n, Q, D = nb_customers(data), veh_capacity(data), max_dist(data)
    visits = zeros(Int, n)
    sum_cost = 0.0
    for (i, r) in enumerate(solution.routes)
        isempty(r) && error("Route #$i is empty")
        sum_demand, len, prev = 0.0, 0.0, 0
        for j in r
            (1 <= j <= n) || error("Route #$i visits $j, which is not a customer")
            visits[j] += 1
            (visits[j] > 1) && error("Customer $j is visited more than once")
            len += distance(data, (prev, j))
            sum_demand += d(data, j)
            prev = j
        end
        len += distance(data, (prev, 0))
        sum_cost += len
        (sum_demand > Q) && error("Route #$i is violating the capacity constraint. Sum of the demands is $(sum_demand) and Q is $Q")
        (D > 0 && len + service_time(data) * length(r) > D + 1e-6) &&
            error("Route #$i has duration $(len + service_time(data) * length(r)) > D = $D")
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
function readsolution(app::Dict{String, Any})
    str = read(app["sol"], String)
    breaks_in = [' '; ':'; '\n'; '\t'; '\r']
    aux = split(str, breaks_in; limit = 0, keepempty = false)
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
function drawsolution(tikzpath, data, solution)
    colors = ["blue", "red!80!black", "green!50!black", "orange!90!black", "violet", "teal", "brown", "magenta",
        "olive", "cyan!60!black"] # one colour per route
    open(tikzpath, "w") do f
        write(f, "\\documentclass[crop,tikz]{standalone}\n\\begin{document}\n")
        # get limits to draw
        pos_x_vals = [i.pos_x for i in data.G′.V′]
        pos_y_vals = [i.pos_y for i in data.G′.V′]
        scale_fac = 1 / (max(maximum(pos_x_vals), maximum(pos_y_vals)) / 10)
        write(f, "\\begin{tikzpicture}[thick, scale=1, every node/.style={scale=0.3}]\n")
        for i in data.G′.V′
            x_plot = scale_fac * i.pos_x
            y_plot = scale_fac * i.pos_y
            if i.id_vertex == 0 # plot depot
                write(
                    f,
                    "\t\\node[draw, line width=0.1mm, rectangle, fill=yellow, inner sep=0.05cm, scale=1.4] (v$(i.id_vertex)) at ($(x_plot),$(y_plot)) {\\footnotesize $(i.id_vertex)};\n",
                )
                # Uncomment to plot without vertex id
                #write(f, "\t\\node[draw, rectangle, fill=yellow, scale=1.4] (v$(i.id_vertex)) at ($(x_plot),$(y_plot)) {};\n")
            else
                write(
                    f,
                    "\t\\node[draw, line width=0.1mm, circle, fill=white, inner sep=0.05cm] (v$(i.id_vertex)) at ($(x_plot),$(y_plot)) {\\footnotesize $(i.id_vertex)};\n",
                )
                # Uncomment to plot without vertex id
                #write(f, "\t\\node[draw, circle, fill=white] (v$(i.id_vertex)) at ($(x_plot),$(y_plot)) {};\n")
            end
        end
        for (k, r) in enumerate(solution.routes)
            col = colors[mod1(k, length(colors))]
            #=prev = r[1] # Uncomment (and comment below) to hide edges with the depot
            for i in r[2:end]
                e = (prev,i)
                write(f, "\t\\draw[$col,-,line width=0.9pt] (v$(e[1])) -- (v$(e[2]));\n")
                prev = i
            end=#
            prev = 0
            for i in r
                e = (prev, i)
                edge_style = (prev == 0) ? "$col,-,line width=0.5pt" : "$col,-,line width=0.9pt" # thinner edges at the depot
                write(f, "\t\\draw[$(edge_style)] (v$(e[1])) -- (v$(e[2]));\n")
                prev = i
            end
            write(f, "\t\\draw[$col,-,line width=0.5pt] (v0) -- (v$(prev));\n")
        end
        write(f, "\\end{tikzpicture}\n")
        write(f, "\\end{document}\n")
    end
end
