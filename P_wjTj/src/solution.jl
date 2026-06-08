mutable struct Solution
    cost::Float64
    # Each route is an ordered list of (job, completion_time) pairs
    schedules::Vector{Vector{Tuple{Int,Int}}}
end

# Recover schedules from the x variable values.
# Follows arcs with value > 0.5 from source (node 0) along each machine path.
function getsolution(data::DataPwjTj, x, A, objval, optimizer)
    src_snk = 0
    node_ids = data.node_ids

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
