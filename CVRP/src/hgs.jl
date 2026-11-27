# Interface to HGS-CVRP (Vidal 2022, "Hybrid genetic search for the CVRP: open-source implementation and SWAP*
# neighborhood", https://github.com/vidalt/HGS-CVRP), through its C interface (C_Interface.h). It is used with the
# option --hgs instead of the heuristic of heuristic.jl. The shared library libhgscvrp is built from the HGS-CVRP
# sources with `cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --target lib`; its path is given by
# the environment variable HGS_CVRP_LIB.
#
# HGS receives the distance matrix of the demo (so that it optimizes exactly the cost of the model, with the same
# rounding), the coordinates when the instance has them (for its SWAP* neighbourhood), the demands, the capacity, the
# route duration limit with the service times, and the maximum number of routes. It does not impose a minimum number of
# routes: if it returns fewer than minr routes, the longest routes are split.

# The C structures, field by field (same types, hence the same alignment as in C)
struct HGSAlgorithmParameters
    nbGranular::Cint
    mu::Cint
    lambda::Cint
    nbElite::Cint
    nbClose::Cint
    nbIterPenaltyManagement::Cint
    targetFeasible::Cdouble
    penaltyDecrease::Cdouble
    penaltyIncrease::Cdouble
    seed::Cint
    nbIter::Cint
    nbIterTraces::Cint
    timeLimit::Cdouble
    useSwapStar::Cint
end

struct HGSSolutionRoute
    length::Cint
    path::Ptr{Cint}
end

struct HGSSolution
    cost::Cdouble
    time::Cdouble
    n_routes::Cint
    routes::Ptr{HGSSolutionRoute}
end

const HGS_HANDLE = Ref{Ptr{Cvoid}}(C_NULL)

# pointer to a function of the library given by HGS_CVRP_LIB (opened once)
function hgs_function(name::Symbol)
    if HGS_HANDLE[] == C_NULL
        lib = get(ENV, "HGS_CVRP_LIB", "")
        isempty(lib) && error("--hgs: set the environment variable HGS_CVRP_LIB to the path of libhgscvrp")
        isfile(lib) || error("--hgs: HGS_CVRP_LIB = $lib is not a file")
        HGS_HANDLE[] = Base.Libc.Libdl.dlopen(lib)
    end
    return Base.Libc.Libdl.dlsym(HGS_HANDLE[], name)
end

# Runs HGS-CVRP for the time limit (CPU seconds) and returns (routes, cost) as cvrp_heuristic, or (nothing, Inf).
function hgs_heuristic(data::DataCVRP, app::Dict{String,Any})
    n = nb_customers(data)
    n == 0 && return (nothing, Inf)
    N = n + 1 # nodes, the depot being node 0
    dist = Cdouble[distance(data, (i, j)) for j in 0:n, i in 0:n] # row-major: dist[N*i + j] is distance(i, j)
    dem = Cdouble[i == 0 ? 0.0 : d(data, i) for i in 0:n]
    D = max_dist(data)
    serv = Cdouble[(i == 0 || D <= 0) ? 0.0 : service_time(data) for i in 0:n]
    x = Cdouble[v.pos_x for v in data.G′.V′]
    y = Cdouble[v.pos_y for v in data.G′.V′]
    limit = something(get(app, "heur_time", nothing), min(20.0, 2.0 + 0.1 * n))
    ap0 = ccall(hgs_function(:default_algorithm_parameters), HGSAlgorithmParameters, ())
    ap = HGSAlgorithmParameters(ap0.nbGranular, ap0.mu, ap0.lambda, ap0.nbElite, ap0.nbClose,
                                ap0.nbIterPenaltyManagement, ap0.targetFeasible, ap0.penaltyDecrease,
                                ap0.penaltyIncrease, Cint(get(app, "heur_seed", 1)), ap0.nbIter, ap0.nbIterTraces,
                                Cdouble(limit), data.coord ? Cint(1) : Cint(0))
    maxr = min(app["maxr"], n)
    sol = ccall(hgs_function(:solve_cvrp_dist_mtx), Ptr{HGSSolution},
                (Cint, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Cdouble, Cdouble, Cchar,
                 Cint, Ref{HGSAlgorithmParameters}, Cchar),
                N, data.coord ? x : C_NULL, data.coord ? y : C_NULL, dist, serv, dem, veh_capacity(data),
                D > 0 ? D : 1e30, D > 0 ? Cchar(1) : Cchar(0), maxr, ap, Cchar(0))
    sol == C_NULL && return (nothing, Inf)
    s = unsafe_load(sol)
    routes = Vector{Int}[]
    for k in 1:s.n_routes
        r = unsafe_load(s.routes, k)
        push!(routes, Int[unsafe_load(r.path, p) for p in 1:r.length])
    end
    ccall(hgs_function(:delete_solution), Cvoid, (Ptr{HGSSolution},), sol)
    isempty(routes) && return (nothing, Inf)
    # too few routes: split the longest routes
    while length(routes) < app["minr"]
        k = argmax(length.(routes))
        length(routes[k]) < 2 && return (nothing, Inf)
        push!(routes, [pop!(routes[k])])
    end
    length(routes) <= app["maxr"] || return (nothing, Inf)
    return (routes, total_cost(data, routes))
end
