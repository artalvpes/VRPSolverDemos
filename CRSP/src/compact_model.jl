# Set partitioning MIP for the CRSP over all feasible ring-stars, solved with CPLEX.
# It is meant to validate the VRPSolver model (6.37) on small instances with a small capacity W (so that
# all ring-stars can be enumerated), and it models the same problem:
#  - every terminal is either on exactly one ring or connected through a star to exactly one ring point;
#  - every Steiner point is visited at most once (as imposed by the master constraints steiner_deg);
#  - a Steiner point on a ring must have a non-empty star (as in the star arcs A1).
#
# A ring-star is a set R of ring points (each one with a star B ⊆ T(i), 0 < d(i,B) <= W) covering disjoint
# sets of terminals with total demand <= W. Its cost is the cost of the stars plus the cost of an optimal
# ring through the root and R (a TSP solved by a memoized Held-Karp dynamic program shared by all rings;
# a single point i gives the ring 0-i-0 with cost 2c(0,i)). For each pair (terminals covered, Steiner
# points used), only the cheapest ring-star is kept as a column.

# Held-Karp over the root (position 0) and the points P (positions 1..N), with the subsets as bitmasks
struct RingTSP
    dist::Matrix{Float64} # dist[p+1, q+1] = c(P[p], P[q]), with P[0] = root
    memo::Dict{Tuple{UInt64,Int},Float64} # (mask, last) => cheapest path from the root through mask ending at last
end

function RingTSP(data::DataCRSP, P::Vector{Int})
    pts = vcat([0], P)
    n = length(pts)
    dist = [(p == q) ? 0.0 : c(data, minmax(pts[p], pts[q])) for p in 1:n, q in 1:n]
    return RingTSP(dist, Dict{Tuple{UInt64,Int},Float64}())
end

bit(p::Int) = UInt64(1) << (p - 1)
positions(mask::UInt64) = [p for p in 1:64 if (mask & bit(p)) != 0]

function path_cost(tsp::RingTSP, mask::UInt64, last::Int)
    rest = mask & ~bit(last)
    (rest == 0) && return tsp.dist[1, last+1]
    return get!(tsp.memo, (mask, last)) do
        minimum(path_cost(tsp, rest, k) + tsp.dist[k+1, last+1] for k in positions(rest))
    end
end

ring_cost(tsp::RingTSP, mask::UInt64) = minimum(path_cost(tsp, mask, j) + tsp.dist[j+1, 1] for j in positions(mask))

# optimal visiting order of the positions in mask
function ring_order(tsp::RingTSP, mask::UInt64)
    cost = ring_cost(tsp, mask)
    last = first(j for j in positions(mask) if isapprox(path_cost(tsp, mask, j) + tsp.dist[j+1, 1], cost))
    order = [last]
    while mask != bit(last)
        cost = path_cost(tsp, mask, last)
        mask &= ~bit(last)
        last = first(k for k in positions(mask) if isapprox(path_cost(tsp, mask, k) + tsp.dist[k+1, last+1], cost))
        pushfirst!(order, last)
    end
    return order
end

struct RingStarColumn
    cost::Float64
    terminals::Vector{Int} # covered terminals
    steiner::Vector{Int} # Steiner points on the ring
    ringstar::RingStar
end

# enumerate the cheapest ring-star for each pair (terminals covered, Steiner points used)
function enumerate_ringstars(data::DataCRSP)
    T, W = terminals(data), capacity(data)
    P = filter(i -> !isempty(feasible_stars(data, i)), points(data)) # points that may be on a ring
    N = length(P)
    (length(T) > 64 || N > 64) && error("The set partitioning model supports at most 64 points")
    tbit = Dict(j => bit(k) for (k, j) in enumerate(T))
    steiner_mask = reduce(|, [bit(p) for p in 1:N if !(P[p] in T)]; init=UInt64(0))
    # ring elements of each point: (covered terminals, demand, star cost, star)
    elems = [[(reduce(|, [tbit[j] for j in B]; init=(P[p] in T) ? tbit[P[p]] : UInt64(0)), d(data, P[p], B),
        sum(b(data, P[p], j) for j in B; init=0.0), B) for B in feasible_stars(data, P[p])] for p in 1:N]
    tsp = RingTSP(data, P)
    best = Dict{Tuple{UInt64,UInt64},Tuple{Float64,UInt64,Vector{Vector{Int}}}}()
    stars = Vector{Vector{Int}}(undef, N) # star of each point on the current ring
    nb_ringstars = 0

    function dfs(first_p::Int, covered::UInt64, ring::UInt64, load::Float64, star_cost::Float64)
        for p in first_p:N, (m, dem, bc, B) in elems[p]
            ((m & covered) != 0 || load + dem > W + 1e-6) && continue
            new_ring = ring | bit(p)
            stars[p] = B
            nb_ringstars += 1
            cost = star_cost + bc + ring_cost(tsp, new_ring)
            key = (covered | m, new_ring & steiner_mask)
            if !haskey(best, key) || cost < best[key][1] - 1e-9
                best[key] = (cost, new_ring, [stars[q] for q in positions(new_ring)])
            end
            dfs(p + 1, covered | m, new_ring, load + dem, star_cost + bc)
        end
    end
    dfs(1, UInt64(0), UInt64(0), 0.0, 0.0)

    columns = RingStarColumn[]
    for ((covered, smask), (cost, ring, ring_stars)) in best
        star_of = Dict(P[p] => B for (p, B) in zip(positions(ring), ring_stars) if !isempty(B))
        rs = RingStar([P[p] for p in ring_order(tsp, ring)], star_of)
        push!(columns, RingStarColumn(cost, [T[k] for k in positions(covered)], [P[p] for p in positions(smask)], rs))
    end
    println("Enumeration: $nb_ringstars ring-stars, $(length(columns)) columns, " *
        "$(length(tsp.memo)) Held-Karp states")
    return columns
end

function build_compact_model(data::DataCRSP)
    T, S = terminals(data), steiner_points(data)
    columns = enumerate_ringstars(data)
    covering = Dict(j => Int[] for j in T)
    using_steiner = Dict(s => Int[] for s in S)
    for (k, col) in enumerate(columns)
        foreach(j -> push!(covering[j], k), col.terminals)
        foreach(s -> push!(using_steiner[s], k), col.steiner)
    end

    m = Model(CPLEX.Optimizer)
    @variable(m, λ[k in 1:length(columns)], Bin)
    @objective(m, Min, sum(col.cost * λ[k] for (k, col) in enumerate(columns)))
    # every terminal is covered by exactly one ring-star
    @constraint(m, cover[j in T], sum(λ[k] for k in covering[j]) == 1)
    # every Steiner point is on at most one ring
    @constraint(m, steiner[s in S; !isempty(using_steiner[s])], sum(λ[k] for k in using_steiner[s]) <= 1)

    return m, columns
end

function compact_solution(m, columns::Vector{RingStarColumn}, app::Dict{String,Any})
    λ = m[:λ]
    ringstars = [col.ringstar for (k, col) in enumerate(columns) if value(λ[k]) > 0.5]
    objval = objective_value(m)
    if !app["noround"]
        objval = trunc(Int, round(objval))
    end
    return Solution(objval, ringstars)
end

# solve the set partitioning model; return (status, solution_found, solution)
function solve_compact_model(data::DataCRSP, app::Dict{String,Any})
    m, columns = build_compact_model(data)
    println("Set partitioning model: $(num_variables(m)) variables, " *
        "$(num_constraints(m; count_variable_in_set_constraints=false)) constraints")
    # (app["ub"] < 10000000.0) && set_attribute(m, "CPXPARAM_MIP_Tolerances_UpperCutoff", app["ub"] + 0.5)
    optimize!(m)
    status = termination_status(m)
    found = primal_status(m) == MOI.FEASIBLE_POINT
    println("statistics_compact: $(basename(app["instance"])) & $status & " *
        "$(found ? objective_value(m) : "--") & $(objective_bound(m)) & $(round(solve_time(m), digits=2)) \\\\")
    flush(stdout)
    sol = found ? compact_solution(m, columns, app) : nothing
    return (status == MOI.OPTIMAL ? :Optimal : status), found, sol
end
