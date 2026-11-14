# Cumulative CVRP, set A.
# The model uses a custom resource: the BaPCod/RCSP library must be built with src/meta_solver/rcsp_custom_res_impl.*
# copied to Tools/rcsp (src and include_dev).
# Same instances and upper bounds as A.batch, one Julia process per instance (run from the CCVRP folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl data/A/A-n37-k6.vrp -m 6 -M 6 -u 34007 &> out/A-n37-k6.out
julia src/run.jl data/A/A-n37-k5.vrp -m 5 -M 5 -u 20006 &> out/A-n37-k5.out
julia src/run.jl data/A/A-n38-k5.vrp -m 5 -M 5 -u 25979 &> out/A-n38-k5.out
julia src/run.jl data/A/A-n39-k6.vrp -m 6 -M 6 -u 27203 &> out/A-n39-k6.out
julia src/run.jl data/A/A-n39-k5.vrp -m 5 -M 5 -u 29438 &> out/A-n39-k5.out
julia src/run.jl data/A/A-n44-k6.vrp -m 6 -M 6 -u 32310 &> out/A-n44-k6.out
julia src/run.jl data/A/A-n45-k6.vrp -m 6 -M 6 -u 36063 &> out/A-n45-k6.out
julia src/run.jl data/A/A-n45-k7.vrp -m 7 -M 7 -u 43520 &> out/A-n45-k7.out
julia src/run.jl data/A/A-n46-k7.vrp -m 7 -M 7 -u 32638 &> out/A-n46-k7.out
julia src/run.jl data/A/A-n48-k7.vrp -m 7 -M 7 -u 40161 &> out/A-n48-k7.out
julia src/run.jl data/A/A-n53-k7.vrp -m 7 -M 7 -u 38554 &> out/A-n53-k7.out
julia src/run.jl data/A/A-n54-k7.vrp -m 7 -M 7 -u 44263 &> out/A-n54-k7.out
julia src/run.jl data/A/A-n55-k9.vrp -m 9 -M 9 -u 40688 &> out/A-n55-k9.out
julia src/run.jl data/A/A-n60-k9.vrp -m 9 -M 9 -u 51490 &> out/A-n60-k9.out
# julia src/run.jl data/A/A-n61-k9.vrp -m 9 -M 9 &> out/A-n61-k9.out   (not solved in 2 minutes; lower bound 40513)
julia src/run.jl data/A/A-n62-k8.vrp -m 8 -M 8 -u 47288 &> out/A-n62-k8.out
julia src/run.jl data/A/A-n63-k9.vrp -m 9 -M 9 -u 63141 &> out/A-n63-k9.out
# julia src/run.jl data/A/A-n63-k10.vrp -m 10 -M 10 &> out/A-n63-k10.out   (not solved in 2 minutes; lower bound 49106)
# julia src/run.jl data/A/A-n64-k9.vrp -m 9 -M 9 &> out/A-n64-k9.out   (not solved in 2 minutes; lower bound 51488)
julia src/run.jl data/A/A-n65-k9.vrp -m 9 -M 9 -u 46833 &> out/A-n65-k9.out
julia src/run.jl data/A/A-n69-k9.vrp -m 9 -M 9 -u 42227 &> out/A-n69-k9.out
# julia src/run.jl data/A/A-n80-k10.vrp -m 10 -M 10 &> out/A-n80-k10.out   (not solved in 2 minutes; lower bound 66618)
