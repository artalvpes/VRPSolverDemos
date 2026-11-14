# Same instances and upper bounds as classic.batch, one Julia process per instance (run from the GAP folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl data/Classic/gapD-5-100.txt -u 6354 --cfg config/GAP_Classic.cfg &> out/gapD-5-100.out
julia src/run.jl data/Classic/gapD-5-200.txt -u 12743 --cfg config/GAP_Classic.cfg &> out/gapD-5-200.out
julia src/run.jl data/Classic/gapD-10-100.txt -u 6348 --cfg config/GAP_Classic.cfg &> out/gapD-10-100.out
# julia src/run.jl data/Classic/gapD-10-200.txt -u 12431 --cfg config/GAP_Classic.cfg &> out/gapD-10-200.out   (not solved in 10 minutes, November 2026; solved in 30 minutes, see CLASSIC_RESULTS.md)
julia src/run.jl data/Classic/gapD-20-100.txt -u 6186 --cfg config/GAP_Classic.cfg &> out/gapD-20-100.out
# julia src/run.jl data/Classic/gapD-20-200.txt -u 12245 --cfg config/GAP_Classic.cfg &> out/gapD-20-200.out
