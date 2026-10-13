# Model (6.37) of Section 6.4.9 of "Optimizing with Column Generation" (Uchoa, Pessoa, Moreno),
# without the rounded capacity cuts (6.37c).
#
# Pricing graph G′ = (V′, A): the root 0 is both source and sink, and each point i ∈ S ∪ T is split
# into an entry node v_in(i) = i and an exit node v_out(i) = n + i.
#  A1: star arcs (v_in(i), v_out(i), B), one for each star B ⊆ T(i) with 0 < d(i,B) <= W
#  A2: ring arcs (v_out(i), v_in(i′)), i ≠ i′
#  A3: arcs (0, v_in(i)) and (v_out(i), 0)
v_in(data::DataCRSP, i) = i
v_out(data::DataCRSP, i) = dimension(data) - 1 + i

function build_model(data::DataCRSP, app::Dict{String,Any})

    E = edges(data) # set of edges of the input graph G
    S, T = steiner_points(data), terminals(data)
    W = capacity(data)
    Z = [(i, j) for i in points(data) for j in star_set(data, i)] # possible star connections
    stars = Dict(i => feasible_stars(data, i) for i in points(data))
    P = filter(i -> !isempty(stars[i]), points(data)) # points that may belong to a ring

    # Formulation
    crsp = VrpModel()
    @variable(crsp.formulation, x[e in E], Int)
    @variable(crsp.formulation, z[(i, j) in Z], Int)
    @objective(crsp.formulation, Min,
        sum(c(data, e) * x[e] for e in E) + sum(b(data, i, j) * z[(i, j)] for (i, j) in Z))
    # (6.37b) every terminal is either on a ring or connected through a star to a single ring point
    centers = Dict(j => [i for (i, j′) in Z if j′ == j] for j in T) # {i : j ∈ T(i)}
    @constraint(crsp.formulation, deg[j in T],
        sum(x[e] for e in δ(data, j)) + 2 * sum(z[(i, j)] for i in centers[j]) == 2.0)

    #println(crsp.formulation)

    # star arcs of each terminal packing set and of each Steiner point (to be filled when building the graph)
    ps_arcs = Dict(j => Int[] for j in T)
    S_ring = filter(i -> i in S, P) # Steiner points that may belong to a ring
    es_arcs = Dict(i => Int[] for i in S_ring)

    # Build the model directed graph G′=(V′,A)
    function build_graph()

        v_source = v_sink = 0
        V′ = vcat([0], [v_in(data, i) for i in P], [v_out(data, i) for i in P])

        L = lowerBoundNbRingStars(data)
        U = length(T)

        G = VrpGraph(crsp, V′, v_source, v_sink, (L, U))
        cap_res_id = add_resource!(G, main=true)
        for v in V′
            set_resource_bounds!(G, v, cap_res_id, 0.0, W)
        end

        # A1: star arcs, consuming d(i,B)
        for i in P, B in stars[i]
            arc_id = add_arc!(G, v_in(data, i), v_out(data, i), [z[(i, j)] for j in B])
            set_arc_consumption!(G, arc_id, cap_res_id, d(data, i, B))
            (i in T) ? push!(ps_arcs[i], arc_id) : push!(es_arcs[i], arc_id)
            for j in B
                push!(ps_arcs[j], arc_id)
            end
        end

        # A2: ring arcs between two distinct points
        for i in P, i′ in P
            if i != i′
                e = (i < i′) ? (i, i′) : (i′, i)
                add_arc!(G, v_out(data, i), v_in(data, i′), x[e])
            end
        end

        # A3: ring arcs incident to the root
        for i in P
            add_arc!(G, 0, v_in(data, i), x[(0, i)])
            add_arc!(G, v_out(data, i), 0, x[(0, i)])
        end

        return G
    end

    G = build_graph()
    add_graph!(crsp, G)
    #println(G)

    # One arc packing set per terminal j: all star arcs that cover j, either because j is on the ring
    # (star arcs of j itself) or because j is in the star (star arcs of another point i with j ∈ B).
    # These packing sets overlap, since a star arc with |B| >= 2 covers several terminals.
    set_arc_packing_sets!(crsp, [[(G, a) for a in ps_arcs[j]] for j in T])

    # One additional arc elementarity set per Steiner point i (its star arcs), so that ng-paths avoid
    # visiting i more than once in the same ring. They are not packing sets because the model allows
    # a Steiner point to belong to several rings.
    es_points = T
    if !app["no_steiner_elem_sets"]
        set_additional_arc_elementarity_sets!(crsp, [(G, es_arcs[i]) for i in S_ring])
        # elementarity set ids: 1..|T| for the terminals (packing sets), then |T|+1.. for the Steiner points
        es_points = vcat(T, S_ring)
    end
    define_elementarity_sets_distance_matrix!(crsp, G, [[distance(data, (i, j)) for j in es_points] for i in es_points])

    set_branching_priority!(crsp, "x", 2)
    set_branching_priority!(crsp, "z", 1)

    return (crsp, x, z)
end
