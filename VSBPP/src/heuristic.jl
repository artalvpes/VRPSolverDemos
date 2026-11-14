# Simple heuristic for the variable-sized bin packing with penalties, used to obtain an initial upper bound.
#
# Construction: while it pays off, open the stock (of an available type) whose best pattern saves the most, where
# the best pattern of a stock of type k is a 0/1 knapsack over the items not yet produced (capacity W_k, value p_j)
# and its saving is the sum of the penalties avoided minus c_k. Two greedy criteria are tried: the largest saving,
# and the largest saving per unit of length.
# Local search: each stock in turn is removed and replaced by the best pattern over its items plus the items not
# produced, for every stock type available (or by nothing), if this improves the cost. Repeated until no
# improvement. A pair move re-packs two stocks at a time. Random restarts perturb the values used by the greedy.

using Random

# 0/1 knapsack over the items cand with capacity cap and values val (default: the penalties): returns the largest
# sum of values and the items.
function knapsack(data::DataVSBPP, cand::Vector{Int}, cap::Int, val::Vector{<:Real}=data.p)
    best = zeros(eltype(val), cap + 1) # best[c + 1]: largest value with total length <= c
    keep = falses(length(cand), cap + 1)
    for (i, j) in enumerate(cand)
        wj, pj = data.w[j], val[j]
        for c in cap:-1:wj
            v = best[c-wj+1] + pj
            if v > best[c+1]
                best[c+1] = v
                keep[i, c+1] = true
            end
        end
    end
    sel, c = Int[], cap
    for i in length(cand):-1:1
        if keep[i, c+1]
            push!(sel, cand[i])
            c -= data.w[cand[i]]
        end
    end
    return best[cap+1], sel
end

# Cost of a solution given as a vector of patterns (stock type, items)
function heuristic_cost(data::DataVSBPP, patterns)
    produced = falses(length(data.w))
    cost = 0
    for (k, its) in patterns
        cost += data.c[k]
        produced[its] .= true
    end
    return cost + sum(data.p[j] for j in items(data) if !produced[j]; init=0)
end

# Greedy construction; per_length = true chooses the stock by saving per unit of length
# (val: values of the items used to choose the patterns, the penalties perturbed in the random restarts)
function greedy(data::DataVSBPP, per_length::Bool, val::Vector{<:Real}=data.p)
    avail = copy(data.u)
    left = collect(items(data))
    patterns = Tuple{Int,Vector{Int}}[]
    while !isempty(left)
        best_score, best_k, best_sel = 0.0, 0, Int[]
        for k in stock_types(data)
            avail[k] > 0 || continue
            v, sel = knapsack(data, left, data.W[k], val)
            saving = v - data.c[k]
            saving > 0 || continue
            score = per_length ? saving / data.W[k] : Float64(saving)
            if score > best_score
                best_score, best_k, best_sel = score, k, sel
            end
        end
        best_k == 0 && break
        push!(patterns, (best_k, best_sel))
        avail[best_k] -= 1
        setdiff!(left, best_sel)
    end
    return patterns
end

function local_search!(data::DataVSBPP, patterns::Vector{Tuple{Int,Vector{Int}}})
    improved = true
    while improved
        improved = false
        for b in eachindex(patterns)
            k, its = patterns[b]
            produced = Set(j for (_, s) in patterns for j in s)
            cand = vcat(its, [j for j in items(data) if !(j in produced)])
            current = sum(data.p[its]; init=0) - data.c[k] # saving of stock b
            avail = copy(data.u)
            for (k2, _) in patterns
                avail[k2] -= 1
            end
            avail[k] += 1 # stock b is removed
            best_saving, best_k, best_sel = 0, 0, Int[] # best_k = 0: close the stock
            for k2 in stock_types(data)
                avail[k2] > 0 || continue
                v, sel = knapsack(data, cand, data.W[k2])
                if v - data.c[k2] > best_saving
                    best_saving, best_k, best_sel = v - data.c[k2], k2, sel
                end
            end
            if best_saving > current
                if best_k == 0
                    deleteat!(patterns, b)
                else
                    patterns[b] = (best_k, best_sel)
                end
                improved = true
                break
            end
        end
    end
    return patterns
end

# Available stocks of each type when the stocks removed are taken out of the solution
function availability(data::DataVSBPP, patterns, removed)
    avail = copy(data.u)
    for (b, (k, _)) in enumerate(patterns)
        (b in removed) || (avail[k] -= 1)
    end
    return avail
end

# Best replacement of the stocks removed (one or two) by up to two new stocks of any available types, chosen by
# sequential knapsacks over their items plus the items not produced. Returns (saving, new patterns).
function best_replacement(data::DataVSBPP, patterns, removed)
    produced = Set(j for (b, (_, s)) in enumerate(patterns) if !(b in removed) for j in s)
    cand = [j for j in items(data) if !(j in produced)]
    avail = availability(data, patterns, removed)
    best_saving, best_new = 0, Tuple{Int,Vector{Int}}[]
    for ka in stock_types(data)
        avail[ka] > 0 || continue
        va, sa = knapsack(data, cand, data.W[ka])
        if va - data.c[ka] > best_saving
            best_saving, best_new = va - data.c[ka], [(ka, sa)]
        end
        rest = setdiff(cand, sa)
        avail[ka] -= 1
        for kb in stock_types(data)
            avail[kb] > 0 || continue
            vb, sb = knapsack(data, rest, data.W[kb])
            saving = va - data.c[ka] + vb - data.c[kb]
            if saving > best_saving
                best_saving, best_new = saving, [(ka, sa), (kb, sb)]
            end
        end
        avail[ka] += 1
    end
    return best_saving, best_new
end

saving(data::DataVSBPP, pattern) = sum(data.p[pattern[2]]; init=0) - data.c[pattern[1]]

# Pair and split moves: one stock (split) or two stocks (pair) are replaced by the best replacement, if this
# improves the cost. Returns true on improvement. Stops at the deadline.
function pair_move!(data::DataVSBPP, patterns::Vector{Tuple{Int,Vector{Int}}}, deadline::Float64)
    for b1 in eachindex(patterns), b2 in b1:length(patterns)
        time() > deadline && return false
        removed = b1 == b2 ? (b1,) : (b1, b2)
        current = sum(saving(data, patterns[b]) for b in removed)
        best_saving, new = best_replacement(data, patterns, removed)
        if best_saving > current
            deleteat!(patterns, sort(collect(removed)))
            append!(patterns, new)
            return true
        end
    end
    return false
end

function improve!(data::DataVSBPP, patterns::Vector{Tuple{Int,Vector{Int}}}, deadline::Float64)
    local_search!(data, patterns)
    while pair_move!(data, patterns, deadline)
        local_search!(data, patterns)
    end
    filter!(pat -> !isempty(pat[2]), patterns)
    return patterns
end

# Returns the best solution found (patterns) and its cost. After the two greedy criteria, random restarts perturb
# the values of the items by up to 10% for the choice of the patterns, up to maxiter iterations or about timelimit
# seconds.
function vsbpp_heuristic(data::DataVSBPP; timelimit::Float64=30.0, maxiter::Int=20, seed::Int=1)
    rng = Random.MersenneTwister(seed)
    best, best_cost = Tuple{Int,Vector{Int}}[], heuristic_cost(data, Tuple{Int,Vector{Int}}[])
    t0 = time()
    iter = 0
    while iter < 2 || (iter < maxiter && time() - t0 < timelimit)
        iter += 1
        val = iter <= 2 ? data.p : data.p .* (1 .+ 0.1 .* (2 .* rand(rng, length(data.p)) .- 1))
        patterns = improve!(data, greedy(data, iseven(iter), val), t0 + timelimit)
        cost = heuristic_cost(data, patterns)
        if cost < best_cost
            best, best_cost = patterns, cost
        end
    end
    return best, best_cost
end
