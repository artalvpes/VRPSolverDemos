mutable struct Vertex
    id_vertex::Int
    pickup::Float64
    delivery::Float64
end

# Directed complete graph: the cost of the arc (i, j) is the entry (i, j) of the matrix of the instance
mutable struct DataVRPSPD
    V′::Vector{Vertex} # set of vertices (access with id_vertex + 1), the depot is the vertex 0
    cost::Dict{Tuple{Int64,Int64},Float64}
    Q::Float64 # vehicle capacity
end

nb_customers(data::DataVRPSPD) = length(data.V′) - 1
customers(data::DataVRPSPD) = 1:nb_customers(data)
pickup(data::DataVRPSPD, i) = data.V′[i+1].pickup # pickup demand of i (0 for the depot)
delivery(data::DataVRPSPD, i) = data.V′[i+1].delivery # delivery demand of i (0 for the depot)
distance(data::DataVRPSPD, i, j) = i == j ? 0.0 : data.cost[(i, j)]
veh_capacity(data::DataVRPSPD) = data.Q
arcs(data::DataVRPSPD) = [(i, j) for i in 0:nb_customers(data) for j in 0:nb_customers(data) if i != j]

# Format of the instances (see data/README.txt): the vehicle capacity, the number n of customers, the matrix of the
# distances (n + 1 rows, the depot is the first), and the delivery and the pickup demands of each customer.
function readVRPSPDData(app::Dict{String,Any})
    aux = split(read(app["instance"], String), [' ', '\n', '\t', '\r']; limit = 0, keepempty = false)
    Q = parse(Float64, aux[1])
    n = parse(Int, aux[2])
    data = DataVRPSPD([Vertex(0, 0.0, 0.0)], Dict(), Q)
    pos = 3
    for i in 0:n, j in 0:n
        i != j && (data.cost[(i, j)] = parse(Float64, aux[pos]))
        pos += 1
    end
    for i in 1:n
        push!(data.V′, Vertex(i, parse(Float64, aux[pos+1]), parse(Float64, aux[pos])))
        pos += 2
    end
    return data
end
