# PDPTW: computational results of the batches

Results of the PDPTW demo on its batches. Ropke instances: cost = 10000 per vehicle + distance, upper bound `-u` = optimal cost + 0.1; the problem is solved for each fleet size from `-M` down while a solution is found, and the nodes and times are the sums over these runs. Li and Lim instances: cost = distance.

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
| `ropke.batch` | 40 | 36 | 4067 s | 9.4 s | 440.1 s |
| `lilim.batch` | 3 | 0 | 1800 s | — | — |

Unsolved instances count as 600 s in the total time; the geometric mean and the maximum are over the solved ones.

## Notes

- CC60, CC65 and DD65: the solver proves optima **below** the upper bounds of the batch (42009.27, 42163.99 and 42107.28, against 42015.5, 42172.1 and 42125.7): the upper bounds of these lines were corrected to 42009.4, 42164.1 and 42107.4.
- DD60: the instance allows K = 3 vehicles, but the batch line gives `-M 4` and the demo does not limit the fleet to K: the solver returned a solution with 4 vehicles, which the checker rejected (`error` in the table). With `-M 3` and the upper bound of the heuristic (which finds no solution with 3 vehicles), DD60 is not solved in 600 s (lower bound 32001.43, no solution found); the line is now commented out with `-M 3`.
- CC70, DD70, DD75 and the three Li and Lim instances are not solved in 600 s; they are now commented out in the batches (`lilim.batch` has no active line left).

## `ropke.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| AA30 | 31119.11 | 31119.11 | 0.6 | 2 | 0.9 |
| AA35 | 31299.78 | 31299.78 | 1.2 | 2 | 1.9 |
| AA40 | 31515.88 | 31515.88 | 1.3 | 2 | 2.5 |
| AA45 | 31759.82 | 31759.82 | 1.8 | 2 | 4.2 |
| AA50 | 41775.02 | 41775.02 | 3.7 | 2 | 4.9 |
| AA55 | 41907.83 | 41907.83 | 2.0 | 2 | 4.2 |
| AA60 | 42140.67 | 42140.67 | 7.8 | 2 | 10.5 |
| AA65 | 42250.20 | 42250.20 | 6.5 | 2 | 10.1 |
| AA70 | 42452.30 | 42452.30 | 11.5 | 2 | 18.8 |
| AA75 | 52461.64 | 52461.64 | 8.4 | 2 | 17.6 |
| BB30 | 31086.30 | 31086.30 | 0.5 | 2 | 0.8 |
| BB35 | 31281.24 | 31281.24 | 0.8 | 2 | 1.3 |
| BB40 | 31493.38 | 31493.38 | 1.6 | 2 | 2.5 |
| BB45 | 41555.13 | 41555.13 | 1.3 | 2 | 3.0 |
| BB50 | 41701.05 | 41701.05 | 1.9 | 2 | 5.4 |
| BB55 | 41885.70 | 41885.70 | 3.6 | 2 | 9.6 |
| BB60 | 62420.06 | 62420.06 | 3.6 | 2 | 6.1 |
| BB65 | 62639.14 | 62639.14 | 4.0 | 2 | 8.3 |
| BB70 | 62951.04 | 62951.04 | 9.4 | 2 | 17.2 |
| CC30 | 31087.75 | 31087.75 | 0.6 | 2 | 1.0 |
| CC35 | 31230.64 | 31230.64 | 0.9 | 2 | 1.4 |
| CC40 | 31358.49 | 31358.49 | 1.4 | 2 | 2.2 |
| CC45 | 31509.10 | 31509.10 | 2.2 | 2 | 3.9 |
| CC50 | 41685.25 | 41685.25 | 3.5 | 2 | 5.5 |
| BB75 | 63127.47 | 63082.02 | 25.2 | 6 | 85.9 |
| CC55 | 41836.30 | 41836.30 | 19.8 | 2 | 23.6 |
| CC65 | 42163.99 | 42150.06 | 38.4 | 10 | 276.9 |
| CC60 | 42009.27 | 41999.44 | 36.4 | 18 | 370.8 |
| CC75 | 52358.98 | 52355.56 | 39.7 | 6 | 118.6 |
| DD30 | 21133.33 | 21133.33 | 1.6 | 2 | 3.0 |
| DD35 | 31210.89 | 31210.89 | 1.4 | 2 | 8.4 |
| DD40 | 31352.19 | 31352.19 | 2.5 | 2 | 15.0 |
| DD45 | 31483.95 | 31483.95 | 4.1 | 2 | 25.9 |
| DD50 | 31600.92 | 31600.92 | 6.2 | 2 | 36.4 |
| DD55 | 31743.28 | 31743.28 | 16.5 | 2 | 118.5 |
| DD60 | not solved (LB 41869.41) | 41868.03 | 70.8 | 3 | error |
| CC70 | not solved (LB 42444.52) | 52201.66 | 5.9 | 6 | limit 600 |
| DD65 | 42107.28 | 42097.46 | 47.9 | 8 | 440.1 |
| DD70 | not solved (LB 42213.77) | 42208.10 | 122.2 | 5 | limit 600 |
| DD75 | not solved (LB 42352.91) | 42345.92 | 112.1 | 3 | limit 600 |

## `lilim.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| LC1_2_1 | not solved (LB 0.00) | -1000000000000.00 | 504.0 | 1 | limit 600 |
| LR1_2_1 | not solved (LB 0.00) | -1000000000000.00 | 550.7 | 1 | limit 600 |
| LC1_2_5 | not solved (LB 0.00) | -1000000000000.00 | 507.0 | 1 | limit 600 |
