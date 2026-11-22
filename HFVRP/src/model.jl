# Parameters of the custom resource; the layout (order of the fields) is the one of the C++ structs of meta_solver
struct HfvrpResArcParams
    d::Cdouble # demand of the head of the arc (0 for the depot)
    c::Cdouble # distance of the arc
end

struct HfvrpResVertexParams end

struct HfvrpResConstParams
    nTypes::Cdouble
    cap::NTuple{8,Cdouble} # capacity of each vehicle type
    fixed::NTuple{8,Cdouble} # fixed cost of each type
    factor::NTuple{8,Cdouble} # cost per unit of distance of each type
end

@register_custom_res_param_types(HfvrpResArcParams, HfvrpResVertexParams, HfvrpResConstParams)

pad8(v) = ntuple(k -> k <= length(v) ? Cdouble(v[k]) : 0.0, 8)

# A route uses the first (cheapest) type of vehicle that carries its load, and costs fixed + factor * distance of that
# type. The custom resource computes the whole cost of the route, that is the cost variable z of the model. The
# variables x are the edges of the graph, and the graph G has two arcs for each of them.
function build_model(data::DataHFVRP, app::Dict{String,Any})
    E = edges(data) # set of edges of the input graph G′
    n = nb_customers(data)
    V = [i for i in 0:n] # set of vertices of the graphs G′ and G
    V⁺ = [i for i in 1:n] # set of customers of the input graph G′
    types = data.vehTypes
    Qmax = types[end].Q

    # Formulation
    hfvrp = VrpModel()
    @variable(hfvrp.formulation, x[e in E], Int)
    @variable(hfvrp.formulation, z >= 0)
    # VrpSolver takes the objective as integral when all the coefficients are integers and the variables of the master are
    # integer, and then rounds the bounds up and the cutoff down. The cost of the routes is in the cost resource and is
    # not an integer, so a continuous variable (always 0, it has no cost) says that the objective is not integral.
    @variable(hfvrp.formulation, nonintegral >= 0)
    @objective(hfvrp.formulation, Min, z)
    @constraint(hfvrp.formulation, deg[i in V⁺], sum(x[e] for e in δ(data, i)) == 2.0)

    # Build the model directed graph G=(V,A)
    function build_graph()
        v_source = v_sink = 0

        L = max(app["minr"], ceil(Int, sum(d(data, i) for i in V⁺) / Qmax))
        U = min(app["maxr"], n)

        # node ids of G from 0 to n
        G = VrpGraph(hfvrp, V, v_source, v_sink, (L, U))
        cap_res_id = add_resource!(G, main = true)
        cost_res_id = add_resource!(G, custom = true, cost_var = z)
        const_params = HfvrpResConstParams(
            Cdouble(length(types)),
            pad8([t.Q for t in types]),
            pad8([t.fixed for t in types]),
            pad8([t.factor for t in types]),
        )
        set_const_custom_res_params!(G, cost_res_id, const_params)

        for i in V
            set_resource_bounds!(G, i, cap_res_id, 0.0, Float64(Qmax)) # accumulated load in [0, Qmax]
        end

        # Build set of arcs A from E (two arcs for each edge (i,j))
        for (i, j) in E
            c_ij = Cdouble(distance(data, i, j))
            arc_id = add_arc!(G, i, j)
            add_arc_var_mapping!(G, arc_id, x[(i, j)])
            set_arc_consumption!(G, arc_id, cap_res_id, (d(data, i) + d(data, j)) / 2)
            set_arc_custom_res_params!(G, arc_id, cost_res_id, HfvrpResArcParams(Cdouble(d(data, j)), c_ij))
            arc_id = add_arc!(G, j, i)
            add_arc_var_mapping!(G, arc_id, x[(i, j)])
            set_arc_consumption!(G, arc_id, cap_res_id, (d(data, i) + d(data, j)) / 2)
            set_arc_custom_res_params!(G, arc_id, cost_res_id, HfvrpResArcParams(Cdouble(d(data, i)), c_ij))
        end

        return G
    end

    G = build_graph()
    add_graph!(hfvrp, G)

    set_vertex_packing_sets!(hfvrp, [[(G, i)] for i in V⁺])

    define_elementarity_sets_distance_matrix!(hfvrp, G, [[distance(data, i, j) for j in V⁺] for i in V⁺])

    add_capacity_cut_separator!(hfvrp, [([(G, i)], d(data, i)) for i in V⁺], Qmax)

    set_branching_priority!(hfvrp, "x", 1)

    function edge_ub_callback()
        for (i, j) in E
            e = (i, j)
            if i != 0 && value(x[e]) > 1.001
                println("Adding edge ub cut for e = ", e)
                add_dynamic_constr!(hfvrp.optimizer, [x[e]], [1.0], <=, 1.0, "edge_ub")
            end
        end
    end
    add_cut_callback!(hfvrp, edge_ub_callback, "edge_ub")

    return (hfvrp, x, z)
end
