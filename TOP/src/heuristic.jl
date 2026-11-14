using Random

# Simple heuristic for the team orienteering problem, used to obtain an initial upper bound when none is given: greedy
# insertion of the customers in the F routes (repeatedly, the feasible insertion of largest profit / added time), with
# 2-opt on each route after each insertion to save time for more insertions; then a ruin and recreate search for 5
# seconds. Returns (routes, profit).

top_dist(data::DataTOP, i, j) = distance(data.G.V[i+1], data.G.V[j+1])

function top_route_time(data::DataTOP, r)
    isempty(r) && return 0.0 # an empty route is not used
    nd = data.n + 1 # end depot
    return top_dist(data, 0, r[1]) + sum(top_dist(data, r[k], r[k+1]) for k in 1:length(r)-1; init=0.0) +
           top_dist(data, r[end], nd)
end

function top_two_opt!(data::DataTOP, r)
    improved = true
    while improved
        improved = false
        best = top_route_time(data, r)
        for i in 1:length(r)-1, j in i+1:length(r)
            c = vcat(r[1:i-1], reverse(r[i:j]), r[j+1:end])
            l = top_route_time(data, c)
            if l < best - 1e-9
                r[:] = c; best = l; improved = true
            end
        end
    end
    return r
end

# greedy insertion of the customers of `left` in the routes (repeatedly, the feasible insertion of largest profit /
# added time), with 2-opt on the route after each insertion
function top_greedy!(data::DataTOP, routes, left)
    V = data.G.V
    while true
        best = (-Inf, 0, 0, 0)
        for i in left, (a, r) in enumerate(routes), q in 1:length(r)+1
            c = insert!(copy(r), q, i)
            tc = top_route_time(data, c)
            tc <= data.T + 1e-6 || continue
            score = V[i+1].profit / (tc - top_route_time(data, r) + 1e-6)
            score > best[1] && (best = (score, i, a, q))
        end
        best[2] == 0 && break
        insert!(routes[best[3]], best[4], best[2])
        delete!(left, best[2])
        top_two_opt!(data, routes[best[3]])
    end
    return routes
end

profit(data::DataTOP, routes) = sum(data.G.V[i+1].profit for r in routes for i in r; init=0)

function top_heuristic(data::DataTOP; seconds=5.0)
    V = data.G.V
    cand = [i for i in 1:data.n if V[i+1].profit > 0 && top_dist(data, 0, i) + top_dist(data, i, data.n + 1) <= data.T + 1e-6]
    best = top_greedy!(data, [Int[] for _ in 1:data.F], Set(cand))
    best_profit = profit(data, best)
    # ruin and recreate: remove about 20% of the visited customers at random, then greedy insertion of all the others
    rng = MersenneTwister(1)
    deadline = time() + seconds
    while time() < deadline && !isempty(cand)
        routes = deepcopy(best)
        visited = vcat(routes...)
        isempty(visited) && break
        removed = Set(shuffle(rng, visited)[1:max(1, length(visited) ÷ 5)])
        for r in routes
            filter!(i -> !(i in removed), r)
            top_two_opt!(data, r)
        end
        left = Set(i for i in cand if !(i in visited) || i in removed)
        top_greedy!(data, routes, left)
        p = profit(data, routes)
        if p > best_profit || (p == best_profit && sum(top_route_time(data, r) for r in routes) <
                                                   sum(top_route_time(data, r) for r in best) - 1e-9)
            best, best_profit = routes, p
        end
    end
    filter!(!isempty, best)
    return (best, best_profit)
end
