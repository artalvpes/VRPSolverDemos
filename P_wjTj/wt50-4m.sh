# Upper bounds are optimal costs + 1 (optima from Pessoa et al. 2010, Table 4).
# Same instances and upper bounds as wt50-4m.batch, one Julia process per instance (run from the P_wjTj folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
# julia src/run.jl instances/WT50-4m/wt50-4m-1.txt -u 786 &> out/wt50-4m-1.out   (not solved in 10 minutes, November 2026; lower bound 785)
# julia src/run.jl instances/WT50-4m/wt50-4m-6.txt -u 8318 &> out/wt50-4m-6.out   (not solved in 10 minutes, November 2026; lower bound 8306)
julia src/run.jl instances/WT50-4m/wt50-4m-11.txt -u 12880 &> out/wt50-4m-11.out
julia src/run.jl instances/WT50-4m/wt50-4m-16.txt -u 25377 &> out/wt50-4m-16.out
julia src/run.jl instances/WT50-4m/wt50-4m-21.txt -u 59441 &> out/wt50-4m-21.out
julia src/run.jl instances/WT50-4m/wt50-4m-26.txt -u 55 &> out/wt50-4m-26.out
julia src/run.jl instances/WT50-4m/wt50-4m-31.txt -u 3062 &> out/wt50-4m-31.out
julia src/run.jl instances/WT50-4m/wt50-4m-36.txt -u 10797 &> out/wt50-4m-36.out
# julia src/run.jl instances/WT50-4m/wt50-4m-41.txt -u 21807 &> out/wt50-4m-41.out   (not solved in 10 minutes, November 2026; lower bound 21795)
julia src/run.jl instances/WT50-4m/wt50-4m-46.txt -u 44456 &> out/wt50-4m-46.out
julia src/run.jl instances/WT50-4m/wt50-4m-51.txt -u 1 &> out/wt50-4m-51.out
# julia src/run.jl instances/WT50-4m/wt50-4m-56.txt -u 571 &> out/wt50-4m-56.out   (not solved in 10 minutes, November 2026; lower bound 541)
# julia src/run.jl instances/WT50-4m/wt50-4m-61.txt -u 7899 &> out/wt50-4m-61.out   (not solved in 10 minutes, November 2026; lower bound 7858)
julia src/run.jl instances/WT50-4m/wt50-4m-66.txt -u 23139 &> out/wt50-4m-66.out
julia src/run.jl instances/WT50-4m/wt50-4m-71.txt -u 42646 &> out/wt50-4m-71.out
julia src/run.jl instances/WT50-4m/wt50-4m-76.txt -u 1 &> out/wt50-4m-76.out
julia src/run.jl instances/WT50-4m/wt50-4m-81.txt -u 496 &> out/wt50-4m-81.out
# julia src/run.jl instances/WT50-4m/wt50-4m-86.txt -u 8370 &> out/wt50-4m-86.out   (not solved in 10 minutes, November 2026; lower bound 8354)
julia src/run.jl instances/WT50-4m/wt50-4m-91.txt -u 26552 &> out/wt50-4m-91.out
julia src/run.jl instances/WT50-4m/wt50-4m-96.txt -u 50327 &> out/wt50-4m-96.out
julia src/run.jl instances/WT50-4m/wt50-4m-101.txt -u 1 &> out/wt50-4m-101.out
julia src/run.jl instances/WT50-4m/wt50-4m-106.txt -u 1 &> out/wt50-4m-106.out
julia src/run.jl instances/WT50-4m/wt50-4m-111.txt -u 10070 &> out/wt50-4m-111.out
# julia src/run.jl instances/WT50-4m/wt50-4m-116.txt -u 11553 &> out/wt50-4m-116.out   (not solved in 10 minutes, November 2026; lower bound 11527)
# julia src/run.jl instances/WT50-4m/wt50-4m-121.txt -u 23793 &> out/wt50-4m-121.out   (not solved in 10 minutes, November 2026; lower bound 23783)
