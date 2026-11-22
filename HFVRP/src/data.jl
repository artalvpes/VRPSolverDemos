using Unicode: Unicode

mutable struct Vertex
    id_vertex::Int
    pos_x::Float64
    pos_y::Float64
    demand::Float64
end

# A type of vehicle: capacity, fixed cost, cost per unit of distance (the limits on the number of vehicles of the file
# are not used: the fleet is unlimited)
mutable struct VehicleType
    Q::Float64
    fixed::Float64
    factor::Float64
end

# Undirected complete graph: the cost of an edge is its Euclidean length times the cost per unit of distance of the vehicle
mutable struct DataHFVRP
    V′::Vector{Vertex} # set of vertices (access with id_vertex + 1), the depot is the vertex 0
    vehTypes::Vector{VehicleType} # sorted by capacity (and so by fixed cost and cost per unit of distance)
end

nb_customers(data::DataHFVRP) = length(data.V′) - 1
customers(data::DataHFVRP) = 1:nb_customers(data)
d(data::DataHFVRP, i) = data.V′[i+1].demand # demand of i (0 for the depot)
distance(data::DataHFVRP, i, j) =
    sqrt((data.V′[i+1].pos_x - data.V′[j+1].pos_x)^2 + (data.V′[i+1].pos_y - data.V′[j+1].pos_y)^2)
edges(data::DataHFVRP) = [(i, j) for i in 0:nb_customers(data) for j in i+1:nb_customers(data)] # set of edges

# return incident edges of i
δ(data::DataHFVRP, i::Integer) = [(min(i, j), max(i, j)) for j in 0:nb_customers(data) if j != i]

# Cost of a route with the given load and distance: the first (cheapest) type that carries the load is used.
# Nothing if no type carries it.
function route_type(data::DataHFVRP, load::Real)
    return findfirst(t -> load < t.Q + 1e-4, data.vehTypes)
end

function check_types(data::DataHFVRP)
    t = data.vehTypes
    length(t) <= 8 || error("At most 8 vehicle types are supported ($(length(t)) in the instance)")
    for k in 2:length(t)
        (t[k-1].Q < t[k].Q && t[k-1].fixed <= t[k].fixed && t[k-1].factor <= t[k].factor) ||
            error("The vehicle types must be sorted: larger capacity, and not smaller fixed cost and cost per distance")
    end
end

# Instances of Brandao (file name brandao*): n, then n + 1 lines `id x y`, n + 1 lines `id demand`, the number of types and
# a line `Q fixed factor l u` per type. Classic ones: n, n + 1 lines `id x y demand`, the number of types and the types.
function readHFVRPData(app::Dict{String,Any})
    raw = Float64[]
    for line in eachline(app["instance"])
        for token in split(line)
            push!(raw, parse(Float64, token))
        end
    end
    format = app["format"]
    format == "auto" && (format = startswith(basename(app["instance"]), "brandao") ? "brandao" : "classic")

    n = Int(raw[1])
    vertices = Vertex[]
    offset = 2
    if format == "brandao"
        for i in 0:n
            push!(vertices, Vertex(i, raw[offset+1], raw[offset+2], 0.0))
            offset += 3
        end
        for i in 0:n
            vertices[i+1].demand = raw[offset+1]
            offset += 2
        end
    else
        for i in 0:n
            push!(vertices, Vertex(i, raw[offset+1], raw[offset+2], raw[offset+3]))
            offset += 4
        end
    end

    nTypes = Int(raw[offset])
    types = VehicleType[]
    for k in 1:nTypes
        push!(types, VehicleType(raw[offset+1], raw[offset+2], raw[offset+3]))
        offset += 5
    end
    data = DataHFVRP(vertices, types)
    check_types(data)
    return data
end
