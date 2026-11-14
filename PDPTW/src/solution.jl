mutable struct Solution
    cost::Union{Int,Float64}
    routes::Array{Array{Int}}
end

# build Solution from the variables x
function getsolution(data::DataPDPTW, x, objval, optimizer, app)
    A, dim = arcs(data), 2 * n(data) + 1
    adj_list = [[] for i in 1:dim]
    for a in A
        val = get_value(optimizer, x[a])
        if val > 0.5
            push!(adj_list[a[1]+1], a[2])
        end
    end
    visited, routes = [false for i in 2:dim], []
    for i in adj_list[1]
        d(data, i) < 0 && !visited[sibling(data, i)] && error("Problem trying to recover the route from the x values. " *
                                                              "Delivery $i visited before the pickup $(sibling(data,i)).")
        r, prev = [], 0
        push!(r, i)
        visited[i] = true
        length(adj_list[i+1]) != 1 && error("Problem trying to recover the route from the x values. " *
                                            "Customer $i has $(length(adj_list[i+1])) outcoming arcs.")
        next = adj_list[i+1][1]
        maxit, it = dim, 0
        while next != 0 && it < maxit
            d(data, next) < 0 && !visited[sibling(data, next)] && error("Problem trying to recover the route from the x values. " *
                                                                        "Delivery $next visited before the pickup $(sibling(data,next)).")
            length(adj_list[next+1]) != 1 && error("Problem trying to recover the route from the x values. " *
                                                   "Customer $next has $(length(adj_list[next+1])) outcoming arcs.")
            push!(r, next)
            visited[next] = true
            next = adj_list[next+1][1]
            it += 1
        end
        (it == maxit) && error("Problem trying to recover the route from the x values. " *
                               "Some route can not be recovered because the return to depot is never reached")
        push!(routes, r)
    end
    !isempty(filter(y -> y == false, visited)) && error("Problem trying to recover the route from the x values. " *
                                                        "At least one vertex was not visited or there are subtours in the solution x.")
    if app["round"]
        objval = trunc(Int, round(objval))
    end

    return Solution(objval, routes)
end

# Checks routes against the definition of the PDPTW, computing distances and times from the vertex data (assuming
# nothing about how the routes were obtained, see Note 6.12 of the book "Optimizing with Column Generation"):
# every pickup and every delivery is visited exactly once, the pickup and the delivery of a request are in the same
# route and the pickup comes first; the load is in [0, Q] along each route; leaving the depot at time 0, the service
# of each vertex starts within its time window (waiting is allowed) and the vehicle returns to the depot before its
# due time; at most K routes (exactly k if k >= 0); the cost is the total distance, plus the fixed cost per vehicle
# in the Ropke and Cordeau instances. Throws an error otherwise.
function checkroutes(data::DataPDPTW, routes, cost::Real, app::Dict{String,Any}; k::Int=-1)
    V, Q, nv, tol = data.G′.V′, veh_capacity(data), 2 * n(data), 1e-6
    dist(i, j) = distance(V[i+1], V[j+1], app["round"])
    route_of, pos = zeros(Int, nv), zeros(Int, nv)
    total = 0.0
    for (kr, r) in enumerate(routes)
        isempty(r) && error("Route #$kr is empty")
        load, time, prev = 0.0, 0.0, 0
        for (p, j) in enumerate(r)
            (1 <= j <= nv) || error("Route #$kr visits $j, which is not a pickup or a delivery")
            (route_of[j] != 0) && error("Vertex $j is visited more than once")
            route_of[j], pos[j] = kr, p
            load += V[j+1].demand
            (load < -tol || load > Q + tol) && error("Route #$kr has load $load after vertex $j, not in [0, $Q]")
            time = max(time + (prev == 0 ? 0 : V[prev+1].service_time) + dist(prev, j), V[j+1].start_tw)
            (time > V[j+1].end_tw + tol) &&
                error("Route #$kr starts the service of vertex $j at $time, after its due time $(V[j+1].end_tw)")
            total += dist(prev, j)
            prev = j
        end
        time += V[prev+1].service_time + dist(prev, 0)
        (time > V[1].end_tw + tol) && error("Route #$kr returns to the depot at $time, after its due time $(V[1].end_tw)")
        total += dist(prev, 0)
    end
    for req in requests(data)
        p, dl = req.pickup.id, req.delivery.id
        (route_of[p] == 0 || route_of[dl] == 0) && error("Request $(req.id) (pickup $p, delivery $dl) is not served")
        (route_of[p] != route_of[dl]) && error("The pickup $p and the delivery $dl of request $(req.id) are in different routes")
        (pos[p] > pos[dl]) && error("The delivery $dl of request $(req.id) comes before its pickup $p")
    end
    nr = length(routes)
    (nr > data.K) && error("The solution has $nr routes, more than K = $(data.K)")
    (k >= 0 && nr != k) && error("The solution has $nr routes, not k = $k")
    expected = app["lilim"] ? total : app["fixed"] * nr + total
    (abs(expected - cost) > 1e-6 * max(1, abs(cost))) &&
        error("Cost calculated from the routes ($expected) is different from the solution cost ($cost)")
end

# Checks the solution x of the model with value z: x_a binary, in-degree and out-degree 1 at every pickup and
# delivery, and the objective (computed from the vertex data) equal to z; then the routes are recovered from x,
# without assuming anything (subtours are detected), and checked with checkroutes. xval maps each arc to x.
function checksolution_x(data::DataPDPTW, xval::Dict, z::Float64, app::Dict{String,Any}; k::Int=-1)
    V, nv, tol = data.G′.V′, 2 * n(data), 1e-6
    for (a, v) in xval
        (abs(v) > tol && abs(v - 1) > tol) && error("x[$a] = $v is not binary")
    end
    used = [a for (a, v) in xval if v > 0.5]
    succ = Dict{Int,Vector{Int}}()
    indeg = zeros(Int, nv)
    for (i, j) in used
        push!(get!(succ, i, Int[]), j)
        j > 0 && (indeg[j] += 1)
    end
    for i in 1:nv
        (indeg[i] != 1) && error("Vertex $i has in-degree $(indeg[i]), not 1")
        (length(get(succ, i, Int[])) != 1) && error("Vertex $i has out-degree $(length(get(succ, i, Int[]))), not 1")
    end
    routes = Vector{Int}[]
    for first in get(succ, 0, Int[])
        r, j = Int[], first
        while j != 0
            (length(r) > nv) && error("A route starting with vertex $first does not return to the depot")
            push!(r, j)
            j = succ[j][1]
        end
        push!(routes, r)
    end
    reached = Set(vcat(routes...))
    in_subtours = [i for i in 1:nv if !(i in reached)]
    isempty(in_subtours) || error("The vertices $in_subtours are in subtours (not reached from the depot)")
    total = sum(distance(V[i+1], V[j+1], app["round"]) for (i, j) in used; init=0.0)
    obj = app["lilim"] ? total : app["fixed"] * length(routes) + total
    (abs(obj - z) > 1e-6 * max(1, abs(z))) && error("Objective calculated from x ($obj) is different from the objective value ($z)")
    checkroutes(data, routes, z, app; k=k)
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
        basic_colors = ["black", "red", "green", "blue", "yellow", "orange", "pink", "magenta", "gray", "darkgray", "lightgray", "brown", "lime", "olive", "purple", "teal", "violet"]
        colors = copy(basic_colors)
        for i in ["!25", "!50", "!75"]
            append!(colors, [c * i for c in basic_colors])
        end
        write(f, "\\documentclass[crop,tikz]{standalone}\n")
        write(f, "\\usetikzlibrary{arrows}\n\\usetikzlibrary{shapes.geometric}\n\\usetikzlibrary {positioning}" *
                 "\n\\pgfdeclarelayer{back}\n\\pgfsetlayers{back,main}\n\\makeatletter\n\\pgfkeys{%" *
                 "\n/tikz/on layer/.code={\n\\def\\tikz@path@do@at@end{\\endpgfonlayer\\endgroup\\tikz@path@do@at@end}%" *
                 "\n\\pgfonlayer{#1}\\begingroup%\n }%\n}\n\\makeatother\n\\begin{document}\n")

        # get limits to draw
        pos_x_vals = [i.pos_x for i in data.G′.V′]
        pos_y_vals = [i.pos_y for i in data.G′.V′]
        scale_fac = 1 / (max(maximum(pos_x_vals), maximum(pos_y_vals)) / 10)
        write(f, "\\begin{tikzpicture}[thick, scale=1, every node/.style={minimum size=0.6cm, scale=0.4}, triangle/.style = {fill=white, regular polygon, regular polygon sides=6, scale=1.1, inner sep=0cm}]\n")
        for i in data.G′.V′
            x_plot, y_plot = scale_fac * i.pos_x, scale_fac * i.pos_y
            if i.id == 0 # plot depot
                write(f, "\t\\node[draw, line width=0.1mm, rectangle, fill=yellow, inner sep=0.05cm, scale=0.9] (v$(i.id)) at ($(x_plot),$(y_plot)) {\\footnotesize $(i.id)};\n")
            elseif i.id <= n(data)
                write(f, "\t\\node[draw, line width=0.1mm, circle, fill=white, inner sep=0.05cm] (v$(i.id)) at ($(x_plot),$(y_plot)) {\\footnotesize $(i.id)};\n")
            else
                write(f, "\t\\node[draw, line width=0.1mm, triangle, fill=white] (v$(i.id)) at ($(x_plot),$(y_plot)) {\\footnotesize $(i.id)};\n")
            end
        end
        write(f, "\\begin{pgfonlayer}{back}\n")
        for (idr, r) in enumerate(solution.routes)
            #=prev = r[1] # Uncomment (and comment below) to hide edges with the depot
            for i in r[2:end]
               e = (prev,i)
               write(f, "\t\\draw[-,line width=0.8pt] (v$(e[1])) -> (v$(e[2]));\n")
               prev = i
            end=#
            prev = 0
            for i in r
                a = (prev, i)
                edge_style = (prev == 0 || i == 0) ? "dashed,line width=0.2pt,opacity=.4" : "line width=0.4pt"
                write(f, "\t\\path[->,$(edge_style), $(colors[idr%length(colors)])] (v$(a[1])) edge node {} (v$(a[2]));\n")
                prev = i
            end
            write(f, "\t\\path[->,dashed,line width=0.2pt,opacity=.4,$(colors[idr%length(colors)])] (v$prev) edge node {} (v0);\n")
        end
        write(f, "\\end{pgfonlayer}\n\\end{tikzpicture}\n")
        write(f, "\\end{document}\n")
    end
end

