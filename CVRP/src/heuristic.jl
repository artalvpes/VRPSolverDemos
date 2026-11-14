# Simple heuristic for the CVRP (with an optional route duration limit D and service times), used to obtain an initial
# upper bound when none is given: parametric Clarke and Wright savings (several values of λ), each followed by a local
# search (2-opt inside the routes, relocation and exchange of customers between routes, first improvement), then an
# adjustment of the number of routes to [minr, maxr] when possible. Returns (routes, cost), or (nothing, Inf) if no
# solution with the number of routes in [minr, maxr] is found. The whole heuristic takes at most about 20 seconds.

route_load(data::DataCVRP, r) = sum(d(data, i) for i in r; init=0.0)
function route_length(data::DataCVRP, r)
    isempty(r) && return 0.0
    return distance(data, (0, r[1])) + sum(distance(data, (r[k], r[k+1])) for k in 1:length(r)-1; init=0.0) +
           distance(data, (r[end], 0))
end
function route_ok(data::DataCVRP, r)
    route_load(data, r) <= veh_capacity(data) + 1e-6 || return false
    D = max_dist(data)
    return D <= 0 || route_length(data, r) + service_time(data) * length(r) <= D + 1e-6
end
total_cost(data::DataCVRP, routes) = sum(route_length(data, r) for r in routes; init=0.0)

function savings_routes(data::DataCVRP, λ::Float64)
    n = nb_customers(data)
    routes = Dict(i => [i] for i in 1:n) # route id = id of its first customer at creation
    route_of = collect(1:n)
    s = [(distance(data, (0, i)) + distance(data, (0, j)) - λ * distance(data, (i, j)), i, j) for i in 1:n for j in i+1:n]
    sort!(s, rev=true)
    for (sv, i, j) in s
        ri, rj = route_of[i], route_of[j]
        ri == rj && continue
        a, b = routes[ri], routes[rj]
        # i and j must be at an end of their routes; orient them so that a ends with i and b starts with j
        (a[end] == i || a[1] == i) && (b[1] == j || b[end] == j) || continue
        a[end] != i && reverse!(a)
        b[1] != j && reverse!(b)
        merged = vcat(a, b)
        route_ok(data, merged) || continue
        routes[ri] = merged
        delete!(routes, rj)
        for k in b
            route_of[k] = ri
        end
    end
    return collect(values(routes))
end

function two_opt!(data::DataCVRP, r)
    improved = true
    while improved
        improved = false
        best = route_length(data, r)
        for i in 1:length(r)-1, j in i+1:length(r)
            c = vcat(r[1:i-1], reverse(r[i:j]), r[j+1:end])
            l = route_length(data, c)
            if l < best - 1e-9 && route_ok(data, c)
                r[:] = c; best = l; improved = true
            end
        end
    end
    return r
end

function local_search!(data::DataCVRP, routes; deadline=time() + 10.0)
    improved = true
    while improved && time() < deadline
        improved = false
        foreach(r -> two_opt!(data, r), routes)
        # relocate a customer to another position (in any route)
        for a in eachindex(routes), p in eachindex(routes[a])
            i = routes[a][p]
            ra = deleteat!(copy(routes[a]), p)
            for b in eachindex(routes), q in 1:length(routes[b])+(a == b ? 0 : 1)
                (a == b && q == p) && continue
                rb = insert!(copy(a == b ? ra : routes[b]), q, i)
                old = route_length(data, routes[a]) + (a == b ? 0.0 : route_length(data, routes[b]))
                new = (a == b ? 0.0 : route_length(data, ra)) + route_length(data, rb)
                if new < old - 1e-9 && route_ok(data, rb)
                    if a == b
                        routes[a] = rb
                    else
                        routes[a], routes[b] = ra, rb
                    end
                    improved = true
                    break
                end
            end
            improved && break
        end
        filter!(!isempty, routes)
        improved && continue
        # exchange two customers of different routes
        for a in eachindex(routes), b in a+1:length(routes), p in eachindex(routes[a]), q in eachindex(routes[b])
            ra, rb = copy(routes[a]), copy(routes[b])
            ra[p], rb[q] = rb[q], ra[p]
            if route_length(data, ra) + route_length(data, rb) <
               route_length(data, routes[a]) + route_length(data, routes[b]) - 1e-9 && route_ok(data, ra) && route_ok(data, rb)
                routes[a], routes[b] = ra, rb
                improved = true
                break
            end
        end
    end
    return routes
end

function cvrp_heuristic(data::DataCVRP, app::Dict{String,Any})
    nb_customers(data) == 0 && return (nothing, Inf)
    all(route_ok(data, [i]) for i in 1:nb_customers(data)) || return (nothing, Inf)
    # parametric savings s_ij = d_0i + d_0j - λ d_ij for a few values of λ; the best solution after the local search
    routes, best = nothing, Inf
    deadline = time() + 20.0
    for λ in (1.0, 0.6, 1.4, 0.8, 1.2, 1.8)
        r = local_search!(data, savings_routes(data, λ); deadline=min(deadline, time() + 10.0))
        c = total_cost(data, r)
        if c < best - 1e-9
            routes, best = r, c
        end
        time() > deadline && break
    end
    # too few routes: split the longest routes
    while length(routes) < app["minr"]
        k = argmax(length.(routes))
        length(routes[k]) < 2 && return (nothing, Inf)
        push!(routes, [pop!(routes[k])])
    end
    # too many routes: try to empty the shortest routes, inserting their customers in the cheapest feasible positions
    while length(routes) > app["maxr"]
        k = argmin(length.(routes))
        rest = [routes[i] for i in eachindex(routes) if i != k]
        for i in routes[k]
            best = (Inf, 0, 0)
            for (a, r) in enumerate(rest), q in 1:length(r)+1
                c = insert!(copy(r), q, i)
                δc = route_length(data, c) - route_length(data, r)
                (δc < best[1] && route_ok(data, c)) && (best = (δc, a, q))
            end
            best[2] == 0 && return (nothing, Inf)
            insert!(rest[best[2]], best[3], i)
        end
        routes = local_search!(data, rest; deadline=time() + 5.0)
    end
    return (routes, total_cost(data, routes))
end
