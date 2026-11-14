import Base.show

# Variable-sized bin packing with penalties:
# J items (length w_j, penalty p_j paid if the item is not produced) and
# K stock types (length W_k, availability u_k, cost c_k per stock used).
struct DataVSBPP
    w::Vector{Int} # w[j] is the length of item j
    p::Vector{Int} # p[j] is the penalty of item j if it is not produced
    W::Vector{Int} # W[k] is the length of stock type k
    u::Vector{Int} # u[k] is the number of available stocks of type k
    c::Vector{Int} # c[k] is the cost of a stock of type k
end

# Instance format (lines starting with '#' are comments):
#   J K
#   w_j p_j        (J lines)
#   W_k u_k c_k    (K lines)
function readVSBPPData(path::AbstractString)
    numbers = Int[]
    for line in eachline(path)
        line = strip(line)
        (isempty(line) || line[1] == '#') && continue
        append!(numbers, parse.(Int, split(line)))
    end
    J, K = numbers[1], numbers[2]
    length(numbers) == 2 + 2J + 3K || error("Invalid instance file $path: expected $(2 + 2J + 3K) numbers")
    items = reshape(numbers[3:2+2J], 2, J)
    stocks = reshape(numbers[3+2J:end], 3, K)
    data = DataVSBPP(items[1, :], items[2, :], stocks[1, :], stocks[2, :], stocks[3, :])
    all(data.w .> 0) && all(data.W .> 0) && all(data.u .>= 0) || error("Invalid instance file $path")
    return data
end

items(data::DataVSBPP) = 1:length(data.w)
stock_types(data::DataVSBPP) = 1:length(data.W)

function show(io::IO, data::DataVSBPP)
    println(io, "Variable-sized bin packing with penalties: $(length(data.w)) items, $(length(data.W)) stock types")
    for k in stock_types(data)
        println(io, "  stock type $k: length = $(data.W[k]), availability = $(data.u[k]), cost = $(data.c[k])")
    end
    for j in items(data)
        println(io, "  item $j: length = $(data.w[j]), penalty = $(data.p[j])")
    end
end
