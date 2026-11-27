# VRPSolverDemos

**Requirements:** Linux or MacOS (use [Docker](https://www.docker.com) or [WSL](https://learn.microsoft.com/en-gb/windows/wsl/) to run in Windows), [Julia](https://julialang.org) version 1.6 or greater, and a [VRPSolver](https://vrpsolver.math.u-bordeaux.fr)-library binary file that shall be generated locally following the instructions from the web site.

**Running the CVRP demo:** The environment variable `BAPCOD_RCSP_LIB` should be set with the path to the VRPSolver-library binary file (including its name) whenever you run this demo. Then, inside the subdirectory CVRP of the directory where you cloned this repository, just type `julia src/run.jl data/A/A-n37-k6.vrp -m 6 -M 6 -u 950` to solve a small classical CVRP instance providing an initial upper bound.

**Regression tests:** A small regression test suite is available under `tests/`. It runs selected instances from the demos and checks the reported optimality flag and objective value against reference values listed in `tests/cases.toml`. To test the local development version of `VrpSolver.jl`, run `julia tests/regression.jl --source dev` from the repository root. To test a specific GitHub branch of `VrpSolver.jl`, run `julia tests/regression.jl --source <branch-name>`. A single demo can be tested with `--demo`, e.g., `julia tests/regression.jl --source dev --demo CVRP`. Use `julia tests/regression.jl --help` for details on adding new cases.

**Upper bounds:** a good upper bound (option `--ub`/`-u`) is very important for the performance of the branch-cut-and-price. When no upper bound is given, the demos run a simple primal heuristic (`src/heuristic.jl`; option `--noheur` to disable it) and use its cost + 1 (or + the smallest cost step) as the upper bound. The option `--tentative`/`-T DELTA1 DELTA2` (also `-t` in the demos without TikZ figures) solves the root node first, giving its lower bound LB, and then the problem with the upper bounds LB + DELTA1, LB + DELTA1 + DELTA2, LB + DELTA1 + 2 DELTA2, ... until a solution is found; at the end it prints a valid lower bound, also when the last run stops at the time limit. The batch files give the optimal cost + 1 as upper bound, for the instances solved in a reasonable time; the harder ones are commented out.

**C++ demos:** the CVRP and P||ΣwjTj demos also exist in C++, written with the C++ interface of BaPCod
(`CVRP/cpp`, `P_wjTj/cpp`): the same command line, configuration files and outputs as the Julia demos, without the
start time of Julia. They are built with CMake against an installed BaPCod; see their `README.md`.

**Quick test:** `bash quick_test.sh`, from the root of this repository, solves one small instance of each demo (each in a few seconds, plus the start of Julia) and prints a summary; set `CCVRP_LIB` to include the CCVRP demo, which needs a library built with its custom resource (see `CCVRP/README.md`). Each demo folder has its own `README.md`.

**Acknowledgements:** These demos use the Julia interface [VrpSolver.jl](https://github.com/tbulhoes/VrpSolver.jl) developed jointly with Teobaldo Bulhões by his initiative.

**Reporting issues:** When reporting bugs, please choose examples as small as possible, provide the necessary data to reproduce the issue, and describe the expected behavior (the optimal solution and its cost, for example).
