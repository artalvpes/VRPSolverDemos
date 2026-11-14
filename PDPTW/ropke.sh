# Running instances of "Ropke, S., Cordeau, J.F.: Branch and cut and price for the pickup and delivery problem with time windows.  Transportation Science 43(3), 267–286 (2009)
# Same instances and upper bounds as ropke.batch, one Julia process per instance (run from the PDPTW folder);
# the instances commented out in the batch are commented out here.
mkdir -p out sol tex
julia src/run.jl data/Ropke/AA30.txt -m 1 -M 3 -u 31119.2 --fixed 10000 -o sol/AA30.sol -t tex/AA30.tex &> out/AA30.out
julia src/run.jl data/Ropke/AA35.txt -m 1 -M 3 -u 31299.9 --fixed 10000 -o sol/AA35.sol -t tex/AA35.tex &> out/AA35.out
julia src/run.jl data/Ropke/AA40.txt -m 1 -M 3 -u 31516.0 --fixed 10000 -o sol/AA40.sol -t tex/AA40.tex &> out/AA40.out
julia src/run.jl data/Ropke/AA45.txt -m 1 -M 3 -u 31759.9 --fixed 10000 -o sol/AA45.sol -t tex/AA45.tex &> out/AA45.out
julia src/run.jl data/Ropke/AA50.txt -m 1 -M 4 -u 41775.1 --fixed 10000 -o sol/AA50.sol -t tex/AA50.tex &> out/AA50.out
julia src/run.jl data/Ropke/AA55.txt -m 1 -M 4 -u 41907.9 --fixed 10000 -o sol/AA55.sol -t tex/AA55.tex &> out/AA55.out
julia src/run.jl data/Ropke/AA60.txt -m 1 -M 4 -u 42140.8 --fixed 10000 -o sol/AA60.sol -t tex/AA60.tex &> out/AA60.out
julia src/run.jl data/Ropke/AA65.txt -m 1 -M 4 -u 42250.3 --fixed 10000 -o sol/AA65.sol -t tex/AA65.tex &> out/AA65.out
julia src/run.jl data/Ropke/AA70.txt -m 1 -M 4 -u 42452.4 --fixed 10000 -o sol/AA70.sol -t tex/AA70.tex &> out/AA70.out
julia src/run.jl data/Ropke/AA75.txt -m 1 -M 5 -u 52461.7 --fixed 10000 -o sol/AA75.sol -t tex/AA75.tex &> out/AA75.out
julia src/run.jl data/Ropke/BB30.txt -m 1 -M 3 -u 31086.4 --fixed 10000 -o sol/BB30.sol -t tex/BB30.tex &> out/BB30.out
julia src/run.jl data/Ropke/BB35.txt -m 1 -M 3 -u 31281.3 --fixed 10000 -o sol/BB35.sol -t tex/BB35.tex &> out/BB35.out
julia src/run.jl data/Ropke/BB40.txt -m 1 -M 3 -u 31493.5 --fixed 10000 -o sol/BB40.sol -t tex/BB40.tex &> out/BB40.out
julia src/run.jl data/Ropke/BB45.txt -m 1 -M 4 -u 41555.2 --fixed 10000 -o sol/BB45.sol -t tex/BB45.tex &> out/BB45.out
julia src/run.jl data/Ropke/BB50.txt -m 1 -M 4 -u 41701.1 --fixed 10000 -o sol/BB50.sol -t tex/BB50.tex &> out/BB50.out
julia src/run.jl data/Ropke/BB55.txt -m 1 -M 4 -u 41885.8 --fixed 10000 -o sol/BB55.sol -t tex/BB55.tex &> out/BB55.out
julia src/run.jl data/Ropke/BB60.txt -m 1 -M 6 -u 62420.2 --fixed 10000 -o sol/BB60.sol -t tex/BB60.tex &> out/BB60.out
julia src/run.jl data/Ropke/BB65.txt -m 1 -M 6 -u 62639.2 --fixed 10000 -o sol/BB65.sol -t tex/BB65.tex &> out/BB65.out
julia src/run.jl data/Ropke/BB70.txt -m 1 -M 6 -u 62951.1 --fixed 10000 -o sol/BB70.sol -t tex/BB70.tex &> out/BB70.out
julia src/run.jl data/Ropke/BB75.txt -m 1 -M 6 -u 63127.6 --fixed 10000 -o sol/BB75.sol -t tex/BB75.tex &> out/BB75.out
julia src/run.jl data/Ropke/CC30.txt -m 1 -M 3 -u 31087.8 --fixed 10000 -o sol/CC30.sol -t tex/CC30.tex &> out/CC30.out
julia src/run.jl data/Ropke/CC35.txt -m 1 -M 3 -u 31230.7 --fixed 10000 -o sol/CC35.sol -t tex/CC35.tex &> out/CC35.out
julia src/run.jl data/Ropke/CC40.txt -m 1 -M 3 -u 31358.6 --fixed 10000 -o sol/CC40.sol -t tex/CC40.tex &> out/CC40.out
julia src/run.jl data/Ropke/CC45.txt -m 1 -M 3 -u 31509.2 --fixed 10000 -o sol/CC45.sol -t tex/CC45.tex &> out/CC45.out
julia src/run.jl data/Ropke/CC50.txt -m 1 -M 4 -u 41685.4 --fixed 10000 -o sol/CC50.sol -t tex/CC50.tex &> out/CC50.out
julia src/run.jl data/Ropke/CC55.txt -m 1 -M 4 -u 41836.4 --fixed 10000 -o sol/CC55.sol -t tex/CC55.tex &> out/CC55.out
julia src/run.jl data/Ropke/CC60.txt -m 1 -M 4 -u 42009.4 --fixed 10000 -o sol/CC60.sol -t tex/CC60.tex &> out/CC60.out
julia src/run.jl data/Ropke/CC65.txt -m 1 -M 4 -u 42164.1 --fixed 10000 -o sol/CC65.sol -t tex/CC65.tex &> out/CC65.out
# julia src/run.jl data/Ropke/CC70.txt -m 1 -M 5 -u 52202.0 --fixed 10000 -o sol/CC70.sol -t tex/CC70.tex &> out/CC70.out   (not solved in 10 minutes, November 2026; lower bound 42444.52)
julia src/run.jl data/Ropke/CC75.txt -m 1 -M 5 -u 52362.5 --fixed 10000 -o sol/CC75.sol -t tex/CC75.tex &> out/CC75.out
julia src/run.jl data/Ropke/DD30.txt -m 1 -M 2 -u 21133.4 --fixed 10000 -o sol/DD30.sol -t tex/DD30.tex &> out/DD30.out
julia src/run.jl data/Ropke/DD35.txt -m 1 -M 3 -u 31211.0 --fixed 10000 -o sol/DD35.sol -t tex/DD35.tex &> out/DD35.out
julia src/run.jl data/Ropke/DD40.txt -m 1 -M 3 -u 31352.3 --fixed 10000 -o sol/DD40.sol -t tex/DD40.tex &> out/DD40.out
julia src/run.jl data/Ropke/DD45.txt -m 1 -M 3 -u 31484.0 --fixed 10000 -o sol/DD45.sol -t tex/DD45.tex &> out/DD45.out
julia src/run.jl data/Ropke/DD50.txt -m 1 -M 3 -u 31601.0 --fixed 10000 -o sol/DD50.sol -t tex/DD50.tex &> out/DD50.out
julia src/run.jl data/Ropke/DD55.txt -m 1 -M 3 -u 31743.4 --fixed 10000 -o sol/DD55.sol -t tex/DD55.tex &> out/DD55.out
# julia src/run.jl data/Ropke/DD60.txt -m 1 -M 3 --fixed 10000 -o sol/DD60.sol -t tex/DD60.tex &> out/DD60.out   (K = 3 vehicles: the previous line, with -M 4 and -u 41869.5, gave a solution with 4 vehicles; not solved in 10 minutes, November 2026; lower bound 32001.43, no solution found)
julia src/run.jl data/Ropke/DD65.txt -m 1 -M 4 -u 42107.4 --fixed 10000 -o sol/DD65.sol -t tex/DD65.tex &> out/DD65.out
# julia src/run.jl data/Ropke/DD70.txt -m 1 -M 4 -u 42220.4 --fixed 10000 -o sol/DD70.sol -t tex/DD70.tex &> out/DD70.out   (not solved in 10 minutes, November 2026; lower bound 42213.77)
# julia src/run.jl data/Ropke/DD75.txt -m 1 -M 4 -u 42396.9 --fixed 10000 -o sol/DD75.sol -t tex/DD75.tex &> out/DD75.out   (not solved in 10 minutes, November 2026; lower bound 42352.91)
