using Random

# Simple heuristic for the GAP, used to obtain an initial upper bound when none is given: regret construction (each
# task goes to its cheapest machine with enough residual capacity, the tasks with the largest regret between their
# two cheapest feasible machines first; the regret is recomputed after each assignment), then a local search (shift of
# a task to another machine and swap of two tasks of different machines, first improvement); the construction is
# repeated with random perturbations of the costs while the time allows (5 seconds). Returns (machine of each task,
# cost), or (nothing, Inf) if no feasible assignment is found.

function gap_construct(data::DataGap, pc::Matrix{Float64})
    T, K = tasks(data), machines(data)
    res = Float64.(capacity(data))
    machine_of = zeros(Int, length(T))
    left = Set(T)
    while !isempty(left)
        best_t, best_k, best_regret = 0, 0, -Inf
        for t in left
            c1, c2, k1 = Inf, Inf, 0
            for k in K
                w(data, t, k) <= res[k] || continue
                if pc[t, k] < c1
                    c2, c1, k1 = c1, pc[t, k], k
                elseif pc[t, k] < c2
                    c2 = pc[t, k]
                end
            end
            k1 == 0 && return nothing # no machine can receive t
            regret = c2 - c1 # Inf when a single machine can receive t
            if regret > best_regret
                best_t, best_k, best_regret = t, k1, regret
            end
        end
        machine_of[best_t] = best_k
        res[best_k] -= w(data, best_t, best_k)
        delete!(left, best_t)
    end
    return machine_of
end

gap_cost(data::DataGap, m) = sum(c(data, t, m[t]) for t in tasks(data))

function gap_local_search!(data::DataGap, m)
    T, K = tasks(data), machines(data)
    load = zeros(length(K))
    for t in T
        load[m[t]] += w(data, t, m[t])
    end
    improved = true
    while improved
        improved = false
        for t in T, k in K # shift
            k == m[t] && continue
            if c(data, t, k) < c(data, t, m[t]) && load[k] + w(data, t, k) <= capacity(data)[k]
                load[m[t]] -= w(data, t, m[t]); load[k] += w(data, t, k); m[t] = k
                improved = true
            end
        end
        for t1 in T, t2 in t1+1:length(T) # swap
            k1, k2 = m[t1], m[t2]
            k1 == k2 && continue
            δ = c(data, t1, k2) + c(data, t2, k1) - c(data, t1, k1) - c(data, t2, k2)
            δ < 0 || continue
            l1 = load[k1] - w(data, t1, k1) + w(data, t2, k1)
            l2 = load[k2] - w(data, t2, k2) + w(data, t1, k2)
            if l1 <= capacity(data)[k1] && l2 <= capacity(data)[k2]
                load[k1], load[k2] = l1, l2
                m[t1], m[t2] = k2, k1
                improved = true
            end
        end
    end
    return m
end

function gap_heuristic(data::DataGap; seconds=5.0)
    T, K = tasks(data), machines(data)
    base = [Float64(c(data, t, k)) for t in T, k in K]
    rng = MersenneTwister(1)
    best, best_cost = nothing, Inf
    deadline = time() + seconds
    it = 0
    while it == 0 || time() < deadline
        # first with the true costs, then with costs (or weights relative to the capacity) perturbed at random
        pc = it == 0 ? base : (it % 2 == 1 ? base .* (0.8 .+ 0.4 .* rand(rng, length(T), length(K))) :
                               [w(data, t, k) / capacity(data)[k] * (0.8 + 0.4 * rand(rng)) for t in T, k in K])
        it += 1
        m = gap_construct(data, pc)
        isnothing(m) && continue
        gap_local_search!(data, m)
        cst = gap_cost(data, m)
        cst < best_cost && ((best, best_cost) = (m, cst))
    end
    return (best, best_cost)
end
