# Parameters of the custom resource; the layout (order of the fields) is the one of the C++ structs of meta_solver
struct MdvrpResArcParams
    c::Cdouble # distance between the customers of the arc (0 for the arcs of the dummy depot)
    tail::Cdouble # vertex that the arc leaves (0 is the dummy depot)
    head::Cdouble # vertex that the arc enters
end

struct MdvrpResVertexParams
    id::Cdouble # vertex id in the model
    x::Cdouble # coordinates of the customer
    y::Cdouble
end

struct MdvrpResConstParams
    nDepots::Cdouble
    rounded::Cdouble # 1.0 if the distances are rounded to the nearest integer
    depotX::NTuple{16,Cdouble} # coordinates of the depots
    depotY::NTuple{16,Cdouble}
end

@register_custom_res_param_types(MdvrpResArcParams, MdvrpResVertexParams, MdvrpResConstParams)

pad16(v) = ntuple(k -> k <= length(v) ? Cdouble(v[k]) : 0.0, 16)

# The model has a single dummy depot. The cost of a route is the distance between its customers plus the cost of the round
# trip of the cheapest depot that serves its first and its last customers; the custom resource computes it, and it is the
# cost variable z of the model. The variables x are the edges of the graph, and the graph G has two arcs for each of them.
function build_model(data::DataMDVRP, app::Dict{String,Any})
    E = edges(data) # set of edges of the input graph G′
    n = nb_customers(data)
    V = [i for i in 0:n] # set of vertices of the graphs G′ and G
    V⁺ = [i for i in 1:n] # set of customers of the input graph G′
    Q = veh_capacity(data)
    data.m <= 16 || error("At most 16 depots are supported ($(data.m) in the instance)")

    # Formulation
    mdvrp = VrpModel()
    @variable(mdvrp.formulation, x[e in E], Int)
    @variable(mdvrp.formulation, z >= 0)
    # VrpSolver takes the objective as integral when all the coefficients are integers and the variables of the master are
    # integer, and then rounds the bounds up and the cutoff down. The cost of the routes is in the cost resource and is
    # not an integer, so a continuous variable (always 0, it has no cost) says that the objective is not integral.
    @variable(mdvrp.formulation, nonintegral >= 0)
    @objective(mdvrp.formulation, Min, z)
    @constraint(mdvrp.formulation, deg[i in V⁺], sum(x[e] for e in δ(data, i)) == 2.0)

    # Build the model directed graph G=(V,A)
    function build_graph()
        v_source = v_sink = 0

        L = max(app["minr"], ceil(Int, sum(d(data, i) for i in V⁺) / Q))
        U = min(app["maxr"], n)

        # node ids of G from 0 to n
        G = VrpGraph(mdvrp, V, v_source, v_sink, (L, U))
        cap_res_id = add_resource!(G, main = true)
        cost_res_id = add_resource!(G, custom = true, cost_var = z)
        const_params = MdvrpResConstParams(
            Cdouble(data.m),
            data.round ? 1.0 : 0.0,
            pad16([v.pos_x for v in depots(data)]),
            pad16([v.pos_y for v in depots(data)]),
        )
        set_const_custom_res_params!(G, cost_res_id, const_params)

        for i in V
            set_resource_bounds!(G, i, cap_res_id, 0.0, Float64(Q)) # accumulated load in [0, Q]
            if i == 0
                set_vertex_custom_res_params!(G, i, cost_res_id, MdvrpResVertexParams(0.0, 0.0, 0.0))
            else
                v = vertex(data, i)
                set_vertex_custom_res_params!(G, i, cost_res_id, MdvrpResVertexParams(i, v.pos_x, v.pos_y))
            end
        end

        # Build set of arcs A from E (two arcs for each edge (i,j))
        for (i, j) in E
            c_ij = (i == 0) ? 0.0 : Cdouble(distance(data, i, j))
            for (a, b) in ((i, j), (j, i))
                arc_id = add_arc!(G, a, b)
                add_arc_var_mapping!(G, arc_id, x[(i, j)])
                set_arc_consumption!(G, arc_id, cap_res_id, (d(data, i) + d(data, j)) / 2)
                set_arc_custom_res_params!(G, arc_id, cost_res_id, MdvrpResArcParams(c_ij, a, b))
            end
        end

        return G
    end

    G = build_graph()
    add_graph!(mdvrp, G)

    set_vertex_packing_sets!(mdvrp, [[(G, i)] for i in V⁺])

    define_elementarity_sets_distance_matrix!(mdvrp, G, [[distance(data, i, j) for j in V⁺] for i in V⁺])

    add_capacity_cut_separator!(mdvrp, [([(G, i)], d(data, i)) for i in V⁺], Q)

    set_branching_priority!(mdvrp, "x", 1)

    function edge_ub_callback()
        for (i, j) in E
            e = (i, j)
            if i != 0 && value(x[e]) > 1.001
                println("Adding edge ub cut for e = ", e)
                add_dynamic_constr!(mdvrp.optimizer, [x[e]], [1.0], <=, 1.0, "edge_ub")
            end
        end
    end
    add_cut_callback!(mdvrp, edge_ub_callback, "edge_ub")

    return (mdvrp, x, z)
end
