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

