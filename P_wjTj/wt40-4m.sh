# Upper bounds are optimal costs + 1 (optima from Pessoa et al. 2010, Table 2).
# Same instances and upper bounds as wt40-4m.batch, one Julia process per instance (run from the P_wjTj folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl instances/WT40-4m/wt40-4m-1.txt -u 440 &> out/wt40-4m-1.out
julia src/run.jl instances/WT40-4m/wt40-4m-6.txt -u 2375 &> out/wt40-4m-6.out
julia src/run.jl instances/WT40-4m/wt40-4m-11.txt -u 5738 &> out/wt40-4m-11.out
julia src/run.jl instances/WT40-4m/wt40-4m-16.txt -u 21494 &> out/wt40-4m-16.out
julia src/run.jl instances/WT40-4m/wt40-4m-21.txt -u 22794 &> out/wt40-4m-21.out
julia src/run.jl instances/WT40-4m/wt40-4m-26.txt -u 89 &> out/wt40-4m-26.out
julia src/run.jl instances/WT40-4m/wt40-4m-31.txt -u 2526 &> out/wt40-4m-31.out
# julia src/run.jl instances/WT40-4m/wt40-4m-36.txt -u 6421 &> out/wt40-4m-36.out   (not solved in 10 minutes, November 2026; lower bound 6371)
julia src/run.jl instances/WT40-4m/wt40-4m-41.txt -u 17686 &> out/wt40-4m-41.out
julia src/run.jl instances/WT40-4m/wt40-4m-46.txt -u 19125 &> out/wt40-4m-46.out
julia src/run.jl instances/WT40-4m/wt40-4m-51.txt -u 1 &> out/wt40-4m-51.out
julia src/run.jl instances/WT40-4m/wt40-4m-56.txt -u 827 &> out/wt40-4m-56.out
julia src/run.jl instances/WT40-4m/wt40-4m-61.txt -u 7358 &> out/wt40-4m-61.out
julia src/run.jl instances/WT40-4m/wt40-4m-66.txt -u 20252 &> out/wt40-4m-66.out
julia src/run.jl instances/WT40-4m/wt40-4m-71.txt -u 26741 &> out/wt40-4m-71.out
julia src/run.jl instances/WT40-4m/wt40-4m-76.txt -u 1 &> out/wt40-4m-76.out
julia src/run.jl instances/WT40-4m/wt40-4m-81.txt -u 565 &> out/wt40-4m-81.out
julia src/run.jl instances/WT40-4m/wt40-4m-86.txt -u 4726 &> out/wt40-4m-86.out
julia src/run.jl instances/WT40-4m/wt40-4m-91.txt -u 15570 &> out/wt40-4m-91.out
julia src/run.jl instances/WT40-4m/wt40-4m-96.txt -u 36267 &> out/wt40-4m-96.out
julia src/run.jl instances/WT40-4m/wt40-4m-101.txt -u 1 &> out/wt40-4m-101.out
julia src/run.jl instances/WT40-4m/wt40-4m-106.txt -u 1 &> out/wt40-4m-106.out
julia src/run.jl instances/WT40-4m/wt40-4m-111.txt -u 11264 &> out/wt40-4m-111.out
julia src/run.jl instances/WT40-4m/wt40-4m-116.txt -u 15567 &> out/wt40-4m-116.out
julia src/run.jl instances/WT40-4m/wt40-4m-121.txt -u 35752 &> out/wt40-4m-121.out
