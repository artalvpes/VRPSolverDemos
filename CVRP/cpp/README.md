# CVRP demo in C++

The same demo as the Julia one in the parent folder, written with the C++ interface of BaPCod instead of VrpSolver.jl:
the same model, the same command line, the same configuration file (`config/CVRP.cfg`) and the same outputs (the
`statistics:` line, the routes, the solution file of `-o` and the TikZ figure of `-t`). It starts in a fraction of a
second, where Julia takes about 10 seconds to load its packages:

```
julia src/run.jl data/A/A-n55-k9.vrp -m 9 -M 9 -u 1074      # 10.8 s, of which 1.0 s in the solver
cpp/build/bin/CVRPDemo data/A/A-n55-k9.vrp -m 9 -M 9 -u 1074 # 0.6 s
```

The C++ code mirrors the Julia one:

| C++ | Julia | Content |
|---|---|---|
| `src/App.cpp` | `parse_commandline` | the command line options |
| `src/Data.cpp` | `src/data.jl` | the CVRPLIB reader (with `DISTANCE` and `SERVICE_TIME`) |
| `src/Model.cpp` | `src/model.jl`, `src/branching.jl` | the model, built as VrpSolver.jl builds it in BaPCod |
| `src/Solver.cpp` | `solve_cvrp`, `solve_cvrp_tentative` | a VRPSolver run, the tentative upper bounds |
| `src/Solution.cpp` | `src/solution.jl` | routes from x, checkers, solution files, TikZ figure |
| `src/HGS.cpp` | `src/hgs.jl` | the interface to HGS-CVRP |
| `src/Main.cpp` | `run_cvrp`, `main` | the main program, batches |

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
cd <VRPSolverDemos>/CVRP/cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

The program is `cpp/build/bin/CVRPDemo`. (The same `CMakeLists.txt` also builds the demo inside the BaPCod tree, if
the folder is copied to `Applications/` and added to `Applications/CMakeLists.txt`.)

## Running

From the `CVRP` folder, with the arguments of the Julia demo:

```bash
cpp/build/bin/CVRPDemo data/A/A-n37-k6.vrp -m 6 -M 6 -u 950                  # with an upper bound
cpp/build/bin/CVRPDemo data/A/A-n37-k6.vrp -m 6 -M 6 -T 1 1                  # tentative upper bounds
cpp/build/bin/CVRPDemo data/A/A-n37-k6.vrp -m 6 -M 6 -u 950 -o A-n37-k6.sol -t A-n37-k6.tex
cpp/build/bin/CVRPDemo -b A.batch &> out/A.out                               # a whole batch
cpp/build/bin/CVRPDemo -h                                                    # the options
```

Differences with the Julia demo:

- **No heuristic of its own.** Without `-u`, `-s` or `-T`, the upper bound is 10^7 (as with `--noheur` in Julia),
  unless HGS-CVRP is used (below). `--noheur` is accepted and does nothing.
- `-f` (show the complete formulation, solved with HiGHS through JuMP) is not available; `--update` does nothing.
- `-k` (strong k-path cuts) stops with the same error as in Julia: VrpSolver currently disables these cuts.

## HGS-CVRP

With `--hgs`, HGS-CVRP (Vidal 2022, <https://github.com/vidalt/HGS-CVRP>) gives the upper bound, as `--hgs` of the
Julia demo: by default when neither `-u` nor `-T` is given, and always with `-H`. Its cost is the upper bound; if the
solver proves that there is no cheaper solution, the HGS solution is optimal and is the answer. `--heur_time` (default
min(20, 2 + 0.1 n) s), `--heur_seed` (default 1) and `--heur_neighbors` (its granular neighbourhood, default 20) are its
parameters. HGS-CVRP is loaded at run time, so the demo builds and runs without it. To use it:

```bash
git clone https://github.com/vidalt/HGS-CVRP.git
cd HGS-CVRP && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --target lib
export HGS_CVRP_LIB=$PWD/build/libhgscvrp.so        # libhgscvrp.dylib on macOS
```

```bash
cpp/build/bin/CVRPDemo data/A/A-n37-k6.vrp -m 6 -M 6 --hgs --heur_time 3
```
