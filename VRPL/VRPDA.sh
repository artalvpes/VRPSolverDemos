# All VRPDA instances, each customer assigned to one of its 3 nearest lockers (default)
# Same instances and upper bounds as VRPDA.batch, one Julia process per instance (run from the VRPL folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl data/VRPDA/s10k20_1.vdap &> out/s10k20_1.out
julia src/run.jl data/VRPDA/s10k20_2.vdap &> out/s10k20_2.out
julia src/run.jl data/VRPDA/s10k20_3.vdap &> out/s10k20_3.out
julia src/run.jl data/VRPDA/s10k20_4.vdap &> out/s10k20_4.out
julia src/run.jl data/VRPDA/s10k20_5.vdap &> out/s10k20_5.out
julia src/run.jl data/VRPDA/s10k30_1.vdap &> out/s10k30_1.out
julia src/run.jl data/VRPDA/s10k30_2.vdap &> out/s10k30_2.out
julia src/run.jl data/VRPDA/s10k30_3.vdap &> out/s10k30_3.out
julia src/run.jl data/VRPDA/s10k30_4.vdap &> out/s10k30_4.out
julia src/run.jl data/VRPDA/s10k30_5.vdap &> out/s10k30_5.out
julia src/run.jl data/VRPDA/s10k40_1.vdap &> out/s10k40_1.out
julia src/run.jl data/VRPDA/s10k40_2.vdap &> out/s10k40_2.out
# julia src/run.jl data/VRPDA/s10k40_3.vdap &> out/s10k40_3.out   (not solved in 10 minutes, November 2026; lower bound 1609.98)
julia src/run.jl data/VRPDA/s10k40_4.vdap &> out/s10k40_4.out
julia src/run.jl data/VRPDA/s10k40_5.vdap &> out/s10k40_5.out
julia src/run.jl data/VRPDA/s10k50_1.vdap &> out/s10k50_1.out
# julia src/run.jl data/VRPDA/s10k50_2.vdap &> out/s10k50_2.out   (not solved in 10 minutes, November 2026; lower bound 1877.24)
julia src/run.jl data/VRPDA/s10k50_3.vdap &> out/s10k50_3.out
julia src/run.jl data/VRPDA/s10k50_4.vdap &> out/s10k50_4.out
julia src/run.jl data/VRPDA/s10k50_5.vdap &> out/s10k50_5.out
julia src/run.jl data/VRPDA/s25k20_1.vdap &> out/s25k20_1.out
julia src/run.jl data/VRPDA/s25k20_2.vdap &> out/s25k20_2.out
julia src/run.jl data/VRPDA/s25k20_3.vdap &> out/s25k20_3.out
julia src/run.jl data/VRPDA/s25k20_4.vdap &> out/s25k20_4.out
julia src/run.jl data/VRPDA/s25k20_5.vdap &> out/s25k20_5.out
julia src/run.jl data/VRPDA/s25k30_1.vdap &> out/s25k30_1.out
julia src/run.jl data/VRPDA/s25k30_2.vdap &> out/s25k30_2.out
julia src/run.jl data/VRPDA/s25k30_3.vdap &> out/s25k30_3.out
julia src/run.jl data/VRPDA/s25k30_4.vdap &> out/s25k30_4.out
julia src/run.jl data/VRPDA/s25k30_5.vdap &> out/s25k30_5.out
julia src/run.jl data/VRPDA/s25k40_1.vdap &> out/s25k40_1.out
julia src/run.jl data/VRPDA/s25k40_2.vdap &> out/s25k40_2.out
julia src/run.jl data/VRPDA/s25k40_3.vdap &> out/s25k40_3.out
julia src/run.jl data/VRPDA/s25k40_4.vdap &> out/s25k40_4.out
julia src/run.jl data/VRPDA/s25k40_5.vdap &> out/s25k40_5.out
julia src/run.jl data/VRPDA/s25k50_1.vdap &> out/s25k50_1.out
julia src/run.jl data/VRPDA/s25k50_2.vdap &> out/s25k50_2.out
julia src/run.jl data/VRPDA/s25k50_3.vdap &> out/s25k50_3.out
julia src/run.jl data/VRPDA/s25k50_4.vdap &> out/s25k50_4.out
julia src/run.jl data/VRPDA/s25k50_5.vdap &> out/s25k50_5.out
julia src/run.jl data/VRPDA/s35k40_1.vdap &> out/s35k40_1.out
julia src/run.jl data/VRPDA/s35k40_2.vdap &> out/s35k40_2.out
julia src/run.jl data/VRPDA/s35k40_3.vdap &> out/s35k40_3.out
julia src/run.jl data/VRPDA/s35k40_4.vdap &> out/s35k40_4.out
julia src/run.jl data/VRPDA/s35k40_5.vdap &> out/s35k40_5.out
julia src/run.jl data/VRPDA/s35k50_1.vdap &> out/s35k50_1.out
julia src/run.jl data/VRPDA/s35k50_2.vdap &> out/s35k50_2.out
julia src/run.jl data/VRPDA/s35k50_3.vdap &> out/s35k50_3.out
julia src/run.jl data/VRPDA/s35k50_4.vdap &> out/s35k50_4.out
julia src/run.jl data/VRPDA/s35k50_5.vdap &> out/s35k50_5.out
julia src/run.jl data/VRPDA/s35k60_1.vdap &> out/s35k60_1.out
julia src/run.jl data/VRPDA/s35k60_2.vdap &> out/s35k60_2.out
julia src/run.jl data/VRPDA/s35k60_3.vdap &> out/s35k60_3.out
julia src/run.jl data/VRPDA/s35k60_4.vdap &> out/s35k60_4.out
julia src/run.jl data/VRPDA/s35k60_5.vdap &> out/s35k60_5.out
# julia src/run.jl data/VRPDA/s35k70_1.vdap &> out/s35k70_1.out   (not solved in 10 minutes, November 2026; lower bound 1753.92)
julia src/run.jl data/VRPDA/s35k70_2.vdap &> out/s35k70_2.out
julia src/run.jl data/VRPDA/s35k70_3.vdap &> out/s35k70_3.out
# julia src/run.jl data/VRPDA/s35k70_4.vdap &> out/s35k70_4.out   (not solved in 10 minutes, November 2026; lower bound 1682.42)
julia src/run.jl data/VRPDA/s35k70_5.vdap &> out/s35k70_5.out
julia src/run.jl data/VRPDA/s40k50_1.vdap &> out/s40k50_1.out
julia src/run.jl data/VRPDA/s40k50_2.vdap &> out/s40k50_2.out
julia src/run.jl data/VRPDA/s40k50_3.vdap &> out/s40k50_3.out
julia src/run.jl data/VRPDA/s40k50_4.vdap &> out/s40k50_4.out
julia src/run.jl data/VRPDA/s40k50_5.vdap &> out/s40k50_5.out
# julia src/run.jl data/VRPDA/s40k60_1.vdap &> out/s40k60_1.out   (not solved in 10 minutes, November 2026; lower bound 1455.37)
julia src/run.jl data/VRPDA/s40k60_2.vdap &> out/s40k60_2.out
julia src/run.jl data/VRPDA/s40k60_3.vdap &> out/s40k60_3.out
julia src/run.jl data/VRPDA/s40k60_4.vdap &> out/s40k60_4.out
julia src/run.jl data/VRPDA/s40k60_5.vdap &> out/s40k60_5.out
julia src/run.jl data/VRPDA/s40k70_1.vdap &> out/s40k70_1.out
julia src/run.jl data/VRPDA/s40k70_2.vdap &> out/s40k70_2.out
# julia src/run.jl data/VRPDA/s40k70_3.vdap &> out/s40k70_3.out   (not solved in 10 minutes, November 2026; lower bound 1639.21)
julia src/run.jl data/VRPDA/s40k70_4.vdap &> out/s40k70_4.out
julia src/run.jl data/VRPDA/s40k70_5.vdap &> out/s40k70_5.out
# julia src/run.jl data/VRPDA/s40k80_1.vdap &> out/s40k80_1.out   (not solved in 10 minutes, November 2026; lower bound 1866.79)
# julia src/run.jl data/VRPDA/s40k80_2.vdap &> out/s40k80_2.out   (not solved in 10 minutes, November 2026; lower bound 1816.29)
# julia src/run.jl data/VRPDA/s40k80_3.vdap &> out/s40k80_3.out   (not solved in 10 minutes, November 2026; lower bound 1909.98)
julia src/run.jl data/VRPDA/s40k80_4.vdap &> out/s40k80_4.out
julia src/run.jl data/VRPDA/s40k80_5.vdap &> out/s40k80_5.out
julia src/run.jl data/VRPDA/s50k60_1.vdap &> out/s50k60_1.out
# julia src/run.jl data/VRPDA/s50k60_2.vdap &> out/s50k60_2.out   (not solved in 10 minutes, November 2026; lower bound 1407.28)
julia src/run.jl data/VRPDA/s50k60_3.vdap &> out/s50k60_3.out
julia src/run.jl data/VRPDA/s50k60_4.vdap &> out/s50k60_4.out
julia src/run.jl data/VRPDA/s50k60_5.vdap &> out/s50k60_5.out
julia src/run.jl data/VRPDA/s50k70_1.vdap &> out/s50k70_1.out
# julia src/run.jl data/VRPDA/s50k70_2.vdap &> out/s50k70_2.out   (not solved in 10 minutes, November 2026; lower bound 1586.57)
# julia src/run.jl data/VRPDA/s50k70_3.vdap &> out/s50k70_3.out   (not solved in 10 minutes, November 2026; lower bound 1622.34)
julia src/run.jl data/VRPDA/s50k70_4.vdap &> out/s50k70_4.out
julia src/run.jl data/VRPDA/s50k70_5.vdap &> out/s50k70_5.out
julia src/run.jl data/VRPDA/s50k80_1.vdap &> out/s50k80_1.out
julia src/run.jl data/VRPDA/s50k80_2.vdap &> out/s50k80_2.out
# julia src/run.jl data/VRPDA/s50k80_3.vdap &> out/s50k80_3.out   (not solved in 10 minutes, November 2026; lower bound 1854.67)
# julia src/run.jl data/VRPDA/s50k80_4.vdap &> out/s50k80_4.out   (not solved in 10 minutes, November 2026; lower bound 1749.49)
# julia src/run.jl data/VRPDA/s50k80_5.vdap &> out/s50k80_5.out   (not solved in 10 minutes, November 2026; lower bound 1736.89)
# julia src/run.jl data/VRPDA/s50k90_1.vdap &> out/s50k90_1.out   (not solved in 10 minutes, November 2026; lower bound 1932.70)
# julia src/run.jl data/VRPDA/s50k90_2.vdap &> out/s50k90_2.out   (not solved in 10 minutes, November 2026; lower bound 2052.64)
julia src/run.jl data/VRPDA/s50k90_3.vdap &> out/s50k90_3.out
# julia src/run.jl data/VRPDA/s50k90_4.vdap &> out/s50k90_4.out   (not solved in 10 minutes, November 2026; lower bound 1925.85)
# julia src/run.jl data/VRPDA/s50k90_5.vdap &> out/s50k90_5.out   (not solved in 10 minutes, November 2026; lower bound 2100.18)
