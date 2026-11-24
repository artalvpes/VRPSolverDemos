using Random

# Simple heuristic for the PDPTW, used to obtain an initial upper bound when none is given: cheapest insertion of the
# requests (pickup and delivery inserted together, the pickup first, in the same route), in increasing order of the
# start of the pickup time window, opening new routes when needed; then a ruin and recreate search (about 15% of the
# requests removed at random and reinserted by cheapest insertion) for 10 seconds. The objective is the total distance,
# plus the fixed cost of each route for the Ropke instances. Returns (routes, cost), or (nothing, Inf) if no solution
# with at most min(K, maxr) routes is found.

pd_dist(data::DataPDPTW, i, j, app) = distance(data.G′.V′[i+1], data.G′.V′[j+1], app["round"])

function pd_route_dist(data::DataPDPTW, r, app)
    isempty(r) && return 0.0
    return pd_dist(data, 0, r[1], app) + sum(pd_dist(data, r[k], r[k+1], app) for k in 1:length(r)-1; init=0.0) +
           pd_dist(data, r[end], 0, app)
end

# load and time windows, computed as in checkroutes (the pairing of pickups and deliveries is kept by construction)
function pd_route_ok(data::DataPDPTW, r, app)
    V, Q, tol = data.G′.V′, veh_capacity(data), 1e-6
    load, time, prev = 0.0, 0.0, 0
    for j in r
        load += V[j+1].demand
        (load < -tol || load > Q + tol) && return false
        time = max(time + (prev == 0 ? 0 : V[prev+1].service_time) + pd_dist(data, prev, j, app), V[j+1].start_tw)
        time > V[j+1].end_tw + tol && return false
        prev = j
    end
    isempty(r) && return true
    return time + V[prev+1].service_time + pd_dist(data, prev, 0, app) <= V[1].end_tw + tol
end

pd_fixed(app) = app["lilim"] ? 0.0 : Float64(app["fixed"])
pd_cost(data::DataPDPTW, routes, app) = sum(pd_route_dist(data, r, app) for r in routes; init=0.0) + pd_fixed(app) * length(routes)

# inserts the requests (in the given order) at their cheapest feasible positions; returns false if one cannot be inserted
function pd_insert!(data::DataPDPTW, routes, reqs, maxroutes, app)
    for q in reqs
        p, dl = data.requests[q].pickup.id, data.requests[q].delivery.id
        best = (Inf, 0, Int[])
        for (a, r) in enumerate(routes), i in 1:length(r)+1, j in i:length(r)+1
            c = copy(r)
            insert!(c, i, p)
            insert!(c, j + 1, dl)
            δc = pd_route_dist(data, c, app) - pd_route_dist(data, r, app)
            (δc < best[1] - 1e-9 && pd_route_ok(data, c, app)) && (best = (δc, a, c))
        end
        if length(routes) < maxroutes
            c = [p, dl]
            δc = pd_route_dist(data, c, app) + pd_fixed(app)
            (δc < best[1] - 1e-9 && pd_route_ok(data, c, app)) && (best = (δc, length(routes) + 1, c))
        end
        best[2] == 0 && return false
        best[2] > length(routes) ? push!(routes, best[3]) : (routes[best[2]] = best[3])
    end
    return true
end

function pdptw_heuristic(data::DataPDPTW, app::Dict{String,Any}; seconds=10.0)
    maxroutes = min(data.K, app["maxr"], n(data))
    reqs = sort(1:n(data), by=q -> (data.requests[q].pickup.start_tw, q))
    best = Vector{Int}[]
    pd_insert!(data, best, reqs, maxroutes, app) || return (nothing, Inf)
    best_cost = pd_cost(data, best, app)
    rng = MersenneTwister(1)
    deadline = time() + seconds
    while time() < deadline
        routes = deepcopy(best)
        removed = shuffle(rng, 1:n(data))[1:max(2, n(data) ÷ 7)]
        rem_vertices = Set(vcat([[data.requests[q].pickup.id, data.requests[q].delivery.id] for q in removed]...))
        for r in routes
            filter!(j -> !(j in rem_vertices), r)
        end
        filter!(!isempty, routes)
        pd_insert!(data, routes, shuffle(rng, removed), maxroutes, app) || continue
        c = pd_cost(data, routes, app)
        c < best_cost - 1e-9 && ((best, best_cost) = (routes, c))
    end
    length(best) < app["minr"] && return (nothing, Inf)
    return (best, best_cost)
end
