# Compact MIP for the CRSP (two-commodity flow formulation), solved with CPLEX.
# It is meant to validate the VRPSolver model (6.37) on small instances, so it models the same problem:
#  - every terminal is either on exactly one ring or connected through a star to exactly one ring point;
#  - every Steiner point is visited at most once (as imposed by the master constraints steiner_deg);
#  - a Steiner point on a ring must have a non-empty star (as in the star arcs A1).
#
# Graph: root r = 0, a copy r′ = N+1 of the root (each ring is a path from r to r′), and nodes 1..N,
# one per point of S ∪ T that may be on a ring.
# Two-commodity flow (Baldacci, Hadjiconstantinou and Mingozzi, 2004): on each used edge {u,v},
# f_uv + f_vu = W; the outbound commodity leaves r with the ring load and the inbound one leaves r′ with W.

function build_compact_model(data::DataCRSP)
    T, W = terminals(data), capacity(data)
    nodes = filter(i -> !isempty(feasible_stars(data, i)), points(data)) # points that may be on a ring
    N = length(nodes)
    r, r′ = 0, N + 1
    V = collect(1:N)
    point(v) = (v == r || v == r′) ? 0 : nodes[v]
    E = [(u, v) for u in 0:N for v in (u+1):(N+1) if (u, v) != (r, r′)]
    A = vcat(E, [(v, u) for (u, v) in E])
    cost(u, v) = c(data, minmax(point(u), point(v)))
    inc = Dict(v => Tuple{Int,Int}[] for v in 0:(N+1)) # incident edges
    for (u, v) in E
        push!(inc[u], (u, v))
        push!(inc[v], (u, v))
    end
    nbr(v) = [(e[1] == v) ? e[2] : e[1] for e in inc[v]]
    Zc = [(v, j) for v in V for j in star_set(data, point(v))] # star connections of each node
    centers = Dict(j => [v for (v, j′) in Zc if j′ == j] for j in T)
    node = Dict(nodes[v] => v for v in V)
    total_demand = sum(d(data, j) for j in T)

    m = Model(CPLEX.Optimizer)
    @variable(m, x[e in E], Bin)
    @variable(m, y[v in V], Bin)
    @variable(m, z[Zc], Bin)
    @variable(m, f[a in A] >= 0)
    @objective(m, Min,
        sum(cost(u, v) * x[(u, v)] for (u, v) in E) + sum(b(data, point(v), j) * z[(v, j)] for (v, j) in Zc))

    @expression(m, load[v in V], d(data, point(v)) * y[v] + sum(d(data, j) * z[(v, j)] for j in star_set(data, point(v))))
    @expression(m, nb_rings, sum(x[(r, v)] for v in V))

    # every terminal is either on a ring or in a star
    @constraint(m, cover[j in T], (haskey(node, j) ? y[node[j]] : 0) + sum(z[(v, j)] for v in centers[j]) == 1)
    # stars only at ring points; Steiner points on a ring need a non-empty star
    @constraint(m, [(v, j) in Zc], z[(v, j)] <= y[v])
    @constraint(m, [v in V; !(point(v) in T)], y[v] <= sum(z[(v, j)] for j in star_set(data, point(v))))
    # degrees
    @constraint(m, deg[v in V], sum(x[e] for e in inc[v]) == 2 * y[v])
    @constraint(m, sum(x[(v, r′)] for v in V) == nb_rings)
    @constraint(m, nb_rings >= lowerBoundNbRingStars(data))
    # two-commodity flow
    @constraint(m, [(u, v) in E], f[(u, v)] + f[(v, u)] == W * x[(u, v)])
    @constraint(m, [v in V], sum(f[(u, v)] - f[(v, u)] for u in nbr(v)) == 2 * load[v])
    @constraint(m, sum(f[(r, v)] for v in V) == total_demand)
    @constraint(m, sum(f[(v, r)] for v in V) == W * nb_rings - total_demand)
    @constraint(m, sum(f[(r′, v)] for v in V) == W * nb_rings)
    @constraint(m, [v in V], f[(v, r′)] == 0)

    return m, nodes, E
end

# decode the ring-stars from the values of x and z. Besides paths from r to r′, the flow constraints also
# accept rings from r back to r (load <= W) and from r′ back to r′ (load = W), which are valid rings as well,
# so r′ is identified with r and the rings are recovered by walking (and consuming) the edges from r.
function compact_solution(data::DataCRSP, m, nodes, E, app::Dict{String,Any})
    x, z = m[:x], m[:z]
    N = length(nodes)
    r, r′ = 0, N + 1
    root(v) = (v == r′) ? r : v
    adj = Dict(v => Int[] for v in 0:N)
    for (u, v) in E
        if value(x[(u, v)]) > 0.5
            push!(adj[root(u)], root(v))
            push!(adj[root(v)], root(u))
        end
    end
    ringstars = RingStar[]
    while !isempty(adj[r])
        ring, stars = Int[], Dict{Int,Vector{Int}}()
        v = pop!(adj[r])
        deleteat!(adj[v], findfirst(==(r), adj[v]))
        while v != r
            i = nodes[v]
            push!(ring, i)
            for j in star_set(data, i)
                value(z[(v, j)]) > 0.5 && push!(get!(stars, i, Int[]), j)
            end
            next = only(adj[v])
            empty!(adj[v])
            deleteat!(adj[next], findfirst(==(v), adj[next]))
            v = next
        end
        push!(ringstars, RingStar(ring, stars))
    end
    any(!isempty, values(adj)) && error("Problem trying to recover the rings of the compact model: there are subtours.")
    objval = objective_value(m)
    if !app["noround"]
        objval = trunc(Int, round(objval))
    end
    return Solution(objval, ringstars)
end

# solve the compact model; return (status, solution_found, solution)
function solve_compact_model(data::DataCRSP, app::Dict{String,Any})
    m, nodes, E = build_compact_model(data)
    println("Compact model: $(length(nodes)) nodes, $(num_variables(m)) variables, " *
            "$(num_constraints(m; count_variable_in_set_constraints=false)) constraints")
    (app["ub"] < 10000000.0) && set_attribute(m, "CPXPARAM_MIP_Tolerances_UpperCutoff", app["ub"] + 0.5)
    optimize!(m)
    status = termination_status(m)
    found = primal_status(m) == MOI.FEASIBLE_POINT
    println("statistics_compact: $(basename(app["instance"])) & $status & " *
            "$(found ? objective_value(m) : "--") & $(objective_bound(m)) & $(round(solve_time(m), digits=2)) \\\\")
    flush(stdout)
    sol = found ? compact_solution(data, m, nodes, E, app) : nothing
    return (status == MOI.OPTIMAL ? :Optimal : status), found, sol
end
