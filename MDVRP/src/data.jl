using Unicode: Unicode

mutable struct Vertex
    id_vertex::Int
    pos_x::Float64
    pos_y::Float64
    demand::Float64
end

# The instance has m depots (the first m vertices of the file) and n customers. The model has a single dummy depot,
# the vertex 0, and the customers 1..n (the customer i is the vertex i + m - 1 of the file).
mutable struct DataMDVRP
    V′::Vector{Vertex} # vertices of the file (access with id_vertex + 1)
    Q::Float64 # vehicle capacity
    n::Int # number of customers
    m::Int # number of depots
    round::Bool # Is the distance matrix rounded?
end

nb_customers(data::DataMDVRP) = data.n
customers(data::DataMDVRP) = 1:data.n
veh_capacity(data::DataMDVRP) = data.Q
vertex(data::DataMDVRP, i::Integer) = data.V′[i+data.m] # file vertex of the customer i
depots(data::DataMDVRP) = data.V′[1:data.m]
d(data::DataMDVRP, i) = i == 0 ? 0.0 : vertex(data, i).demand # demand of the customer i (0 for the dummy depot)
edges(data::DataMDVRP) = [(i, j) for i in 0:data.n for j in i+1:data.n] # set of edges of the model

# return incident edges of i
δ(data::DataMDVRP, i::Integer) = [(min(i, j), max(i, j)) for j in 0:data.n if j != i]

function euclidean(data::DataMDVRP, u::Vertex, v::Vertex)
    xSq = (v.pos_x - u.pos_x)^2
    ySq = (v.pos_y - u.pos_y)^2
    return data.round ? floor(sqrt(xSq + ySq) + 0.5) : sqrt(xSq + ySq)
end

# distance between the customers i and j
distance(data::DataMDVRP, i, j) = i == j ? 0.0 : euclidean(data, vertex(data, i), vertex(data, j))

# cost of a round trip from the depot k that serves the customer i first and the customer j last
depot_trip(data::DataMDVRP, k::Int, i, j) = euclidean(data, data.V′[k], vertex(data, i)) + euclidean(data, vertex(data, j), data.V′[k])

# cost of the cheapest round trip from a depot that serves the customer i first and the customer j last
C0(data::DataMDVRP, i, j) = minimum(depot_trip(data, k, i, j) for k in 1:data.m)

# tokens of the section `name` (up to the next section or the end of the file)
function section(tokens, name)
    i = findfirst(==(name), tokens)
    i === nothing && return nothing
    j = findnext(t -> endswith(t, "SECTION") || t == "EOF", tokens, i + 1)
    return tokens[i+1:(j === nothing ? length(tokens) : j - 1)]
end

# Cordeau's format: DIMENSION, CAPACITY, the coordinates and the demands of the vertices, and the depots. The depots
# have to be the first vertices (the types of problem of the file, such as MDOVRP, are not used: the routes are closed).
function readMDVRPData(app::Dict{String,Any})
    str = Unicode.normalize(read(app["instance"], String); stripcc = true)
    tokens = split(str, [' ', ':', '\n']; limit = 0, keepempty = false)

    dim = parse(Int, tokens[findfirst(==("DIMENSION"), tokens)+1])
    Q = parse(Float64, tokens[findfirst(==("CAPACITY"), tokens)+1])
    coords = section(tokens, "NODE_COORD_SECTION")
    dem = section(tokens, "DEMAND_SECTION")
    depot_section = section(tokens, "DEPOT_SECTION")
    depot_ids = [parse(Int, t) for t in depot_section if t != "-1"]
    m = length(depot_ids)
    depot_ids == collect(1:m) || error("The depots must be the first vertices of the instance")

    V′ = [Vertex(k - 1, parse(Float64, coords[3k-1]), parse(Float64, coords[3k]), 0.0) for k in 1:dim]
    for k in 1:dim
        V′[parse(Int, dem[2k-1])].demand = parse(Float64, dem[2k])
    end
    return DataMDVRP(V′, Q, dim - m, m, app["round"])
end
