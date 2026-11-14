# VSBPP: computational results of the batches

Results of the VSBPP demo on its batches, with the upper bound `-u` = optimal cost + 1.

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
| `toy.batch` | 5 | 5 | 3 s | 0.5 s | 1.3 s |
| `test.batch` | 11 | 11 | 29 s | 1.5 s | 11.1 s |

Unsolved instances count as 600 s in the total time; the geometric mean and the maximum are over the solved ones.

## `toy.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| toy1 | 8 | 8 | 0.3 | 1 | 0.3 |
| toy2 | 21 | 21 | 0.4 | 1 | 0.4 |
| toy3 | 90 | 90 | 0.3 | 1 | 0.3 |
| toy4 | 246 | 246 | 0.3 | 1 | 0.3 |
| toy5 | 210 | 210 | 1.3 | 1 | 1.3 |

## `test.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| vc_K5_n20_u1_s1 | 45270 | 45270 | 0.7 | 1 | 0.7 |
| zc_K5_n20_u1_s1 | 16066 | 16066 | 0.7 | 1 | 0.7 |
| vc_K3_n30_u3_s1 | 67121 | 67121 | 1.5 | 1 | 1.5 |
| zc_K5_n30_u1_s1 | 44259 | 44259 | 0.4 | 1 | 0.4 |
| vc_K4_n40_u3_s1 | 89719 | 89481 | 0.4 | 55 | 3.5 |
| zc_K5_n40_u2_s1 | 33089 | 32926 | 0.4 | 21 | 2.3 |
| zc_K5_n50_u2_s1 | 63148 | 63148 | 1.0 | 1 | 1.0 |
| vc_K5_n50_u11_s1 | 106209 | 105646 | 0.8 | 223 | 6.2 |
| zc_K5_n60_u2_s1 | 94337 | 94337 | 0.5 | 1 | 0.5 |
| vc_K5_n60_u4_s1 | 134410 | 134198 | 0.8 | 431 | 11.1 |
| zc_K5_n100_u4_s1 | 141223 | 141192 | 0.7 | 9 | 1.4 |
