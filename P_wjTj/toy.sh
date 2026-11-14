# Same instances and upper bounds as toy.batch, one Julia process per instance (run from the P_wjTj folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl instances/toy/wt10-2m-1.txt &> out/wt10-2m-1.out
julia src/run.jl instances/toy/wt10-2m-2.txt &> out/wt10-2m-2.out
julia src/run.jl instances/toy/wt10-2m-3.txt &> out/wt10-2m-3.out
julia src/run.jl instances/toy/wt10-2m-4.txt &> out/wt10-2m-4.out
julia src/run.jl instances/toy/wt10-2m-5.txt &> out/wt10-2m-5.out
julia src/run.jl instances/toy/wt10-2m-6.txt &> out/wt10-2m-6.out
julia src/run.jl instances/toy/wt10-2m-7.txt &> out/wt10-2m-7.out
julia src/run.jl instances/toy/wt10-2m-8.txt &> out/wt10-2m-8.out
julia src/run.jl instances/toy/wt10-2m-9.txt &> out/wt10-2m-9.out
julia src/run.jl instances/toy/wt10-2m-10.txt &> out/wt10-2m-10.out
