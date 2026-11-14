# GAP: computational results of the batches

Results of the GAP demo on `classic.batch` and `nauss.batch`, with the upper bound `-u` = optimal cost + 1. `CLASSIC_RESULTS.md` compares the classic instances with the literature, and `NAUSS_BENCHMARK.md` compares four upper bound policies on the Nauss instances (with 1800 s).

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
| `classic.batch` | 5 | 4 | 1145 s | 76.0 s | 341.9 s |
| `nauss.batch` | 30 | 28 | 4555 s | 75.5 s | 524.8 s |

Unsolved instances count as 600 s in the total time; the geometric mean and the maximum are over the solved ones.

## Notes

- gapD-10-200 (classic) and gapD-25-100-e0, gapD-25-100-e2 (Nauss) are not solved in 600 s (they are in 1800 s, see the other two documents); they are now commented out in the batches.
- Some runs print `BaPCod WARNING : objVal = ... does not correspond to the cost of the best column`, with differences up to 2e-6. They come from dual values below 1e-6 that BaPCod drops when it computes the reduced costs given to the pricing; they do not affect the results, and a BaPCod change in preparation removes them.

## `classic.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| gapD-5-100 | 6353 | 6353 | 17.6 | 1 | 17.6 |
| gapD-10-100 | 6347 | 6343 | 9.2 | 9 | 37.3 |
| gapD-5-200 | 12742 | 12741 | 112.8 | 3 | 148.2 |
| gapD-20-100 | 6185 | 6177 | 8.0 | 123 | 341.9 |
| gapD-10-200 | not solved (LB 12428) | 12427 | 91.0 | 19 | limit 600 |

## `nauss.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| gapD-25-90-e0 | 5681 | 5673 | 2.0 | 49 | 25.6 |
| gapD-25-90-e1 | 5627 | 5619 | 2.1 | 95 | 52.8 |
| gapD-25-90-e3 | 5657 | 5650 | 2.0 | 33 | 19.4 |
| gapD-25-90-e4 | 5647 | 5639 | 2.2 | 31 | 19.5 |
| gapD-25-90-e5 | 5621 | 5614 | 1.9 | 15 | 7.9 |
| gapD-25-90-e2 | 5676 | 5665 | 2.6 | 261 | 161.4 |
| gapD-25-90-e6 | 5657 | 5649 | 2.2 | 35 | 18.8 |
| gapD-25-90-e8 | 5574 | 5567 | 2.0 | 15 | 9.8 |
| gapD-25-90-e7 | 5614 | 5606 | 2.2 | 129 | 77.5 |
| gapD-25-90-e9 | 5660 | 5650 | 2.3 | 373 | 315.0 |
| gapD-25-100-e1 | 6327 | 6320 | 2.5 | 117 | 75.2 |
| gapD-25-100-e0 | not solved (LB 6340) | 6338 | 3.8 | 1001 | limit 600 |
| gapD-25-100-e3 | 6283 | 6275 | 2.7 | 139 | 83.2 |
| gapD-25-100-e4 | 6305 | 6296 | 2.9 | 257 | 150.5 |
| gapD-25-100-e5 | 6289 | 6280 | 2.9 | 141 | 80.6 |
| gapD-25-100-e2 | not solved (LB 6293) | 6291 | 3.9 | 1023 | limit 600 |
| gapD-25-100-e6 | 6227 | 6218 | 3.0 | 277 | 146.8 |
| gapD-25-100-e8 | 6248 | 6240 | 2.7 | 117 | 62.0 |
| gapD-25-100-e9 | 6301 | 6292 | 2.9 | 297 | 175.7 |
| gapD-30-100-e0 | 6270 | 6262 | 2.7 | 111 | 73.1 |
| gapD-25-100-e7 | 6238 | 6228 | 3.2 | 865 | 524.8 |
| gapD-30-100-e1 | 6299 | 6290 | 2.6 | 173 | 101.8 |
| gapD-30-100-e2 | 6162 | 6153 | 2.6 | 183 | 157.2 |
| gapD-30-100-e4 | 6322 | 6315 | 2.4 | 67 | 37.7 |
| gapD-30-100-e3 | 6306 | 6296 | 2.7 | 233 | 157.2 |
| gapD-30-100-e5 | 6284 | 6275 | 2.3 | 179 | 123.0 |
| gapD-30-100-e6 | 6329 | 6318 | 2.5 | 303 | 207.7 |
| gapD-30-100-e7 | 6358 | 6349 | 2.5 | 167 | 101.5 |
| gapD-30-100-e9 | 6433 | 6425 | 2.5 | 55 | 31.6 |
| gapD-30-100-e8 | 6372 | 6362 | 2.6 | 499 | 357.3 |
