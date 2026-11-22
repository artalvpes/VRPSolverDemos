# Parameters of the custom resource; the layout (order of the fields) is the one of the C++ structs of meta_solver
struct SpdResArcParams
    p::Cdouble # pickup demand of the head of the arc (0 for the depot)
    d::Cdouble # delivery demand of the head of the arc (0 for the depot)
end

struct SpdResVertexParams end

struct SpdResConstParams
    Q::Cdouble # vehicle capacity
end

@register_custom_res_param_types(SpdResArcParams, SpdResVertexParams, SpdResConstParams)

# A vehicle leaves the depot with the deliveries of its route and, at each customer, delivers and then picks up. Its load
# must not exceed the capacity in any position of the route, what the custom resource checks. The main resource is the
# accumulated pickup, that cannot exceed the capacity either. The cost of the route is the distance of its arcs, so the
# variables are the arcs of the directed graph (the load depends on the direction of the route).
function build_model(data::DataVRPSPD, app::Dict{String,Any})
    A = arcs(data) # set of arcs of the complete directed graph G′
    n = nb_customers(data)
    V = [i for i in 0:n] # set of vertices of the graphs G′ and G
    V⁺ = [i for i in 1:n] # set of customers of the input graph G′
    Q = veh_capacity(data)

    # Formulation
    spd = VrpModel()
    @variable(spd.formulation, x[a in A], Int)
    @objective(spd.formulation, Min, sum(distance(data, a[1], a[2]) * x[a] for a in A))
    @constraint(spd.formulation, deg[i in V⁺], sum(x[a] for a in A if a[2] == i) == 1.0)

    # Build the model directed graph G=(V,A)
    function build_graph()
        v_source = v_sink = 0

        # a route leaves the depot with all the deliveries and ends with all the pickups
        L = max(app["minr"], ceil(Int, max(sum(delivery(data, i) for i in V⁺), sum(pickup(data, i) for i in V⁺)) / Q), 1)
        U = min(app["maxr"], n)

        # node ids of G from 0 to n
        G = VrpGraph(spd, V, v_source, v_sink, (L, U))
        pick_res_id = add_resource!(G, main = true) # accumulated pickup
        spd_res_id = add_resource!(G, custom = true)
        set_const_custom_res_params!(G, spd_res_id, SpdResConstParams(Cdouble(Q)))

        for i in V
            set_resource_bounds!(G, i, pick_res_id, 0.0, Float64(Q))
        end

        for (i, j) in A
            arc_id = add_arc!(G, i, j)
            add_arc_var_mapping!(G, arc_id, x[(i, j)])
            set_arc_consumption!(G, arc_id, pick_res_id, Float64(pickup(data, j)))
            set_arc_custom_res_params!(G, arc_id, spd_res_id, SpdResArcParams(Cdouble(pickup(data, j)), Cdouble(delivery(data, j))))
        end

        return G
    end

    G = build_graph()
    add_graph!(spd, G)

    set_vertex_packing_sets!(spd, [[(G, i)] for i in V⁺])

    define_elementarity_sets_distance_matrix!(spd, G, [[distance(data, i, j) for j in V⁺] for i in V⁺])

    set_branching_priority!(spd, "x", 1)

    return (spd, x)
end
