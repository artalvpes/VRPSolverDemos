using Unicode: Unicode

mutable struct Vertex
    id_vertex::Int
    pos_x::Float64
    pos_y::Float64
    demand::Float64
end

# Undirected complete graph G = (V, E), V = {0} ∪ S ∪ T
mutable struct InputGraph
    V::Vector{Vertex} # set of vertices (access with id_vertex + 1)
    E::Vector{Tuple{Int64,Int64}} # set of edges
    cost::Dict{Tuple{Int64,Int64},Float64} # ring installation cost for each edge
end

mutable struct DataCRSP
    G::InputGraph
    W::Float64 # ring-star capacity
    root_id::Int
    S::Vector{Int} # Steiner points
    T::Vector{Int} # terminals
    stars::Vector{Vector{Int}} # stars[i+1] = T(i), possible star connections of point i
    star_cost_factor::Float64 # b_ij = star_cost_factor * (euclidian distance between i and j)
    coord::Bool # instance with NODE_COORD_SECTION
    round::Bool # Is the distance matrix rounded?
end

# Euclidian distance
function distance(data::DataCRSP, arc::Tuple{Int64,Int64})
    e = (arc[1] < arc[2]) ? arc : (arc[2], arc[1])
    if haskey(data.G.cost, e) # use already calculated value
        return data.G.cost[e]
    elseif data.coord
        dist = euclidian(data, arc)
        return data.round ? floor(dist + 0.5) : dist
    else
        return 0.0
    end
end

function euclidian(data::DataCRSP, arc::Tuple{Int64,Int64})
    u, v = arc
    vertices = data.G.V
    # array <vertices> is indexed from 1 (root is vertices[1], vertex 1 is vertices[2], and so on)
    x_sq = (vertices[v+1].pos_x - vertices[u+1].pos_x)^2
    y_sq = (vertices[v+1].pos_y - vertices[u+1].pos_y)^2
    return sqrt(x_sq + y_sq)
end

contains(p, s) = findnext(s, p, 1) !== nothing

# Builds a CRSP instance from a CVRP instance (CVRPLIB format):
#  - the depot becomes the root 0;
#  - the first round(steiner_pct% * n) non-root vertices become Steiner points (demand 0),
#    the remaining ones become terminals (keeping their CVRP demands);
#  - the vehicle capacity becomes the ring-star capacity W;
#  - T(i), for each i ∈ S ∪ T, is the set of the star_size terminals closest to i;
#  - ring installation costs are given by the distances, while star connection costs are
#    cheaper: b_ij = star_cost_factor * distance(i,j).
function readCRSPData(app::Dict{String,Any})
    str = Unicode.normalize(read(app["instance"], String); stripcc=true)
    breaks_in = [' '; ':'; '\n']
    aux = split(str, breaks_in; limit=0, keepempty=false)

    (0.0 <= app["star_cost_factor"] <= 1.0) || error("--star_cost_factor must be in [0,1]")
    G = InputGraph([], [], Dict())
    data = DataCRSP(G, 0, 0, Int[], Int[], Vector{Int}[], app["star_cost_factor"], false, !app["noround"])

    for i in 1:length(aux)
        if contains(aux[i], "CAPACITY")
            data.W = parse(Float64, aux[i+1])
        elseif contains(aux[i], "NODE_COORD_SECTION")
            data.coord = true
            j = i + 1
            while aux[j] != "DEMAND_SECTION"
                v = Vertex(0, 0, 0, 0)
                v.id_vertex = parse(Int, aux[j]) - 1 # root is forced to be 0, first point to be 1, and so on
                v.pos_x = parse(Float64, aux[j+1])
                v.pos_y = parse(Float64, aux[j+2])
                push!(G.V, v) # add v in the vertex array
                j += 3
            end
        elseif contains(aux[i], "DEMAND_SECTION")
            j = i + 1
            while aux[j] != "DEPOT_SECTION"
                pos = parse(Int, aux[j])
                G.V[pos].demand = parse(Float64, aux[j+1])
                j += 2
            end
            data.root_id = 0
            break
        end
    end
    !data.coord && error("The CRSP instance builder requires a NODE_COORD_SECTION")

    # partition the non-root vertices into Steiner points and terminals
    n = length(G.V) - 1
    (0.0 <= app["steiner_pct"] <= 100.0) || error("--steiner_pct must be in [0,100]")
    nS = round(Int, app["steiner_pct"] * n / 100)
    data.S = collect(1:nS)
    data.T = collect((nS+1):n)
    isempty(data.T) && error("The instance has no terminals (steiner_pct = $(app["steiner_pct"]))")
    for i in data.S
        G.V[i+1].demand = 0.0 # d_i = 0 for Steiner points
    end

    # E = {{i,j} : i,j ∈ V, i < j}
    for i in 0:n, j in (i+1):n
        e = (i, j)
        push!(G.E, e)
        G.cost[e] = distance(data, e)
    end

    # T(i): the star_size closest terminals to i (ties broken by vertex id)
    k = app["star_size"]
    k < 0 && error("--star_size must be non-negative")
    data.stars = [Int[] for _ in 0:n]
    for i in 1:n
        candidates = sort(filter(j -> j != i, data.T); by=j -> (distance(data, (i, j)), j))
        data.stars[i+1] = sort(candidates[1:min(k, length(candidates))])
    end

    return data
end

edges(data::DataCRSP) = data.G.E # return set of edges
c(data::DataCRSP, e) = data.G.cost[e] # ring installation cost of the edge e
# cost of connecting terminal j to the ring point i
function b(data::DataCRSP, i, j)
    cost = data.star_cost_factor * euclidian(data, (i, j))
    return data.round ? floor(cost + 0.5) : cost
end
dimension(data::DataCRSP) = length(data.G.V) # return number of vertices
d(data::DataCRSP, i) = data.G.V[i+1].demand # return demand of i
capacity(data::DataCRSP) = data.W
steiner_points(data::DataCRSP) = data.S
terminals(data::DataCRSP) = data.T
points(data::DataCRSP) = vcat(data.S, data.T) # S ∪ T
star_set(data::DataCRSP, i) = data.stars[i+1] # T(i)
d(data::DataCRSP, i, B) = d(data, i) + sum(d(data, j) for j in B; init=0.0) # d(i,B)

# all stars B ⊆ T(i) such that 0 < d(i,B) <= W
function feasible_stars(data::DataCRSP, i)
    Ti = star_set(data, i)
    stars = Vector{Int}[]
    for mask in 0:(2^length(Ti)-1)
        B = [Ti[p] for p in 1:length(Ti) if (mask >> (p - 1)) & 1 == 1]
        dB = d(data, i, B)
        (0.0 < dB <= capacity(data)) && push!(stars, B)
    end
    return stars
end

function lowerBoundNbRingStars(data::DataCRSP)
    return Int(ceil(sum(d(data, i) for i in terminals(data)) / capacity(data)))
end

# return incident edges of i
function δ(data::DataCRSP, i::Integer)
    incident_edges = Vector{Tuple}()
    for j in 0:i-1
        push!(incident_edges, (j, i))
    end
    for j in i+1:(length(data.G.V)-1)
        push!(incident_edges, (i, j))
    end
    return incident_edges
end

function print_instance(data::DataCRSP)
    S, T = steiner_points(data), terminals(data)
    println("CRSP instance: |V| = $(dimension(data)), |S| = $(length(S)), |T| = $(length(T)), " *
            "W = $(capacity(data)), total demand = $(sum(d(data, j) for j in T)), " *
            "star cost factor = $(data.star_cost_factor)")
    println("Steiner points: $(S)")
    num_star_arcs = 0
    for i in points(data)
        nb = length(feasible_stars(data, i))
        num_star_arcs += nb
        println("  T($i) = $(star_set(data, i)), b = $([b(data, i, j) for j in star_set(data, i)])  " *
                "($(i in S ? "Steiner" : "terminal, d = $(d(data, i))"), $nb feasible stars)")
    end
    println("Total number of star arcs: $num_star_arcs")
    flush(stdout)
end
