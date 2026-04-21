import Base.show, Base.print

mutable struct Vertex
   id_vertex::Int
   pos_x::Float64
   pos_y::Float64
   service_time::Int
   demand::Int
   start_tw::Int
   end_tw::Int
end

# Directed graph
mutable struct InputGraph
   V′::Vector{Vertex} # set of vertices
   A::Vector{Tuple{Int64,Int64}} # set of edges
   cost::Dict{Tuple{Int64,Int64},Float64} # cost for each arc
   time::Dict{Tuple{Int64,Int64},Float64} # time for each arc
end

mutable struct DataVRPTW
   n::Int
   G′::InputGraph
   Q::Float64 # vehicle capacity
   K::Int #num vehicles available
end

# Euclidian distance
function distance(v1::Vertex, v2::Vertex)
   x_sq = (v1.pos_x - v2.pos_x)^2
   y_sq = (v1.pos_y - v2.pos_y)^2
   return floor(sqrt(x_sq + y_sq)*10)/10
end

function readVRPTWData(path_file::String)
   # STEP 1 : pushing data in a vector.
   data = Vector{String}()
   open(path_file) do file
      for line in eachline(file)
         if findfirst("CUST", line) != nothing || findfirst("VEH", line) != nothing || 
	    findfirst("NUMBER", line) != nothing
            continue
         end
         for peaceofdata in split(line)
            push!(data, String(peaceofdata))
         end
      end
   end

   n = div(length(data) - 3, 7) - 1
   K = parse(Int, data[2])
   Q = parse(Float64, data[3])

   vertices = Vertex[] 
   for i in 0:n
      offset = 3 + i*7
      x = parse(Float64, data[offset + 2])     
      y = parse(Float64, data[offset + 3])     
      d = parse(Int, data[offset + 4])     
      l = parse(Int, data[offset + 5])     
      u = parse(Int, data[offset + 6])     
      s = parse(Int, data[offset + 7])     
      push!(vertices, Vertex(i, x, y, s, d, l, u))
   end
  
   A = Tuple{Int64,Int64}[]
   cost = Dict{Tuple{Int64,Int64},Float64}()
   time = Dict{Tuple{Int64,Int64},Float64}()

   function add_arc!(i, j)
      push!(A, (i,j)) 
      cost[(i,j)] = distance(vertices[i + 1], vertices[j + 1])  
      time[(i,j)] = distance(vertices[i + 1], vertices[j + 1]) + vertices[i + 1].service_time 
   end
   for i in 1:n
      #arc from depot
      add_arc!(0, i)
      #arc to depot
      add_arc!(i, 0)
      for j in 1:n
         if (i != j) 
            add_arc!(i, j)
         end
      end
   end

   DataVRPTW(n, InputGraph(vertices, A, cost, time), Q, K)
end

arcs(data::DataVRPTW) = data.G′.A # return set of arcs
function c(data,a) 
   if !(haskey(data.G′.cost, a)) 
      return Inf
   end
   return data.G′.cost[a] 
end     
function t(data,a) 
   if !(haskey(data.G′.time, a)) 
      return Inf
   end
   return data.G′.time[a] 
end     
n(data::DataVRPTW) = data.n # return number of requests
d(data::DataVRPTW, i) = data.G′.V′[i+1].demand # return demand of i
s(data::DataVRPTW, i) = data.G′.V′[i+1].service_time # return service time of i
l(data::DataVRPTW, i) = Float64(data.G′.V′[i+1].start_tw)
u(data::DataVRPTW, i) = Float64(data.G′.V′[i+1].end_tw)
veh_capacity(data::DataVRPTW) = Int(data.Q)

function lowerBoundNbVehicles(data::DataVRPTW) 
   return 1
end

function upperBoundNbVehicles(data::DataVRPTW) 
   return data.K
end
