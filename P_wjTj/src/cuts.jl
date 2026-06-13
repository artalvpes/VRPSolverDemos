# ECC (Extended Capacity Cut) separator for P||∑w_j T_j
# Translated from CutGenerator.cpp and roundEccSep.cpp

const ECC_VIOLATED_EPS = 0.05
const ECC_CONNECT_EPS = 0.01
const COL_EXPAND_EPS = 1e-6
const MAX_CAP_HECC = 3000
const ECC_CHECK_EPS = 1e-4

# Fractional part in [0,1) that handles negative numerators correctly.
function eccfrac(num::Int64, den::Int)::Float64
    den == 0 && error("eccfrac: den=0")
    d = div(num, den)
    d * den == num && return 0.0
    return num > 0 ? Float64(num) / den - d : Float64(num) / den - d + 1.0
end

# One entry of the reversed LpSolution used for cut separation.
# Arcs are REVERSED relative to the original P_wjTj graph so that:
#   incapcoeff applies to arcs entering S  (i∉S, j∈S in cut-sep notation
#                                           = original arc from outside S to inside S)
#   outcapcoeff applies to arcs leaving S
# Mapping from original P_wjTj arc (u→v) to reversed cut-sep arc (i,j,d):
#   type-1 (source→job_j):          i=job_j,  j=0,     d=0
#   type-2 (job_i at t_i→job_j):    i=job_j,  j=job_i, d=t_i
#   type-3 (job_j at t_j→sink):     i=0,      j=job_j, d=t_j
struct LpArcCap
    i::Int                      # tail job (0 = source/sink)
    j::Int                      # head job (0 = source/sink)
    d::Int                      # remaining demand index (completion time in original)
    val::Float64                # current LP value
    orig::Tuple{Int64,Int64}    # original (u,v) node-ID pair → x[(u,v)]
end

function build_lpsol(x, A,
    node_to_job::Dict{Int,Int}, id_to_t::Dict{Int,Int})
    arcs_cap = LpArcCap[]
    for (u, v) in A
        val = value(x[(u, v)])
        val < 1e-8 && continue
        push!(arcs_cap, LpArcCap(
            node_to_job[v], node_to_job[u], id_to_t[u], val, (u, v)))
    end
    return arcs_cap
end

# --- RationalMap helpers (Dict keyed by Julia Rational{Int}) -------------

function rmap_update!(rmap::Dict{Rational{Int},Float64},
    numer::Int, denom::Int, delta::Float64)
    denom == 0 && return
    r = Rational{Int}(numer, denom)   # Julia normalises automatically
    v = get(rmap, r, 0.0) + delta
    if abs(v) < COL_EXPAND_EPS
        delete!(rmap, r)
    else
        rmap[r] = v
    end
end

# --- RECC_DoRoundings translation ----------------------------------------

mutable struct YZChange
    demY::Vector{Int}
    valY::Vector{Float64}
    demZ::Vector{Int}
    valZ::Vector{Float64}
    prevSetDem::Int
end

function recc_do_roundings!(chg::YZChange,
    inc_before::Dict{Rational{Int},Float64},
    inc_after::Dict{Rational{Int},Float64},
    cap::Int, set_demand::Int,
    best_num::Ref{Int}, best_den::Ref{Int})

    # Update inc_after: remove prevSetDem RHS contribution, add set_demand
    for i in 0:(chg.prevSetDem-1)
        i * cap > chg.prevSetDem * MAX_CAP_HECC && break
        rmap_update!(inc_after, i, chg.prevSetDem, 1.0)
    end
    for i in 0:(set_demand-1)
        i * cap > set_demand * MAX_CAP_HECC && break
        rmap_update!(inc_after, i, set_demand, -1.0)
    end

    # Update inc_after for y variables (arcs with both endpoints status changing)
    for idx in eachindex(chg.demY)
        q = chg.demY[idx]
        for i in 0:(q-1)
            i * cap > q * MAX_CAP_HECC && break
            rmap_update!(inc_after, i, q, chg.valY[idx])
        end
    end

    # Update inc_before for z variables (crossing arcs)
    for idx in eachindex(chg.demZ)
        q = chg.demZ[idx]
        for i in 1:(q-1)
            i * cap > q * MAX_CAP_HECC && break
            rmap_update!(inc_before, i, q, -chg.valZ[idx])
        end
    end

    # Find best multiplier via merge of two sorted rational maps.
    # inc_before entries are evaluated just before their key (left limit).
    # inc_after entries are evaluated just after their key (right limit).
    sb = sort!(collect(inc_before), by=p -> p[1])
    sa = sort!(collect(inc_after), by=p -> p[1])

    lhs = 0.0
    ib, ia = 1, 1
    best_num[] = 0
    best_den[] = 1
    best_viol = -2.0 * cap

    while ib <= length(sb) || ia <= length(sa)
        use_before = false
        use_after = false
        if ib <= length(sb) && ia <= length(sa)
            rb, ra = sb[ib][1], sa[ia][1]
            m1 = Int64(rb.num) * Int64(ra.den)
            m2 = Int64(ra.num) * Int64(rb.den)
            use_before = (m1 <= m2)
            use_after = (m2 <= m1)
        elseif ib <= length(sb)
            use_before = true
        else
            use_after = true
        end

        if use_before
            r, delta = sb[ib]
            ib += 1
            lhs += delta
            viol = -lhs
            if viol > best_viol
                best_viol = viol
                best_num[] = r.num
                best_den[] = r.den
            end
        end

        if use_after
            r, delta = sa[ia]
            ia += 1
            lhs += delta
            # Step just past this multiplier by adding a small fraction
            max_den2 = max(cap, set_demand)
            i_step = div(Int64(cap) * Int64(max_den2), Int64(r.den)) + 1
            num2 = r.num * i_step + 1
            den2 = r.den * i_step
            viol = -lhs
            if viol > best_viol
                best_viol = viol
                best_num[] = num2
                best_den[] = den2
            end
        end
    end
end

# --- genSingleECCCut translation -----------------------------------------

struct ECCCut
    S::BitVector                 # S[j+1] for job j=0..n; S[1]=false always (source)
    cap::Int
    incapcoeff::Vector{Float64}  # [d+1] for d=0..cap; coefficient for arcs entering S
    outcapcoeff::Vector{Float64} # [d+1]; coefficient for arcs leaving S
    rhs::Float64
    violation::Float64           # rhs - lhs (positive means violated)
end

function gen_single_ecc_cut(arcs_cap::Vector{LpArcCap},
    num::Int, den::Int, set_list::Vector{Int},
    n::Int, cap::Int, demands::Vector{Int},
    min_violation::Float64)
    # Returns (violated::Bool, cut::ECCCut)

    S = falses(n + 1)
    demand = 0
    for jb in set_list
        S[jb+1] = true
        demand += demands[jb+1]
    end

    rhs_frac = eccfrac(Int64(demand) * Int64(num), den)
    rhs_val = rhs_frac > 0.0 ? 1.0 - rhs_frac : 0.0

    incapcoeff = Vector{Float64}(undef, cap + 1)
    outcapcoeff = Vector{Float64}(undef, cap + 1)
    for d in 0:cap
        f = eccfrac(Int64(d) * Int64(num), den)
        incapcoeff[d+1] = f == 0.0 ? 0.0 : 1.0 - f
        f = eccfrac(-Int64(d) * Int64(num), den)
        outcapcoeff[d+1] = f == 0.0 ? 0.0 : 1.0 - f
    end

    lhs = 0.0
    for ac in arcs_cap
        ac.d > cap && continue
        if !S[ac.i+1] && S[ac.j+1]
            lhs += incapcoeff[ac.d+1] * ac.val
        elseif S[ac.i+1] && !S[ac.j+1]
            lhs += outcapcoeff[ac.d+1] * ac.val
        end
    end

    violation = rhs_val - lhs
    return violation > min_violation, ECCCut(S, cap, incapcoeff, outcapcoeff, rhs_val, violation)
end

# --- extCapCutGenByHeur translation --------------------------------------

function ext_cap_cut_gen_by_heur!(arcs_cap::Vector{LpArcCap},
    n::Int, cap::Int, demands::Vector{Int},
    cut_batch::Int, next_ecc_vertex::Ref{Int})
    # Returns Vector{ECCCut} of violated cuts.

    # Symmetric adjacency list over non-source jobs (1..n)
    adj_vertex = [Int[] for _ in 1:n]
    adj_value = [Float64[] for _ in 1:n]
    for ac in arcs_cap
        ac.val < ECC_CONNECT_EPS && continue
        i, j = ac.i, ac.j
        (i == 0 || j == 0) && continue
        pos = findfirst(==(j), adj_vertex[i])
        if pos === nothing
            push!(adj_vertex[i], j)
            push!(adj_value[i], ac.val)
        else
            adj_value[i][pos] += ac.val
        end
        pos = findfirst(==(i), adj_vertex[j])
        if pos === nothing
            push!(adj_vertex[j], i)
            push!(adj_value[j], ac.val)
        else
            adj_value[j][pos] += ac.val
        end
    end

    # Capacitated-arc adjacency for all nodes 0..n (Julia index j+1)
    adj_cap_arcs = [Int[] for _ in 0:n]
    for (k, ac) in enumerate(arcs_cap)
        push!(adj_cap_arcs[ac.i+1], k)
        push!(adj_cap_arcs[ac.j+1], k)
    end

    cuts = ECCCut[]
    seen_sets = Set{BitVector}()

    for _ in 1:n
        v = next_ecc_vertex[]
        next_ecc_vertex[] = (v % n) + 1    # cycles through 1..n

        in_set = falses(n + 1)
        in_set[v+1] = true
        vertex_set = [v]
        candidates = copy(adj_vertex[v])
        last_vertex = v
        set_demand = demands[v+1]

        inc_before = Dict{Rational{Int},Float64}()
        inc_after = Dict{Rational{Int},Float64}()
        best_num = Ref(0)
        best_den = Ref(1)

        while true
            # Build YZChange for last_vertex having just been added to S
            chg = YZChange(Int[], Float64[], Int[], Float64[],
                set_demand - demands[last_vertex+1])
            for k in adj_cap_arcs[last_vertex+1]
                ac = arcs_cap[k]
                if ac.i == last_vertex
                    if in_set[ac.j+1]
                        push!(chg.demY, ac.d)
                        push!(chg.valY, -ac.val)
                    else
                        push!(chg.demZ, ac.d)
                        push!(chg.valZ, ac.val)
                    end
                elseif ac.j == last_vertex
                    if in_set[ac.i+1]
                        push!(chg.demZ, ac.d)
                        push!(chg.valZ, -ac.val)
                    else
                        push!(chg.demY, ac.d)
                        push!(chg.valY, ac.val)
                    end
                end
            end

            recc_do_roundings!(chg, inc_before, inc_after,
                cap, set_demand, best_num, best_den)

            # Evaluate cut for the current set
            violated, cut = gen_single_ecc_cut(arcs_cap, best_num[], best_den[],
                vertex_set, n, cap, demands, ECC_VIOLATED_EPS)
            push!(seen_sets, copy(in_set))
            if violated
                # println("ECC violation=$(round(cut.violation,digits=4)), ",
                #     "r=$(best_num[])/$(best_den[]), S=$vertex_set")
                push!(cuts, cut)
                length(cuts) >= cut_batch && return cuts
            end

            # Find best candidate to add to S
            best_cand = 0
            best_pos = -1
            best_viol_c = -2.0 * (cap + length(vertex_set))

            for k in eachindex(candidates)
                ci = candidates[k]
                in_set[ci+1] = true
                if copy(in_set) in seen_sets
                    in_set[ci+1] = false
                    continue
                end

                set_demand += demands[ci+1]
                push!(vertex_set, ci)
                _, trial = gen_single_ecc_cut(arcs_cap, best_num[], best_den[],
                    vertex_set, n, cap, demands, 1.1)    # 1.1: never kept
                viol = trial.violation
                if viol < 0.0
                    viol = -2.0 * length(vertex_set)
                    for kk in eachindex(adj_vertex[ci])
                        in_set[adj_vertex[ci][kk]+1] && (viol += adj_value[ci][kk])
                    end
                end

                if viol > best_viol_c
                    best_viol_c = viol
                    best_cand = ci
                    best_pos = k
                end

                in_set[ci+1] = false
                set_demand -= demands[ci+1]
                pop!(vertex_set)
            end

            best_cand == 0 && break

            # Remove best_cand from candidates; add its new neighbours
            if best_pos < length(candidates)
                candidates[best_pos] = candidates[end]
            end
            pop!(candidates)
            for nb in adj_vertex[best_cand]
                !in_set[nb+1] && !(nb in candidates) && push!(candidates, nb)
            end
            in_set[best_cand+1] = true
            set_demand += demands[best_cand+1]
            push!(vertex_set, best_cand)
            last_vertex = best_cand
        end
    end

    return cuts
end

# --- Cut violation cross-check -------------------------------------------

# Recompute the cut's LHS straight from the LP via value() on the assembled
# (vars, coeffs), independent of arcs_cap / build_lpsol, and confirm it agrees
# with the violation reported by the separator. Errors out on disagreement.
function check_ecc_violation(vars, coeffs, cut::ECCCut)
    lhs = 0.0
    for k in eachindex(vars)
        lhs += coeffs[k] * value(vars[k])
    end
    violation = cut.rhs - lhs
    if abs(violation - cut.violation) > ECC_CHECK_EPS
        error("ECC violation mismatch: recomputed=$violation, " *
              "reported=$(cut.violation), diff=$(abs(violation - cut.violation))")
    end
end

# --- Callback registration -----------------------------------------------

function add_ecc_cuts!(model, data::DataPwjTj, x, A, node_ids, ub)
    n, T = data.n, data.T
    jobs = data.jobs

    # demands[j+1] = p_j for j=1..n;  demands[1]=0 for source/sink (j=0)
    demands = zeros(Int, n + 1)
    for j in 1:n
        demands[j+1] = jobs[j].p
    end

    node_to_job = Dict{Int,Int}(0 => 0)
    id_to_t = Dict{Int,Int}(0 => 0)
    for ((j, t), nid) in node_ids
        node_to_job[nid] = j
        id_to_t[nid] = t
    end

    # Cost of arc (u,v) is the head node v's cost (objective in model.jl);
    # source/sink node 0 costs 0. Used to compute the current relaxation value.
    node_cost = Dict{Int,Float64}(0 => 0.0)
    for ((j, t), nid) in node_ids
        node_cost[nid] = Float64(job_cost(data, j, t))
    end

    cut_batch = 100
    next_ecc_vertex = Ref(1)   # persists across callback calls

    function ecc_callback()
        # Skip separation once the relaxation bound already reaches the cutoff:
        # if the current LP value rounds up to >= ub, no integer improving
        # solution exists below ub, so further cuts are pointless.
        relax = 0.0
        for (u, v) in A
            relax += node_cost[v] * value(x[(u, v)])
        end
        relax >= ub - 1.0 - ECC_CHECK_EPS && return

        arcs_cap = build_lpsol(x, A, node_to_job, id_to_t)
        cuts_found = ext_cap_cut_gen_by_heur!(arcs_cap, n, T, demands,
            cut_batch, next_ecc_vertex)
        for cut in cuts_found
            vars = VariableRef[]
            coeffs = Float64[]
            # Iterate over ALL arcs in A (not just nonzero-value arcs_cap):
            # zero-value arcs don't affect the violation but must still appear
            # in the cut. (i,j,d) is the reversed-arc key, as in build_lpsol.
            for (u, v) in A
                i, j, d = node_to_job[v], node_to_job[u], id_to_t[u]
                d > cut.cap && continue
                coeff = 0.0
                if !cut.S[i+1] && cut.S[j+1]
                    coeff = cut.incapcoeff[d+1]
                elseif cut.S[i+1] && !cut.S[j+1]
                    coeff = cut.outcapcoeff[d+1]
                end
                abs(coeff) < 1e-10 && continue
                push!(vars, x[(u, v)])
                push!(coeffs, coeff)
            end
            check_ecc_violation(vars, coeffs, cut)
            isempty(vars) && continue
            add_dynamic_constr!(model.optimizer, vars, coeffs, >=, cut.rhs, "hecc")
        end
    end

    add_cut_callback!(model, ecc_callback, "hecc")
end
