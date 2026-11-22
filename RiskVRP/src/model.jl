# Parameters of the custom resource; the layout (order of the fields) is the one of the C++ structs of meta_solver
struct RiskResArcParams
    dt::Cdouble # demand of the tail of the arc (0 for the depot)
    c::Cdouble # distance of the arc
end

struct RiskResVertexParams end

struct RiskResConstParams
    Rmax::Cdouble # maximum risk of a route
end

@register_custom_res_param_types(RiskResArcParams, RiskResVertexParams, RiskResConstParams)

# The risk of a route is the sum, over its customers, of the demand times the distance from the customer to the end of the
# route. It is computed by the custom resource. The cost of the route is the distance of its arcs, so the variables are
# the arcs of the directed graph (the risk depends on the direction of the route).
function build_model(data::DataRiskVRP, app::Dict{String,Any})
    A = arcs(data) # set of arcs of the complete directed graph G′
    n = nb_customers(data)
    V = [i for i in 0:n] # set of vertices of the graphs G′ and G
    V⁺ = [i for i in 1:n] # set of customers of the input graph G′

    # Formulation
    risk = VrpModel()
    @variable(risk.formulation, x[a in A], Int)
    @objective(risk.formulation, Min, sum(distance(data, a[1], a[2]) * x[a] for a in A))
    @constraint(risk.formulation, deg[i in V⁺], sum(x[a] for a in A if a[2] == i) == 1.0)

    # Build the model directed graph G=(V,A)
    function build_graph()
        v_source = v_sink = 0

        L = max(app["minr"], 1)
        U = min(app["maxr"], n)

        # node ids of G from 0 to n
        G = VrpGraph(risk, V, v_source, v_sink, (L, U))
        len_res_id = add_resource!(G, main = true) # number of arcs of the path: an elementary route has at most n + 1
        risk_res_id = add_resource!(G, custom = true)
        set_const_custom_res_params!(G, risk_res_id, RiskResConstParams(Cdouble(risk_threshold(data))))

        for i in V
            set_resource_bounds!(G, i, len_res_id, 0.0, Float64(n + 1))
        end

        for (i, j) in A
            arc_id = add_arc!(G, i, j)
            add_arc_var_mapping!(G, arc_id, x[(i, j)])
            set_arc_consumption!(G, arc_id, len_res_id, 1.0)
            set_arc_custom_res_params!(G, arc_id, risk_res_id, RiskResArcParams(Cdouble(d(data, i)), Cdouble(distance(data, i, j))))
        end

        return G
    end

    G = build_graph()
    add_graph!(risk, G)

    set_vertex_packing_sets!(risk, [[(G, i)] for i in V⁺])

    define_elementarity_sets_distance_matrix!(risk, G, [[distance(data, i, j) for j in V⁺] for i in V⁺])

    set_branching_priority!(risk, "x", 1)

    return (risk, x)
end
