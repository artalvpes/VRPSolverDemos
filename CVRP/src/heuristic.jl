# Heuristic for the CVRP (with an optional route duration limit D and service times), used to obtain an initial upper
# bound when none is given:
#   1. parametric Clarke and Wright savings (several values of λ); the best solution with a number of routes in
#      [minr, maxr] is kept (the best one if there is none);
#   2. adjustment of the number of routes to [minr, maxr]: with too many routes, a first local search (that may merge
#      routes), then the customers of the shortest routes are moved elsewhere, and, for a tight fleet where this fails,
#      the routes are built again by a bin packing of the demands into maxr routes;
#   3. local search with granular neighbourhoods (each customer is only tried with its nearest customers): relocation
#      before or after a neighbour, exchange with a neighbour, 2-opt inside a route and 2-opt* between two routes, all
#      evaluated in constant time, first improvement;
#   4. ruin and recreate around the local search until the time limit: a customer and some of its nearest customers
#      are removed and reinserted at their cheapest feasible positions, the local search is applied, and the result is
#      accepted if it is not worse than the current solution by more than a threshold that decreases to zero.
# The number of routes stays in [minr, maxr] during steps 3 and 4. Returns (routes, cost), or (nothing, Inf) if no
# solution with the number of routes in [minr, maxr] is found. Parameters (app): heur_time, the time limit (default
# min(20, 2 + 0.1 n) seconds), heur_neighbors, the number of nearest customers (default 20), and heur_seed (default 1).

using Random

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

# ---------------------------------------------------------------------------------------------------------------------
# Local search state: the routes, with for each route its load, its length and the prefix load and length at each
# position, and for each customer its route and its position.

mutable struct LSState
    n::Int
    Q::Float64
    D::Float64                # route duration limit (0: none)
    S::Float64                # service time of each customer
    minr::Int
    maxr::Int
    c::Matrix{Float64}        # c[i+1, j+1] = distance between i and j (0 is the depot)
    dem::Vector{Float64}      # dem[i] = demand of customer i
    near::Vector{Vector{Int}} # near[i] = nearest customers of i
    routes::Vector{Vector{Int}}
    load::Vector{Float64}
    len::Vector{Float64}
    pload::Vector{Vector{Float64}} # pload[r][k] = load of the first k customers of route r
    plen::Vector{Vector{Float64}}  # plen[r][k] = length from the depot to the k-th customer of route r
    route_of::Vector{Int}
    pos::Vector{Int}
end

dist(s::LSState, i, j) = s.c[i+1, j+1]
cost(s::LSState) = sum(s.len)
ok(s::LSState, load, len, nc) = load <= s.Q + 1e-6 && (s.D <= 0 || len + s.S * nc <= s.D + 1e-6)

function LSState(data::DataCVRP, routes, minr, maxr; K=20)
    n = nb_customers(data)
    c = [distance(data, (i, j)) for i in 0:n, j in 0:n]
    near = [sort(filter(!=(i), 1:n), by=j -> c[i+1, j+1])[1:min(K, n - 1)] for i in 1:n]
    s = LSState(n, veh_capacity(data), max_dist(data), service_time(data), minr, maxr, c,
                [d(data, i) for i in 1:n], near, [copy(r) for r in routes], Float64[], Float64[],
                Vector{Float64}[], Vector{Float64}[], zeros(Int, n), zeros(Int, n))
    refresh_all!(s)
    return s
end

function refresh!(s::LSState, r::Int)
    rt = s.routes[r]
    m = length(rt)
    pl, pd = zeros(m), zeros(m)
    load, len, prev = 0.0, 0.0, 0
    for k in 1:m
        i = rt[k]
        load += s.dem[i]
        len += dist(s, prev, i)
        pl[k], pd[k] = load, len
        s.route_of[i], s.pos[i] = r, k
        prev = i
    end
    s.pload[r], s.plen[r] = pl, pd
    s.load[r] = load
    s.len[r] = m == 0 ? 0.0 : len + dist(s, prev, 0)
end

function refresh_all!(s::LSState)
    nr = length(s.routes)
    s.load, s.len = zeros(nr), zeros(nr)
    s.pload, s.plen = [Float64[] for _ in 1:nr], [Float64[] for _ in 1:nr]
    for r in 1:nr
        refresh!(s, r)
    end
end

# removes the empty routes while there are more than minr routes
function drop_empty!(s::LSState)
    while length(s.routes) > s.minr && any(isempty, s.routes)
        deleteat!(s.routes, findfirst(isempty, s.routes))
    end
    refresh_all!(s)
end

prv(s::LSState, i) = s.pos[i] == 1 ? 0 : s.routes[s.route_of[i]][s.pos[i]-1]
nxt(s::LSState, i) = (r = s.routes[s.route_of[i]]; s.pos[i] == length(r) ? 0 : r[s.pos[i]+1])

# Tries the moves of customer u with its neighbours; applies the first improving one and returns true.
function improve_customer!(s::LSState, u::Int)
    eps = 1e-9
    ru = s.route_of[u]
    pu, nu = prv(s, u), nxt(s, u)
    for v in s.near[u]
        rv = s.route_of[v]
        pv, nv = prv(s, v), nxt(s, v)
        if ru != rv
            # relocate u after v, or before v
            if length(s.routes[ru]) > 1 || length(s.routes) > s.minr
                rem = dist(s, pu, nu) - dist(s, pu, u) - dist(s, u, nu)
                # (the route of u is checked too: with rounded distances, removing a customer can lengthen a route)
                if ok(s, s.load[rv] + s.dem[u], 0.0, 0) &&
                   ok(s, s.load[ru] - s.dem[u], s.len[ru] + rem, length(s.routes[ru]) - 1)
                    for (a, b, after) in ((v, nv, true), (pv, v, false))
                        ins = dist(s, a, u) + dist(s, u, b) - dist(s, a, b)
                        if rem + ins < -eps && ok(s, s.load[rv] + s.dem[u], s.len[rv] + ins, length(s.routes[rv]) + 1)
                            deleteat!(s.routes[ru], s.pos[u])
                            insert!(s.routes[rv], s.pos[v] + (after ? 1 : 0), u)
                            refresh!(s, ru); refresh!(s, rv)
                            isempty(s.routes[ru]) && drop_empty!(s)
                            return true
                        end
                    end
                end
            end
            # exchange u and v
            du = dist(s, pv, u) + dist(s, u, nv) - dist(s, pv, v) - dist(s, v, nv)
            dv = dist(s, pu, v) + dist(s, v, nu) - dist(s, pu, u) - dist(s, u, nu)
            if du + dv < -eps && ok(s, s.load[rv] - s.dem[v] + s.dem[u], s.len[rv] + du, length(s.routes[rv])) &&
               ok(s, s.load[ru] - s.dem[u] + s.dem[v], s.len[ru] + dv, length(s.routes[ru]))
                s.routes[ru][s.pos[u]], s.routes[rv][s.pos[v]] = v, u
                refresh!(s, ru); refresh!(s, rv)
                return true
            end
            # 2-opt*: the routes are cut after u and after v, and the parts are reconnected
            if two_opt_star!(s, u, v) || two_opt_star!(s, v, u)
                return true
            end
        else
            # 2-opt inside the route: reverse the segment between u and v
            a, b = s.pos[u] < s.pos[v] ? (u, v) : (v, u)
            pa, nb = prv(s, a), nxt(s, b)
            delta = dist(s, pa, b) + dist(s, a, nb) - dist(s, pa, a) - dist(s, b, nb)
            if delta < -eps && ok(s, s.load[ru], s.len[ru] + delta, length(s.routes[ru]))
                reverse!(s.routes[ru], s.pos[a], s.pos[b])
                refresh!(s, ru)
                return true
            end
            # relocate u after v or before v in the same route
            for (x, y, after) in ((v, nv, true), (pv, v, false))
                (x == u || y == u) && continue
                delta = dist(s, pu, nu) - dist(s, pu, u) - dist(s, u, nu) + dist(s, x, u) + dist(s, u, y) - dist(s, x, y)
                if delta < -eps && ok(s, s.load[ru], s.len[ru] + delta, length(s.routes[ru]))
                    rt = s.routes[ru]
                    deleteat!(rt, s.pos[u])
                    insert!(rt, findfirst(==(v), rt) + (after ? 1 : 0), u)
                    refresh!(s, ru)
                    return true
                end
            end
        end
    end
    return false
end

# 2-opt* between the routes of u and v (different routes); two reconnections:
#   (u, next of v): the head of route u up to u, then the tail of route v after v, and conversely;
#   (u, v): the head of route u up to u, then the head of route v up to v reversed, and the reversed tail of route u,
#   then the tail of route v.
function two_opt_star!(s::LSState, u::Int, v::Int)
    eps = 1e-9
    ru, rv = s.route_of[u], s.route_of[v]
    Ru, Rv = s.routes[ru], s.routes[rv]
    ku, kv = s.pos[u], s.pos[v]
    nu, nv = nxt(s, u), nxt(s, v)
    lu, lv = s.pload[ru][ku], s.pload[rv][kv]   # loads of the heads
    du, dv = s.plen[ru][ku], s.plen[rv][kv]     # lengths of the heads (from the depot)
    tlu, tlv = s.len[ru] - du - dist(s, u, nu), s.len[rv] - dv - dist(s, v, nv) # lengths of the tails (to the depot)
    mu, mv = length(Ru), length(Rv)
    # head u + tail v, head v + tail u
    if (ku < mu || kv < mv)
        delta = dist(s, u, nv) + dist(s, v, nu) - dist(s, u, nu) - dist(s, v, nv)
        if delta < -eps &&
           ok(s, lu + s.load[rv] - lv, du + dist(s, u, nv) + tlv, ku + mv - kv) &&
           ok(s, lv + s.load[ru] - lu, dv + dist(s, v, nu) + tlu, kv + mu - ku)
            newu, newv = vcat(Ru[1:ku], Rv[kv+1:end]), vcat(Rv[1:kv], Ru[ku+1:end])
            if (isempty(newu) || isempty(newv)) && length(s.routes) <= s.minr
                return false
            end
            s.routes[ru], s.routes[rv] = newu, newv
            refresh!(s, ru); refresh!(s, rv)
            (isempty(newu) || isempty(newv)) && drop_empty!(s)
            return true
        end
    end
    # head u + reversed head v, reversed tail u + tail v
    delta = dist(s, u, v) + dist(s, nu, nv) - dist(s, u, nu) - dist(s, v, nv)
    if delta < -eps &&
       ok(s, lu + lv, du + dist(s, u, v) + dv, ku + kv) &&
       ok(s, s.load[ru] - lu + s.load[rv] - lv, tlu + dist(s, nu, nv) + tlv, mu - ku + mv - kv)
        newu, newv = vcat(Ru[1:ku], reverse(Rv[1:kv])), vcat(reverse(Ru[ku+1:end]), Rv[kv+1:end])
        if isempty(newv) && length(s.routes) <= s.minr
            return false
        end
        s.routes[ru], s.routes[rv] = newu, newv
        refresh!(s, ru); refresh!(s, rv)
        isempty(newv) && drop_empty!(s)
        return true
    end
    return false
end

function local_search!(s::LSState, rng; deadline=Inf)
    order = collect(1:s.n)
    improved = true
    while improved && time() < deadline
        improved = false
        shuffle!(rng, order)
        for u in order
            while improve_customer!(s, u)
                improved = true
            end
        end
    end
    return s
end

# Ruin and recreate: removes customer seed and its nearest customers (up to k), then inserts them again at their
# cheapest feasible positions (a new route is opened when there is none and the number of routes allows it).
# Returns false if a customer could not be inserted.
function ruin_recreate!(s::LSState, rng, k::Int)
    seed = rand(rng, 1:s.n)
    removed = vcat([seed], s.near[seed][1:min(k - 1, length(s.near[seed]))])
    for i in removed
        r = s.route_of[i]
        deleteat!(s.routes[r], findfirst(==(i), s.routes[r]))
    end
    refresh_all!(s)
    rand(rng) < 0.5 ? shuffle!(rng, removed) : sort!(removed, by=i -> -s.dem[i])
    for i in removed
        best, br, bk = Inf, 0, 0
        for r in eachindex(s.routes)
            s.load[r] + s.dem[i] <= s.Q + 1e-6 || continue
            rt = s.routes[r]
            m = length(rt)
            for k in 1:m+1
                a = k == 1 ? 0 : rt[k-1]
                b = k == m + 1 ? 0 : rt[k]
                δc = dist(s, a, i) + dist(s, i, b) - dist(s, a, b)
                if δc < best && ok(s, s.load[r] + s.dem[i], s.len[r] + δc, m + 1)
                    best, br, bk = δc, r, k
                end
            end
        end
        if br == 0
            length(s.routes) < s.maxr || return false
            push!(s.routes, [i])
            push!(s.load, 0.0); push!(s.len, 0.0); push!(s.pload, Float64[]); push!(s.plen, Float64[])
            refresh!(s, length(s.routes))
        else
            insert!(s.routes[br], bk, i)
            refresh!(s, br)
        end
    end
    drop_empty!(s)
    # an empty route that could not be dropped (already minr routes) would leave fewer than minr routes: rejected
    return !any(isempty, s.routes)
end

# Empties the shortest routes until there are maxr routes, moving their customers to their cheapest feasible positions.
# Returns nothing if a customer cannot be moved.
function empty_shortest_routes(data::DataCVRP, routes, maxr)
    routes = [copy(r) for r in routes]
    while length(routes) > maxr
        k = argmin(length.(routes))
        rest = [routes[i] for i in eachindex(routes) if i != k]
        for i in routes[k]
            bst = (Inf, 0, 0)
            for (a, r) in enumerate(rest), q in 1:length(r)+1
                c = insert!(copy(r), q, i)
                δc = route_length(data, c) - route_length(data, r)
                (δc < bst[1] && route_ok(data, c)) && (bst = (δc, a, q))
            end
            bst[2] == 0 && return nothing
            insert!(rest[bst[2]], bst[3], i)
        end
        routes = rest
    end
    return routes
end

# Routes for a tight fleet: the customers, by decreasing demand with a random perturbation (none in the first try),
# are put in the route with the most remaining capacity where they fit (maxr routes); each route is then ordered by
# the nearest neighbour rule. Tries until the deadline; returns nothing if no assignment satisfies the capacity (and
# the duration limit).
function binpack_routes(data::DataCVRP, maxr, rng; deadline=time() + 5.0)
    n, Q = nb_customers(data), veh_capacity(data)
    try_ = 0
    while try_ == 0 || time() < deadline
        noise = try_ == 0 ? 0.0 : 0.3 * rand(rng)
        order = sort(1:n, by=i -> -d(data, i) * (1 + noise * rand(rng)))
        bins = [Int[] for _ in 1:maxr]
        load = zeros(maxr)
        okall = true
        for i in order
            cand = [b for b in 1:maxr if load[b] + d(data, i) <= Q + 1e-6]
            if isempty(cand)
                okall = false
                break
            end
            b = (try_ == 0 || rand(rng) < 0.7) ? cand[argmax(Q .- load[cand])] : rand(rng, cand)
            push!(bins[b], i)
            load[b] += d(data, i)
        end
        try_ += 1
        okall || continue
        routes = Vector{Int}[]
        for bin in bins
            isempty(bin) && continue
            r, left, cur = Int[], Set(bin), 0
            while !isempty(left)
                nx = argmin(j -> distance(data, (cur, j)), collect(left))
                push!(r, nx); delete!(left, nx); cur = nx
            end
            push!(routes, r)
        end
        all(route_ok(data, r) for r in routes) && return routes
    end
    return nothing
end

function cvrp_heuristic(data::DataCVRP, app::Dict{String,Any})
    n = nb_customers(data)
    n == 0 && return (nothing, Inf)
    all(route_ok(data, [i]) for i in 1:n) || return (nothing, Inf)
    t0 = time()
    limit = something(get(app, "heur_time", nothing), min(20.0, 2.0 + 0.1 * n))
    # 1. parametric savings s_ij = d_0i + d_0j - λ d_ij for a few values of λ
    # the best one with a number of routes in [minr, maxr], or the best one if there is none
    routes, best = nothing, (true, Inf)
    for λ in (1.0, 0.6, 1.4, 0.8, 1.2, 1.8)
        r = savings_routes(data, λ)
        key = (!(app["minr"] <= length(r) <= app["maxr"]), total_cost(data, r))
        (key < best) && ((routes, best) = (r, key))
    end
    rng = MersenneTwister(get(app, "heur_seed", 1))
    K = get(app, "heur_neighbors", 20)
    minr, maxr = max(1, app["minr"]), min(app["maxr"], n)
    # 2. too many routes: a local search without bounds on the number of routes (it may merge routes), then the
    # customers of the shortest routes are moved to their cheapest feasible positions, and, if that fails, the routes
    # are built again by a bin packing of the demands into maxr routes
    if length(routes) > maxr
        s0 = LSState(data, routes, 1, n; K=K)
        local_search!(s0, rng; deadline=t0 + limit / 4)
        routes = [r for r in s0.routes if !isempty(r)]
    end
    if length(routes) > maxr
        routes = empty_shortest_routes(data, routes, maxr)
        isnothing(routes) && (routes = binpack_routes(data, maxr, rng; deadline=t0 + limit / 2))
        isnothing(routes) && return (nothing, Inf)
    end
    # too few routes: split the longest routes
    while length(routes) < minr
        k = argmax(length.(routes))
        length(routes[k]) < 2 && return (nothing, Inf)
        push!(routes, [pop!(routes[k])])
    end
    # 3. local search
    s = LSState(data, routes, minr, maxr; K=K)
    local_search!(s, rng; deadline=t0 + limit)
    best_routes, best_cost = deepcopy(s.routes), cost(s)
    # 4. ruin and recreate with a decreasing acceptance threshold
    cur_routes, cur_cost = deepcopy(s.routes), best_cost
    T0 = 0.01 * best_cost / max(1, length(s.routes))
    tstart = time()
    while time() < t0 + limit
        k = rand(rng, max(2, min(10, n ÷ 4)):max(2, min(30, n ÷ 3)))
        if ruin_recreate!(s, rng, k)
            local_search!(s, rng; deadline=t0 + limit)
            c = cost(s)
            frac = (time() - tstart) / max(1e-9, t0 + limit - tstart)
            if c < best_cost - 1e-9
                best_routes, best_cost = deepcopy(s.routes), c
            end
            if c < cur_cost + T0 * max(0.0, 1.0 - frac)
                cur_routes, cur_cost = deepcopy(s.routes), c
                continue
            end
        end
        s.routes = deepcopy(cur_routes)
        refresh_all!(s)
    end
    routes = [r for r in best_routes if !isempty(r)]
    return (routes, total_cost(data, routes))
end
