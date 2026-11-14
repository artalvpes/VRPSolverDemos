# PDPTW: pickup and delivery with time windows

There are n requests; each request must be picked up at its pickup vertex and delivered at its delivery vertex, by
the same vehicle,
pickup before delivery, within the time windows of both vertices and without exceeding the vehicle capacity Q along
the route. Each vertex is visited exactly once.

Two objectives, according to the instance set:

- **Ropke and Cordeau (2009)** (`data/Ropke`, 40 instances AA, BB, CC, DD with 30 to 75 requests): minimize a fixed
  cost per vehicle (option `--fixed`, default 10000) plus the distance, i.e. first the number of vehicles, then the
  distance. The number of vehicles is bounded by `-m` and `-M`.
- **Li and Lim (2001)** (`data/LiLim`, 30 instances LC1, LR1, LRC1 with 100 requests, option `--lilim`): minimize
  the distance, with at most K vehicles.

Distances are Euclidean, not rounded (option `-r` to round them).

## Model

- Graph: the depot (vertex 0, source and sink) and the 2n pickup and delivery vertices, one arc per possible move,
  mapped to x_a.
- Resources: the time (main resource, intervals given by the time windows), the load (consumption d_j, which is
  negative at deliveries, interval [0, Q]), and **one binary resource per request**, +1 at its pickup and -1 at its
  delivery, interval [0, 1]: a path can only visit a delivery after its pickup and must end with all its requests
  delivered. The load and request resources are not disposable (the consumption cannot be wasted).
- Master: in-degree 1 for each pickup vertex (the delivery follows from the request resources); with the Ropke
  objective, the expression num_veh (number of arcs leaving the depot) gets the fixed cost.
- One packing set per pickup vertex; the initial ng-neighbourhood of a vertex is given explicitly (its request and
  the 7 nearest ones, for the pickup and the delivery vertices). Branching on num_veh (priority 3), then on x.
- For the Ropke instances, the problem is solved for a fixed fleet of k vehicles, k = `-M`, `-M` - 1, ..., `-m`,
  while a solution is found; the last solution found (the fewest vehicles) is the optimum.

Configuration: `config/PDPTW.cfg` (original RCSP solver, `RCSPuseMetaSolver = 0`).

## Running

From the `PDPTW` folder, with `BAPCOD_RCSP_LIB` set to the VRPSolver library:

```bash
julia src/run.jl data/Ropke/AA30.txt -m 1 -M 3 -u 31119.2 --fixed 10000              # Ropke, with an upper bound
julia src/run.jl data/Ropke/AA30.txt -m 1 -M 3 --fixed 10000                         # the heuristic gives the upper bound
julia src/run.jl data/LiLim/LC1_2_1.txt --lilim -u 2704.7 -o LC1_2_1.sol -t LC1_2_1.tex
julia src/run.jl data/LiLim/LC1_2_1.txt --lilim -T 1 1                               # tentative upper bounds (Li and Lim only)
julia src/run.jl -b ropke.batch &> out/ropke.out                                     # a whole batch in one process
bash ropke.sh                                                                        # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-u` | upper bound (the solver looks for a solution of cost below it) |
| `--noheur` | without `-u`, no heuristic: no upper bound |
| `-T D1 D2` | Li and Lim only: tentative upper bounds from the root bound |
| `-m`, `-M`, `--fixed` | Ropke: minimum and maximum number of vehicles, fixed cost per vehicle |
| `--lilim` | the instance is in the Li and Lim format (objective: distance) |
| `-r` | round the distances |
| `-o`, `-t` | write the solution and a TikZ figure |
| `-s`, `-n` | read a solution from a file; with `-n`, only check (and draw) it, without solving |
| `-c` | configuration file (default `config/PDPTW.cfg`) |
| `-b` | batch file: one line of options per instance |

Every solution is checked against the definition of the problem (precedence and pairing, time windows, capacity,
number of vehicles, cost). The TikZ figure draws each route in its own colour; to get a PDF: `pdflatex LC1_2_1.tex`.

`ropke.batch` and `lilim.batch` give the optimal costs + 0.1 as upper bounds; the instances not solved in 10
minutes are commented out, which includes all the Li and Lim instances (their root alone takes several minutes).
Results: `RESULTS.md`.
