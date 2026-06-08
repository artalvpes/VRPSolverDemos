mutable struct Job
    p::Int  # processing time
    w::Int  # weight
    d::Int  # due date
end

mutable struct DataPwjTj
    n::Int              # number of jobs
    m::Int              # number of machines
    jobs::Vector{Job}
    T::Int              # time horizon (max completion time)
    # node_ids[(j,t)] = graph node ID for job j completing at time t
    node_ids::Dict{Tuple{Int,Int}, Int}
    # job_node_list[j] = sorted list of graph node IDs for job j
    job_node_list::Vector{Vector{Int}}
    total_nodes::Int    # total number of job-time nodes (IDs 1..total_nodes; 0 = source/sink)
end

# Weighted tardiness cost of job j completing at time t
function job_cost(data::DataPwjTj, j::Int, t::Int)
    return max(0, data.jobs[j].w * (t - data.jobs[j].d))
end

function readPwjTjData(path_file::String)
    # Instance filename format: wt{n}-{m}m-{inst}.txt
    fname = splitext(basename(path_file))[1]
    parts = split(fname, "-")
    n = parse(Int, parts[1][3:end])      # "wt40" -> 40
    m = parse(Int, parts[2][1:end-1])    # "2m"  -> 2

    jobs = Job[]
    open(path_file) do f
        readline(f)  # first line is n (discard; we read n from the filename)
        p_arr = parse.(Int, split(readline(f)))
        w_arr = parse.(Int, split(readline(f)))
        d_arr = parse.(Int, split(readline(f)))
        for i in 1:n
            push!(jobs, Job(p_arr[i], w_arr[i], d_arr[i]))
        end
    end

    psum = sum(j.p for j in jobs)
    pmax = maximum(j.p for j in jobs)

    # Time horizon: no idle times between jobs, idle only at end if needed
    T = if m == 1
        psum
    else
        div(psum - pmax, m) + pmax
    end

    # Assign contiguous node IDs: 0 = source/sink, 1..total for (job, time) pairs
    node_ids = Dict{Tuple{Int,Int}, Int}()
    job_node_list = [Int[] for _ in 1:n]
    next_id = 0
    for j in 1:n
        for t in jobs[j].p:T
            next_id += 1
            node_ids[(j, t)] = next_id
            push!(job_node_list[j], next_id)
        end
    end

    return DataPwjTj(n, m, jobs, T, node_ids, job_node_list, next_id)
end
