import Base.show, Base.print

mutable struct Solution
    cost::Float64
    routes::Array{Array{Int, 1}}
end

# build Solution from the variables x
function getsolution(data::DataVRPTW, x, objval, optimizer)
    A, dim = arcs(data), n(data) + 1
    adj_list = [[] for i in 1:dim]
    for a in A
        val = get_value(optimizer, x[a])
        if val > 0.5
            push!(adj_list[a[1]+1], a[2])
        end
    end
    visited, routes = [false for i in 2:dim], []
    for i in adj_list[1]
        if !visited[i]
            r, prev = [], 0
            push!(r, i)
            visited[i] = true
            length(adj_list[i+1]) != 1 && error(
                "Problem trying to recover the route from the x values. " *
                "Customer $i has $(length(adj_list[i+1])) outcoming arcs.",
            )
            next, prev = adj_list[i+1][1], i
            maxit, it = dim, 0
            while next != 0 && it < maxit
                length(adj_list[next+1]) != 1 && error(
                    "Problem trying to recover the route from the x values. " *
                    "Customer $next has $(length(adj_list[next+1])) outcoming arcs.",
                )
                push!(r, next)
                visited[next] = true
                aux = next
                next, prev = adj_list[next+1][1], aux
                it += 1
            end
            (it == maxit) && error(
                "Problem trying to recover the route from the x values. " *
                "Route cannot be recovered because the return to depot is never reached",
            )
            push!(routes, r)
        end
    end
    !isempty(filter(y -> y == false, visited)) && error(
        "Problem trying to recover the route from the x values. " *
        "At least one vertex was not visited or there are subtours in the solution x.",
    )

    return Solution(objval, routes)
end

# Checks routes against the definition of the VRPTW, computing distances and times from the vertex data (assuming
# nothing about how the routes were obtained, see Note 6.12 of the book "Optimizing with Column Generation"):
# every customer is visited exactly once; the demand of each route is at most Q; leaving the depot at time 0, the
# service of each customer starts within its time window (waiting is allowed), and the vehicle returns to the depot
# before its due time; at most K routes; the total distance is cost. Throws an error otherwise.
function checkroutes(data::DataVRPTW, routes, cost::Real)
    V, Q, tol = data.G′.V′, veh_capacity(data), 1e-6
    dist(i, j) = distance(V[i+1], V[j+1])
    visits = zeros(Int, n(data))
    total = 0.0
    for (k, r) in enumerate(routes)
        isempty(r) && error("Route #$k is empty")
        load, time, prev = 0.0, 0.0, 0
        for j in r
            (1 <= j <= n(data)) || error("Route #$k visits $j, which is not a customer")
            visits[j] += 1
            (visits[j] > 1) && error("Customer $j is visited more than once")
            load += V[j+1].demand
            time = max(time + (prev == 0 ? 0 : V[prev+1].service_time) + dist(prev, j), V[j+1].start_tw)
            (time > V[j+1].end_tw + tol) &&
                error("Route #$k starts the service of customer $j at $time, after its due time $(V[j+1].end_tw)")
            total += dist(prev, j)
            prev = j
        end
        time += V[prev+1].service_time + dist(prev, 0)
        (time > V[1].end_tw + tol) && error("Route #$k returns to the depot at $time, after its due time $(V[1].end_tw)")
        total += dist(prev, 0)
        (load > Q + tol) && error("Route #$k has demand $load > Q = $Q")
    end
    not_visited = findall(==(0), visits)
    isempty(not_visited) || error("The following customers are not visited: $not_visited")
    (length(routes) > data.K) && error("The solution has $(length(routes)) routes, more than K = $(data.K)")
    (abs(total - cost) > 1e-6 * max(1, abs(cost))) &&
        error("Cost calculated from the routes ($total) is different from the solution cost ($cost)")
end

# Checks the solution x of the model with value z: x_a binary, in-degree and out-degree 1 at every customer, and the
# sum of c_a x_a (computed from the vertex data) equal to z; then the routes are recovered from x, without
# assuming anything (subtours are detected), and checked with checkroutes. xval maps each arc to the value of x.
function checksolution_x(data::DataVRPTW, xval::Dict, z::Float64)
    V, nc, tol = data.G′.V′, n(data), 1e-6
    for (a, v) in xval
        (abs(v) > tol && abs(v - 1) > tol) && error("x[$a] = $v is not binary")
    end
    used = [a for (a, v) in xval if v > 0.5]
    succ = Dict{Int,Vector{Int}}()
    indeg = zeros(Int, nc)
    for (i, j) in used
        push!(get!(succ, i, Int[]), j)
        j > 0 && (indeg[j] += 1)
    end
    for i in 1:nc
        (indeg[i] != 1) && error("Customer $i has in-degree $(indeg[i]), not 1")
        (length(get(succ, i, Int[])) != 1) && error("Customer $i has out-degree $(length(get(succ, i, Int[]))), not 1")
    end
    cost = sum(distance(V[i+1], V[j+1]) for (i, j) in used; init=0.0)
    (abs(cost - z) > 1e-6 * max(1, abs(z))) && error("Cost calculated from x ($cost) is different from the objective value ($z)")
    routes = Vector{Int}[]
    for first in get(succ, 0, Int[])
        r, j = Int[], first
        while j != 0
            (length(r) > nc) && error("A route starting with customer $first does not return to the depot")
            push!(r, j)
            j = succ[j][1]
        end
        push!(routes, r)
    end
    # customers not reached from the depot are in subtours
    reached = Set(vcat(routes...))
    in_subtours = [i for i in 1:nc if !(i in reached)]
    isempty(in_subtours) || error("The customers $in_subtours are in subtours (not reached from the depot)")
    checkroutes(data, routes, z)
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

contains(p, s) = findnext(s, p, 1) != nothing
# read solution from file
function readsolution(solpath)
    str = read(solpath, String)
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
            sol.cost = parse(Float64, aux[j+1])
            return sol
        end
        j += 2 # skip "Route" and "#j:" elements
    end
    error("The solution file was not read successfully. This format is not recognized.")
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
    open(tikzpath, "w") do f
        write(f, "\\documentclass[crop,tikz]{standalone}\n")
        write(
            f,
            "\\usetikzlibrary{arrows}\n\\usetikzlibrary{shapes.geometric}\n\\usetikzlibrary {positioning}" *
            "\n\\pgfdeclarelayer{back}\n\\pgfsetlayers{back,main}\n\\makeatletter\n\\pgfkeys{%" *
            "\n/tikz/on layer/.code={\n\\def\\tikz@path@do@at@end{\\endpgfonlayer\\endgroup\\tikz@path@do@at@end}%" *
            "\n\\pgfonlayer{#1}\\begingroup%\n }%\n}\n\\makeatother\n\\begin{document}\n",
        )

        # get limits to draw
        pos_x_vals = [i.pos_x for i in data.G′.V′]
        pos_y_vals = [i.pos_y for i in data.G′.V′]
        scale_fac = 1 / (max(maximum(pos_x_vals), maximum(pos_y_vals)) / 10)
        write(
            f,
            "\\begin{tikzpicture}[thick, scale=1, every node/.style={minimum size=0.6cm, scale=0.4}, triangle/.style = {fill=white, regular polygon, regular polygon sides=6, scale=1.1, inner sep=0cm}]\n",
        )
        for i in data.G′.V′
            x_plot, y_plot = scale_fac * i.pos_x, scale_fac * i.pos_y
            if i.id_vertex == 0 # plot depot
                write(
                    f,
                    "\t\\node[draw, line width=0.1mm, rectangle, fill=yellow, inner sep=0.05cm, scale=0.9] (v$(i.id_vertex)) at ($(x_plot),$(y_plot)) {\\footnotesize $(i.id_vertex)};\n",
                )
            elseif i.id_vertex <= n(data)
                write(
                    f,
                    "\t\\node[draw, line width=0.1mm, circle, fill=white, inner sep=0.05cm] (v$(i.id_vertex)) at ($(x_plot),$(y_plot)) {\\footnotesize $(i.id_vertex)};\n",
                )
            else
                write(
                    f,
                    "\t\\node[draw, line width=0.1mm, triangle, fill=white] (v$(i.id_vertex)) at ($(x_plot),$(y_plot)) {\\footnotesize $(i.id_vertex)};\n",
                )
            end
        end
        write(f, "\\begin{pgfonlayer}{back}\n")
        for (idr, r) in enumerate(solution.routes)
            prev = 0
            for i in r
                a = (prev, i)
                edge_style = (prev == 0 || i == 0) ? "dashed,line width=0.2pt,opacity=.4" : "line width=0.4pt"
                write(f, "\t\\path[->,$(edge_style)] (v$(a[1])) edge node {} (v$(a[2]));\n")
                prev = i
            end
            write(f, "\t\\path[->,dashed,line width=0.2pt,opacity=.4] (v$prev) edge node {} (v0);\n")
        end
        write(f, "\\end{pgfonlayer}\n\\end{tikzpicture}\n")
        write(f, "\\end{document}\n")
    end
end


