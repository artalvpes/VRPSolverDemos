function build_model(data::DataPwjTj, app::Dict{String,Any})
    n, m, T = data.n, data.m, data.T
    jobs = data.jobs

    src_snk = 0

    # Node IDs assigned lazily during BFS — only reachable (j,t) pairs get an ID.
    # 0 = source/sink; 1..next_id[] = job-time nodes.
    node_ids = Dict{Tuple{Int,Int},Int}()
    job_node_list = [Int[] for _ in 1:n]
    next_id = Ref(0)

    function register_node!(j, t)
        next_id[] += 1
        node_ids[(j, t)] = next_id[]
        push!(job_node_list[j], next_id[])
        return next_id[]
    end

    # Arc type 1: source -> node(j, p_j)  [job j is first, starts at time 0]
    # Arc type 2: node(i, t) -> node(j, t+p_j)  [job j immediately follows job i]
    # Arc type 3: node(j, t) -> source  [job j is last on its machine]
    # (Proposition 3 is automatically satisfied: only x^0_{0j} arcs from source)
    A = Tuple{Int64,Int64}[]
    function add_arc_data!(u, v)
        push!(A, (u, v))
    end

    # BFS queue seeded by type 1 arc destinations
    to_visit = Tuple{Int,Int}[]

    # Type 1: register first-job nodes and create source arcs
    for j in 1:n
        t_j = jobs[j].p
        t_j > T && continue
        nid_j = register_node!(j, t_j)
        add_arc_data!(src_snk, nid_j)
        push!(to_visit, (j, t_j))
    end

    # Type 2: BFS — register and connect only nodes reachable from the source
    next_pos = 1
    while next_pos <= length(to_visit)
        (i, t) = to_visit[next_pos]
        next_pos += 1
        nid_i = node_ids[(i, t)]
        p_i = jobs[i].p
        for j in 1:n
            i == j && continue
            t_j = t + jobs[j].p
            t_j > T && continue
            # Proposition 2: remove arc if swapping i and j gives a no-worse schedule
            delta = job_cost(data, i, t) + job_cost(data, j, t_j) -
                    job_cost(data, j, t_j - p_i) - job_cost(data, i, t_j)
            jobs[i].p < jobs[j].p && delta > 0 && continue
            jobs[i].p > jobs[j].p && delta >= 0 && continue
            i < j && jobs[i].p == jobs[j].p && delta > 0 && continue
            i > j && jobs[i].p == jobs[j].p && delta >= 0 && continue
            nid_j = get(node_ids, (j, t_j), 0)
            if nid_j == 0
                nid_j = register_node!(j, t_j)
                push!(to_visit, (j, t_j))
            end
            add_arc_data!(nid_i, nid_j)
        end
    end

    # Type 3: arcs from visited job nodes back to source/sink
    psum = sum(j.p for j in jobs)
    pmax = maximum(j.p for j in jobs)
    for ((j, t_j), nid_j) in node_ids
        if t_j >= div(psum - pmax, m) && t_j <= div(psum - jobs[j].p, m) + jobs[j].p
            add_arc_data!(nid_j, src_snk)
        end
    end

    # Cost indexed by destination node ID (1-based: node k -> index k+1).
    # Built after BFS so all node IDs are known. Node 0 stays at 0.0.
    node_cost = zeros(Float64, next_id[] + 1)
    for ((j, t), nid) in node_ids
        node_cost[nid+1] = Float64(job_cost(data, j, t))
    end

    println("The model uses a graph with $(length(A)) arcs!")

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
        V1 = collect(0:next_id[])
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

    # Expression y[(i,j)]: sum of x over arcs from job i to job j (0 = source/sink).
    # arcs_per_pair is a (n+1)×(n+1) matrix indexed by [tailjob+1, headjob+1].
    node_to_job = Dict{Int,Int}(src_snk => 0)
    for j in 1:n, nid in job_node_list[j]
        node_to_job[nid] = j
    end
    arcs_per_pair = [Tuple{Int64,Int64}[] for _ in 1:n+1, _ in 1:n+1]
    for a in A
        push!(arcs_per_pair[node_to_job[a[1]]+1, node_to_job[a[2]]+1], a)
    end
    job_pairs = [(i, j) for i in 0:n for j in 0:n if !isempty(arcs_per_pair[i+1, j+1])]

    GC.enable(false)
    @expression(model.formulation, y[ij in job_pairs],
        sum(x[a] for a in arcs_per_pair[ij[1]+1, ij[2]+1]))
    GC.enable(true)

    set_branching_priority!(model, y, "y", 2)
    set_branching_priority!(model, x, "x", 1)

    add_ecc_cuts!(model, data, x, A, node_ids, app["ub"])

    return (model, x, A, node_ids)
end
