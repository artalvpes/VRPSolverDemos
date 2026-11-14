# Upper bounds are optimal costs + 1 (optima found by this demo, November 2026). wt40-10m-76 has optimum 0.
# Same instances and upper bounds as wt40-10m.batch, one Julia process per instance (run from the P_wjTj folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl instances/WT40-10m/wt40-10m-1.txt -u 502 &> out/wt40-10m-1.out
julia src/run.jl instances/WT40-10m/wt40-10m-6.txt -u 1585 &> out/wt40-10m-6.out
julia src/run.jl instances/WT40-10m/wt40-10m-11.txt -u 3930 &> out/wt40-10m-11.out
julia src/run.jl instances/WT40-10m/wt40-10m-16.txt -u 11988 &> out/wt40-10m-16.out
julia src/run.jl instances/WT40-10m/wt40-10m-21.txt -u 12061 &> out/wt40-10m-21.out
julia src/run.jl instances/WT40-10m/wt40-10m-26.txt -u 209 &> out/wt40-10m-26.out
julia src/run.jl instances/WT40-10m/wt40-10m-31.txt -u 2137 &> out/wt40-10m-31.out
julia src/run.jl instances/WT40-10m/wt40-10m-36.txt -u 4941 &> out/wt40-10m-36.out
julia src/run.jl instances/WT40-10m/wt40-10m-41.txt -u 10305 &> out/wt40-10m-41.out
julia src/run.jl instances/WT40-10m/wt40-10m-46.txt -u 10349 &> out/wt40-10m-46.out
julia src/run.jl instances/WT40-10m/wt40-10m-51.txt -u 243 &> out/wt40-10m-51.out
julia src/run.jl instances/WT40-10m/wt40-10m-56.txt -u 723 &> out/wt40-10m-56.out
julia src/run.jl instances/WT40-10m/wt40-10m-61.txt -u 5770 &> out/wt40-10m-61.out
julia src/run.jl instances/WT40-10m/wt40-10m-66.txt -u 11644 &> out/wt40-10m-66.out
julia src/run.jl instances/WT40-10m/wt40-10m-71.txt -u 14291 &> out/wt40-10m-71.out
julia src/run.jl instances/WT40-10m/wt40-10m-76.txt -u 1 &> out/wt40-10m-76.out
julia src/run.jl instances/WT40-10m/wt40-10m-81.txt -u 1416 &> out/wt40-10m-81.out
julia src/run.jl instances/WT40-10m/wt40-10m-86.txt -u 4920 &> out/wt40-10m-86.out
julia src/run.jl instances/WT40-10m/wt40-10m-91.txt -u 9662 &> out/wt40-10m-91.out
julia src/run.jl instances/WT40-10m/wt40-10m-96.txt -u 18581 &> out/wt40-10m-96.out
julia src/run.jl instances/WT40-10m/wt40-10m-101.txt -u 121 &> out/wt40-10m-101.out
julia src/run.jl instances/WT40-10m/wt40-10m-106.txt -u 809 &> out/wt40-10m-106.out
julia src/run.jl instances/WT40-10m/wt40-10m-111.txt -u 7767 &> out/wt40-10m-111.out
julia src/run.jl instances/WT40-10m/wt40-10m-116.txt -u 9855 &> out/wt40-10m-116.out
julia src/run.jl instances/WT40-10m/wt40-10m-121.txt -u 18815 &> out/wt40-10m-121.out
