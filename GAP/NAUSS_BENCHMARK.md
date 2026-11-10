# GAP: Nauss instances with four upper bound policies

Benchmark of the GAP demo on the 30 Nauss instances with 90 or 100 tasks and 25 or 30 machines
(the instances used by Pessoa et al. 2020), with four ways of giving (or not) an upper bound:

| Policy | Batch | Options |
|---|---|---|
| Literature ub | `nauss-literature-ub.batch` | `-u <ub from the literature>` |
| Diving, no ub | `nauss-diving.batch` | `-d` (diving heuristic at the root, parameters of Pessoa et al. 2020) |
| Tentative ub, no ub | `nauss-tentative.batch` | `-t 10 4`: the root is solved first, then the problem is solved with ub = LB + 10, LB + 14, ... |
| ub = opt + 1 | `nauss.batch` | `-u <optimum + 1>` |

All runs use `config/GAP_Nauss.cfg` with `GlobalTimeLimit = 1800` (seconds). For the tentative policy, the nodes
and the time are the sums over all its VRPSolver calls (root and tentative runs). Every solution was checked
by the solution checker of the demo.

## Summary

| Policy | Solved (of 30) | Total time (s) | Geometric mean time (s) | Total nodes |
|---|---|---|---|---|
| Literature ub | 28 | 12697 | 260.2 | 16028 |
| Diving, no ub | 27 | 17426 | 410.9 | 20626 |
| Tentative ub, no ub | 29 | 8938 | 141.4 | 14332 |
| ub = opt + 1 | 30 | 5444 | 85.5 | 9254 |

Unsolved runs count as 1800 s in the time columns.

## Results per instance

Nodes / time in seconds.

| Instance | Optimum | Lit. ub value | Root LB | Literature ub | Diving, no ub | Tentative ub, no ub (calls after the root) | ub = opt + 1 |
|---|---|---|---|---|---|---|---|
| gapD-25-90-e0 | 5681 | 5686 | 5673 | 123 / 70 | 217 / 253 | 72 / 39 (1) | 49 / 26 |
| gapD-25-90-e1 | 5627 | 5637 | 5619 | 167 / 112 | 187 / 168 | 112 / 62 (1) | 95 / 51 |
| gapD-25-90-e2 | 5676 | 5680 | 5665 | 293 / 174 | 411 / 415 | 437 / 257 (2) | 261 / 147 |
| gapD-25-90-e3 | 5657 | 5663 | 5650 | 121 / 68 | 85 / 86 | 88 / 52 (1) | 33 / 18 |
| gapD-25-90-e4 | 5647 | 5647 | 5639 | 21 / 10 (infeasible, see note 1) | 201 / 175 | 54 / 32 (1) | 31 / 18 |
| gapD-25-90-e5 | 5621 | 5632 | 5614 | 207 / 121 | 185 / 151 | 34 / 19 (1) | 15 / 7 |
| gapD-25-90-e6 | 5657 | 5666 | 5649 | 225 / 127 | 213 / 215 | 62 / 34 (1) | 35 / 19 |
| gapD-25-90-e7 | 5614 | 5621 | 5606 | 221 / 124 | 315 / 235 | 136 / 72 (1) | 129 / 67 |
| gapD-25-90-e8 | 5574 | 5580 | 5567 | 71 / 44 | 107 / 107 | 32 / 21 (1) | 15 / 9 |
| gapD-25-90-e9 | 5660 | 5670 | 5650 | 513 / 452 | 889 / 867 | 1187 / 1104 (2) | 373 / 296 |
| gapD-25-100-e0 | 6349 | 6359 | 6338 | 2631 / >1800 (time limit) | 2361 / >1800 (time limit) | 3331 / >1800 (time limit) (2) | 2459 / 1346 |
| gapD-25-100-e1 | 6327 | 6339 | 6320 | 903 / 724 | 1765 / >1800 (time limit) | 804 / 505 (1) | 117 / 72 |
| gapD-25-100-e2 | 6303 | 6311 | 6291 | 1353 / 918 | 1467 / 1003 | 1521 / 887 (2) | 1579 / 914 |
| gapD-25-100-e3 | 6283 | 6292 | 6275 | 185 / 142 | 163 / 164 | 188 / 112 (1) | 139 / 81 |
| gapD-25-100-e4 | 6305 | 6311 | 6296 | 485 / 311 | 375 / 296 | 258 / 143 (1) | 257 / 140 |
| gapD-25-100-e5 | 6289 | 6293 | 6280 | 175 / 105 | 873 / 918 | 142 / 78 (1) | 141 / 77 |
| gapD-25-100-e6 | 6227 | 6232 | 6218 | 535 / 311 | 2479 / >1800 (time limit) | 278 / 147 (1) | 277 / 144 |
| gapD-25-100-e7 | 6238 | 6247 | 6228 | 1419 / 971 | 1751 / 1202 | 1537 / 951 (2) | 865 / 524 |
| gapD-25-100-e8 | 6248 | 6254 | 6240 | 211 / 149 | 207 / 199 | 120 / 72 (1) | 117 / 62 |
| gapD-25-100-e9 | 6301 | 6308 | 6292 | 1373 / 899 | 795 / 560 | 298 / 178 (1) | 297 / 172 |
| gapD-30-100-e0 | 6270 | 6275 | 6262 | 337 / 211 | 561 / 617 | 206 / 130 (1) | 111 / 69 |
| gapD-30-100-e1 | 6299 | 6309 | 6290 | 587 / 406 | 771 / 534 | 174 / 103 (1) | 173 / 96 |
| gapD-30-100-e2 | 6162 | 6175 | 6153 | 337 / 334 | 319 / 320 | 184 / 151 (1) | 183 / 146 |
| gapD-30-100-e3 | 6306 | 6311 | 6296 | 319 / 193 | 435 / 355 | 479 / 295 (2) | 233 / 152 |
| gapD-30-100-e4 | 6322 | 6330 | 6315 | 293 / 186 | 517 / 428 | 164 / 96 (1) | 67 / 39 |
| gapD-30-100-e5 | 6284 | 6290 | 6275 | 405 / 274 | 383 / 346 | 180 / 115 (1) | 179 / 112 |
| gapD-30-100-e6 | 6329 | 6338 | 6318 | 1419 / 941 | 1245 / 985 | 843 / 538 (2) | 303 / 189 |
| gapD-30-100-e7 | 6358 | 6365 | 6349 | 321 / 206 | 383 / 337 | 168 / 95 (1) | 167 / 92 |
| gapD-30-100-e8 | 6372 | 6376 | 6362 | 641 / 440 | 727 / 834 | 1145 / 791 (2) | 499 / 330 |
| gapD-30-100-e9 | 6433 | 6439 | 6425 | 137 / 84 | 239 / 259 | 98 / 58 (1) | 55 / 29 |

Root LB is the root lower bound (rounded up) of the run with ub = opt + 1.

## Notes

1. **gapD-25-90-e4.** The upper bound of the literature, 5647, is the optimum itself. With it, the VRPSolver
   ends with "Problem infeasible". This is correct: it proves that there is no solution with a cost below 5647.
   With `-u 5648` the optimal solution of cost 5647 is found.
2. **Literature upper bounds.** Except for gapD-25-90-e4, they are 4 to 13 above the optimum. The time of the
   VRPSolver depends strongly on the upper bound. For example, gapD-25-100-e1 takes 72 s with ub = opt + 1,
   505 s with ub = opt + 3 (tentative policy) and 724 s with ub = opt + 12 (literature).
3. **Tentative upper bounds.** The policy needs a single call after the root when opt < LB + 10, and a second
   call otherwise (8 of the 30 instances: gapD-25-100-e0, gapD-25-100-e2, gapD-25-100-e7, gapD-25-90-e2, gapD-25-90-e9, gapD-30-100-e3, gapD-30-100-e6, gapD-30-100-e8). An unsuccessful call proves that there is
   no solution below its upper bound, so the method is exact. The difference between the optimum and the
   (rounded up) root lower bound ranges from 7 to 12 on these instances, so
   `-t 13 4` would have needed a single call in all of them (a choice made after seeing the results).
   gapD-25-100-e0 was solved by the tentative policy (optimum 6349) but its three calls took 1858 s in total, above
   the 1800 s limit, so it is counted as unsolved.
4. **Diving.** The diving heuristic at the root often gives a poor upper bound, and the search is then larger.
   It did not finish within 1800 s on gapD-25-100-e0 (incumbent 6349 = optimum, lower bound 6340),
   gapD-25-100-e1 (incumbent 6330, optimum 6327) and gapD-25-100-e6 (incumbent 6231, optimum 6227).
   The literature ub did not finish on gapD-25-100-e0 either (incumbent 6349 = optimum, lower bound 6340).
5. Without any upper bound and without `-d` or `-t`, the demo has no primal heuristic and may not find any
   solution for a long time on these instances.

## Setup

- Laptop with an Intel Core i7-12800H and 32 GB of memory; 2 runs in parallel (memory is the limit: the instances
  with 25 or 30 machines use 5 to 10 GB per process, mostly for the enumerated paths kept for the open nodes).
- Julia 1.10.11, VrpSolver.jl branch `update_rcsp_interface`, CPLEX 20.1.
- BaPCod master c11ec6c plus MR !33 (commit 8c91e28), RCSP master ede92a1 plus MR !35 (commits b1253e0, ed4f76e).
- November 2026.

## Reproducing

From the GAP folder (with `GlobalTimeLimit = 1800` added to a copy of `config/GAP_Nauss.cfg` to apply the same limit):

```
julia src/run.jl -b nauss.batch &> out/nauss.out
julia src/run.jl -b nauss-literature-ub.batch &> out/nauss-literature-ub.out
julia src/run.jl -b nauss-diving.batch &> out/nauss-diving.out
julia src/run.jl -b nauss-tentative.batch &> out/nauss-tentative.out
```

Reference: A. Pessoa, R. Sadykov, E. Uchoa, F. Vanderbeck. A generic exact solver for vehicle routing and related
problems. Mathematical Programming 183:483-523, 2020.

