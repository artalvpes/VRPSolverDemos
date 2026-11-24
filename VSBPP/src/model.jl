# Map Decomposition Model for the variable-sized bin packing with penalties.
#
#   min  sum_k c_k t_k + sum_j p_j y_j
#   s.t. x_j + y_j = 1              j in J   (item j is produced or its penalty is paid)
#        t_k <= u_k                 k in K   (availability of stock type k)
#        x_j = sum_q q(a_j+) lambda_q        (mapping: x_j is the use of arc a_j+)
#        t_k = sum_q q(a_k) lambda_q         (mapping: t_k is the use of sink arc a_k)
#
# y_j = 1 - x_j is used because VRPSolver does not accept a constant in the objective.
# A single graph generates the cutting patterns of all stock types:
#   v_0 -> v_1 -> ... -> v_J : two parallel arcs per item, a_j+ (produce, consumes w_j) and a_j- (skip);
#   v_J -> v_{J+1}           : one parallel arc a_k per stock type, with the resource interval [0, W_k].
function build_model(data::DataVSBPP)
    J, K = items(data), stock_types(data)
    nJ = length(J)
    Wmax = maximum(data.W)

    vsbpp = VrpModel()
    @variable(vsbpp.formulation, x[j in J] >= 0, Int) # x[j] = 1 if item j is produced
    @variable(vsbpp.formulation, y[j in J] >= 0, Int) # y[j] = 1 if item j is not produced
    @variable(vsbpp.formulation, t[k in K] >= 0, Int) # t[k] = number of stocks of type k used
    @objective(vsbpp.formulation, Min, sum(data.c[k] * t[k] for k in K) + sum(data.p[j] * y[j] for j in J))
    @constraint(vsbpp.formulation, prod[j in J], x[j] + y[j] == 1)
    @constraint(vsbpp.formulation, avail[k in K], t[k] <= data.u[k])

    # Each path is one cutting pattern; at most sum(u) patterns (stocks) in a solution
    V = collect(0:nJ+1)
    v_source, v_sink = 0, nJ + 1
    G = VrpGraph(vsbpp, V, v_source, v_sink, (0, sum(data.u)))
    len_res = add_resource!(G, main=true)
    for v in V
        set_resource_bounds!(G, v, len_res, 0.0, v == v_source ? 0.0 : Float64(Wmax))
    end

    produce_arc = Int[] # produce_arc[j] is the id of arc a_j+
    for j in J
        a_plus = add_arc!(G, j - 1, j)
        set_arc_consumption!(G, a_plus, len_res, Float64(data.w[j]))
        add_arc_var_mapping!(G, a_plus, x[j])
        push!(produce_arc, a_plus)

        a_minus = add_arc!(G, j - 1, j)
        set_arc_consumption!(G, a_minus, len_res, 0.0)
    end
    stock_arc = Int[] # stock_arc[k] is the id of the sink arc a_k
    for k in K
        a_k = add_arc!(G, nJ, nJ + 1)
        set_arc_consumption!(G, a_k, len_res, 0.0)
        set_arc_resource_bounds!(G, a_k, len_res, 0.0, Float64(data.W[k]))
        add_arc_var_mapping!(G, a_k, t[k])
        push!(stock_arc, a_k)
    end
    add_graph!(vsbpp, G)

    # One packing set per item: arc a_j+ appears at most once in a solution (enables rank-1 cuts and enumeration)
    set_arc_packing_sets!(vsbpp, [[(G, produce_arc[j])] for j in J])
    # One additional elementarity set per sink arc a_k. The enumeration keeps only the cheapest path among those
    # that visit the same elementarity sets; without these sets, the same items cut from different stock types
    # would be the same path for the enumeration, and patterns would be lost (wrong optima were obtained).
    # They are not packing sets: several stocks of the same type can be used.
    set_additional_arc_elementarity_sets!(vsbpp, [(G, [stock_arc[k]]) for k in K])

    # Branching on t_k and x_j is robust but may not suffice to reach an integer solution. The branching on the
    # accumulated resource consumption (Gelinas et al. 1995) is disabled in the current VrpSolver.jl, so the
    # Ryan and Foster branching on pairs of items (packing sets) is used as the last resort.
    set_branching_priority!(vsbpp, "t", 3)
    set_branching_priority!(vsbpp, "x", 2)
    enable_packset_ryanfoster_branching!(vsbpp, 1)

    return vsbpp, x, t, G, produce_arc, stock_arc
end
