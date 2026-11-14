# All instances of the set A (25% Steiner points, |T(i)| = 3, star cost factor 0.5)
# Same instances and upper bounds as A.batch, one Julia process per instance (run from the CRSP folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl data/A/A-n32-k5.vrp -p 25 -k 3 -a 0.5 &> out/A-n32-k5.out
julia src/run.jl data/A/A-n33-k5.vrp -p 25 -k 3 -a 0.5 &> out/A-n33-k5.out
julia src/run.jl data/A/A-n33-k6.vrp -p 25 -k 3 -a 0.5 &> out/A-n33-k6.out
julia src/run.jl data/A/A-n34-k5.vrp -p 25 -k 3 -a 0.5 &> out/A-n34-k5.out
julia src/run.jl data/A/A-n36-k5.vrp -p 25 -k 3 -a 0.5 &> out/A-n36-k5.out
julia src/run.jl data/A/A-n37-k5.vrp -p 25 -k 3 -a 0.5 &> out/A-n37-k5.out
julia src/run.jl data/A/A-n37-k6.vrp -p 25 -k 3 -a 0.5 &> out/A-n37-k6.out
julia src/run.jl data/A/A-n38-k5.vrp -p 25 -k 3 -a 0.5 &> out/A-n38-k5.out
julia src/run.jl data/A/A-n39-k5.vrp -p 25 -k 3 -a 0.5 &> out/A-n39-k5.out
julia src/run.jl data/A/A-n39-k6.vrp -p 25 -k 3 -a 0.5 &> out/A-n39-k6.out
julia src/run.jl data/A/A-n44-k6.vrp -p 25 -k 3 -a 0.5 &> out/A-n44-k6.out
julia src/run.jl data/A/A-n45-k6.vrp -p 25 -k 3 -a 0.5 &> out/A-n45-k6.out
julia src/run.jl data/A/A-n45-k7.vrp -p 25 -k 3 -a 0.5 &> out/A-n45-k7.out
julia src/run.jl data/A/A-n46-k7.vrp -p 25 -k 3 -a 0.5 &> out/A-n46-k7.out
julia src/run.jl data/A/A-n48-k7.vrp -p 25 -k 3 -a 0.5 &> out/A-n48-k7.out
julia src/run.jl data/A/A-n53-k7.vrp -p 25 -k 3 -a 0.5 &> out/A-n53-k7.out
julia src/run.jl data/A/A-n54-k7.vrp -p 25 -k 3 -a 0.5 &> out/A-n54-k7.out
julia src/run.jl data/A/A-n55-k9.vrp -p 25 -k 3 -a 0.5 &> out/A-n55-k9.out
julia src/run.jl data/A/A-n60-k9.vrp -p 25 -k 3 -a 0.5 &> out/A-n60-k9.out
julia src/run.jl data/A/A-n61-k9.vrp -p 25 -k 3 -a 0.5 &> out/A-n61-k9.out
julia src/run.jl data/A/A-n62-k8.vrp -p 25 -k 3 -a 0.5 &> out/A-n62-k8.out
julia src/run.jl data/A/A-n63-k9.vrp -p 25 -k 3 -a 0.5 &> out/A-n63-k9.out
julia src/run.jl data/A/A-n63-k10.vrp -p 25 -k 3 -a 0.5 &> out/A-n63-k10.out
# julia src/run.jl data/A/A-n64-k9.vrp -p 25 -k 3 -a 0.5 &> out/A-n64-k9.out   (not solved in 10 minutes, November 2026; lower bound 1016)
julia src/run.jl data/A/A-n65-k9.vrp -p 25 -k 3 -a 0.5 &> out/A-n65-k9.out
julia src/run.jl data/A/A-n69-k9.vrp -p 25 -k 3 -a 0.5 &> out/A-n69-k9.out
# julia src/run.jl data/A/A-n80-k10.vrp -p 25 -k 3 -a 0.5 &> out/A-n80-k10.out   (not solved in 10 minutes, November 2026; lower bound 1188)
