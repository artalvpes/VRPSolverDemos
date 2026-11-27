# CVRP: capacitated vehicle routing

Vehicles of capacity Q leave the depot, visit customers with demands d_i and come back to the depot; each customer is
visited exactly once, and the cost is the total distance travelled. The number of routes can be bounded with `-m`
(minimum) and `-M` (maximum). If the instance has a maximum route length (`DISTANCE`, as in the CMT instances), the
routes must also respect it, counting the service time (`SERVICE_TIME`) of each customer.

This is the basic demo of VRPSolver; the others are built on the same structure.

## Instances

`data/` holds CVRPLIB instances: sets A, B, E, F, M, P (Augerat, Christofides and Eilon, Fisher, Christofides,
Mingozzi and Toth), X (Uchoa et al. 2017), CMT (Christofides, Mingozzi and Toth, some with route length limits) and
`toy.vrp`. Distances are Euclidean, rounded to the nearest integer as in CVRPLIB (option `-r` to keep them exact).

## Model

- Graph: the depot (vertex 0, source and sink) and one vertex per customer, two arcs per edge, both mapped to the
  edge variable x_e. The number of paths is between max(`-m`, a lower bound on the number of vehicles) and `-M`.
- Resources: the capacity, consumption (d_i + d_j)/2 per arc, interval [0, Q]; with a route length limit D, also the
  distance (travel time plus service time), interval [0, D] (option `-R`: the distance alone).
- Master: degree 2 for each customer; objective min Σ c_e x_e.
- One packing set per customer (enabling rank-1 cuts, route enumeration and the elementarity of the ng-routes),
  ng-neighbourhoods based on the distances, rounded capacity cuts (and route length cuts with D), optionally strong
  k-path cuts (`-k`).
- Branching on the edges x_e (priority 2, `-l` lowers it to 1), together with the branching on the number of
  vehicles; option `-B` adds a branching on clusters of customers. Option `-e` adds a cut callback that imposes
  x_e <= 1 on the edges between two customers (an example of user cuts).

Configuration: `config/CVRP.cfg` (original RCSP solver, `RCSPuseMetaSolver = 0`). `config/CMT13.cfg` is an
alternative named after the instance CMT13 (rank-1 cuts with arc memory and at most 3 rows, a smaller tailing-off
threshold, a time limit on the reduced cost fixing); choose it with `-c config/CMT13.cfg`.

## Upper bounds and the heuristic

When neither `-u` nor `-T` is given, `src/heuristic.jl` gives the upper bound: its cost. The solver then looks for a
cheaper solution; if it proves that there is none, the heuristic solution is optimal and is printed as the answer.
(With `-u`, the upper bound is meant to be the cost of a solution not known yet, plus 1.) `-H` runs the heuristic in
any case.
It builds a solution by the Clarke and Wright savings (several values of λ), adjusts the number of routes to
[`-m`, `-M`] (by a bin packing of the demands when the fleet is tight), and improves it by a local search with
granular neighbourhoods (relocation, exchange, 2-opt and 2-opt*, each customer tried with its nearest customers)
inside a ruin and recreate loop, until its time limit. On the 138 instances of the batches (all lines, with their
number of routes), it finds the optimum of 69 and is 0.34% above the optimum on average (at most 2.7%).

## Running

From the `CVRP` folder, with `BAPCOD_RCSP_LIB` set to the VRPSolver library:

```bash
julia src/run.jl data/A/A-n37-k6.vrp -m 6 -M 6 -u 950                 # with an upper bound
julia src/run.jl data/A/A-n37-k6.vrp -m 6 -M 6                        # the heuristic gives the upper bound
julia src/run.jl data/A/A-n37-k6.vrp -m 6 -M 6 -T 1 1                 # tentative upper bounds from the root bound
julia src/run.jl data/A/A-n37-k6.vrp -m 6 -M 6 -u 950 -o A-n37-k6.sol -t A-n37-k6.tex
julia src/run.jl -b A.batch &> out/A.out                              # a whole batch in one process
bash A.sh                                                             # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-u` | upper bound (the solver looks for a solution of cost below it) |
| `--noheur` | without `-u` and `-T`, no heuristic: no upper bound |
| `-T D1 D2` | tentative upper bounds: solve the root, then try ub = LB + D1, LB + D1 + D2, ... until a solution is found |
| `-H` | run the heuristic also with `-u` or `-T`: the ub is then the smaller of `-u` and the heuristic cost |
| `--heur_time`, `--heur_neighbors`, `--heur_seed` | time limit of the heuristic (default min(20, 2 + 0.1 n) s), nearest customers tried by its local search (default 20), random seed (default 1) |
| `-m`, `-M` | minimum and maximum number of routes |
| `-r` | do not round the distances |
| `-o`, `-t` | write the solution (CVRPLIB format) and a TikZ figure |
| `-s`, `-n` | read a solution from a file; with `-n`, only check (and draw) it, without solving |
| `-c` | configuration file (default `config/CVRP.cfg`) |
| `-b` | batch file: one line of options per instance |
| `-e`, `-k`, `-B`, `-R`, `-l` | edge cuts by callback, strong k-path cuts, cluster branching, single resource, low edge branching priority |
| `-f` | print the complete formulation, with all the feasible paths (tiny instances only) |

Every solution is checked against the definition of the problem (degrees, capacity, route length, number of routes,
cost). The TikZ figure draws each route in its own colour; to get a PDF: `pdflatex A-n37-k6.tex`.

**C++ version:** `cpp/` has the same demo written with the C++ interface of BaPCod (same command line, configuration
and outputs; it starts in a fraction of a second, and can use the heuristic HGS-CVRP); see `cpp/README.md`.

The batches (`A`, `B`, `EM`, `F`, `P`, `X`) give the optimal costs + 1 as upper bounds; the instances not solved in a
few minutes are commented out. Results: `RESULTS.md`.
