# Model: one vertex for each pair (locker s, customer c) such that s covers c, as in the graph of Oliveira, Lima,
# Pessoa and Roboredo (2025) for the VRPDA.
function build_model(data::DataVRPL, app::Dict{String,Any})

    C = customers(data)
    Q = veh_capacity(data)

    # vertices: 0 is the depot, and pair[v] = (c, s) for v = 1..N, sorted by customer (so that, for two vertices i < j
    # of the same locker, the customer of i is smaller than the customer of j)
    pair = [(c, s) for c in C for s in covering_lockers(data, c)]
    N = length(pair)
    V = [v for v in 0:N]
    V⁺ = [v for v in 1:N]
    vertices_of = [Int[] for c in C] # vertices_of[c] are the vertices of the customer c (its packing set)
    for v in V⁺
        push!(vertices_of[pair[v][1]], v)
    end
    locker(v) = (v == 0) ? 0 : pair[v][2]
    customer(v) = (v == 0) ? 0 : pair[v][1]
    half_f(v) = (v == 0) ? 0.0 : f(data, pair[v][1], pair[v][2]) / 2
    demand(v) = (v == 0) ? 0.0 : w(data, pair[v][1])

    # edges between vertices of different customers; the cost includes half of the assignment cost of each end (the
    # travel cost between two vertices of the same locker is zero)
    E = [(i, j) for i in V for j in V if i < j && (i == 0 || customer(i) != customer(j))]
    cost(e) = half_f(e[1]) + d(data, locker(e[1]), locker(e[2])) + half_f(e[2])
    same_locker(e) = e[1] != 0 && locker(e[1]) == locker(e[2])
    if !app["no_preprocessing"]
        nb_edges = length(E)
        t = @elapsed E = remove_dominated_edges(data, E, pair, vertices_of, cost, Q)
        println("Preprocessing: $(nb_edges - length(E)) of $nb_edges edges are dominated and were removed " *
                "($(length(E)) remain), $(round(t, digits=2)) s")
        flush(stdout)
    end
    incident = [Tuple{Int,Int}[] for v in V]
    for e in E
        push!(incident[e[1]+1], e)
        push!(incident[e[2]+1], e)
    end

    # Formulation
    vrpl = VrpModel()
    @variable(vrpl.formulation, x[e in E] >= 0, Int)
    @objective(vrpl.formulation, Min, sum(cost(e) * x[e] for e in E))
    @constraint(
        vrpl.formulation, deg[c in C], sum(x[e] for v in vertices_of[c] for e in incident[v+1]) == 2.0
    )

    #println(vrpl.formulation)

    # Build the model directed graph G=(V,A)
    function build_graph()

        v_source = v_sink = 0

        # The number of routes is not limited by default (at most one route per customer).
        L = max(app["minr"], lowerBoundNbVehicles(data))
        U = min(app["maxr"], nb_customers(data))

        G = VrpGraph(vrpl, V, v_source, v_sink, (L, U))
        cap_res_id = add_resource!(G, main=true) # R = R_M = {cap_res_id}
        for v in V
            set_resource_bounds!(G, v, cap_res_id, 0.0, Q)
        end

        # Two arcs for each edge (i,j) between different lockers (or with the depot), and a single arc i -> j (i < j)
        # between two vertices of the same locker (the set A2 of the paper): the customers assigned to a locker in a
        # stop are visited in increasing order, which removes the equivalent paths that only permute them. Each arc
        # consumes half of the demands of i and j.
        for (i, j) in E
            arc_id = add_arc!(G, i, j)
            add_arc_var_mapping!(G, arc_id, x[(i, j)])
            set_arc_consumption!(G, arc_id, cap_res_id, (demand(i) + demand(j)) / 2)
            if !same_locker((i, j))
                arc_id = add_arc!(G, j, i)
                add_arc_var_mapping!(G, arc_id, x[(i, j)])
                set_arc_consumption!(G, arc_id, cap_res_id, (demand(i) + demand(j)) / 2)
            end
        end

        return G
    end

    G = build_graph()
    add_graph!(vrpl, G)
    #println(G)

    # one packing set per customer: its vertices (one for each covering locker)
    set_vertex_packing_sets!(vrpl, [[(G, v) for v in vertices_of[c]] for c in C])

    define_elementarity_sets_distance_matrix!(vrpl, G, [[customer_distance(data, c1, c2) for c2 in C] for c1 in C])

    add_capacity_cut_separator!(vrpl, [([(G, v) for v in vertices_of[c]], w(data, c)) for c in C], Q)

    # branching on the assignments (y[(s,c)] = 1 if the customer c is assigned to the locker s, i.e., if the vertex
    # v_sc is visited), then on the edges (only for the vertices that still have edges: after the preprocessing, a
    # vertex may have none)
    vertex_of = Dict((pair[v][2], pair[v][1]) => v for v in V⁺) # vertex_of[(s,c)] is the vertex v_sc
    @expression(vrpl.formulation, y[sc in [(pair[u][2], pair[u][1]) for u in V⁺ if !isempty(incident[u+1])]],
        0.5 * sum(x[e] for e in incident[vertex_of[sc]+1]))
    set_branching_priority!(vrpl, y, "y", 2)
    set_branching_priority!(vrpl, "x", 1)

    return (vrpl, x, pair)
end

# Removes the dominated edges, adapting Proposition 1 of Oliveira, Lima, Pessoa and Roboredo (2025) (itself adapted
# from Freitas, Silva and Uchoa (2023) for the GVRP). An edge {v1, v2}, where v2 = (c2, s2) is a customer vertex, is
# dominated "at v2" if, for every vertex v3 that can follow v2 in a route after v1 (the depot, or a vertex of a
# customer c3 not in {c1, c2} with w(c1) + w(c2) + w(c3) <= Q), there is another vertex v4 = (c2, s4) of the same
# customer such that cbar(v1,v2) + cbar(v2,v3) > cbar(v1,v4) + cbar(v4,v3), or the two sides are equal and s4 < s2.
# Then, in any solution that uses {v1, v2}, replacing v2 by v4 gives a solution that is not worse. Since each
# replacement strictly decreases (cost, sum of the locker indices of the visited vertices) in lexicographic order, all
# the dominated edges can be removed together without losing an optimal solution (the paper uses ">=" without the tie
# breaking and states the result for a single edge). An edge is removed if it is dominated at one of its ends. The
# order of the customers in a locker stop does not change the cost, so the single arc between two vertices of the same
# locker is not a restriction for these replacements.
function remove_dominated_edges(data::DataVRPL, E, pair, vertices_of, cost, Q)
    N = length(pair)
    cust(v) = (v == 0) ? 0 : pair[v][1]
    lock(v) = (v == 0) ? 0 : pair[v][2]
    dem(v) = (v == 0) ? 0.0 : w(data, pair[v][1])
    cb(a, b) = (a == b) ? Inf : cost((min(a, b), max(a, b))) # cbar (undefined for a == b)
    eps = 1e-9
    function dominated_at(v1, v2)
        v2 == 0 && return false
        c1, c2, s2 = cust(v1), cust(v2), lock(v2)
        alternatives = [v4 for v4 in vertices_of[c2] if v4 != v2]
        isempty(alternatives) && return false
        for v3 in 0:N
            if v3 != 0
                c3 = cust(v3)
                (c3 == c1 || c3 == c2 || dem(v1) + dem(v2) + dem(v3) > Q + eps) && continue
            end
            lhs = cb(v1, v2) + cb(v2, v3)
            found = false
            for v4 in alternatives
                rhs = cb(v1, v4) + cb(v4, v3)
                if lhs > rhs + eps || (abs(lhs - rhs) <= eps && lock(v4) < s2)
                    found = true
                    break
                end
            end
            found || return false
        end
        return true
    end
    return [(i, j) for (i, j) in E if !(dominated_at(i, j) || dominated_at(j, i))]
end
