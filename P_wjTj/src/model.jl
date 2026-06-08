function build_model(data::DataPwjTj, ::Dict{String,Any})
    n, m, T = data.n, data.m, data.T
    jobs = data.jobs
    node_ids = data.node_ids
    job_node_list = data.job_node_list

    # Source/sink node ID (like a depot in VRP: paths start and end here)
    src_snk = 0

    # Arc type 1: source -> node(j, p_j)  [job j is first, starts at time 0]
    # Arc type 2: node(i, t) -> node(j, t+p_j)  [job j immediately follows job i]
    # Arc type 3: node(j, t) -> source  [job j is last on its machine]
    # (Proposition 3 is automatically satisfied: only x^0_{0j} arcs from source)
    A = Tuple{Int64,Int64}[]

    # Cost indexed by destination node ID: node_cost[a[2]+1] gives the arc cost.
    # Node 0 (source/sink) stays at 0.0 (type 3 arcs have no cost).
    node_cost = zeros(Float64, data.total_nodes + 1)
    for (j, t) in keys(node_ids)
        node_cost[node_ids[(j, t)]+1] = Float64(job_cost(data, j, t))
    end

    function add_arc_data!(u, v)
        push!(A, (u, v))
    end

    # Bool array to track visited nodes (indexed by node ID 0..total_nodes)
    visited = falses(data.total_nodes + 1)
    # BFS queue of (j, t) tuples seeded by type 1 arc destinations
    to_visit = Tuple{Int,Int}[]

    # Type 1: arcs from source to each job's first possible node (start at time 0)
    for j in 1:n
        t_j = jobs[j].p
        if t_j <= T
            add_arc_data!(src_snk, node_ids[(j, t_j)])
            push!(to_visit, (j, t_j))
        end
    end

    # Type 2: BFS — only create arcs from nodes reachable from the source
    next_pos = 1
    while next_pos <= length(to_visit)
        (i, t) = to_visit[next_pos]
        next_pos += 1
        nid_i = node_ids[(i, t)]
        visited[nid_i] && continue
        p_i = jobs[i].p
        for j in 1:n
            i == j && continue
            t_j = t + jobs[j].p
            t_j > T && continue
            nid_j = get(node_ids, (j, t_j), -1)
            nid_j == -1 && continue
            # Proposition 2: remove arc if swapping i and j gives a no-worse schedule
            delta = job_cost(data, i, t) + job_cost(data, j, t_j) -
                    job_cost(data, j, t_j - p_i) - job_cost(data, i, t_j)
            i < j && delta >= 0 && continue
            i > j && delta > 0 && continue
            add_arc_data!(nid_i, nid_j)
            visited[nid_j] || push!(to_visit, (j, t_j))
        end
        visited[nid_i] = true
    end

    # Type 3: arcs from each job node back to source/sink
    psum = sum(j.p for j in jobs)
    pmax = maximum(j.p for j in jobs)
    for ((j, t_j), nid_j) in node_ids
        if t_j >= div(psum - pmax, m) && t_j <= div(psum - jobs[j].p, m) + jobs[j].p
            add_arc_data!(nid_j, src_snk)
        end
    end

    # Build VrpSolver formulation
    model = VrpModel()
    @variable(model.formulation, x[a in A], Int)
    @objective(model.formulation, Min, sum(node_cost[a[2]+1] * x[a] for a in A))

    # Each job must be processed exactly once:
    # sum of x over all arcs entering any node of job j equals 1
    job_node_sets = [Set(job_node_list[j]) for j in 1:n]
    @constraint(model.formulation, cover[j in 1:n],
        sum(x[a] for a in A if a[2] in job_node_sets[j]) == 1.0)

    function buildgraph()
        # All node IDs: 0 (source/sink) plus all job-time nodes
        V1 = collect(0:data.total_nodes)

        # Exactly m machines = exactly m paths from source back to source
        G = VrpGraph(model, V1, src_snk, src_snk, (m, m))

        for a in A
            arc_id = add_arc!(G, a[1], a[2])
            add_arc_var_mapping!(G, arc_id, x[a])
        end

        return G
    end

    G = buildgraph()
    add_graph!(model, G)

    # Packing sets: for each job j, all its (j,t) nodes form one set.
    # At most one machine path may process each job.
    set_vertex_packing_sets!(model, [
        [(G, nid) for nid in job_node_list[j]] for j in 1:n
    ])

    # Elementarity sets distance matrix based on absolute due date differences.
    # Entry [i][j] = |d_i - d_j|, guiding ng-route neighbourhood initialisation.
    dist_matrix = [[Float64(abs(jobs[i].d - jobs[j].d)) for j in 1:n] for i in 1:n]
    define_elementarity_sets_distance_matrix!(model, G, dist_matrix)

    # Expression y[(i,j)]: sum of x over all type-2 arcs from job i to job j
    node_to_job = Dict{Int,Int}(nid => j
                                for j in 1:n for nid in job_node_list[j])
    arcs_per_pair = Dict{Tuple{Int,Int},Vector{Tuple{Int64,Int64}}}()
    for a in A
        (a[1] == src_snk || a[2] == src_snk) && continue
        push!(get!(arcs_per_pair, (node_to_job[a[1]], node_to_job[a[2]]),
                Tuple{Int64,Int64}[]), a)
    end
    job_pairs = collect(keys(arcs_per_pair))
    @expression(model.formulation, y[ij in job_pairs],
        sum(x[a] for a in arcs_per_pair[ij]))
    set_branching_priority!(model, y, "y", 2)
    set_branching_priority!(model, x, "x", 1)

    return (model, x, A)
end
