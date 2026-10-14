mutable struct RingStar
    ring::Vector{Int} # sequence of points in the ring (the root 0 is implicit at both ends)
    stars::Dict{Int,Vector{Int}} # stars[i] = terminals connected to the ring point i
end

mutable struct Solution
    cost::Union{Int,Float64}
    ringstars::Vector{RingStar}
end

# build Solution from the aggregated values of x and z. They must be used instead of the paths, because an
# integer solution of the VRPSolver is integer in the original variables, not necessarily in the path
# variables λ (e.g. the non-elementary path 0-11-17-11-0 and the path 0-17-0, both with λ = 0.5, give the
# integer ring 0-11-17-0). Since every point has degree at most 2, x decomposes uniquely into rings.
function getsolution(data::DataCRSP, optimizer::VrpOptimizer, x, z, objval, app::Dict{String,Any})
    adj = Dict(i => Int[] for i in 0:(dimension(data)-1))
    for (i, j) in edges(data)
        for _ in 1:round(Int, get_value(optimizer, x[(i, j)]))
            push!(adj[i], j)
            push!(adj[j], i)
        end
    end
    star_of = Dict{Int,Vector{Int}}() # star_of[i] = terminals connected to the ring point i
    for (i, j) in z.axes[1]
        get_value(optimizer, z[(i, j)]) > 0.5 && push!(get!(star_of, i, Int[]), j)
    end
    ringstars = RingStar[]
    while !isempty(adj[0])
        ring, v = Int[], pop!(adj[0])
        deleteat!(adj[v], findfirst(==(0), adj[v]))
        while v != 0
            push!(ring, v)
            length(adj[v]) != 1 && error(
                "Problem trying to recover the rings from the x values. Point $v has $(length(adj[v]) + 1) incident edges.",
            )
            next = pop!(adj[v])
            deleteat!(adj[next], findfirst(==(v), adj[next]))
            v = next
        end
        push!(ringstars, RingStar(ring, Dict(i => star_of[i] for i in ring if haskey(star_of, i))))
    end
    any(!isempty, values(adj)) && error("Problem trying to recover the rings from the x values. There are subtours.")
    on_ring = Set(i for rs in ringstars for i in rs.ring)
    for i in keys(star_of)
        (i in on_ring) || error("Star center $i is not on any ring")
    end
    if !app["noround"]
        objval = trunc(Int, round(objval))
    end
    return Solution(objval, ringstars)
end

function print_ringstars(solution)
    for (k, rs) in enumerate(solution.ringstars)
        print("Ring-star #$k: ")
        for i in rs.ring
            print(i)
            haskey(rs.stars, i) && print("{", join(rs.stars[i], ","), "}")
            print(" ")
        end
        println()
    end
end

# checks the feasiblity of a solution
function checksolution(data::DataCRSP, solution)
    W = capacity(data)
    covered = Dict(j => 0 for j in terminals(data))
    sum_cost = 0.0
    for (k, rs) in enumerate(solution.ringstars)
        sum_demand, prev = 0.0, 0
        for i in rs.ring
            (i in points(data)) || error("Ring-star #$k: invalid ring point $i")
            (i in rs.ring[1:findfirst(==(i), rs.ring)-1]) && error("Ring-star #$k: point $i is repeated in the ring")
            sum_cost += c(data, (min(prev, i), max(prev, i)))
            prev = i
        end
        sum_cost += c(data, (0, prev))
        for j in rs.ring
            if j in terminals(data)
                covered[j] += 1
                sum_demand += d(data, j)
            end
        end
        for (i, B) in rs.stars
            (i in rs.ring) || error("Ring-star #$k: star center $i is not in the ring")
            for j in B
                (j in star_set(data, i)) || error("Ring-star #$k: terminal $j is not in T($i)")
                covered[j] += 1
                sum_demand += d(data, j)
                sum_cost += b(data, i, j)
            end
        end
        (sum_demand > W) && error(
            "Ring-star #$k is violating the capacity constraint. Sum of the demands is $(sum_demand) and W is $W",
        )
    end
    for (j, cnt) in covered
        (cnt != 1) && error("Terminal $j is covered $cnt times")
    end
    (abs(solution.cost - sum_cost) > 0.001) && error(
        "Cost calculated from the ring-stars ($sum_cost) is different from that passed as" *
        " argument ($(solution.cost)).",
    )
end

# write solution as TikZ figure (.tex)
# root: yellow square; terminals: white circles; Steiner points: gray diamonds (faded if unused);
# ring edges: solid lines; star connections: dashed lines.
function drawsolution(tikzpath, data::DataCRSP, solution)
    used = Set(i for rs in solution.ringstars for i in rs.ring)
    open(tikzpath, "w") do f
        write(f, "\\documentclass[crop,tikz]{standalone}\n")
        write(f, "\\usetikzlibrary{shapes.geometric}\n\\begin{document}\n")
        # get limits to draw
        pos_x_vals = [i.pos_x for i in data.G.V]
        pos_y_vals = [i.pos_y for i in data.G.V]
        scale_fac = 1 / (max(maximum(pos_x_vals), maximum(pos_y_vals)) / 10)
        write(f, "\\begin{tikzpicture}[thick, scale=1, every node/.style={scale=0.3}]\n")
        for v in data.G.V
            i = v.id_vertex
            x_plot, y_plot = scale_fac * v.pos_x, scale_fac * v.pos_y
            style = if i == data.root_id
                "draw, line width=0.1mm, rectangle, fill=yellow, inner sep=0.05cm, scale=1.4"
            elseif i in steiner_points(data)
                "draw, line width=0.1mm, diamond, fill=gray!40, inner sep=0.03cm" *
                (i in used ? "" : ", opacity=.3")
            else
                "draw, line width=0.1mm, circle, fill=white, inner sep=0.05cm"
            end
            write(f, "\t\\node[$style] (v$i) at ($(x_plot),$(y_plot)) {\\footnotesize $i};\n")
        end
        for rs in solution.ringstars
            prev = 0
            for i in vcat(rs.ring, [0])
                write(f, "\t\\draw[-,line width=0.8pt] (v$prev) -- (v$i);\n")
                prev = i
            end
            for (i, B) in rs.stars, j in B
                write(f, "\t\\draw[dashed,-,line width=0.5pt] (v$i) -- (v$j);\n")
            end
        end
        write(f, "\\end{tikzpicture}\n")
        write(f, "\\end{document}\n")
    end
end

# write solution in a file
function writesolution(solpath, solution)
    open(solpath, "w") do f
        redirect_stdout(f) do
            print_ringstars(solution)
            println("Cost $(solution.cost)")
        end
    end
end
