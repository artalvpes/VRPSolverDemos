# Cumulative CVRP: computational results of the batches

Results of the CCVRP demo on the instances of the sets A and B of the CVRP demo, with the number of routes of the
CVRP batches (`-m k -M k`) and the upper bound `-u` = optimal cost + 1 (`A.batch`, `B.batch`; the same commands
one per process in `A.sh`, `B.sh`). Each arc costs its distance times the load on board (the return to the depot
costs nothing), each route counted in its cheaper direction; see `README.md`.

Setup (13/11/2026):

- `config/CCVRP.cfg` (meta-solver, no time limit), Julia 1.10.11, CPLEX 20.1;
- BaPCod master (ad23eb0) with the diving fix (MR !36), RCSP master (a0fe3a7) built with the custom resource of
  `src/meta_solver/rcsp_custom_res_impl.*` copied to `Tools/rcsp` (`src` and `include_dev`);
- Intel Core i7-12800H, 32 GB; the two batches ran in parallel (`julia src/run.jl -b A.batch`, `-b B.batch`);
- every solution was checked by the solution checker of the demo (routes, capacity, number of routes, cumulative cost).

## Summary

| Set | Instances | Optimal | Total nodes | Total time (s) | Geometric mean time (s) | Max time (s) | Commented out |
|---|---|---|---|---|---|---|---|
| A | 18 | 18 | 18 | 36.5 | 1.62 | 4.3 | 4 |
| B | 13 | 13 | 13 | 53.2 | 2.45 | 20.4 | 7 |

All the instances of the batches are solved at the root: with the upper bound optimum + 1, the root lower bound,
rounded up, reaches the optimum, so no branching is needed. The root time is the total time.

## Set A

| Instance | Routes | Optimum | Root LB | Root time (s) | Nodes | Time (s) |
|---|---|---|---|---|---|---|
| A-n37-k6 | 6 | 34006 | 34006 | 1.60 | 1 | 1.61 |
| A-n37-k5 | 5 | 20005 | 20005 | 0.56 | 1 | 0.56 |
| A-n38-k5 | 5 | 25978 | 25978 | 1.01 | 1 | 1.01 |
| A-n39-k6 | 6 | 27202 | 27202 | 0.57 | 1 | 0.57 |
| A-n39-k5 | 5 | 29437 | 29437 | 2.93 | 1 | 2.93 |
| A-n44-k6 | 6 | 32309 | 32309 | 0.64 | 1 | 0.64 |
| A-n45-k6 | 6 | 36062 | 36062 | 1.26 | 1 | 1.26 |
| A-n45-k7 | 7 | 43519 | 43519 | 0.93 | 1 | 0.93 |
| A-n46-k7 | 7 | 32637 | 32637 | 0.49 | 1 | 0.49 |
| A-n48-k7 | 7 | 40160 | 40160 | 2.01 | 1 | 2.01 |
| A-n53-k7 | 7 | 38553 | 38553 | 4.17 | 1 | 4.17 |
| A-n54-k7 | 7 | 44262 | 44262 | 1.61 | 1 | 1.61 |
| A-n55-k9 | 9 | 40687 | 40687 | 2.20 | 1 | 2.21 |
| A-n60-k9 | 9 | 51489 | 51489 | 3.40 | 1 | 3.40 |
| A-n62-k8 | 8 | 47287 | 47287 | 2.34 | 1 | 2.34 |
| A-n63-k9 | 9 | 63140 | 63140 | 4.27 | 1 | 4.27 |
| A-n65-k9 | 9 | 46832 | 46832 | 2.54 | 1 | 2.54 |
| A-n69-k9 | 9 | 42226 | 42226 | 3.91 | 1 | 3.93 |

Commented out in `A.batch` (not solved in 2 minutes when the batches were built, November 2026):

| Instance | Routes | Lower bound after 2 minutes |
|---|---|---|
| A-n61-k9 | 9 | 40513 |
| A-n63-k10 | 10 | 49106 |
| A-n64-k9 | 9 | 51488 |
| A-n80-k10 | 10 | 66618 |

## Set B

| Instance | Routes | Optimum | Root LB | Root time (s) | Nodes | Time (s) |
|---|---|---|---|---|---|---|
| B-n38-k6 | 6 | 28508 | 28508 | 0.64 | 1 | 0.64 |
| B-n39-k5 | 5 | 19982 | 19982 | 3.96 | 1 | 3.97 |
| B-n41-k6 | 6 | 33130 | 33130 | 0.40 | 1 | 0.40 |
| B-n43-k6 | 6 | 27977 | 27977 | 1.96 | 1 | 1.96 |
| B-n44-k7 | 7 | 37082 | 37082 | 1.53 | 1 | 1.53 |
| B-n45-k5 | 5 | 25360 | 25360 | 6.98 | 1 | 6.99 |
| B-n45-k6 | 6 | 27594 | 27594 | 1.96 | 1 | 1.96 |
| B-n50-k8 | 8 | 50643 | 50643 | 2.76 | 1 | 2.76 |
| B-n52-k7 | 7 | 28535 | 28535 | 2.05 | 1 | 2.05 |
| B-n56-k7 | 7 | 25087 | 25087 | 1.11 | 1 | 1.11 |
| B-n57-k9 | 9 | 65711 | 65711 | 3.73 | 1 | 3.73 |
| B-n64-k9 | 9 | 35457 | 35457 | 5.67 | 1 | 5.67 |
| B-n78-k10 | 10 | 46468 | 46468 | 20.41 | 1 | 20.41 |

Commented out in `B.batch` (not solved in 2 minutes when the batches were built, November 2026):

| Instance | Routes | Lower bound after 2 minutes |
|---|---|---|
| B-n50-k7 | 7 | 27583 |
| B-n51-k7 | 7 | 43231 |
| B-n57-k7 | 7 | 50314 |
| B-n63-k10 | 10 | 61647 |
| B-n66-k9 | 9 | 52564 |
| B-n67-k10 | 10 | 39620 |
| B-n68-k9 | 9 | 51975 |
