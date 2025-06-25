# VRPSolverDemos

**Requirements:** Linux or MacOS (use [Docker](https://www.docker.com) or [WSL](https://learn.microsoft.com/en-gb/windows/wsl/) to run in Windows), [Julia](https://julialang.org) version 1.6 or greater with [CPLEX](https://www.ibm.com/br-pt/products/ilog-cplex-optimization-studio) properly installed (see instructions below), and a [VRPSolver](https://vrpsolver.math.u-bordeaux.fr)-library binary file that can be downloaded from [here](https://drive.google.com/drive/folders/15hRXyZljTOQJVGqNQnhrEpgjGxcP41V5?usp=sharing).

**CPLEX installation on Julia:** The environment variable `CPLEX_STUDIO_BINARIES` should be set with the path to the CPLEX binaries folder before running this demo for the first time. To test this installation, please enter the Julia REPL (type `julia` in a terminal window) and type `]` (without `Enter`), and then `add CPLEX`, and `build`. If no error occurs, you are ready.

**Running the demo:** The environment variable `BAPCOD_RCSP_LIB` should be set with the path to the VRPSolver-library binary file (including its name) whenever you run this demo. Then, inside the directory where you cloned this repository, just type `julia src/run.jl data/A/A-n37-k6.vrp -m 6 -M 6 -u 950` to solve a small classical CVRP instance providing an initial upper bound.

**Reporting issues:** This is an ongoing work. Even the original VRPSolver interface is not complete. I am waiting for nice examples from you to implement and test the features that are missing and fix bugs. So, when reporting bugs, please choose examples as small as possible, provide the necessary data to reproduce the issue, and describe the expected behavior (the optimal solution and its cost, for example).
