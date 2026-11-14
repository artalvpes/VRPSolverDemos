# Running all instances of the sets F
# Same instances and upper bounds as F.batch, one Julia process per instance (run from the CVRP folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl data/F/F-n45-k4.vrp -m 4 -M 4 -u 725 &> out/F-n45-k4.out
julia src/run.jl data/F/F-n72-k4.vrp -m 4 -M 4 -u 238 &> out/F-n72-k4.out
# julia src/run.jl data/F/F-n135-k7.vrp -m 7 -M 7 -u 1163 &> out/F-n135-k7.out   (not solved in 10 minutes, November 2026; lower bound 1158)
