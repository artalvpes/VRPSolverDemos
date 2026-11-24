# Upper bounds are optimal costs + 1 (optima from Pessoa et al. 2010, Table 1).
# Same instances and upper bounds as wt40-2m.batch, one Julia process per instance (run from the P_wjTj folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl instances/WT40-2m/wt40-2m-1.txt -u 607 &> out/wt40-2m-1.out
julia src/run.jl instances/WT40-2m/wt40-2m-6.txt -u 3887 &> out/wt40-2m-6.out
julia src/run.jl instances/WT40-2m/wt40-2m-11.txt -u 9618 &> out/wt40-2m-11.out
# julia src/run.jl instances/WT40-2m/wt40-2m-16.txt -u 38357 &> out/wt40-2m-16.out   (not solved in 10 minutes, November 2026; lower bound 38335)
julia src/run.jl instances/WT40-2m/wt40-2m-21.txt -u 41049 &> out/wt40-2m-21.out
julia src/run.jl instances/WT40-2m/wt40-2m-26.txt -u 88 &> out/wt40-2m-26.out
julia src/run.jl instances/WT40-2m/wt40-2m-31.txt -u 3813 &> out/wt40-2m-31.out
# julia src/run.jl instances/WT40-2m/wt40-2m-36.txt -u 10714 &> out/wt40-2m-36.out   (not solved in 10 minutes, November 2026; lower bound 10702)
julia src/run.jl instances/WT40-2m/wt40-2m-41.txt -u 30803 &> out/wt40-2m-41.out
julia src/run.jl instances/WT40-2m/wt40-2m-46.txt -u 34147 &> out/wt40-2m-46.out
julia src/run.jl instances/WT40-2m/wt40-2m-51.txt -u 1 &> out/wt40-2m-51.out
julia src/run.jl instances/WT40-2m/wt40-2m-56.txt -u 1280 &> out/wt40-2m-56.out
# julia src/run.jl instances/WT40-2m/wt40-2m-61.txt -u 11489 &> out/wt40-2m-61.out   (not solved in 10 minutes, November 2026; lower bound 11391)
# julia src/run.jl instances/WT40-2m/wt40-2m-66.txt -u 35280 &> out/wt40-2m-66.out   (not solved in 10 minutes, November 2026; lower bound 35190)
julia src/run.jl instances/WT40-2m/wt40-2m-71.txt -u 47953 &> out/wt40-2m-71.out
julia src/run.jl instances/WT40-2m/wt40-2m-76.txt -u 1 &> out/wt40-2m-76.out
# julia src/run.jl instances/WT40-2m/wt40-2m-81.txt -u 572 &> out/wt40-2m-81.out   (not solved in 10 minutes, November 2026; lower bound 520)
julia src/run.jl instances/WT40-2m/wt40-2m-86.txt -u 6049 &> out/wt40-2m-86.out
julia src/run.jl instances/WT40-2m/wt40-2m-91.txt -u 26076 &> out/wt40-2m-91.out
julia src/run.jl instances/WT40-2m/wt40-2m-96.txt -u 66117 &> out/wt40-2m-96.out
julia src/run.jl instances/WT40-2m/wt40-2m-101.txt -u 1 &> out/wt40-2m-101.out
julia src/run.jl instances/WT40-2m/wt40-2m-106.txt -u 1 &> out/wt40-2m-106.out
julia src/run.jl instances/WT40-2m/wt40-2m-111.txt -u 17937 &> out/wt40-2m-111.out
julia src/run.jl instances/WT40-2m/wt40-2m-116.txt -u 25871 &> out/wt40-2m-116.out
julia src/run.jl instances/WT40-2m/wt40-2m-121.txt -u 64517 &> out/wt40-2m-121.out
