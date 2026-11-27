# P||ΣwjTj demo in C++

The same demo as the Julia one in the parent folder, written with the C++ interface of BaPCod instead of VrpSolver.jl:
the same model (the time-indexed graph, the branching on y, the extended capacity cuts by a cut callback), the same
command line, the same configuration file (`config/PwjTj.cfg`) and the same outputs (the `statistics:` line, the
schedules, the solution file of `-o`). It starts at once, where Julia takes about 10 seconds to load its packages, and
it builds the model directly in BaPCod: the Julia demo first builds a JuMP model with one variable per arc of the
graph, and its cut callback reads the values of all of them at each call.

```
julia src/run.jl instances/WT40-4m/wt40-4m-1.txt -u 440       # Julia
cpp/build/bin/PwjTjDemo instances/WT40-4m/wt40-4m-1.txt -u 440 # C++
```

The C++ code mirrors the Julia one:

| C++ | Julia | Content |
|---|---|---|
| `src/App.cpp` | `parse_commandline` | the command line options |
| `src/Data.cpp` | `src/data.jl` | the instance reader |
| `src/Model.cpp` | `src/model.jl` | the graph and the model, built as VrpSolver.jl builds it in BaPCod |
| `src/Cuts.cpp` | `src/cuts.jl` | the extended capacity cut separator (cut callback) |
| `src/Heuristic.cpp` | `src/heuristic.jl` | the heuristic that gives the upper bound without `-u` |
| `src/Solver.cpp` | `solve_pwjtj`, `solve_pwjtj_tentative` | a VRPSolver run, the tentative upper bounds |
| `src/Solution.cpp` | `src/solution.jl` | schedules from x, checker, solution file |
| `src/Main.cpp` | `run_pwjtj`, `main` | the main program, batches |

## Building

The demo is built against an installed BaPCod with the VRPSolver extension (RCSP). From the BaPCod folder (the one of
`Scripts/install_bapcod.sh`), after BaPCod was built:

```bash
cmake --install build/Bapcod --prefix $HOME/bapcod-install
```

Then, with the paths of the BaPCod build (the same as for `install_bapcod.sh`):

```bash
export BAPCOD_ROOT=$HOME/bapcod-install
export BOOST_ROOT=<BaPCod folder>/Tools/boost_1_88_0/build
export LEMON_ROOT=<BaPCod folder>/Tools/lemon-1.3.1/build
export CPLEX_ROOT=<CPLEX Studio folder>
cd <VRPSolverDemos>/P_wjTj/cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

The program is `cpp/build/bin/PwjTjDemo`.

## Running

From the `P_wjTj` folder, with the arguments of the Julia demo:

```bash
cpp/build/bin/PwjTjDemo instances/WT40-4m/wt40-4m-1.txt -u 440               # with an upper bound
cpp/build/bin/PwjTjDemo instances/toy/wt10-2m-3.txt                          # the heuristic gives the upper bound
cpp/build/bin/PwjTjDemo instances/WT40-4m/wt40-4m-1.txt -T 1 1               # tentative upper bounds
cpp/build/bin/PwjTjDemo instances/WT40-4m/wt40-4m-1.txt -u 440 -o wt40-4m-1.sol
cpp/build/bin/PwjTjDemo -b wt40-4m.batch &> out/wt40-4m.out                  # a whole batch
cpp/build/bin/PwjTjDemo -h                                                   # the options
```

Differences with the Julia demo:

- The nodes of the graph and the arcs of type 1 and 2 are numbered as in Julia; the arcs to the sink are created in the
  order of the node numbers (Julia takes them in the order of a `Dict`). The solver may then take other (equivalent)
  decisions: the costs are the same, the number of nodes and the times may differ a little.
- The iterated local search of the heuristic uses the random numbers of C++, not those of Julia: without `-u`, the
  heuristic may give another upper bound (the construction and the first local searches are the same).
- `--update` does nothing.
