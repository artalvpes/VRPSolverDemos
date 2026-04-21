function build_model(data::DataVRPTW, app)

   A = arcs(data) 
   V = [i for i in 1:n(data)] 
   Q = veh_capacity(data)

   # Formulation
   vrptw = VrpModel()
   @variable(vrptw.formulation, x[a in A], Int)
   @objective(vrptw.formulation, Min, sum(c(data,a) * x[a] for a in A))
   @constraint(vrptw.formulation, indeg[i in V], sum(x[a] for a in A if a[2] == i) == 1.0)

   #println(vrptw.formulation)

   # Build the model directed graph G=(V1,A1)
   function buildgraph()

      v_source = v_sink = 0
      V1 = [i for i in 0:n(data)]

      L, U = lowerBoundNbVehicles(data), upperBoundNbVehicles(data) # multiplicity

      G = VrpGraph(vrptw, V1, v_source, v_sink, (L, U))

      if app["enable_cap_res"]
         cap_res_id = add_resource!(G, main = true)
      end
      time_res_id = add_resource!(G, main = true)

      for v in V1
         if app["enable_cap_res"]
            set_resource_bounds!(G, v, cap_res_id, 0, Q)
         end
         set_resource_bounds!(G, v, time_res_id, l(data, v), u(data, v))
      end

      for (i,j) in A
         arc_id = add_arc!(G, i, j)
         add_arc_var_mapping!(G, arc_id, x[(i,j)])
         if app["enable_cap_res"]
            set_arc_consumption!(G, arc_id, cap_res_id, d(data, j))
         end
         set_arc_consumption!(G, arc_id, time_res_id, t(data, (i, j)))
      end

      return G
   end

   G = buildgraph()
   add_graph!(vrptw, G)
   #println(G)

   set_vertex_packing_sets!(vrptw, [[(G,i)] for i in V])

   define_elementarity_sets_distance_matrix!(vrptw, G, [[c(data, (i, j)) for j in V] for i in V])

   add_capacity_cut_separator!(vrptw, [ ( [(G,i)], Float64(d(data, i)) ) for i in V], Float64(Q))

   set_branching_priority!(vrptw, "x", 1)

   return (vrptw, x)
end
