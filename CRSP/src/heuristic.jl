# Simple heuristic for the CRSP, used to obtain an initial upper bound when none is given: the terminals are first
# routed in rings only (Clarke and Wright savings with the capacity W, then 2-opt and relocation of terminals between
# rings, first improvement); then, while it pays, a terminal of a ring is removed from the ring and connected by a star
# arc to another point of the same ring that can serve it (j in T(i)); the capacity of the ring-star does not change.
# Steiner points are not used. Returns a Solution, or nothing.

ring_edge(data::DataCRSP, i, j) = c(data, (min(i, j), max(i, j)))
function ring_cost(data::DataCRSP, r)
    isempty(r) && return 0.0
    return ring_edge(data, 0, r[1]) + sum(ring_edge(data, r[k], r[k+1]) for k in 1:length(r)-1; init=0.0) + ring_edge(data, r[end], 0)
end
ring_demand(data::DataCRSP, r) = sum(d(data, j) for j in r; init=0.0)

function crsp_rings(data::DataCRSP)
    W, T = capacity(data), terminals(data)
    routes = Dict(j => [j] for j in T)
    route_of = Dict(j => j for j in T)
    s = [(ring_edge(data, 0, i) + ring_edge(data, 0, j) - ring_edge(data, i, j), i, j) for i in T for j in T if i < j]
    sort!(s, rev=true)
    for (_, i, j) in s
        ri, rj = route_of[i], route_of[j]
        ri == rj && continue
        a, b = routes[ri], routes[rj]
        (a[end] == i || a[1] == i) && (b[1] == j || b[end] == j) || continue
        ring_demand(data, a) + ring_demand(data, b) <= W + 1e-9 || continue
        a[end] != i && reverse!(a)
        b[1] != j && reverse!(b)
        routes[ri] = vcat(a, b)
        delete!(routes, rj)
        for k in b
            route_of[k] = ri
        end
    end
    rings = collect(values(routes))
    # local search: 2-opt and relocation between rings
    improved = true
    deadline = time() + 10.0
    while improved && time() < deadline
        improved = false
        for r in rings, i in 1:length(r)-1, j in i+1:length(r)
            c2 = vcat(r[1:i-1], reverse(r[i:j]), r[j+1:end])
            if ring_cost(data, c2) < ring_cost(data, r) - 1e-9
                r[:] = c2; improved = true
            end
        end
        for a in eachindex(rings), p in eachindex(rings[a])
            t = rings[a][p]
            ra = deleteat!(copy(rings[a]), p)
            for b in eachindex(rings)
                a == b && continue
                ring_demand(data, rings[b]) + d(data, t) <= W + 1e-9 || continue
                for q in 1:length(rings[b])+1
                    rb = insert!(copy(rings[b]), q, t)
                    if ring_cost(data, ra) + ring_cost(data, rb) < ring_cost(data, rings[a]) + ring_cost(data, rings[b]) - 1e-9
                        rings[a], rings[b] = ra, rb
                        improved = true
                        break
                    end
                end
                improved && break
            end
            improved && break
        end
        filter!(!isempty, rings)
    end
    return rings
end

function crsp_heuristic(data::DataCRSP)
    all(d(data, j) <= capacity(data) for j in terminals(data)) || return nothing
    ringstars = [RingStar(r, Dict{Int,Vector{Int}}()) for r in crsp_rings(data)]
    for rs in ringstars
        improved = true
        while improved
            improved = false
            for (p, j) in enumerate(rs.ring)
                length(rs.ring) == 1 && break
                haskey(rs.stars, j) && continue # j is the center of a star
                for i in rs.ring
                    (i != j && j in star_set(data, i)) || continue
                    r2 = deleteat!(copy(rs.ring), p)
                    gain = ring_cost(data, rs.ring) - ring_cost(data, r2) - b(data, i, j)
                    if gain > 1e-9
                        rs.ring = r2
                        push!(get!(rs.stars, i, Int[]), j)
                        improved = true
                        break
                    end
                end
                improved && break
            end
        end
    end
    cost = sum(ring_cost(data, rs.ring) + sum(b(data, i, j) for (i, B) in rs.stars for j in B; init=0.0) for rs in ringstars)
    return Solution(data.round ? round(Int, cost) : cost, ringstars)
end
