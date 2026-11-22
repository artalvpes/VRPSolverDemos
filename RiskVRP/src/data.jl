using Unicode: Unicode

mutable struct Vertex
    id_vertex::Int
    pos_x::Float64
    pos_y::Float64
    demand::Float64
end

# Directed complete graph: the cost of the arc (i, j) is the distance from i to j
mutable struct DataRiskVRP
    V′::Vector{Vertex} # set of vertices (access with id_vertex + 1), the depot is the vertex 0
    cost::Dict{Tuple{Int64,Int64},Float64}
    T::Float64 # maximum risk of a route
    coord::Bool # instance with NODE_COORD_SECTION
end

nb_customers(data::DataRiskVRP) = length(data.V′) - 1
customers(data::DataRiskVRP) = 1:nb_customers(data)
d(data::DataRiskVRP, i) = data.V′[i+1].demand # demand of i (0 for the depot)
distance(data::DataRiskVRP, i, j) = i == j ? 0.0 : data.cost[(i, j)]
risk_threshold(data::DataRiskVRP) = data.T
arcs(data::DataRiskVRP) = [(i, j) for i in 0:nb_customers(data) for j in 0:nb_customers(data) if i != j]

# tokens of the section `name` (up to the next section or the end of the file)
function section(tokens, name)
    i = findfirst(==(name), tokens)
    i === nothing && return nothing
    j = findnext(t -> endswith(t, "SECTION") || t == "EOF", tokens, i + 1)
    return tokens[i+1:(j === nothing ? length(tokens) : j - 1)]
end

function header(tokens, key)
    i = findfirst(==(key), tokens)
    return i === nothing ? nothing : tokens[i+1]
end

# The instances have either the coordinates of the vertices or the matrix of the distances (EXPLICIT / FULL_MATRIX).
# The distance of the coordinates is the Euclidean one, not rounded.
function readRiskData(app::Dict{String,Any})
    str = Unicode.normalize(read(app["instance"], String); stripcc = true)
    tokens = split(str, [' ', ':', '\n']; limit = 0, keepempty = false)

    dim = parse(Int, header(tokens, "DIMENSION"))
    data = DataRiskVRP([], Dict(), parse(Float64, header(tokens, "RISK_THRESHOLD")), false)

    coords = section(tokens, "NODE_COORD_SECTION")
    data.coord = coords !== nothing
    for k in 1:dim
        x, y = data.coord ? (parse(Float64, coords[3k-1]), parse(Float64, coords[3k])) : (0.0, 0.0)
        push!(data.V′, Vertex(k - 1, x, y, 0.0))
    end
    dem = section(tokens, "DEMAND_SECTION")
    for k in 1:dim
        data.V′[parse(Int, dem[2k-1])].demand = parse(Float64, dem[2k])
    end

    if data.coord
        for i in 0:dim-1, j in 0:dim-1
            i == j && continue
            u, v = data.V′[i+1], data.V′[j+1]
            data.cost[(i, j)] = sqrt((v.pos_x - u.pos_x)^2 + (v.pos_y - u.pos_y)^2)
        end
    else
        matrix = section(tokens, "EDGE_WEIGHT_SECTION")
        for i in 0:dim-1, j in 0:dim-1
            i != j && (data.cost[(i, j)] = parse(Float64, matrix[i*dim+j+1]))
        end
    end
    return data
end
