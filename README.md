# VRPSolverDemos

**Requirements:** Linux or MacOS (use [Docker](https://www.docker.com) or [WSL](https://learn.microsoft.com/en-gb/windows/wsl/) to run in Windows), [Julia](https://julialang.org) version 1.6 or greater, and a [VRPSolver](https://vrpsolver.math.u-bordeaux.fr)-library binary file that shall be generated locally following the instructions from the web site.

**Running the demo:** The environment variable `BAPCOD_RCSP_LIB` should be set with the path to the VRPSolver-library binary file (including its name) whenever you run this demo. Then, inside the directory where you cloned this repository, just type `julia src/run.jl data/A/A-n37-k6.vrp -m 6 -M 6 -u 950` to solve a small classical CVRP instance providing an initial upper bound.

**Reporting issues:** This is an ongoing work. Even the original VRPSolver interface is not complete. I am waiting for nice examples from you to implement and test the features that are missing and fix bugs. So, when reporting bugs, please choose examples as small as possible, provide the necessary data to reproduce the issue, and describe the expected behavior (the optimal solution and its cost, for example).
