# GAP: generalized assignment problem

There are tasks T and machines K. Assigning task t to machine k costs c_tk and uses w_tk of the capacity Q_k of the
machine. Each task is assigned to exactly one machine, without exceeding the capacities; the cost is minimized.

The demo is an example of a model with **one graph per machine** (several subproblems) and of a problem that is not a
routing problem: each path is a feasible set of tasks for one machine (a knapsack solution).

## Instances

- `data/Classic`: OR-Library instances of types C and D (5 to 40 machines, 100 to 400 tasks); `classic.batch` uses the
  type D ones with up to 200 tasks.
- `data/Nauss`: 140 instances of type D of Nauss (2003), 10 for each of 14 sizes (machines × tasks: 10×225, 10×250,
  10×300, 10×400, 15×150, 15×200, 20×125, 20×150, 20×200, 20×400, 25×90, 25×100, 30×100, 40×200);
  `nauss.batch` uses the 30 with 90 or 100 tasks and 25 or 30 machines (those used by Pessoa et al. 2020).
- `data/toy2.txt`: a small instance.

## Model

```
min  Σ_t Σ_k c_tk x_tk
s.t. Σ_k x_tk = 1        t in T
```

- For each machine k, a graph with vertices 0, 1, ..., |T|; between t-1 and t, two parallel arcs: one assigns task t
  (consumes w_tk, mapped to x_tk), the other skips it. One resource, the capacity used, interval [0, Q_k]. Each graph
  gives at most one path (L = 0, U = 1).
- One packing set per task: its assignment arcs in all the graphs. This enables rank-1 cuts and the enumeration.
- Branching on x.

Configurations: `config/GAP_Classic.cfg` and `config/GAP_Nauss.cfg` (no ng-routes, since the paths are elementary by
construction; rank-1 cuts with vertex memory, which is full memory in these graphs).

## Running

From the `GAP` folder, with `BAPCOD_RCSP_LIB` set to the VRPSolver library:

```bash
julia src/run.jl data/Classic/gapD-5-100.txt -u 6354 --cfg config/GAP_Classic.cfg     # with an upper bound
julia src/run.jl data/Classic/gapD-5-100.txt --cfg config/GAP_Classic.cfg            # the heuristic gives the upper bound
julia src/run.jl data/Nauss/gapD-25-90-e0.txt -t 10 4 --cfg config/GAP_Nauss.cfg      # tentative upper bounds
julia src/run.jl data/Nauss/gapD-25-90-e0.txt -d --cfg config/GAP_Nauss.cfg           # diving heuristic at the root
julia src/run.jl -b classic.batch &> out/classic.out                                   # a whole batch in one process
bash classic.sh                                                                        # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-u` | upper bound (the solver looks for a solution of cost below it) |
| `--noheur` | without `-u`, no heuristic: no upper bound |
| `-t D1 D2` (or `-T`) | tentative upper bounds: solve the root **without** an upper bound, then try ub = LB + D1, LB + D1 + D2, ... until a solution is found |
| `-d` | diving heuristic of Pessoa et al. (2020) at the root, useful when no good upper bound is known |
| `--timelimit` | time limit in seconds of each VRPSolver run (the configs of the demo have none) |
| `-c` | configuration file |
| `-b` | batch file: one line of options per instance |

Every solution is checked against the definition of the problem (each task assigned once, capacities, cost).

Batches:

| Batch | Content |
|---|---|
| `classic.batch` | type D classic instances, ub = optimum + 1 |
| `nauss.batch` | the 30 Nauss instances of Pessoa et al. (2020), ub = optimum + 1 |
| `nauss-literature-ub.batch`, `nauss-diving.batch`, `nauss-tentative.batch` | the same 30 instances with the upper bounds of the literature, with the diving heuristic and with tentative upper bounds |
| `nauss-hard.batch` | larger Nauss instances, out of reach of an exact solution in reasonable time |

## The compact MIP, for comparison

To see what VRPSolver gains, the folder `mip/` has a script that gives the same instances to CPLEX, through JuMP,
with the textbook formulation of the GAP:

```
min  Σ_t Σ_k c_tk x_tk
s.t. Σ_k x_tk = 1             t in T   (each task goes to one machine)
     Σ_t w_tk x_tk <= Q_k     k in K   (capacity of each machine)
     x_tk in {0, 1}
```

For each instance, the script:

1. solves the LP relaxation and prints its value, the bound that CPLEX starts from (option `--nolp` skips this);
2. runs CPLEX on the MIP, with the time limit and the upper bound given;
3. checks the solution found, if any, against the definition of the problem, and prints it;
4. prints a `statistics:` line: instance, LP bound, nodes, best bound, solution (`--` if none) and time.

To run it, from the `GAP` folder:

```bash
julia mip/gap_mip.jl data/Classic/gapD-5-100.txt --ub 6354 --timelimit 60
julia mip/gap_mip.jl -b mip/classic.batch &> out/mip_classic.out      # the 6 classic instances of type D
julia mip/gap_mip.jl -b mip/nauss.batch &> out/mip_nauss.out          # the 30 Nauss instances of nauss.batch
```

| Option | Meaning |
|---|---|
| `-u` | upper bound: CPLEX only looks for solutions of cost below it, as `-u` of the demo |
| `--timelimit` | time limit in seconds (0, the default: no limit) |
| `--threads` | CPLEX threads (default 1) |
| `--nolp` | do not solve the LP relaxation first |
| `-b` | batch file: one line of options per instance |

The first run installs JuMP, CPLEX.jl and ArgParse in the environment of `mip/`; CPLEX.jl needs the environment
variable `CPLEX_STUDIO_BINARIES` (the folder of the CPLEX library, for example
`$CPLEX_ROOT/cplex/bin/x86-64_linux/`). The batches `mip/classic.batch` and `mip/nauss.batch` use the upper bounds
optimum + 1 of the demo batches (including the instances commented out there) and 60 s per instance.

Results: `RESULTS.md` (`classic.batch` and `nauss.batch` with the current configurations, 600 s),
`CLASSIC_RESULTS.md` (classic instances, compared with the literature) and `NAUSS_BENCHMARK.md` (the four upper bound
policies on the Nauss instances, 1800 s).
