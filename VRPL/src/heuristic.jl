using Random

# Simple heuristic for the VRP with lockers, used to obtain an initial upper bound when none is given:
#   1. each customer is assigned to its cheapest covering locker;
#   2. the customers of each locker are grouped into stops of load at most Q (first fit, decreasing demands);
#   3. the stops are routed by Clarke and Wright savings (two stops of the same locker are at distance 0);
#   4. local search: move a customer to another stop of a locker that covers it (possibly in another route; a stop that
#      becomes empty is removed), move a whole stop to another position (in any route), and 2-opt on each route;
#   5. ruin and recreate for 5 seconds: about 15% of the customers are removed and reinserted, each one in the cheapest
#      existing stop of a covering locker with enough capacity, or in a new stop inserted at the cheapest position.
# A route is a vector of stops (locker, customers). Returns (routes, cost) or (nothing, Inf).

stop_load(data::DataVRPL, cs) = sum(w(data, c) for c in cs; init=0.0)
route_load(data::DataVRPL, r) = sum(stop_load(data, cs) for (s, cs) in r; init=0.0)
function route_travel(data::DataVRPL, r)
    isempty(r) && return 0.0
    return d(data, 0, r[1][1]) + sum(d(data, r[k][1], r[k+1][1]) for k in 1:length(r)-1; init=0.0) + d(data, r[end][1], 0)
end
route_cost(data::DataVRPL, r) = route_travel(data, r) + sum(f(data, c, s) for (s, cs) in r for c in cs; init=0.0)
total_cost(data::DataVRPL, routes) = sum(route_cost(data, r) for r in routes; init=0.0)

function vrpl_initial(data::DataVRPL)
    Q = veh_capacity(data)
    loc = [argmin(s -> (f(data, c, s), s), covering_lockers(data, c)) for c in customers(data)]
    stops = Tuple{Int,Vector{Int}}[]
    for s in lockers(data)
        cs = sort([c for c in customers(data) if loc[c] == s], by=c -> -w(data, c))
        bins = Vector{Int}[]
        for c in cs
            b = findfirst(bn -> stop_load(data, bn) + w(data, c) <= Q, bins)
            isnothing(b) ? push!(bins, [c]) : push!(bins[b], c)
        end
        append!(stops, [(s, bn) for bn in bins])
    end
    # savings between stops
    routes = Dict(i => [stops[i]] for i in eachindex(stops))
    route_of = collect(eachindex(stops))
    sv = [(d(data, 0, stops[i][1]) + d(data, 0, stops[j][1]) - d(data, stops[i][1], stops[j][1]), i, j)
          for i in eachindex(stops) for j in i+1:length(stops)]
    sort!(sv, rev=true)
    for (_, i, j) in sv
        ri, rj = route_of[i], route_of[j]
        ri == rj && continue
        a, b = routes[ri], routes[rj]
        (a[end] == stops[i] || a[1] == stops[i]) && (b[1] == stops[j] || b[end] == stops[j]) || continue
        route_load(data, a) + route_load(data, b) <= Q + 1e-9 || continue
        a[end] != stops[i] && reverse!(a)
        b[1] != stops[j] && reverse!(b)
        routes[ri] = vcat(a, b)
        delete!(routes, rj)
        for k in eachindex(stops)
            route_of[k] == rj && (route_of[k] = ri)
        end
    end
    return collect(values(routes))
end

function vrpl_two_opt!(data::DataVRPL, r)
    improved = true
    while improved
        improved = false
        best = route_travel(data, r)
        for i in 1:length(r)-1, j in i+1:length(r)
            c = vcat(r[1:i-1], reverse(r[i:j]), r[j+1:end])
            l = route_travel(data, c)
            if l < best - 1e-9
                r[:] = c; best = l; improved = true
            end
        end
    end
    return r
end

function vrpl_local_search!(data::DataVRPL, routes; deadline=time() + 5.0)
    Q = veh_capacity(data)
    improved = true
    while improved && time() < deadline
        improved = false
        foreach(r -> vrpl_two_opt!(data, r), routes)
        # move a customer to another stop of a covering locker
        for a in eachindex(routes), p in eachindex(routes[a]), c in routes[a][p][2]
            ra = deepcopy(routes[a])
            filter!(x -> x != c, ra[p][2])
            isempty(ra[p][2]) && deleteat!(ra, p)
            for b in eachindex(routes)
                rb = a == b ? ra : routes[b]
                for (q, (s, cs)) in enumerate(rb)
                    covers(data, s, c) || continue
                    nb = deepcopy(rb)
                    push!(nb[q][2], c)
                    route_load(data, nb) <= Q + 1e-9 || continue
                    old = route_cost(data, routes[a]) + (a == b ? 0.0 : route_cost(data, routes[b]))
                    new = (a == b ? 0.0 : route_cost(data, ra)) + route_cost(data, nb)
                    if new < old - 1e-9
                        if a == b
                            routes[a] = nb
                        else
                            routes[a], routes[b] = ra, nb
                        end
                        improved = true
                        break
                    end
                end
                improved && break
            end
            improved && break
        end
        filter!(!isempty, routes)
        improved && continue
        # move a whole stop to another position
        for a in eachindex(routes), p in eachindex(routes[a])
            st = routes[a][p]
            ra = deleteat!(copy(routes[a]), p)
            for b in eachindex(routes), q in 1:length(a == b ? ra : routes[b])+1
                (a == b && q == p) && continue
                nb = insert!(copy(a == b ? ra : routes[b]), q, st)
                route_load(data, nb) <= Q + 1e-9 || continue
                old = route_cost(data, routes[a]) + (a == b ? 0.0 : route_cost(data, routes[b]))
                new = (a == b ? 0.0 : route_cost(data, ra)) + route_cost(data, nb)
                if new < old - 1e-9
                    if a == b
                        routes[a] = nb
                    else
                        routes[a], routes[b] = ra, nb
                    end
                    improved = true
                    break
                end
            end
            improved && break
        end
        filter!(!isempty, routes)
    end
    return routes
end

# reinserts the customers (in the given order): the cheapest existing stop of a covering locker with enough capacity, or
# a new stop at the cheapest position (in an existing route with enough capacity, or in a new route)
function vrpl_reinsert!(data::DataVRPL, routes, cs)
    Q = veh_capacity(data)
    for c in cs
        best = (Inf, 0, 0, 0, false) # (added cost, route, position, locker, new stop)
        for (a, r) in enumerate(routes)
            load = route_load(data, r)
            load + w(data, c) <= Q + 1e-9 || continue
            base = route_travel(data, r)
            for (q, (s, _)) in enumerate(r)
                covers(data, s, c) && f(data, c, s) < best[1] && (best = (f(data, c, s), a, q, s, false))
            end
            for s in covering_lockers(data, c), q in 1:length(r)+1
                nr = insert!(copy(r), q, (s, Int[]))
                δ = route_travel(data, nr) - base + f(data, c, s)
                δ < best[1] - 1e-9 && (best = (δ, a, q, s, true))
            end
        end
        for s in covering_lockers(data, c) # new route
            δ = d(data, 0, s) + d(data, s, 0) + f(data, c, s)
            δ < best[1] - 1e-9 && (best = (δ, length(routes) + 1, 1, s, true))
        end
        _, a, q, s, new = best
        a > length(routes) && push!(routes, Tuple{Int,Vector{Int}}[])
        if new
            insert!(routes[a], q, (s, [c]))
        else
            push!(routes[a][q][2], c)
        end
    end
    return routes
end

function vrpl_heuristic(data::DataVRPL; seconds=5.0)
    all(w(data, c) <= veh_capacity(data) for c in customers(data)) || return (nothing, Inf)
    best = vrpl_local_search!(data, vrpl_initial(data))
    best_cost = total_cost(data, best)
    rng = MersenneTwister(1)
    deadline = time() + seconds
    K = nb_customers(data)
    while time() < deadline
        routes = deepcopy(best)
        removed = shuffle(rng, collect(customers(data)))[1:max(2, K ÷ 7)]
        for r in routes
            for st in r
                filter!(c -> !(c in removed), st[2])
            end
            filter!(st -> !isempty(st[2]), r)
        end
        filter!(!isempty, routes)
        vrpl_reinsert!(data, routes, shuffle(rng, removed))
        vrpl_local_search!(data, routes; deadline=min(deadline, time() + 1.0))
        c = total_cost(data, routes)
        c < best_cost - 1e-9 && ((best, best_cost) = (routes, c))
    end
    return (best, best_cost)
end
