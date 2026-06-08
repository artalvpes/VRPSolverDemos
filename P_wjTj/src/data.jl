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

    return DataPwjTj(n, m, jobs, T)
end
