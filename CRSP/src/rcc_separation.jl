# Exact separation of the strengthened rounded capacity cuts of Section 6.4.9:
#
#   Σ_{e∈δ(S′)} x_e + 2 Σ_{i∉S′} Σ_{B⊆T(i): B∩S′≠∅} w_iB ≥ 2⌈d(S′)/W⌉,   S′ ⊆ S ∪ T
#
# by a MIP similar to the one in Section 3.3 of Fukasawa, Poggi de Aragão, Reis and Uchoa,
# "Robust Branch-and-Cut-and-Price for the Capacitated Vehicle Routing Problem", RPEP 3(8), 2003.
# For each M ∈ {1, ..., ⌈d(T)/W⌉ - 1}, it finds a set S′ (y_i = 1 iff i ∈ S′) with d(S′) ≥ M·W + 1
# minimizing the left-hand side. If its value is below 2(M+1), the cut over S′ is violated.

const RCC_EPS = 1e-6 # values below it are considered zero
const RCC_VIOL_TOL = 1e-4 # minimum violation of a separated cut

struct RCCut
    S′::Vector{Int} # points in the cut set
    edges::Vector{Tuple{Int,Int}} # edges in δ(S′) (coefficient 1 on x)
    stars::Vector{Tuple{Int,Int}} # keys (i,s) of the star arcs leaving S′ (coefficient 2 on w)
    rhs::Float64
end

# keys (i, s) of the w variables, where s is the index of the star in stars[i]
w_keys(stars::Dict{Int,Vector{Vector{Int}}}) = [(i, s) for i in sort(collect(keys(stars))) for s in 1:length(stars[i])]

# builds the complete cut over S′ (not only over the support of the current solution)
function build_rcc(data::DataCRSP, stars::Dict{Int,Vector{Vector{Int}}}, S′::Vector{Int})
    in_S = Set(S′)
    cut_edges = [e for e in edges(data) if (e[1] in in_S) != (e[2] in in_S)]
    cut_stars = [(i, s) for (i, s) in w_keys(stars) if !(i in in_S) && any(j -> j in in_S, stars[i][s])]
    rhs = 2 * ceil(sum(d(data, j) for j in S′; init=0.0) / capacity(data))
    return RCCut(sort(S′), cut_edges, cut_stars, rhs)
end

rcc_lhs(cut::RCCut, xbar, wbar) =
    sum(get(xbar, e, 0.0) for e in cut.edges; init=0.0) + 2 * sum(get(wbar, k, 0.0) for k in cut.stars; init=0.0)

# returns the violated cuts for the solution (xbar, wbar)
function separate_rcc(data::DataCRSP, stars::Dict{Int,Vector{Vector{Int}}},
    xbar::Dict{Tuple{Int,Int},Float64}, wbar::Dict{Tuple{Int,Int},Float64})

    W, T, V⁺ = capacity(data), terminals(data), points(data)
    cuts = RCCut[]
    max_M = Int(ceil(sum(d(data, j) for j in T) / W)) - 1
    max_M < 1 && return cuts

    sup_e = [e for (e, val) in xbar if val > RCC_EPS] # support edges
    sup_w = [k for (k, val) in wbar if val > RCC_EPS] # support star arcs

    mip = Model(CPLEX.Optimizer)
    set_silent(mip)
    set_attribute(mip, "CPXPARAM_Threads", 1)
    @variable(mip, y[i in V⁺], Bin) # y_0 = 0 (root is never in S′)
    @variable(mip, u[e in sup_e] >= 0) # u_e = 1 if e ∈ δ(S′)
    @variable(mip, s[k in sup_w] >= 0) # s_iB = 1 if i ∉ S′ and B ∩ S′ ≠ ∅
    for (i, j) in sup_e
        if i == 0
            @constraint(mip, u[(i, j)] >= y[j])
        else
            @constraint(mip, u[(i, j)] >= y[i] - y[j])
            @constraint(mip, u[(i, j)] >= y[j] - y[i])
        end
    end
    for (i, sid) in sup_w, j in stars[i][sid]
        @constraint(mip, s[(i, sid)] >= y[j] - y[i])
    end
    @objective(mip, Min, sum(xbar[e] * u[e] for e in sup_e) + 2 * sum(wbar[k] * s[k] for k in sup_w))
    @constraint(mip, cap, sum(d(data, j) * y[j] for j in T) >= 0)

    found = Set{Vector{Int}}()
    for M in 1:max_M
        set_normalized_rhs(cap, M * W + 1)
        optimize!(mip)
        is_solved_and_feasible(mip) || continue
        if objective_value(mip) < 2 * (M + 1) - RCC_VIOL_TOL
            S′ = sort([i for i in V⁺ if value(y[i]) > 0.5])
            (S′ in found) && continue
            push!(found, S′)
            cut = build_rcc(data, stars, S′)
            if rcc_lhs(cut, xbar, wbar) < cut.rhs - RCC_VIOL_TOL
                push!(cuts, cut)
            end
        end
    end
    return cuts
end
