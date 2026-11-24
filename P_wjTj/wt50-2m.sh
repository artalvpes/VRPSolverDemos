# Upper bounds are optimal costs + 1 (optima from Pessoa et al. 2010, Table 3).
# Same instances and upper bounds as wt50-2m.batch, one Julia process per instance (run from the P_wjTj folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl instances/WT50-2m/wt50-2m-1.txt -u 1269 &> out/wt50-2m-1.out
julia src/run.jl instances/WT50-2m/wt50-2m-6.txt -u 14273 &> out/wt50-2m-6.out
julia src/run.jl instances/WT50-2m/wt50-2m-11.txt -u 23029 &> out/wt50-2m-11.out
julia src/run.jl instances/WT50-2m/wt50-2m-16.txt -u 46073 &> out/wt50-2m-16.out
julia src/run.jl instances/WT50-2m/wt50-2m-21.txt -u 111070 &> out/wt50-2m-21.out
julia src/run.jl instances/WT50-2m/wt50-2m-26.txt -u 27 &> out/wt50-2m-26.out
julia src/run.jl instances/WT50-2m/wt50-2m-31.txt -u 5379 &> out/wt50-2m-31.out
julia src/run.jl instances/WT50-2m/wt50-2m-36.txt -u 18957 &> out/wt50-2m-36.out
julia src/run.jl instances/WT50-2m/wt50-2m-41.txt -u 38059 &> out/wt50-2m-41.out
julia src/run.jl instances/WT50-2m/wt50-2m-46.txt -u 82106 &> out/wt50-2m-46.out
julia src/run.jl instances/WT50-2m/wt50-2m-51.txt -u 1 &> out/wt50-2m-51.out
julia src/run.jl instances/WT50-2m/wt50-2m-56.txt -u 762 &> out/wt50-2m-56.out
julia src/run.jl instances/WT50-2m/wt50-2m-61.txt -u 13683 &> out/wt50-2m-61.out
julia src/run.jl instances/WT50-2m/wt50-2m-66.txt -u 40908 &> out/wt50-2m-66.out
julia src/run.jl instances/WT50-2m/wt50-2m-71.txt -u 78533 &> out/wt50-2m-71.out
julia src/run.jl instances/WT50-2m/wt50-2m-76.txt -u 1 &> out/wt50-2m-76.out
julia src/run.jl instances/WT50-2m/wt50-2m-81.txt -u 543 &> out/wt50-2m-81.out
julia src/run.jl instances/WT50-2m/wt50-2m-86.txt -u 12558 &> out/wt50-2m-86.out
julia src/run.jl instances/WT50-2m/wt50-2m-91.txt -u 47350 &> out/wt50-2m-91.out
julia src/run.jl instances/WT50-2m/wt50-2m-96.txt -u 92823 &> out/wt50-2m-96.out
julia src/run.jl instances/WT50-2m/wt50-2m-101.txt -u 1 &> out/wt50-2m-101.out
julia src/run.jl instances/WT50-2m/wt50-2m-106.txt -u 1 &> out/wt50-2m-106.out
julia src/run.jl instances/WT50-2m/wt50-2m-111.txt -u 15565 &> out/wt50-2m-111.out
julia src/run.jl instances/WT50-2m/wt50-2m-116.txt -u 19609 &> out/wt50-2m-116.out
julia src/run.jl instances/WT50-2m/wt50-2m-121.txt -u 41697 &> out/wt50-2m-121.out
