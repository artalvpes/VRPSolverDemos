mutable struct Solution
    cost::Float64
    # Each route is an ordered list of (job, completion_time) pairs
    schedules::Vector{Vector{Tuple{Int,Int}}}
end

# Recover schedules from the x variable values.
# Follows arcs with value > 0.5 from source (node 0) along each machine path.
function getsolution(_::DataPwjTj, x, A, node_ids, objval, optimizer)
    src_snk = 0

    # Build adjacency list from arcs with positive value
    adj = Dict{Int,Vector{Int}}()
    for (u, v) in A
        val = get_value(optimizer, x[(u, v)])
        if val > 0.5
            push!(get!(adj, u, Int[]), v)
        end
    end

    # Build reverse map: node_id -> (job, completion_time)
    id_to_jt = Dict{Int,Tuple{Int,Int}}()
    for ((j, t), nid) in node_ids
        id_to_jt[nid] = (j, t)
    end

    schedules = Vector{Tuple{Int,Int}}[]
    for start in get(adj, src_snk, Int[])
        schedule = Tuple{Int,Int}[]
        cur = start
        while cur != src_snk
            (j, t) = id_to_jt[cur]
            push!(schedule, (j, t))
            nexts = get(adj, cur, Int[])
            length(nexts) != 1 && error(
                "Node $cur (job $j, t=$t) has $(length(nexts)) outgoing arcs in solution."
            )
            cur = nexts[1]
        end
        push!(schedules, schedule)
    end

    return Solution(objval, schedules)
end

# Checks the solution x of the model with value z against the definition of P||sum w_j T_j, assuming nothing about how
# it was obtained (see Note 6.12 of the book "Optimizing with Column Generation"). The node ids of x are interpreted
# with node_ids ((job, completion time) -> id); everything else is checked from the job data: x_a binary; flow
# conservation at every node; the paths from the source give at most m machine schedules; every job is processed
# exactly once; on each machine the jobs do not overlap and start at time >= 0 (idle times are allowed); and z is
# the sum over the jobs of w_j max(0, C_j - d_j). xval maps each arc to x. Throws an error otherwise.
function checksolution_x(data::DataPwjTj, xval::Dict, node_ids::Dict, z::Float64)
    tol, src = 1e-6, 0
    for (a, v) in xval
        (abs(v) > tol && abs(v - 1) > tol) && error("x[$a] = $v is not binary")
    end
    id_to_jt = Dict(nid => jt for (jt, nid) in node_ids)
    succ = Dict{Int,Vector{Int}}()
    indeg = Dict{Int,Int}()
    for (a, v) in xval
        v > 0.5 || continue
        push!(get!(succ, a[1], Int[]), a[2])
        indeg[a[2]] = get(indeg, a[2], 0) + 1
    end
    for (nid, d) in indeg
        nid == src && continue
        nout = length(get(succ, nid, Int[]))
        (d != 1 || nout != 1) && error("Node $nid $(id_to_jt[nid]) has in-degree $d and out-degree $nout")
    end
    starts = get(succ, src, Int[])
    (length(starts) > data.m) && error("The solution uses $(length(starts)) machines, more than m = $(data.m)")
    done = zeros(Int, data.n)
    cost = 0.0
    reached = Set{Int}()
    for (k, first) in enumerate(starts)
        cur, prev_end = first, 0
        while cur != src
            (cur in reached) && error("Node $cur is reached twice")
            push!(reached, cur)
            j, t = id_to_jt[cur]
            job = data.jobs[j]
            done[j] += 1
            (t - job.p < prev_end) && error("On machine $k, job $j starts at $(t - job.p), before the previous job ends ($prev_end)")
            cost += max(0, job.w * (t - job.d))
            prev_end = t
            cur = succ[cur][1]
        end
    end
    unreached = [nid for nid in keys(indeg) if nid != src && !(nid in reached)]
    isempty(unreached) || error("The nodes $unreached are not on a path from the source (cycles)")
    for j in 1:data.n
        (done[j] != 1) && error("Job $j is processed $(done[j]) times, not once")
    end
    (abs(cost - z) > 1e-6 * max(1, abs(z))) && error("The total weighted tardiness ($cost) is different from the objective value ($z)")
end

function print_schedules(data::DataPwjTj, solution::Solution)
    jobs = data.jobs
    for (k, sched) in enumerate(solution.schedules)
        print("Machine #$k:")
        for (j, t) in sched
            start_t = t - jobs[j].p
            tardiness = max(0, t - jobs[j].d)
            print(" [job $j, start=$start_t, end=$t, tard=$tardiness]")
        end
        println()
    end
end

function writesolution(solpath::String, solution::Solution)
    open(solpath, "w") do f
        for (k, sched) in enumerate(solution.schedules)
            write(f, "Machine #$k:")
            for (j, t) in sched
                write(f, " $j($t)")
            end
            write(f, "\n")
        end
        write(f, "Cost $(solution.cost)\n")
    end
end
