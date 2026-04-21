mutable struct Vertex
    id::Int
    pos_x::Float64
    pos_y::Float64
    service_time::Int
    demand::Int
    start_tw::Int
    end_tw::Int
    request_id::Int
end

mutable struct Request
    id::Int
    pickup::Vertex
    delivery::Vertex
end

# Directed graph
mutable struct InputGraph
    V′::Array{Vertex} # set of vertices
    A::Array{Tuple{Int64,Int64}} # set of edges
    cost::Dict{Tuple{Int64,Int64},Float64} # cost for each arc
    time::Dict{Tuple{Int64,Int64},Float64} # time for each arc
end

mutable struct DataPDPTW
    n::Int
    requests::Array{Request}
    G′::InputGraph
    Q::Float64 # vehicle capacity
    K::Int #num vehicles available
end

# Euclidian distance
function distance(v1::Vertex, v2::Vertex, round::Bool)
    x_sq = (v1.pos_x - v2.pos_x)^2
    y_sq = (v1.pos_y - v2.pos_y)^2
    if round
        return floor(sqrt(x_sq + y_sq) + 0.5)
    end
    return sqrt(x_sq + y_sq)
end

function build_arcs(vertices::Array{Vertex}, n::Int, round_dists::Bool)
    A = Tuple{Int64,Int64}[]
    cost = Dict{Tuple{Int64,Int64},Float64}()
    time = Dict{Tuple{Int64,Int64},Float64}()

    function add_arc!(i, j)
        push!(A, (i, j))
        cost[(i, j)] = distance(vertices[i+1], vertices[j+1], round_dists)
        time[(i, j)] = distance(vertices[i+1], vertices[j+1], round_dists) + vertices[i+1].service_time
    end
    for i in 1:2*n
        #arc from depot
        if vertices[i+1].demand > 0
            add_arc!(0, i)
        end
        #arc to depot
        if vertices[i+1].demand < 0
            add_arc!(i, 0)
        end
        for j in 1:2n
            if (i != j) #&& (i - j != n)
                add_arc!(i, j)
            end
        end
    end
    return (A, cost, time)
end

function readLiLimData(path_file::String, round_dists::Bool)
    # STEP 1 : pushing data in a vector.
    data = Array{Any,1}()
    open(path_file) do file
        for line in eachline(file)
            for peaceofdata in split(line)
                push!(data, String(peaceofdata))
            end
        end
    end

    K = parse(Int, data[1])
    Q = parse(Float64, data[2])
    n = Int((length(data) - 3 - 9) / 18)

    vertices = Vertex[]
    siblings = []
    for i in 0:2*n
        offset = 3 + i * 9
        x = parse(Float64, data[offset+2])
        y = parse(Float64, data[offset+3])
        d = parse(Int, data[offset+4])
        l = parse(Int, data[offset+5])
        u = parse(Int, data[offset+6])
        s = parse(Int, data[offset+7])
        if d < 0
            push!(siblings, parse(Int, data[offset+8]))
        elseif d > 0
            push!(siblings, parse(Int, data[offset+9]))
        end
        push!(vertices, Vertex(i, x, y, s, d, l, u, 0))
    end

    requests = Request[]
    for i in 1:2*n
        if vertices[i+1].demand > 0
            req_id = length(requests) + 1
            vertices[i+1].request_id = req_id
            vertices[siblings[i]+1].request_id = req_id
            push!(requests, Request(req_id, vertices[i+1], vertices[siblings[i]+1]))
        end
    end
    A, cost, time = build_arcs(vertices, n, round_dists)
    DataPDPTW(n, requests, InputGraph(vertices, A, cost, time), Q, K)
end

function readRopkeData(path_file::String, round_dists::Bool)
    # STEP 1 : pushing data in a vector.
    data = Array{Any,1}()
    open(path_file) do file
        for line in eachline(file)
            for peaceofdata in split(line)
                push!(data, String(peaceofdata))
            end
        end
    end

    K = parse(Int, data[1])
    n = parse(Int, data[2])
    Q = parse(Float64, data[4])

    vertices = Vertex[]
    for i in 0:2*n
        offset = 5 + i * 7
        x = parse(Float64, data[offset+2])
        y = parse(Float64, data[offset+3])
        s = parse(Int, data[offset+4])
        d = parse(Int, data[offset+5])
        l = parse(Int, data[offset+6])
        u = parse(Int, data[offset+7])
        r = i > n ? i - n : i
        push!(vertices, Vertex(i, x, y, s, d, l, u, r))
    end

    requests = Request[]
    for i in 1:n
        push!(requests, Request(i, vertices[i+1], vertices[i+n+1]))
    end
    A, cost, time = build_arcs(vertices, n, round_dists)
    DataPDPTW(n, requests, InputGraph(vertices, A, cost, time), Q, K)
end

arcs(data::DataPDPTW) = data.G′.A # return set of arcs
function c(data, a)
    if !(haskey(data.G′.cost, a))
        return Inf
    end
    return data.G′.cost[a]
end
function t(data, a)
    if !(haskey(data.G′.time, a))
        return Inf
    end
    return data.G′.time[a]
end
n(data::DataPDPTW) = data.n # return number of requests
d(data::DataPDPTW, i) = data.G′.V′[i+1].demand # return demand of i
s(data::DataPDPTW, i) = data.G′.V′[i+1].service_time # return service time of i
l(data::DataPDPTW, i) = data.G′.V′[i+1].start_tw
u(data::DataPDPTW, i) = data.G′.V′[i+1].end_tw
r(data::DataPDPTW, i) = data.G′.V′[i+1].request_id
requests(data::DataPDPTW) = data.requests
veh_capacity(data::DataPDPTW) = Int(data.Q)

function sibling(data::DataPDPTW, i)
    if d(data, i) > 0
        data.requests[r(data, i)].delivery.id
    elseif d(data, i) < 0
        data.requests[r(data, i)].pickup.id
    else
        return 0
    end
end

function lowerBoundNbVehicles(data::DataPDPTW)
    return 1
end

function upperBoundNbVehicles(data::DataPDPTW)
    return data.K
end
