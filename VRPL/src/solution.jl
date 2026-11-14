# A route is a sequence of stops (locker, customers assigned to the locker in this stop); it starts and ends at the
# depot, which is not included. A locker may appear in more than one stop (of the same route or of different routes).
mutable struct Solution
    cost::Union{Int,Float64}
    routes::Vector{Vector{Tuple{Int,Vector{Int}}}}
end

intcost(v) = isinteger(v) ? Int(v) : v

# build Solution from the edge variables x (each route is a sequence of vertices from the depot to the depot)
function getsolution(data::DataVRPL, x, pair, objval)
    # adjacency lists of the support graph (an edge with x = 2 appears twice); every visited vertex has degree 2
    N = length(pair)
    adj = [Int[] for v in 0:N]
    for e in x.axes[1]
        v = value(x[e])
        (v < -1e-6 || abs(v - round(v)) > 1e-6) && error("x[$e] = $v is not a non-negative integer")
        val = round(Int, v)
        for k in 1:val
            push!(adj[e[1]+1], e[2])
            push!(adj[e[2]+1], e[1])
        end
    end
    routes = Vector{Tuple{Int,Vector{Int}}}[]
    visited = falses(N)
    for first in adj[1]
        visited[first] && continue
        seq = Int[]
        prev, cur = 0, first
        while cur != 0
            visited[cur] && error("Problem trying to recover the routes from the x values (vertex $cur repeated).")
            length(adj[cur+1]) != 2 && error(
                "Problem trying to recover the routes from the x values. Vertex $cur has $(length(adj[cur+1])) " *
                "incident edges.",
            )
            visited[cur] = true
            push!(seq, cur)
            nextv = (adj[cur+1][1] == prev) ? adj[cur+1][2] : adj[cur+1][1]
            prev, cur = cur, nextv
        end
        # sequence of vertices -> sequence of locker stops (consecutive vertices of the same locker form one stop)
        route = Tuple{Int,Vector{Int}}[]
        for v in seq
            c, s = pair[v]
            if !isempty(route) && route[end][1] == s
                push!(route[end][2], c)
            else
                push!(route, (s, [c]))
            end
        end
        push!(routes, route)
    end
    return Solution(round(objval, digits=6), routes)
end

function route_string(route)
    return join(["$s [" * join(string.(cs), " ") * "]" for (s, cs) in route], " ")
end

route_load(data::DataVRPL, route) = sum(w(data, c) for (s, cs) in route for c in cs; init=0.0)

# prints each route with its load (sum of the demands of its customers)
function print_routes(data::DataVRPL, solution)
    for (i, r) in enumerate(solution.routes)
        println("Route #$i: ", route_string(r), " (load $(intcost(route_load(data, r))) of $(intcost(veh_capacity(data))))")
    end
end

# Checks a solution directly against the definition of the problem, assuming nothing about how it was obtained (see
# Note 6.12 of the book "Optimizing with Column Generation"). Each route starts at the depot, visits a sequence of
# lockers and returns to the depot; each customer is assigned exactly once, in a stop of a route, to one of its k
# nearest lockers; the load of each route (sum of the demands of its customers) is at most Q; the number of routes is
# in [minr, maxr]; and the cost (travel costs between consecutive stops, from and to the depot, plus the assignment
# costs) is equal to the cost of the solution. Throws an error otherwise.
function checksolution(data::DataVRPL, solution; minr::Int=1, maxr::Int=typemax(Int))
    Q = veh_capacity(data)
    nr = length(solution.routes)
    (minr <= nr <= maxr) || error("The solution has $nr routes, out of the interval [$minr, $maxr]")
    assigned = zeros(Int, nb_customers(data))
    sum_cost = 0.0
    for (i, r) in enumerate(solution.routes)
        isempty(r) && error("Route #$i is empty")
        load, prev = 0.0, 0
        for (s, cs) in r
            (1 <= s <= nb_lockers(data)) || error("Route #$i visits an invalid locker $s")
            sum_cost += d(data, prev, s)
            for c in cs
                (1 <= c <= nb_customers(data)) || error("Route #$i assigns an invalid customer $c")
                assigned[c] += 1
                (assigned[c] == 2) && error("Customer $c is assigned more than once")
                covers(data, s, c) || error(
                    "Customer $c is assigned to the locker $s, which is not one of its $(nb_nearest(data)) nearest " *
                    "lockers $(covering_lockers(data, c))",
                )
                sum_cost += f(data, c, s)
                load += w(data, c)
            end
            prev = s
        end
        sum_cost += d(data, prev, 0)
        (load > Q + 1e-6) && error("Route #$i is violating the capacity constraint. Its load is $load and Q is $Q")
    end
    unassigned = findall(==(0), assigned)
    isempty(unassigned) || error("The following customers were not assigned: $unassigned")
    (abs(solution.cost - sum_cost) > 0.001) && error(
        "Cost calculated from the routes ($sum_cost) is different from that passed as argument ($(solution.cost)).",
    )
end

# read solution from file (format written by writesolution)
function readsolution(app::Dict{String,Any})
    sol = Solution(0, [])
    for line in readlines(app["sol"])
        toks = split(replace(line, "[" => " [ ", "]" => " ] "))
        isempty(toks) && continue
        if lowercase(toks[1]) == "cost"
            v = parse(Float64, toks[2])
            sol.cost = intcost(v)
            return sol
        end
        lowercase(toks[1]) == "route" || error("Invalid line in the solution file: $line")
        route = Tuple{Int,Vector{Int}}[]
        j = 3 # skip "Route" and "#i:"
        while j <= length(toks)
            s = parse(Int, toks[j])
            toks[j+1] == "[" || error("Invalid route in the solution file: $line")
            j += 2
            cs = Int[]
            while toks[j] != "]"
                push!(cs, parse(Int, toks[j]))
                j += 1
            end
            push!(route, (s, cs))
            j += 1
        end
        push!(sol.routes, route)
    end
    error("The solution file was not read successfully (missing Cost line).")
end

# write solution in a file
function writesolution(solpath, solution)
    open(solpath, "w") do io
        for (i, r) in enumerate(solution.routes)
            println(io, "Route #$i: ", route_string(r))
        end
        println(io, "Cost $(solution.cost)")
    end
end

# write solution as TikZ figure (.tex): depot (yellow diamond), lockers (squares, gray if visited, white otherwise),
# customers (circles), routes (solid lines, one color per route) and assignments (dotted lines)
function drawsolution(tikzpath, data::DataVRPL, solution)
    pts = vcat([data.depot_xy], data.locker_xy, data.customer_xy)
    xmin, xmax = extrema(p[1] for p in pts)
    ymin, ymax = extrema(p[2] for p in pts)
    scale = 12 / max(xmax - xmin, ymax - ymin, 1e-9) # the figure is at most 12cm wide/high
    pos(p) = (round(scale * (p[1] - xmin), digits=3), round(scale * (p[2] - ymin), digits=3))
    visited = Set(s for r in solution.routes for (s, cs) in r)
    colors = ["blue", "red!80!black", "green!50!black", "orange!90!black", "violet", "teal", "brown", "magenta",
        "olive", "cyan!60!black"]
    open(tikzpath, "w") do io
        write(io, "\\documentclass[crop,tikz]{standalone}\n\\usetikzlibrary{shapes.geometric}\n\\begin{document}\n")
        write(io, "\\begin{tikzpicture}[every node/.style={font=\\tiny, inner sep=1pt}]\n")
        # routes and assignments first, so that the vertices are drawn over them
        x0, y0 = pos(data.depot_xy)
        write(io, "\t\\coordinate (v0) at ($x0,$y0);\n")
        for s in lockers(data)
            x, y = pos(data.locker_xy[s])
            write(io, "\t\\coordinate (v$s) at ($x,$y);\n")
        end
        for c in customers(data)
            x, y = pos(data.customer_xy[c])
            write(io, "\t\\coordinate (c$c) at ($x,$y);\n")
        end
        for (i, r) in enumerate(solution.routes)
            col = colors[mod1(i, length(colors))]
            pts_route = vcat(["v0"], ["v$s" for (s, cs) in r], ["v0"])
            write(io, "\t\\draw[$col, line width=0.9pt] " * join(["($p)" for p in pts_route], " -- ") * ";\n")
            for (s, cs) in r, c in cs
                write(io, "\t\\draw[$col, dotted, line width=0.7pt] (v$s) -- (c$c);\n")
            end
        end
        write(io, "\t\\node[draw, diamond, fill=yellow, minimum size=9pt] at (v0) {0};\n")
        for s in lockers(data)
            fill = (s in visited) ? "gray!40" : "white"
            write(io, "\t\\node[draw, rectangle, fill=$fill, minimum size=7pt] at (v$s) {$s};\n")
        end
        for c in customers(data)
            write(io, "\t\\node[draw, circle, fill=white, minimum size=6pt] at (c$c) {$c};\n")
        end
        write(io, "\\end{tikzpicture}\n\\end{document}\n")
    end
end
