# VRPL: VRP with lockers

A fleet of vehicles with capacity Q leaves the depot and visits lockers. The customers are not visited: each customer
is assigned to a locker visited by some route, and its demand is carried by that route. The cost is the travel cost
plus the assignment costs f_sc = alpha x distance(c, s). Differences from the VRPDA of Oliveira, Lima, Pessoa and
Roboredo (Computers & Operations Research 182, 2025):

- **Coverage.** A customer can only be assigned to one of its k nearest lockers (option `--nearest`/`-k`, default 3;
  ties are broken by the locker index). In the VRPDA, any locker can serve any customer.
- **Multiple visits.** A locker may be visited more than once, by the same route or by different routes, and it has no
  capacity. In the VRPDA, each locker is visited at most once.
- The number of routes is not limited (options `--minr` and `--maxr`).

## Instances

- `data/CVRP`: the CVRPLIB instances of the CVRP demo (sets A, B, CMT, E, F, M, P, X). The node 1 is the depot, the
  **last l nodes are the lockers** (option `--lockers`/`-l`, default 20; their demands are ignored) and the other
  nodes are the customers. Euclidean distances **without rounding** (with the rounding of CVRPLIB, ties between
  equivalent routes were frequent). Default alpha = 3 (the customers are expected to walk little). The fields DISTANCE and SERVICE_TIME are ignored.
- `data/VRPDA`: the 100 instances of Reihaneh and Ghoniem (2018, 2019) used in the paper (.vdap files, 10 to 50
  lockers, 20 to 90 customers, Q = 25). Euclidean distances between the coordinates, without rounding, with the depot
  at the origin; the distance matrices of the files (truncated to integers) and the fields `m` and `Lambda` are not
  used. Default alpha = 1.

## Model

The model is based on the graph of the paper (Fig. 2): the depot (vertex 0, source and
sink) and one vertex v_sc for each locker s and each customer c covered by s.

- Edges between vertices of different customers, with cost f_sc/2 + d(s,s') + f_s'c'/2 (f = 0 for the depot), so the
  assignment cost of each visited vertex is paid once. The travel cost between vertices of the same locker is zero.
- Two arcs per edge, except between two vertices of the same locker: a single arc from the smaller to the larger
  customer (the set A2 of the paper), so the customers of a locker stop are visited in a unique order. Without this,
  each permutation of the customers of a stop is a different path with the same cost, and the pricing is very slow.
- Capacity resource with the CVRP consumption ((demand of i + demand of j)/2 per arc).
- One packing set per customer (its vertices), rounded capacity cuts, rank-1 cuts, ng-neighbourhoods based on the
  distances between customers. Master: degree 2 for each customer (sum over its vertices). Branching on the
  assignments y_sc = (sum of the edges of v_sc)/2 (priority 2), then on the edges.
- The enumeration is valid because the only master constraints are the degree constraints of the customers (one per
  packing set). For this reason, locker capacities cannot be added to the master.
- **Preprocessing** (disabled with `-P`), adapted from Proposition 1 of the paper: the edge {v1, v2} is removed if,
  for every vertex v3 that can follow v2 (the depot, or a customer c3 not in {c1, c2} with w1 + w2 + w3 <= Q), another
  vertex v4 of the customer of v2 gives a cheaper path v1-v4-v3, or one of the same cost with a smaller locker index.
  The tie breaking allows all the dominated edges to be removed together without losing the optimum. It removes about
  30 to 60% of the edges.

A previous model with one vertex per locker and one loop arc per assignment (packing sets on arcs) was removed: it
has no rounded capacity cuts, and the current RCSP solver cannot handle it when a locker covers more than about 15
customers (the ng-memory of a vertex is limited to 15 packing sets).

## Configuration

`config/VRPL.cfg` has the parameters of the code of the paper. With `CutTailingOffThreshold = 0.01` and
`CutTailingOffCounterThreshold = 3`, the root ends early and the solver branches soon, which works well with a good
upper bound (the paper always used the upper bound of an ILS heuristic).

## Upper bounds

- `--ub`/`-u`: a known upper bound; the solver searches for solutions of cost strictly below it.
- Without `-u`, the heuristic of `src/heuristic.jl` gives the upper bound (cost + 0.01): each customer is assigned to
  its cheapest covering locker, the customers of a locker are grouped into stops of load at most Q, the stops are routed
  by Clarke and Wright savings, then a local search (moves of customers between stops of covering lockers, moves of
  stops, 2-opt) and a ruin and recreate search for 5 seconds. With `--noheur`, the cost of the trivial solution (one
  route per customer, to its cheapest covering locker) + 1 is used. In both cases the bound is of the scale of the
  problem: VrpSolver.jl uses the cutoff as the cost of the artificial variables of the master, and a huge cutoff (such
  as 10^7) causes numerical troubles in the LPs.
- `--tentative`/`-T DELTA1 DELTA2`: the root is solved first, giving its lower bound LB; then the problem is solved
  with the cutoffs LB + DELTA1, LB + DELTA1 + DELTA2, LB + DELTA1 + 2 DELTA2, ... until a solution is found. A run
  that ends without a solution proves that there is no solution below its cutoff; at the end, a valid lower bound is
  printed (also when the last run stops at the time limit).
- `--diving`/`-d` and `--rm_heuristic`/`-H`: the diving heuristic and the restricted master heuristic of BaPCod (few
  tests).

## Running

From this folder, with the environment variable `BAPCOD_RCSP_LIB` set as for the other demos:

```
julia src/run.jl data/VRPDA/s10k20_1.vdap
julia src/run.jl data/CVRP/E/E-n51-k5.vrp -o out/E-n51-k5.sol -t out/E-n51-k5.tex   # l = 20, k = 3, alpha = 3
julia src/run.jl data/CVRP/E/E-n76-k7.vrp -l 10 -a 1 -T 5 5                         # tentative upper bounds
julia src/run.jl data/CVRP/E/E-n51-k5.vrp -s out/E-n51-k5.sol -n                    # check a solution
julia src/run.jl -b VRPDA.batch &> out/VRPDA.out
bash VRPDA.sh                                                                        # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-l` | CVRPLIB instances: number of lockers, the last l nodes (default 20) |
| `-a` | alpha: assignment cost = alpha x distance(customer, locker) |
| `-k` | each customer can only be assigned to one of its k nearest lockers (default 3) |
| `-P` | no preprocessing (dominated edges are kept) |
| `-u`, `--noheur`, `-T D1 D2` | upper bound, no heuristic, tentative upper bounds (see above) |
| `-d`, `-H` | diving heuristic, restricted master heuristic |
| `-m`, `-M` | minimum and maximum number of routes |
| `-o`, `-t` | write the solution and a TikZ figure |
| `-s`, `-n` | read a solution from a file; with `-n`, only check (and draw) it, without solving |
| `-c` | configuration file (default `config/VRPL.cfg`) |
| `-b` | batch file: one line of options per instance |

A route is printed as its sequence of locker stops, each with the customers assigned in it, e.g.
`Route #1: 2 [1 2 22] 1 [3 26 28] 18 [7 8 23 24]`. The solution checker is written from the definition of the problem, assuming
nothing about how the solution was obtained: it verifies the assignments (each customer once, to one of its k nearest
lockers), the capacity of each route, the number of routes and the cost recomputed from the routes. Before that, the
values of the variables x are checked to be integral. The TikZ figure (`-t`, compile with
pdflatex) shows the depot (yellow diamond), the lockers (squares, gray if visited), the customers (circles), the routes
(solid lines, one color per route) and the assignments (dotted lines).

## Validation

The model was compared with an independent exact dynamic programming (Held-Karp over the sets of lockers of a
route, then a set-partitioning DP over the subsets of customers) on small instances with up to 13 customers and 10
lockers (P-n16-k8 to P-n23-k8 with l = 5 to 10, and VRPDA instances restricted to their first customers): the same
optimal values were obtained. The preprocessing gives the same optima as the runs without it.

Results of `VRPDA.batch`: `RESULTS.md`.
