# VRPTW: vehicle routing with time windows

At most K vehicles of capacity Q leave the depot and visit customers with demands d_i, service times s_i and time
windows [a_i, b_i]: the service of i must start in its window (a vehicle that arrives early waits), and the vehicle
must be back at the depot before the end of the depot window. Each customer is visited exactly once; the cost is the
total distance.

## Instances

- `data/100`: 14 instances with 100 customers of Solomon (1987), of the types C2, R2 and RC2 (wide time windows, long
  routes).
- `data/200`: the 60 instances with 200 customers of Gehring and Homberger (1999), 10 of each type C1, C2, R1, R2,
  RC1 and RC2.
- `data/toy.txt`: a small instance.

Distances and travel times are the Euclidean distances truncated to one decimal place, the usual convention for
these instances (see the [VRPTW instances note of CVRPLIB](https://galgos.inf.puc-rio.br/cvrplib/uploads/files/vrptw_challenge/instances.pdf)).

## Model

- Graph: the depot (vertex 0, source and sink) and one vertex per customer, one arc per possible move (i, j), mapped
  to the arc variable x_a. Between 1 and K paths.
- Resources: the time, consumption t_ij (travel time plus the service time of i) and interval [a_i, b_i] at each
  vertex; the waiting is implicit, since a label reaching i before a_i starts at a_i. Optionally (`-e`) the capacity,
  consumption d_j, interval [0, Q]. Without `-e`, the capacity is imposed by the rounded capacity cuts.
- The ends of the time windows get a tolerance of 1e-3: the travel times are multiples of 0.1 that are not exact in
  floating point, and their sums could exceed an integer due time by about 1e-13, which made the solver discard
  feasible routes. A real violation is at least 0.1.
- Master: in-degree 1 for each customer; objective min Σ c_a x_a. One packing set per customer, ng-neighbourhoods,
  rounded capacity cuts, rank-1 cuts, branching on x.

Configuration: `config/VRPTW_set_1.cfg` and `config/VRPTW_set_2.cfg` differ in the rank-1 cuts (at most 7 rows in
set 1) and in the strong branching tree size estimation ratios; the batches give the one to use for each instance.

## Running

From the `VRPTW` folder, with `BAPCOD_RCSP_LIB` set to the VRPSolver library:

```bash
julia src/run.jl data/100/C203.txt -u 588.8 --cfg config/VRPTW_set_2.cfg      # with an upper bound
julia src/run.jl data/100/C203.txt --cfg config/VRPTW_set_2.cfg               # the heuristic gives the upper bound
julia src/run.jl data/100/C203.txt -T 1 1 --cfg config/VRPTW_set_2.cfg        # tentative upper bounds
julia src/run.jl data/100/C203.txt -u 588.8 --cfg config/VRPTW_set_2.cfg -o C203.sol -t C203.tex
julia src/run.jl -b solomon.batch &> out/solomon.out                           # a whole batch in one process
bash solomon.sh                                                                # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-u` | upper bound (the solver looks for a solution of cost below it) |
| `--noheur` | without `-u`, no heuristic: no upper bound |
| `-T D1 D2` | tentative upper bounds: solve the root, then try ub = LB + D1, LB + D1 + D2, ... until a solution is found |
| `-e` | add the capacity resource to the pricing |
| `-o`, `-t` | write the solution and a TikZ figure |
| `-s`, `-n` | read a solution from a file; with `-n`, only check (and draw) it, without solving |
| `-c` | configuration file (default `config/VRPTW_set_1.cfg`) |
| `-b` | batch file: one line of options per instance |

Every solution is checked against the definition of the problem (time windows, capacity, number of vehicles, cost).
The TikZ figure draws each route in its own colour, with arrows; to get a PDF: `pdflatex C203.tex`.

The batches `solomon.batch` and `homberger.batch` give the optimal costs + 0.1 as upper bounds; the instances not
solved in a few minutes are commented out. Results: `RESULTS.md`.
