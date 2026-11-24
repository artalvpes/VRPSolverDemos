# Upper bounds are optimal costs + 1 (optima found by this demo, November 2026). wt50-10m-76 has optimum 0.
# Exceptions: wt50-10m-31 and wt50-10m-106 are open (not solved within 1800 s; best bounds 1891 and 828). Their upper
# bounds are the best known solution costs + 1 (1905 and 840), and they may take much longer than the others.
# Same instances and upper bounds as wt50-10m.batch, one Julia process per instance (run from the P_wjTj folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
# julia src/run.jl instances/WT50-10m/wt50-10m-1.txt -u 560 &> out/wt50-10m-1.out   (not solved in 10 minutes, November 2026; lower bound 559)
julia src/run.jl instances/WT50-10m/wt50-10m-6.txt -u 4783 &> out/wt50-10m-6.out
julia src/run.jl instances/WT50-10m/wt50-10m-11.txt -u 7083 &> out/wt50-10m-11.out
julia src/run.jl instances/WT50-10m/wt50-10m-16.txt -u 13762 &> out/wt50-10m-16.out
julia src/run.jl instances/WT50-10m/wt50-10m-21.txt -u 28667 &> out/wt50-10m-21.out
julia src/run.jl instances/WT50-10m/wt50-10m-26.txt -u 201 &> out/wt50-10m-26.out
# julia src/run.jl instances/WT50-10m/wt50-10m-31.txt -u 1906 &> out/wt50-10m-31.out   (not solved in 10 minutes, November 2026; lower bound 1890)
julia src/run.jl instances/WT50-10m/wt50-10m-36.txt -u 7153 &> out/wt50-10m-36.out
julia src/run.jl instances/WT50-10m/wt50-10m-41.txt -u 12422 &> out/wt50-10m-41.out
julia src/run.jl instances/WT50-10m/wt50-10m-46.txt -u 22155 &> out/wt50-10m-46.out
julia src/run.jl instances/WT50-10m/wt50-10m-51.txt -u 53 &> out/wt50-10m-51.out
# julia src/run.jl instances/WT50-10m/wt50-10m-56.txt -u 522 &> out/wt50-10m-56.out   (not solved in 10 minutes, November 2026; lower bound 520)
julia src/run.jl instances/WT50-10m/wt50-10m-61.txt -u 5320 &> out/wt50-10m-61.out
julia src/run.jl instances/WT50-10m/wt50-10m-66.txt -u 12896 &> out/wt50-10m-66.out
julia src/run.jl instances/WT50-10m/wt50-10m-71.txt -u 21299 &> out/wt50-10m-71.out
julia src/run.jl instances/WT50-10m/wt50-10m-76.txt -u 1 &> out/wt50-10m-76.out
julia src/run.jl instances/WT50-10m/wt50-10m-81.txt -u 931 &> out/wt50-10m-81.out
julia src/run.jl instances/WT50-10m/wt50-10m-86.txt -u 6691 &> out/wt50-10m-86.out
julia src/run.jl instances/WT50-10m/wt50-10m-91.txt -u 14484 &> out/wt50-10m-91.out
julia src/run.jl instances/WT50-10m/wt50-10m-96.txt -u 25101 &> out/wt50-10m-96.out
julia src/run.jl instances/WT50-10m/wt50-10m-101.txt -u 71 &> out/wt50-10m-101.out
# julia src/run.jl instances/WT50-10m/wt50-10m-106.txt -u 841 &> out/wt50-10m-106.out   (not solved in 10 minutes, November 2026; lower bound 828)
julia src/run.jl instances/WT50-10m/wt50-10m-111.txt -u 7532 &> out/wt50-10m-111.out
julia src/run.jl instances/WT50-10m/wt50-10m-116.txt -u 7016 &> out/wt50-10m-116.out
julia src/run.jl instances/WT50-10m/wt50-10m-121.txt -u 13342 &> out/wt50-10m-121.out
