# Define a union-finding data structure compatible with all Julia versions (name was changed! )
if @isdefined IntDisjointSet
    const UF = IntDisjointSet
else
    const UF = IntDisjointSets
end

function add_cluster_branching!(model::VrpModel, data::DataCVRP, param::Float64, x)
    if param == 0.0
        return nothing
    end

    # build a sorted array of cost-and-edge tuples connecting customers
    n = nb_customers(data)
    E = edges(data)
    edge_costs = [(c(data, (i, j)), i, j) for (i, j) in E if i != 0]
    sort!(edge_costs)

    # phase 1 computes the average cost and its standard deviation, and phase 2 builds the cluster forest
    cost_threshold = Inf
    clusters = UF(n)
    for phase in 1:2
        sum_costs = 0.0
        sum_sq_costs = 0.0
        pos = 1
        while num_groups(clusters) > 1
            c, i, j = edge_costs[pos]
            if c > cost_threshold
                break
            end
            if !in_same_set(clusters, i, j)
                sum_costs += c
                sum_sq_costs += c * c
                union!(clusters, i, j)
            end
            pos += 1
        end
        if phase == 1
            cost_threshold = sum_costs / (n - 1) + sqrt(sum_sq_costs / (n - 1))
            clusters = UF(n)
        end
    end

    # assign one sequential cluster id to each cluster
    k = 0
    cluster_id = fill(-1, n)
    for i in 1:n
        r = find_root!(clusters, i)
        if cluster_id[r] == -1
            k += 1
            cluster_id[r] = k
        end
        cluster_id[i] = cluster_id[r]
    end
    m = k
    if m == 1
        return nothing
    end

    # add the branching expressions to the model
    @expression(
        model.formulation, ω[k in 1:m],
        sum(x[e] for e in E if (e[1] != 0 && cluster_id[e[1]] == k) != (cluster_id[e[2]] == k))
    )
    set_branching_priority!(model, ω, "omega", 2)
    @expression(
        model.formulation, Ψ[k in 1:m, l in k+1:m],
        sum(x[e] for e in E if e[1] != 0 && (cluster_id[e[1]], cluster_id[e[2]]) in ((k, l), (l, k)))
    )
    set_branching_priority!(model, Ψ, "Psi", 2)
    return nothing
end
