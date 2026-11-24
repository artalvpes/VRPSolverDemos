# P||ΣwjTj: computational results of the batches

Results of the P||ΣwjTj demo on its batches, with the upper bound `-u` = optimal cost + 1 (the toy instances have no upper bound: the heuristic gives it). `wt50-2m.batch` was not run: each instance needs more than 17 GB of memory.

Setup (13–14/11/2026):

- the configuration of each line of the batch (`config/*.cfg`) with `GlobalTimeLimit = 600` seconds added, one
  instance per Julia process;
- BaPCod master (ad23eb0) with the diving fix (MR !36), RCSP master (a0fe3a7); Julia 1.10.11, CPLEX 20.1;
- Intel Core i7-12800H, 32 GB, two runs in parallel (the batches with 2 and 4 machines, one at a time, because of the memory);
- every solution was checked by the solution checker of the demo, written from the definition of the problem.

Times are the solver times in seconds (`bcTimeMain`), without the start of Julia; "Root LB" is the lower bound at the
end of the root node, "LB" the best lower bound when the time limit was reached.

## Summary

| Batch | Instances | Solved in 600 s | Total time | Geometric mean time | Max time |
|---|---|---|---|---|---|
| `toy.batch` | 10 | 10 | 7 s | 0.9 s | 1.0 s |
| `wt40-10m.batch` | 25 | 25 | 140 s | 4.6 s | 15.5 s |
| `wt50-10m.batch` | 25 | 21 | 2673 s | 10.4 s | 34.7 s |
| `wt40-4m.batch` | 25 | 24 | 3172 s | 42.8 s | 595.1 s |
| `wt50-4m.batch` | 25 | 17 | 7981 s | 124.4 s | 492.0 s |
| `wt40-2m.batch` | 25 | 20 | 6452 s | 96.2 s | 557.8 s |

Unsolved instances count as 600 s in the total time; the geometric mean and the maximum are over the solved ones.

## Notes

- toy: when the heuristic finds a solution of cost 0, it is optimal and the solver is not called (no root bound, nodes or time in the table).
- Not solved in 600 s: wt50-10m-1, -31, -56, -106; wt40-4m-36; wt50-4m-1, -6, -41, -56, -61, -86, -116, -121; wt40-2m-16, -36, -61, -66, -81. They are now commented out in the batches; several of them are solved in 1800 s, others are out of reach.

## `toy.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| wt10-2m-1 | 0 | — | — | — | — |
| wt10-2m-2 | 0 | — | — | — | — |
| wt10-2m-3 | 65 | 65 | 1.0 | 1 | 1.0 |
| wt10-2m-4 | 70 | 70 | 1.0 | 1 | 1.0 |
| wt10-2m-5 | 94 | 94 | 0.9 | 1 | 0.9 |
| wt10-2m-6 | 2 | 2 | 1.0 | 1 | 1.0 |
| wt10-2m-7 | 199 | 199 | 0.9 | 1 | 0.9 |
| wt10-2m-8 | 0 | — | — | — | — |
| wt10-2m-9 | 98 | 98 | 0.9 | 1 | 0.9 |
| wt10-2m-10 | 152 | 152 | 0.9 | 1 | 0.9 |

## `wt40-10m.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| wt40-10m-1 | 501 | 489 | 4.6 | 9 | 12.9 |
| wt40-10m-6 | 1584 | 1584 | 3.4 | 1 | 3.4 |
| wt40-10m-11 | 3929 | 3917 | 6.8 | 5 | 10.6 |
| wt40-10m-16 | 11987 | 11987 | 3.0 | 1 | 3.0 |
| wt40-10m-21 | 12060 | 12060 | 2.5 | 1 | 2.5 |
| wt40-10m-26 | 208 | 190 | 4.3 | 25 | 10.0 |
| wt40-10m-31 | 2136 | 2136 | 4.2 | 1 | 4.2 |
| wt40-10m-36 | 4940 | 4940 | 3.2 | 1 | 3.2 |
| wt40-10m-41 | 10304 | 10304 | 4.2 | 1 | 4.2 |
| wt40-10m-46 | 10348 | 10348 | 2.3 | 1 | 2.3 |
| wt40-10m-51 | 242 | 242 | 4.0 | 1 | 4.1 |
| wt40-10m-61 | 5769 | 5769 | 3.4 | 1 | 3.4 |
| wt40-10m-56 | 722 | 706 | 5.3 | 5 | 12.4 |
| wt40-10m-66 | 11643 | 11643 | 3.3 | 1 | 3.3 |
| wt40-10m-71 | 14290 | 14290 | 3.1 | 1 | 3.1 |
| wt40-10m-81 | 1415 | 1415 | 3.9 | 1 | 3.9 |
| wt40-10m-76 | 0 | 0 | 3.8 | 37 | 15.5 |
| wt40-10m-86 | 4919 | 4919 | 3.4 | 1 | 3.4 |
| wt40-10m-91 | 9661 | 9661 | 3.9 | 1 | 3.9 |
| wt40-10m-96 | 18580 | 18580 | 3.1 | 1 | 3.1 |
| wt40-10m-106 | 808 | 808 | 3.2 | 1 | 3.2 |
| wt40-10m-101 | 120 | 120 | 4.8 | 21 | 13.6 |
| wt40-10m-111 | 7766 | 7766 | 3.4 | 1 | 3.4 |
| wt40-10m-116 | 9854 | 9854 | 3.5 | 1 | 3.5 |
| wt40-10m-121 | 18814 | 18814 | 3.5 | 1 | 3.5 |

## `wt50-10m.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| wt50-10m-6 | 4782 | 4782 | 7.7 | 1 | 7.7 |
| wt50-10m-11 | 7082 | 7076 | 16.7 | 3 | 20.1 |
| wt50-10m-16 | 13761 | 13761 | 6.0 | 1 | 6.0 |
| wt50-10m-21 | 28666 | 28666 | 6.8 | 1 | 6.8 |
| wt50-10m-26 | 200 | 200 | 7.0 | 37 | 29.9 |
| wt50-10m-1 | not solved (LB 559) | 533 | 18.9 | 239 | limit 600 |
| wt50-10m-36 | 7152 | 7152 | 7.2 | 1 | 7.2 |
| wt50-10m-41 | 12421 | 12421 | 7.8 | 1 | 7.8 |
| wt50-10m-46 | 22154 | 22154 | 5.4 | 1 | 5.4 |
| wt50-10m-51 | 52 | 42 | 18.6 | 21 | 33.5 |
| wt50-10m-31 | not solved (LB 1890) | 1888 | 14.5 | 103 | limit 600 |
| wt50-10m-61 | 5319 | 5319 | 6.7 | 1 | 6.7 |
| wt50-10m-66 | 12895 | 12895 | 6.6 | 1 | 6.6 |
| wt50-10m-71 | 21298 | 21298 | 5.9 | 1 | 5.9 |
| wt50-10m-76 | 0 | 0 | 6.7 | 29 | 29.6 |
| wt50-10m-81 | 930 | 930 | 8.4 | 1 | 8.4 |
| wt50-10m-86 | 6690 | 6677 | 11.0 | 3 | 16.0 |
| wt50-10m-91 | 14483 | 14483 | 13.4 | 1 | 13.4 |
| wt50-10m-96 | 25100 | 25100 | 6.2 | 1 | 6.2 |
| wt50-10m-101 | 70 | 70 | 6.3 | 35 | 34.7 |
| wt50-10m-56 | not solved (LB 520) | 520 | 17.0 | 151 | limit 600 |
| wt50-10m-111 | 7531 | 7531 | 6.7 | 1 | 6.7 |
| wt50-10m-116 | 7015 | 7015 | 8.2 | 1 | 8.2 |
| wt50-10m-121 | 13341 | 13341 | 6.6 | 1 | 6.7 |
| wt50-10m-106 | not solved (LB 828) | 828 | 13.4 | 159 | limit 600 |

## `wt40-4m.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| wt40-4m-1 | 439 | 439 | 16.5 | 29 | 40.5 |
| wt40-4m-6 | 2374 | 2374 | 22.1 | 21 | 40.3 |
| wt40-4m-11 | 5737 | 5737 | 20.2 | 9 | 32.2 |
| wt40-4m-16 | 21493 | 21486 | 18.1 | 3 | 23.3 |
| wt40-4m-21 | 22793 | 22793 | 5.6 | 1 | 5.6 |
| wt40-4m-26 | 88 | 88 | 7.6 | 31 | 41.2 |
| wt40-4m-31 | 2525 | 2500 | 54.1 | 39 | 595.1 |
| wt40-4m-36 | not solved (LB 6371) | 6364 | 62.5 | 27 | limit 600 |
| wt40-4m-41 | 17685 | 17640 | 23.2 | 29 | 209.0 |
| wt40-4m-46 | 19124 | 19124 | 3.7 | 1 | 3.7 |
| wt40-4m-51 | 0 | 0 | 8.1 | 25 | 42.3 |
| wt40-4m-56 | 826 | 816 | 49.5 | 39 | 136.2 |
| wt40-4m-61 | 7357 | 7321 | 26.3 | 51 | 451.0 |
| wt40-4m-66 | 20251 | 20251 | 7.7 | 1 | 7.7 |
| wt40-4m-71 | 26740 | 26740 | 5.2 | 1 | 5.2 |
| wt40-4m-76 | 0 | 0 | 7.0 | 51 | 75.2 |
| wt40-4m-81 | 564 | 559 | 70.6 | 3 | 79.8 |
| wt40-4m-86 | 4725 | 4725 | 8.6 | 1 | 8.6 |
| wt40-4m-91 | 15569 | 15569 | 13.7 | 1 | 13.7 |
| wt40-4m-96 | 36266 | 36266 | 8.1 | 1 | 8.1 |
| wt40-4m-101 | 0 | 0 | 7.0 | 57 | 83.4 |
| wt40-4m-106 | 0 | 0 | 7.2 | 31 | 44.7 |
| wt40-4m-111 | 11263 | 11218 | 41.8 | 41 | 394.6 |
| wt40-4m-116 | 15566 | 15545 | 22.9 | 13 | 86.1 |
| wt40-4m-121 | 35751 | 35741 | 38.7 | 11 | 144.6 |

## `wt50-4m.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| wt50-4m-1 | not solved (LB 785) | 785 | 135.3 | 57 | limit 600 |
| wt50-4m-6 | not solved (LB 8306) | 8304 | 171.4 | 7 | limit 600 |
| wt50-4m-11 | 12879 | 12875 | 129.8 | 17 | 395.2 |
| wt50-4m-16 | 25376 | 25376 | 22.6 | 1 | 22.6 |
| wt50-4m-21 | 59440 | 59440 | 14.9 | 1 | 14.9 |
| wt50-4m-26 | 54 | 54 | 14.4 | 63 | 162.8 |
| wt50-4m-31 | 3061 | 3061 | 18.6 | 31 | 88.2 |
| wt50-4m-36 | 10796 | 10796 | 119.0 | 5 | 127.7 |
| wt50-4m-41 | not solved (LB 21795) | 21785 | 54.9 | 35 | limit 600 |
| wt50-4m-46 | 44455 | 44453 | 77.1 | 3 | 81.9 |
| wt50-4m-51 | 0 | 0 | 13.2 | 57 | 181.2 |
| wt50-4m-56 | not solved (LB 541) | 541 | 93.5 | 15 | limit 600 |
| wt50-4m-61 | not solved (LB 7858) | 7856 | 180.0 | 9 | limit 600 |
| wt50-4m-66 | 23138 | 23138 | 13.5 | 1 | 13.5 |
| wt50-4m-71 | 42645 | 42627 | 30.7 | 15 | 233.1 |
| wt50-4m-76 | 0 | 0 | 16.4 | 59 | 225.0 |
| wt50-4m-81 | 495 | 493 | 179.9 | 37 | 385.9 |
| wt50-4m-86 | not solved (LB 8354) | 8333 | 68.4 | 27 | limit 600 |
| wt50-4m-91 | 26551 | 26548 | 70.4 | 3 | 77.6 |
| wt50-4m-96 | 50326 | 50316 | 121.1 | 23 | 492.0 |
| wt50-4m-101 | 0 | 0 | 14.2 | 85 | 296.6 |
| wt50-4m-106 | 0 | 0 | 14.6 | 65 | 202.6 |
| wt50-4m-111 | 10069 | 10051 | 66.9 | 7 | 180.0 |
| wt50-4m-116 | not solved (LB 11527) | 11523 | 55.7 | 19 | limit 600 |
| wt50-4m-121 | not solved (LB 23783) | 23774 | 69.3 | 25 | limit 600 |

## `wt40-2m.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| wt40-2m-1 | 606 | 606 | 132.5 | 29 | 266.8 |
| wt40-2m-6 | 3886 | 3886 | 100.2 | 33 | 216.1 |
| wt40-2m-11 | 9617 | 9617 | 58.8 | 9 | 85.2 |
| wt40-2m-16 | not solved (LB 38335) | 38335 | 602.7 | 1 | limit 600 |
| wt40-2m-21 | 41048 | 41048 | 9.0 | 1 | 9.1 |
| wt40-2m-26 | 87 | 87 | 28.2 | 41 | 136.2 |
| wt40-2m-31 | 3812 | 3812 | 214.5 | 7 | 358.5 |
| wt40-2m-36 | not solved (LB 10702) | 10702 | 602.4 | 1 | limit 600 |
| wt40-2m-41 | 30802 | 30802 | 11.6 | 1 | 11.6 |
| wt40-2m-46 | 34146 | 34146 | 6.3 | 1 | 6.3 |
| wt40-2m-51 | 0 | 0 | 14.0 | 43 | 183.4 |
| wt40-2m-56 | 1279 | 1279 | 75.9 | 29 | 199.3 |
| wt40-2m-61 | not solved (LB 11391) | 11391 | 601.4 | 1 | limit 600 |
| wt40-2m-66 | not solved (LB 35190) | 35190 | 605.7 | 1 | limit 600 |
| wt40-2m-71 | 47952 | 47952 | 69.0 | 1 | 69.0 |
| wt40-2m-76 | 0 | 0 | 10.6 | 53 | 181.6 |
| wt40-2m-81 | not solved (LB 520) | 520 | 351.9 | 3 | limit 600 |
| wt40-2m-86 | 6048 | 6041 | 428.9 | 3 | 557.8 |
| wt40-2m-91 | 26075 | 26075 | 17.3 | 1 | 17.3 |
| wt40-2m-96 | 66116 | 66116 | 38.4 | 1 | 38.4 |
| wt40-2m-101 | 0 | 0 | 16.1 | 51 | 232.0 |
| wt40-2m-106 | 0 | 0 | 14.7 | 51 | 250.9 |
| wt40-2m-111 | 17936 | 17936 | 239.9 | 1 | 239.9 |
| wt40-2m-116 | 25870 | 25870 | 358.6 | 1 | 358.6 |
| wt40-2m-121 | 64516 | 64516 | 34.2 | 1 | 34.2 |
