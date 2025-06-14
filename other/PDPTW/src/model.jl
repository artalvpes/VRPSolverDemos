function build_model(data::DataPDPTW, app; k=-1)
    A = arcs(data)
    n = data.n
    P = [i for i in 1:2*n if d(data, i) > 0]
    D = [i for i in 1:2*n if d(data, i) < 0]
    Q = veh_capacity(data)

    # Formulation
    pdptw = VrpModel()
    @variable(pdptw.formulation, x[a in A], Int)
    @expression(pdptw.formulation, num_veh, sum(x[a] for a in A if a[1] == 0))
    if app["lilim"]
        @objective(pdptw.formulation, Min, sum(c(data, a) * x[a] for a in A))
    else
        @objective(pdptw.formulation, Min, app["fixed"] * num_veh + sum(c(data, a) * x[a] for a in A))
    end
    @constraint(pdptw.formulation, indeg[i in P], sum(x[a] for a in A if a[2] == i) == 1.0)

    # print(pdptw.formulation)

    # Build the model directed graph G=(V1,A1)
    function buildgraph()

        v_source = v_sink = 0
        V1 = [i for i in 0:2*n]

        # multiplicity
        if app["lilim"]
            L = lowerBoundNbVehicles(data)
            U = upperBoundNbVehicles(data)
        else
            L = U = k
        end
        G = VrpGraph(pdptw, V1, v_source, v_sink, (L, U))

        request_resources_ids = []
        for i in 1:n
            push!(request_resources_ids, add_resource!(G, binary=true, disposable=false))
        end
        cap_res_id = add_resource!(G, disposable=false)
        time_res_id = add_resource!(G, main=true)

        for v in V1
            set_resource_bounds!(G, v, cap_res_id, 0, v == 0 ? 0 : Q)
            set_resource_bounds!(G, v, time_res_id, l(data, v), u(data, v))
            for i in 1:n
                set_resource_bounds!(G, v, request_resources_ids[i], 0, v == 0 ? 0 : 1)
            end
        end

        for (i, j) in A
            arc_id = add_arc!(G, i, j)
            add_arc_var_mapping!(G, arc_id, x[(i, j)])
            set_arc_consumption!(G, arc_id, cap_res_id, d(data, j))
            set_arc_consumption!(G, arc_id, time_res_id, t(data, (i, j)))
            if d(data, j) > 0
                set_arc_consumption!(G, arc_id, request_resources_ids[r(data, j)], 1)
            elseif d(data, j) < 0
                set_arc_consumption!(G, arc_id, request_resources_ids[r(data, j)], -1)
            end
        end

        return G
    end

    G = buildgraph()
    add_graph!(pdptw, G)
    # println(G)

    set_vertex_packing_sets!(pdptw, [[(G, i)] for i in P])

    # in this application, initial ng-neighbourhood is not defined using the
    # distance matrix, but it is defined explicitely
    function define_initial_neighborhood(data::DataPDPTW, vertex_id::Int, vertex_elem_set_id::Int, neigh_size::Int)
        dists = [(ps_id, c(data, (vertex_id, P[ps_id]))) for ps_id in 1:n]
        sort!(dists, by=x -> x[2])
        add_elem_set_to_vertex_init_ng_neighbourhood!(pdptw, G, vertex_id, vertex_elem_set_id)
        add_elem_set_to_vertex_init_ng_neighbourhood!(pdptw, G, sibling(data, vertex_id), vertex_elem_set_id)
        for i in 1:neigh_size-1
            add_elem_set_to_vertex_init_ng_neighbourhood!(pdptw, G, vertex_id, dists[i][1])
            add_elem_set_to_vertex_init_ng_neighbourhood!(pdptw, G, sibling(data, vertex_id), dists[i][1])
        end
    end
    for es_id in 1:n
        define_initial_neighborhood(data, P[es_id], es_id, min(n, 8))
    end

    set_branching_priority!(pdptw, "x", 1)
    # set_branching_priority!(pdptw, num_veh, "num_veh", 2) # branching in expressions is still not supported
    return (pdptw, x)
end
