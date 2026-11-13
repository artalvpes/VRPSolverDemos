using Random

# Simple heuristic for the VRPTW, used to obtain an initial upper bound when none is given: sequential cheapest
# insertion (each route is seeded with the unrouted customer of earliest due time, or the farthest one from the depot
# (two runs), then the feasible insertion of
# smallest added distance is repeated), then a local search (relocation and exchange of customers between routes,
# first improvement) that keeps the time windows and the capacity. Returns (routes, cost), or (nothing, Inf) if the
# solution needs more than K routes. Finally, a ruin and recreate search improves the best solution for 10 seconds.

hdist(data::DataVRPTW, i, j) = distance(data.G′.V′[i+1], data.G′.V′[j+1])

function route_cost(data::DataVRPTW, r)
    isempty(r) && return 0.0
    return hdist(data, 0, r[1]) + sum(hdist(data, r[k], r[k+1]) for k in 1:length(r)-1; init=0.0) + hdist(data, r[end], 0)
end

# capacity and time windows, computed as in checkroutes
function route_ok(data::DataVRPTW, r)
    V, tol = data.G′.V′, 1e-6
    sum(V[j+1].demand for j in r; init=0) <= veh_capacity(data) + tol || return false
    time, prev = 0.0, 0
    for j in r
        time = max(time + (prev == 0 ? 0 : V[prev+1].service_time) + hdist(data, prev, j), V[j+1].start_tw)
        time > V[j+1].end_tw + tol && return false
        prev = j
    end
    isempty(r) && return true
    return time + V[prev+1].service_time + hdist(data, prev, 0) <= V[1].end_tw + tol
end

function insertion_routes(data::DataVRPTW, seed_rule::Int)
    V = data.G′.V′
    left = Set(1:n(data))
    routes = Vector{Int}[]
    while !isempty(left)
        # seed: earliest due time (rule 1) or farthest from the depot (rule 2)
        seed = seed_rule == 1 ? argmin(j -> (V[j+1].end_tw, j), collect(left)) : argmax(j -> (hdist(data, 0, j), -j), collect(left))
        route_ok(data, [seed]) || return nothing
        r = [seed]
        delete!(left, seed)
        while true
            best = (Inf, 0, 0)
            for j in left, q in 1:length(r)+1
                c = insert!(copy(r), q, j)
                δc = route_cost(data, c) - route_cost(data, r)
                (δc < best[1] - 1e-9 && route_ok(data, c)) && (best = (δc, j, q))
            end
            best[2] == 0 && break
            insert!(r, best[3], best[2])
            delete!(left, best[2])
        end
        push!(routes, r)
    end
    return routes
end

function local_search!(data::DataVRPTW, routes; deadline=time() + 20.0)
    improved = true
    while improved && time() < deadline
        improved = false
        for a in eachindex(routes), p in eachindex(routes[a])
            i = routes[a][p]
            ra = deleteat!(copy(routes[a]), p)
            for b in eachindex(routes), q in 1:length(routes[b])+(a == b ? 0 : 1)
                (a == b && q == p) && continue
                rb = insert!(copy(a == b ? ra : routes[b]), q, i)
                old = route_cost(data, routes[a]) + (a == b ? 0.0 : route_cost(data, routes[b]))
                new = (a == b ? 0.0 : route_cost(data, ra)) + route_cost(data, rb)
                if new < old - 1e-9 && route_ok(data, rb) && (a == b || route_ok(data, ra))
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
        for a in eachindex(routes), b in a+1:length(routes), p in eachindex(routes[a]), q in eachindex(routes[b])
            ra, rb = copy(routes[a]), copy(routes[b])
            ra[p], rb[q] = rb[q], ra[p]
            if route_cost(data, ra) + route_cost(data, rb) < route_cost(data, routes[a]) + route_cost(data, routes[b]) - 1e-9 &&
               route_ok(data, ra) && route_ok(data, rb)
                routes[a], routes[b] = ra, rb
                improved = true
                break
            end
        end
    end
    return routes
end

# inserts the customers of `left` (in the given order) at their cheapest feasible positions, opening new routes if needed
function reinsert!(data::DataVRPTW, routes, left)
    for j in left
        best = (Inf, 0, 0)
        for (a, r) in enumerate(routes), q in 1:length(r)+1
            c = insert!(copy(r), q, j)
            δc = route_cost(data, c) - route_cost(data, r)
            (δc < best[1] - 1e-9 && route_ok(data, c)) && (best = (δc, a, q))
        end
        if best[2] == 0
            route_ok(data, [j]) || return false
            push!(routes, [j])
        else
            insert!(routes[best[2]], best[3], j)
        end
    end
    return true
end

function vrptw_heuristic(data::DataVRPTW; seconds=10.0)
    best, best_cost = nothing, Inf
    for rule in (1, 2)
        routes = insertion_routes(data, rule)
        isnothing(routes) && continue
        local_search!(data, routes; deadline=time() + 10.0)
        c = sum(route_cost(data, r) for r in routes)
        (length(routes) <= data.K && c < best_cost) && ((best, best_cost) = (routes, c))
    end
    isnothing(best) && return (nothing, Inf)
    # ruin and recreate: remove about 15% of the customers at random, reinsert them by cheapest insertion, local search
    rng = MersenneTwister(1)
    deadline = time() + seconds
    while time() < deadline
        routes = deepcopy(best)
        removed = shuffle(rng, 1:n(data))[1:max(2, n(data) ÷ 7)]
        for r in routes
            filter!(j -> !(j in removed), r)
        end
        filter!(!isempty, routes)
        reinsert!(data, routes, shuffle(rng, removed)) || continue
        local_search!(data, routes; deadline=min(deadline, time() + 2.0))
        c = sum(route_cost(data, r) for r in routes)
        (length(routes) <= data.K && c < best_cost - 1e-9) && ((best, best_cost) = (routes, c))
    end
    return (best, best_cost)
end
