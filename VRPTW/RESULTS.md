# VRPTW: computational results of the batches

Results of the VRPTW demo on its batches (Solomon instances with 100 customers and Gehring and Homberger instances with 200 customers), with the upper bound `-u` = optimal cost + 0.1.

Setup (13–14/11/2026):

- the configuration of each line of the batch (`config/*.cfg`) with `GlobalTimeLimit = 600` seconds added, one
  instance per Julia process;
- BaPCod master (ad23eb0) with the diving fix (MR !36), RCSP master (a0fe3a7); Julia 1.10.11, CPLEX 20.1;
- Intel Core i7-12800H, 32 GB, two runs in parallel;
- every solution was checked by the solution checker of the demo, written from the definition of the problem.

Times are the solver times in seconds (`bcTimeMain`), without the start of Julia; "Root LB" is the lower bound at the
end of the root node, "LB" the best lower bound when the time limit was reached.

## Summary

| Batch | Instances | Solved in 600 s | Total time | Geometric mean time | Max time |
|---|---|---|---|---|---|
| `solomon.batch` | 13 | 13 | 479 s | 31.7 s | 74.2 s |
| `homberger.batch` | 18 | 18 | 964 s | 29.8 s | 141.2 s |

Unsolved instances count as 600 s in the total time; the geometric mean and the maximum are over the solved ones.

## Notes

- Some runs print `BaPCod WARNING : objVal = ... does not correspond to the cost of the best column`, with differences up to 1e-5. They come from dual values below 1e-6 that BaPCod drops when it computes the reduced costs given to the pricing; they do not affect the results, and a BaPCod change in preparation removes them.

## `solomon.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| C203 | 588.7 | 588.7 | 9.9 | 1 | 9.9 |
| C204 | 588.1 | 588.1 | 14.4 | 1 | 14.4 |
| RC204 | 783.5 | 783.5 | 34.3 | 1 | 34.3 |
| RC207 | 962.9 | 962.9 | 34.3 | 1 | 34.3 |
| RC208 | 776.1 | 776.1 | 28.1 | 1 | 28.1 |
| R202 | 1029.6 | 1029.6 | 15.7 | 1 | 15.7 |
| R203 | 870.8 | 870.8 | 24.8 | 1 | 24.8 |
| R206 | 875.9 | 875.9 | 38.6 | 1 | 38.6 |
| R204 | 731.3 | 731.3 | 69.1 | 1 | 69.1 |
| R209 | 854.8 | 854.8 | 40.0 | 1 | 40.0 |
| R207 | 794.0 | 794.0 | 43.9 | 1 | 43.9 |
| R211 | 746.7 | 746.7 | 51.8 | 1 | 51.8 |
| R210 | 900.5 | 900.5 | 74.2 | 1 | 74.2 |

## `homberger.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| C2_2_2 | 1851.4 | 1851.4 | 59.4 | 1 | 59.4 |
| C2_2_1 | 1922.1 | 1922.1 | 84.2 | 1 | 84.2 |
| C2_2_6 | 1844.8 | 1844.8 | 74.3 | 1 | 74.3 |
| C2_2_5 | 1869.6 | 1869.6 | 82.2 | 1 | 82.2 |
| C2_2_7 | 1842.2 | 1842.2 | 48.3 | 1 | 48.3 |
| C2_2_8 | 1813.7 | 1813.7 | 75.5 | 1 | 75.5 |
| RC2_2_1 | 2797.4 | 2797.4 | 85.9 | 1 | 85.9 |
| C2_2_9 | 1815.0 | 1815.0 | 141.2 | 1 | 141.2 |
| R2_2_1 | 3468.0 | 3468.0 | 46.3 | 1 | 46.3 |
| C1_2_1 | 2698.6 | 2698.6 | 4.3 | 1 | 4.3 |
| C1_2_2 | 2694.3 | 2694.3 | 8.9 | 1 | 8.9 |
| C1_2_5 | 2694.9 | 2694.9 | 4.6 | 1 | 4.6 |
| C1_2_6 | 2694.9 | 2694.9 | 4.1 | 1 | 4.1 |
| C1_2_7 | 2694.9 | 2694.9 | 3.9 | 1 | 3.9 |
| C1_2_8 | 2684.0 | 2684.0 | 10.4 | 1 | 10.4 |
| R2_2_2 | 3008.2 | 3008.2 | 136.7 | 1 | 136.7 |
| C1_2_9 | 2639.6 | 2639.6 | 19.1 | 1 | 19.1 |
| R1_2_1 | 4667.2 | 4660.2 | 8.5 | 49 | 74.5 |
