mutable struct RingStar
    ring::Vector{Int} # sequence of points in the ring (the root 0 is implicit at both ends)
    stars::Dict{Int,Vector{Int}} # stars[i] = terminals connected to the ring point i
end

mutable struct Solution
    cost::Union{Int,Float64}
    ringstars::Vector{RingStar}
end

# recover the ring from the edges used by a path, walking from the root
function recover_ring(ring_edges::Vector{Tuple{Int,Int}})
    adj = Dict{Int,Vector{Int}}()
    for (i, j) in ring_edges
        push!(get!(adj, i, Int[]), j)
        push!(get!(adj, j, Int[]), i)
    end
    ring, curr, closed = Int[], 0, false
    for _ in 1:length(ring_edges)
        isempty(get(adj, curr, Int[])) && error("Problem trying to recover a ring from the x values.")
        next = pop!(adj[curr])
        deleteat!(adj[next], findfirst(==(curr), adj[next]))
        if next == 0
            closed = true
            break
        end
        push!(ring, next)
        curr = next
    end
    (!closed || length(ring) + 1 != length(ring_edges)) && error(
        "Problem trying to recover a ring from the x values. The edges do not form a single cycle through the root.",
    )
    return ring
end

# build Solution from the values of x and z in each path (ring-star) of the solution
function getsolution(data::DataCRSP, optimizer::VrpOptimizer, x, z, objval, app::Dict{String,Any})
    ringstars = RingStar[]
    for p in 1:get_number_of_positive_paths(optimizer)
        ring_edges = Tuple{Int,Int}[]
        for e in edges(data)
            for _ in 1:round(Int, get_value(optimizer, x[e], p))
                push!(ring_edges, e)
            end
        end
        stars = Dict{Int,Vector{Int}}()
        for i in points(data), j in star_set(data, i)
            if get_value(optimizer, z[(i, j)], p) > 0.5
                push!(get!(stars, i, Int[]), j)
            end
        end
        for _ in 1:round(Int, get_value(optimizer, p)) # path multiplicity
            push!(ringstars, RingStar(recover_ring(ring_edges), stars))
        end
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
