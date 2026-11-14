mkdir -p out
julia src/run.jl data/toy/toy1.txt -u 9 &> out/toy1.out
julia src/run.jl data/toy/toy2.txt &> out/toy2.out
julia src/run.jl data/toy/toy3.txt &> out/toy3.out
julia src/run.jl data/toy/toy4.txt &> out/toy4.out
julia src/run.jl data/toy/toy5.txt &> out/toy5.out
