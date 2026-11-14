# Upper bounds are optimal costs + 1 (optima found by this demo, November 2026).
# Classes: vc (stock cost 7000*(W/10000)^0.8) and zc (stock cost 0), one instance per class for n = 20, 30, ..., 60, plus zc_K5_n100_u4_s1.
# Not included: vc_K5_n100_u11_s1, not solved within 30 minutes (best bound 225968, best solution 226057).
# Same instances and upper bounds as test.batch, one Julia process per instance (run from the VSBPP folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl data/test/vc_K5_n20_u1_s1.txt -u 45271 &> out/vc_K5_n20_u1_s1.out
julia src/run.jl data/test/zc_K5_n20_u1_s1.txt -u 16067 &> out/zc_K5_n20_u1_s1.out
julia src/run.jl data/test/vc_K3_n30_u3_s1.txt -u 67122 &> out/vc_K3_n30_u3_s1.out
julia src/run.jl data/test/zc_K5_n30_u1_s1.txt -u 44260 &> out/zc_K5_n30_u1_s1.out
julia src/run.jl data/test/vc_K4_n40_u3_s1.txt -u 89720 &> out/vc_K4_n40_u3_s1.out
julia src/run.jl data/test/zc_K5_n40_u2_s1.txt -u 33090 &> out/zc_K5_n40_u2_s1.out
julia src/run.jl data/test/vc_K5_n50_u11_s1.txt -u 106210 &> out/vc_K5_n50_u11_s1.out
julia src/run.jl data/test/zc_K5_n50_u2_s1.txt -u 63149 &> out/zc_K5_n50_u2_s1.out
julia src/run.jl data/test/vc_K5_n60_u4_s1.txt -u 134411 &> out/vc_K5_n60_u4_s1.out
julia src/run.jl data/test/zc_K5_n60_u2_s1.txt -u 94338 &> out/zc_K5_n60_u2_s1.out
julia src/run.jl data/test/zc_K5_n100_u4_s1.txt -u 141224 &> out/zc_K5_n100_u4_s1.out
