# TOP: computational results of the batches

Results of the TOP demo on `chao.batch` (set 4 of Chao, Golden and Wasil), with the upper bound `-u` = minus the optimal profit + 1. The costs are minus the profits.

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
| `chao.batch` | 46 | 46 | 145 s | 1.8 s | 22.1 s |

Unsolved instances count as 600 s in the total time; the geometric mean and the maximum are over the solved ones.

## `chao.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| p4.2.a | -206 | -206 | 0.6 | 1 | 0.6 |
| p4.2.b | -341 | -341 | 0.6 | 1 | 0.6 |
| p4.2.c | -452 | -452 | 0.8 | 1 | 0.8 |
| p4.2.d | -531 | -531 | 1.1 | 1 | 1.1 |
| p4.2.e | -618 | -618 | 1.4 | 1 | 1.4 |
| p4.2.f | -687 | -687 | 2.7 | 1 | 2.7 |
| p4.2.g | -757 | -757 | 3.7 | 1 | 3.7 |
| p4.2.h | -835 | -835 | 4.0 | 1 | 4.0 |
| p4.2.i | -918 | -918 | 3.1 | 1 | 3.1 |
| p4.2.j | -965 | -965 | 5.1 | 1 | 5.1 |
| p4.2.k | -1022 | -1022 | 8.6 | 1 | 8.6 |
| p4.2.l | -1074 | -1074 | 10.7 | 1 | 10.7 |
| p4.2.m | -1132 | -1132 | 9.3 | 1 | 9.3 |
| p4.3.a | 0 | 0 | 0.6 | 1 | 0.6 |
| p4.3.b | -38 | -38 | 0.6 | 1 | 0.6 |
| p4.3.c | -193 | -193 | 0.6 | 1 | 0.6 |
| p4.3.d | -335 | -335 | 0.8 | 1 | 0.8 |
| p4.3.e | -468 | -468 | 0.8 | 1 | 0.8 |
| p4.3.f | -579 | -579 | 1.0 | 1 | 1.0 |
| p4.3.g | -653 | -653 | 1.2 | 1 | 1.2 |
| p4.3.h | -729 | -729 | 1.3 | 1 | 1.3 |
| p4.3.i | -809 | -809 | 1.4 | 1 | 1.4 |
| p4.3.j | -861 | -861 | 2.3 | 1 | 2.3 |
| p4.3.k | -919 | -919 | 2.7 | 1 | 2.7 |
| p4.3.l | -979 | -979 | 7.4 | 1 | 7.4 |
| p4.3.m | -1063 | -1063 | 2.9 | 1 | 2.9 |
| p4.3.n | -1121 | -1121 | 3.8 | 1 | 3.8 |
| p4.3.o | -1172 | -1172 | 4.4 | 1 | 4.4 |
| p4.3.p | -1222 | -1222 | 5.8 | 1 | 5.8 |
| p4.3.q | -1253 | -1253 | 7.0 | 1 | 7.0 |
| p4.4.a | 0 | 0 | 0.5 | 1 | 0.5 |
| p4.4.b | 0 | 0 | 0.5 | 1 | 0.5 |
| p4.4.c | 0 | 0 | 0.5 | 1 | 0.5 |
| p4.4.d | -38 | -38 | 0.5 | 1 | 0.5 |
| p4.4.e | -183 | -183 | 0.6 | 1 | 0.6 |
| p4.4.f | -324 | -324 | 0.6 | 1 | 0.6 |
| p4.4.h | -571 | -571 | 0.7 | 1 | 0.7 |
| p4.4.g | -461 | -461 | 0.7 | 1 | 0.7 |
| p4.4.i | -657 | -657 | 1.1 | 1 | 1.1 |
| p4.4.j | -732 | -732 | 1.2 | 1 | 1.2 |
| p4.4.k | -821 | -821 | 1.5 | 1 | 1.5 |
| p4.4.l | -880 | -880 | 1.8 | 1 | 1.8 |
| p4.4.o | -1061 | -1061 | 2.2 | 1 | 2.2 |
| p4.4.p | -1124 | -1124 | 3.5 | 1 | 3.5 |
| p4.4.r | -1216 | -1216 | 11.3 | 1 | 11.3 |
| p4.4.q | -1161 | -1161 | 22.1 | 1 | 22.1 |
