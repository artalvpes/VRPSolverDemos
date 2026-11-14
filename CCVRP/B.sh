# Cumulative CVRP, set B.
# The model uses a custom resource: the BaPCod/RCSP library must be built with src/meta_solver/rcsp_custom_res_impl.*
# copied to Tools/rcsp (src and include_dev).
# Same instances and upper bounds as B.batch, one Julia process per instance (run from the CCVRP folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl data/B/B-n38-k6.vrp -m 6 -M 6 -u 28509 &> out/B-n38-k6.out
julia src/run.jl data/B/B-n39-k5.vrp -m 5 -M 5 -u 19983 &> out/B-n39-k5.out
julia src/run.jl data/B/B-n41-k6.vrp -m 6 -M 6 -u 33131 &> out/B-n41-k6.out
julia src/run.jl data/B/B-n43-k6.vrp -m 6 -M 6 -u 27978 &> out/B-n43-k6.out
julia src/run.jl data/B/B-n44-k7.vrp -m 7 -M 7 -u 37083 &> out/B-n44-k7.out
julia src/run.jl data/B/B-n45-k5.vrp -m 5 -M 5 -u 25361 &> out/B-n45-k5.out
julia src/run.jl data/B/B-n45-k6.vrp -m 6 -M 6 -u 27595 &> out/B-n45-k6.out
julia src/run.jl data/B/B-n50-k8.vrp -m 8 -M 8 -u 50644 &> out/B-n50-k8.out
# julia src/run.jl data/B/B-n50-k7.vrp -m 7 -M 7 &> out/B-n50-k7.out   (not solved in 2 minutes; lower bound 27583)
# julia src/run.jl data/B/B-n51-k7.vrp -m 7 -M 7 &> out/B-n51-k7.out   (not solved in 2 minutes; lower bound 43231)
julia src/run.jl data/B/B-n52-k7.vrp -m 7 -M 7 -u 28536 &> out/B-n52-k7.out
julia src/run.jl data/B/B-n56-k7.vrp -m 7 -M 7 -u 25088 &> out/B-n56-k7.out
julia src/run.jl data/B/B-n57-k9.vrp -m 9 -M 9 -u 65712 &> out/B-n57-k9.out
# julia src/run.jl data/B/B-n57-k7.vrp -m 7 -M 7 &> out/B-n57-k7.out   (not solved in 2 minutes; lower bound 50314)
# julia src/run.jl data/B/B-n63-k10.vrp -m 10 -M 10 &> out/B-n63-k10.out   (not solved in 2 minutes; lower bound 61647)
julia src/run.jl data/B/B-n64-k9.vrp -m 9 -M 9 -u 35458 &> out/B-n64-k9.out
# julia src/run.jl data/B/B-n66-k9.vrp -m 9 -M 9 &> out/B-n66-k9.out   (not solved in 2 minutes; lower bound 52564)
# julia src/run.jl data/B/B-n67-k10.vrp -m 10 -M 10 &> out/B-n67-k10.out   (not solved in 2 minutes; lower bound 39620)
# julia src/run.jl data/B/B-n68-k9.vrp -m 9 -M 9 &> out/B-n68-k9.out   (not solved in 2 minutes; lower bound 51975)
julia src/run.jl data/B/B-n78-k10.vrp -m 10 -M 10 -u 46469 &> out/B-n78-k10.out
