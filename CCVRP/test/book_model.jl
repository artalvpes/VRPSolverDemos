# Alternative CCVRP model from Section 6.4.8 of the book "Optimizing with Column Generation"
# (model 6.36), which uses only standard resources.
#
# Routes are generated backwards (from the last customer to the depot), so that the number of
# customers already visited is known when an edge is traversed. An arc (i,j,t) of the graph
# represents the traversal of edge {i,j} from j to i by a vehicle that still has t customers to
# serve (i among them), and is mapped to variable x[e,t] with cost t * c_e. Resource 1 is the
# vehicle capacity and resource 2 counts the customers already served, with interval [t,t] on
# the arc (i,j,t).
#
# Note: the book minimizes the sum of the arrival times, whereas the demo (custom resource) minimizes
# the sum of the arrival times weighted by the demands. Both coincide when all demands are 1.

# upper bound on the number of customers of a route
function max_route_size(data, L::Int)
    n = C.nb_customers(data)
    W = C.veh_capacity(data)
    size, load = 0, 0.0
    for dem in sort([C.d(data, i) for i in 1:n])
        load + dem > W && break
        load += dem
        size += 1
    end
    return min(size, n - L + 1)
end

function build_book_model(data, app::Dict{String,Any})
    E = C.edges(data)
    n = C.nb_customers(data)
    V = [i for i in 0:n]
    V⁺ = [i for i in 1:n]
    W = C.veh_capacity(data)
    L = max(app["minr"], C.lowerBoundNbVehicles(data))
    U = min(app["maxr"], n)
    T = max_route_size(data, L)

    # values of t after the preprocessing: arcs (0,j,0) and (j,0,t) with t ≥ 1 for edges
    # incident to the depot, and arcs (i,j,t) with 1 ≤ t ≤ T-1 for edges between customers
    trange(e) = (e[1] == 0) ? (0:T) : (1:T-1)

    model = VrpModel()
    form = model.formulation
    @variable(form, x[e in E, t in trange(e)] >= 0, Int)
    @expression(form, xagg[e in E], sum(x[e, t] for t in trange(e)))
    @objective(form, Min, sum(t * C.c(data, e) * x[e, t] for e in E for t in trange(e)))
    @constraint(form, deg[i in V⁺], sum(xagg[e] for e in C.δ(data, i)) == 2.0)

    G = VrpGraph(model, V, 0, 0, (L, U))
    cap_res_id = add_resource!(G, main=true)
    cnt_res_id = add_resource!(G)
    for i in V
        set_resource_bounds!(G, i, cap_res_id, 0.0, W)
        set_resource_bounds!(G, i, cnt_res_id, 0.0, T)
    end

    function add_book_arc!(i, j, t, e)
        arc_id = add_arc!(G, i, j, x[e, t])
        set_arc_consumption!(G, arc_id, cap_res_id, C.d(data, j))
        set_arc_consumption!(G, arc_id, cnt_res_id, (i == 0) ? 0 : 1)
        set_arc_resource_bounds!(G, arc_id, cnt_res_id, t, t)
    end
    for e in E
        (i, j) = e
        if i == 0
            add_book_arc!(0, j, 0, e) # last leg of the route (free)
            for t in 1:T
                add_book_arc!(j, 0, t, e) # first leg of a route with t customers
            end
        else
            for t in 1:T-1
                add_book_arc!(i, j, t, e)
                add_book_arc!(j, i, t, e)
            end
        end
    end
    add_graph!(model, G)

    set_vertex_packing_sets!(model, [[(G, i)] for i in V⁺])
    define_elementarity_sets_distance_matrix!(model, G, [[C.distance(data, (i, j)) for j in V⁺] for i in V⁺])
    add_capacity_cut_separator!(model, [([(G, i)], C.d(data, i)) for i in V⁺], W)

    # branching on the aggregated edge variables
    set_branching_priority!(model, xagg, "xagg", 1)

    function edge_ub_callback()
        for e in E
            e[1] == 0 && continue
            vars = [x[e, t] for t in trange(e)]
            if sum(value(v) for v in vars) > 1.001
                println("Adding edge ub cut for e = ", e)
                add_dynamic_constr!(model.optimizer, vars, [1.0 for _ in vars], <=, 1.0, "edge_ub")
            end
        end
    end
    add_cut_callback!(model, edge_ub_callback, "edge_ub")

    return (model, x, trange)
end

# build the solution from the aggregated values of x
function get_book_solution(data, x, trange, objval, app::Dict{String,Any})
    n = C.nb_customers(data)
    adj = [Int[] for _ in 0:n]
    for e in C.edges(data)
        val = sum(value(x[e, t]) for t in trange(e))
        for _ in 1:round(Int, val)
            push!(adj[e[1]+1], e[2])
            push!(adj[e[2]+1], e[1])
        end
    end
    visited = falses(n)
    routes = Vector{Int}[]
    for first in adj[1]
        visited[first] && continue
        r, prev, cur = Int[], 0, first
        while cur != 0
            (visited[cur] || length(adj[cur+1]) != 2) &&
                error("Problem trying to recover the route from the x values at customer $cur.")
            visited[cur] = true
            push!(r, cur)
            next = (adj[cur+1][1] == prev) ? adj[cur+1][2] : adj[cur+1][1]
            prev, cur = cur, next
        end
        push!(routes, C.fix_route_sense(data, r))
    end
    !all(visited) && error("Problem trying to recover the routes: some customer was not visited.")
    if !app["noround"]
        objval = trunc(Int, round(objval))
    end
    return C.Solution(objval, routes)
end
