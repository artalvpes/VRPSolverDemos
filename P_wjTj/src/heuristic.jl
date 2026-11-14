# Simple heuristic for P||sum w_j T_j, used to obtain an initial upper bound.
#
# Construction: list scheduling. The machine that becomes free first receives the unscheduled job of highest
# priority, for several rules: ATC (apparent tardiness cost) with K in {0.5, 1, 2, 4}, WSPT and EDD.
# Local search (first improvement, until no improvement): move a job to any position of any machine, and swap two
# jobs. Then an iterated local search perturbs the best solution with random moves.
# A solution is a vector of machine sequences; there is no idle time.

using Random

function machine_cost(data::DataPwjTj, seq::Vector{Int})
    t, c = 0, 0
    for j in seq
        t += data.jobs[j].p
        c += job_cost(data, j, t)
    end
    return c
end

schedule_cost(data::DataPwjTj, sched) = sum(machine_cost(data, s) for s in sched)

function list_schedule(data::DataPwjTj, priority::Function)
    sched = [Int[] for _ in 1:data.m]
    free = zeros(Int, data.m)
    left = Set(1:data.n)
    while !isempty(left)
        k = argmin(free)
        t = free[k]
        j = argmax(j -> (priority(j, t), -j), collect(left))
        push!(sched[k], j)
        free[k] = t + data.jobs[j].p
        delete!(left, j)
    end
    return sched
end

function local_search!(data::DataPwjTj, sched::Vector{Vector{Int}})
    costs = [machine_cost(data, s) for s in sched]
    improved = true
    while improved
        improved = false
        # move a job to any position of any machine
        for a in 1:data.m, i in 1:length(sched[a])
            j = sched[a][i]
            sa = deleteat!(copy(sched[a]), i)
            ca = machine_cost(data, sa)
            for b in 1:data.m, pos in 1:(length(sched[b]) + (a == b ? 0 : 1))
                (a == b && pos == i) && continue
                sb = insert!(copy(a == b ? sa : sched[b]), pos, j)
                cb = machine_cost(data, sb)
                delta = (a == b) ? cb - costs[a] : ca + cb - costs[a] - costs[b]
                if delta < 0
                    if a == b
                        sched[a], costs[a] = sb, cb
                    else
                        sched[a], costs[a], sched[b], costs[b] = sa, ca, sb, cb
                    end
                    improved = true
                    break
                end
            end
            improved && break
        end
        improved && continue
        # swap two jobs
        for a in 1:data.m, i in 1:length(sched[a]), b in a:data.m, i2 in 1:length(sched[b])
            (a == b && i2 <= i) && continue
            sa = copy(sched[a])
            sb = (a == b) ? sa : copy(sched[b])
            sa[i], sb[i2] = sched[b][i2], sched[a][i]
            ca = machine_cost(data, sa)
            cb = (a == b) ? ca : machine_cost(data, sb)
            delta = (a == b) ? ca - costs[a] : ca + cb - costs[a] - costs[b]
            if delta < 0
                sched[a], costs[a] = sa, ca
                a != b && ((sched[b], costs[b]) = (sb, cb))
                improved = true
                break
            end
        end
    end
    return sched
end

# Returns the best schedule found and its cost
function pwjtj_heuristic(data::DataPwjTj; ils_iterations::Int=200, seed::Int=1)
    jobs = data.jobs
    pbar = sum(j.p for j in jobs) / data.n
    rules = Function[(j, t) -> -jobs[j].d, (j, t) -> jobs[j].w / jobs[j].p]
    for K in (0.5, 1.0, 2.0, 4.0)
        push!(rules, (j, t) -> jobs[j].w / jobs[j].p * exp(-max(0, jobs[j].d - jobs[j].p - t) / (K * pbar)))
    end
    best, best_cost = Vector{Int}[], typemax(Int)
    for rule in rules
        sched = local_search!(data, list_schedule(data, rule))
        c = schedule_cost(data, sched)
        if c < best_cost
            best, best_cost = sched, c
        end
    end
    rng = MersenneTwister(seed)
    for _ in 1:ils_iterations
        best_cost == 0 && break
        sched = deepcopy(best)
        for _ in 1:3 # perturbation: three random moves
            a = rand(rng, findall(!isempty, sched))
            j = popat!(sched[a], rand(rng, 1:length(sched[a])))
            b = rand(rng, 1:data.m)
            insert!(sched[b], rand(rng, 1:length(sched[b])+1), j)
        end
        local_search!(data, sched)
        c = schedule_cost(data, sched)
        if c < best_cost
            best, best_cost = sched, c
        end
    end
    return best, best_cost
end
