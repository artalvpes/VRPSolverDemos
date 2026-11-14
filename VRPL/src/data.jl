using Unicode: Unicode

# Instance of the VRP with lockers. The depot is the vertex 0, the lockers (delivery sites) are the vertices 1..S, and
# the customers are numbered 1..K. Two instance formats are read: the .vdap files of the VRPDA (Reihaneh and Ghoniem,
# 2019) and the .vrp files of CVRPLIB, whose last l nodes are taken as lockers.
mutable struct DataVRPL
    S::Int # number of lockers
    K::Int # number of customers
    Q::Float64 # vehicle capacity
    w::Vector{Float64} # w[c] is the demand of the customer c
    dist::Matrix{Float64} # dist[i+1, j+1] is the travel cost between the vertices i and j (0 is the depot)
    f::Matrix{Float64} # f[c, s] is the cost of assigning the customer c to the locker s
    depot_xy::Tuple{Float64,Float64} # coordinates of the depot
    locker_xy::Vector{Tuple{Float64,Float64}} # coordinates of the lockers
    customer_xy::Vector{Tuple{Float64,Float64}} # coordinates of the customers
    k::Int # each customer can only be assigned to one of its k nearest lockers
    cover::Vector{Vector{Int}} # cover[c] are the k nearest lockers of the customer c (in increasing distance)
end

lockers(data::DataVRPL) = 1:data.S
customers(data::DataVRPL) = 1:data.K
nb_lockers(data::DataVRPL) = data.S
nb_customers(data::DataVRPL) = data.K
veh_capacity(data::DataVRPL) = data.Q
w(data::DataVRPL, c) = data.w[c] # demand of the customer c
d(data::DataVRPL, i, j) = data.dist[i+1, j+1] # travel cost between the vertices i and j
f(data::DataVRPL, c, s) = data.f[c, s] # assignment cost of the customer c to the locker s
nb_nearest(data::DataVRPL) = data.k
covers(data::DataVRPL, s, c) = s in data.cover[c] # can the locker s serve the customer c?
covering_lockers(data::DataVRPL, c) = data.cover[c]
covered_customers(data::DataVRPL, s) = [c for c in customers(data) if covers(data, s, c)]

function customer_distance(data::DataVRPL, c1, c2)
    (x1, y1), (x2, y2) = data.customer_xy[c1], data.customer_xy[c2]
    return sqrt((x1 - x2)^2 + (y1 - y2)^2)
end

function lowerBoundNbVehicles(data::DataVRPL)
    return Int(ceil(sum(data.w) / data.Q))
end

# Reads a .vdap file. Sections (in this order): sNum, kNum, m, Lambda, Q, d (K demands), s2sDis ((S+1)x(S+1) matrix
# with the depot as the last row/column and 99999 on the diagonal), k2sDis (KxS matrix), Coordination of Sites (S lines
# "id x y") and Coordination of Customers (K lines "id x y"). The travel and assignment costs are the Euclidean
# distances between the coordinates, without rounding, with the depot at the origin (as in the generator of the
# instances). The matrices of the file (distances truncated to integers) are not used, and neither are the fields m
# (number of vehicles) and Lambda (0.5 in all files, i.e., routing and assignment costs have the same weight).
function readVRPLData(app::Dict{String,Any})
    return endswith(lowercase(app["instance"]), ".vrp") ? readCVRPLIBData(app) : readVDAPData(app)
end

euclid(p, q) = sqrt((p[1] - q[1])^2 + (p[2] - q[2])^2)

# builds the instance from the coordinates. Travel cost: Euclidean distance (rounded to the nearest integer if `rnd`).
# Assignment cost: `assign_factor` times the (rounded if `rnd`) Euclidean distance between the customer and the locker.
function build_data(app, Q, w, depot_xy, locker_xy, customer_xy, rnd::Bool, assign_factor::Float64)
    S, K = length(locker_xy), length(customer_xy)
    dist_fn(p, q) = rnd ? floor(euclid(p, q) + 0.5) : euclid(p, q)
    vertex_xy = vcat([depot_xy], locker_xy) # vertex 0 is the depot
    dist = [dist_fn(vertex_xy[i], vertex_xy[j]) for i in 1:S+1, j in 1:S+1]
    fmat = [assign_factor * dist_fn(customer_xy[c], locker_xy[s]) for c in 1:K, s in 1:S]

    k = app["nearest"]
    (k < 1) && error("The number of nearest lockers must be at least 1")
    k = min(k, S)
    # the k nearest lockers of each customer; ties are broken by the locker index, so the sets are deterministic
    cover = [sort(lockers_by_distance(fmat, c, S)[1:k]) for c in 1:K]
    return DataVRPL(S, K, Q, w, dist, fmat, depot_xy, locker_xy, customer_xy, k, cover)
end

contains(p, s) = findnext(s, p, 1) !== nothing

# Reads a CVRPLIB file (EUC_2D, NODE_COORD_SECTION and DEMAND_SECTION, as in the CVRP demo). The node 1 is the depot,
# the last l nodes (option --lockers) are the lockers (their demands are ignored) and the other nodes are the
# customers. The distances are the Euclidean distances, without rounding (with the rounding of CVRPLIB, ties between
# equivalent routes were frequent); the cost of assigning a customer to a locker is alpha (option --alpha, default 3:
# the customers are expected to walk little) times their distance. DISTANCE and SERVICE_TIME are ignored.
function readCVRPLIBData(app::Dict{String,Any})
    str = Unicode.normalize(read(app["instance"], String); stripcc=true)
    aux = split(str, [' ', ':', '\n', '\t', '\r']; limit=0, keepempty=false)
    Q = 0.0
    xy = Tuple{Float64,Float64}[]
    dem = Float64[]
    for i in 1:length(aux)
        if contains(aux[i], "CAPACITY")
            Q = parse(Float64, aux[i+1])
        elseif contains(aux[i], "NODE_COORD_SECTION")
            j = i + 1
            while aux[j] != "DEMAND_SECTION"
                push!(xy, (parse(Float64, aux[j+1]), parse(Float64, aux[j+2])))
                j += 3
            end
            dem = zeros(length(xy))
        elseif contains(aux[i], "DEMAND_SECTION")
            j = i + 1
            while aux[j] != "DEPOT_SECTION"
                dem[parse(Int, aux[j])] = parse(Float64, aux[j+1])
                j += 2
            end
            break
        end
    end
    n = length(xy) # nodes 1..n, the node 1 is the depot
    l = app["lockers"]
    (l < 1 || l > n - 2) && error("The number of lockers must be in [1, $(n - 2)] for this instance ($n nodes)")
    customer_nodes = 2:n-l
    locker_nodes = n-l+1:n
    alpha = (get(app, "alpha", nothing) === nothing) ? 3.0 : app["alpha"]
    return build_data(app, Q, dem[customer_nodes], xy[1], xy[locker_nodes], xy[customer_nodes], false, alpha)
end

function readVDAPData(app::Dict{String,Any})
    str = Unicode.normalize(read(app["instance"], String); stripcc=true)
    aux = split(str, [' ', '\t', '\n', '\r']; keepempty=false)

    pos = Dict{String,Int}() # position of the token that follows each keyword
    for (i, tok) in enumerate(aux)
        if tok in ("sNum:", "kNum:", "Q:", "d:")
            pos[rstrip(tok, ':')] = i + 1
        elseif tok == "Sites:" || tok == "Customers:"
            pos[tok] = i + 1
        end
    end
    for key in ("sNum", "kNum", "Q", "d", "Sites:", "Customers:")
        haskey(pos, key) || error("Section $key not found in $(app["instance"])")
    end
    num(i) = parse(Float64, aux[i])

    S = parse(Int, aux[pos["sNum"]])
    K = parse(Int, aux[pos["kNum"]])
    Q = num(pos["Q"])
    w = [num(pos["d"] + c - 1) for c in 1:K]

    locker_xy = [(num(pos["Sites:"] + 3 * (s - 1) + 1), num(pos["Sites:"] + 3 * (s - 1) + 2)) for s in 1:S]
    customer_xy = [(num(pos["Customers:"] + 3 * (c - 1) + 1), num(pos["Customers:"] + 3 * (c - 1) + 2)) for c in 1:K]

    # the depot is at the origin, as in the generator of the instances
    alpha = (get(app, "alpha", nothing) === nothing) ? 1.0 : app["alpha"]
    return build_data(app, Q, w, (0.0, 0.0), locker_xy, customer_xy, false, alpha)
end

lockers_by_distance(fmat, c, S) = sort(1:S, by=s -> (fmat[c, s], s))

function print_coverage(data::DataVRPL)
    S, K = nb_lockers(data), nb_customers(data)
    per_locker = [length(covered_customers(data, s)) for s in lockers(data)]
    println("Instance: $S lockers, $K customers, Q = $(data.Q), total demand = $(sum(data.w))")
    println(
        "Coverage: each customer can be assigned to its $(data.k) nearest lockers. Customers covered per locker: " *
        "average $(round(sum(per_locker) / S, digits=2)) ($(round(100 * sum(per_locker) / (S * K), digits=1))% of $K), " *
        "min $(minimum(per_locker)), max $(maximum(per_locker)).",
    )
    flush(stdout)
end
