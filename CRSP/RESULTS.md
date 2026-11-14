# CRSP: computational results of the batches

Results of the CRSP demo on `A.batch` (set A, 25% of Steiner points, k = 3, star cost factor 0.5), without a given upper bound: the heuristic of the demo gives it.

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
| `A.batch` | 27 | 25 | 2356 s | 22.1 s | 274.2 s |

Unsolved instances count as 600 s in the total time; the geometric mean and the maximum are over the solved ones.

## Notes

- A-n64-k9 and A-n80-k10 are not solved in 600 s; they are now commented out in the batch.
- Some runs print `BaPCod WARNING : objVal = ... does not correspond to the cost of the best column`, with differences up to 2e-5. They come from dual values below 1e-6 that BaPCod drops when it computes the reduced costs given to the pricing; they do not affect the results, and a BaPCod change in preparation removes them.

## `A.batch`

| Instance | Best solution | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| A-n32-k5 | 577 | 577 | 10.9 | 1 | 10.9 |
| A-n33-k5 | 483 | 483 | 15.5 | 1 | 15.5 |
| A-n33-k6 | 530 | 530 | 8.1 | 1 | 8.1 |
| A-n34-k5 | 521 | 521 | 5.8 | 1 | 5.8 |
| A-n36-k5 | 569 | 569 | 6.8 | 1 | 6.8 |
| A-n37-k5 | 422 | 422 | 10.0 | 1 | 10.0 |
| A-n37-k6 | 661 | 661 | 12.0 | 1 | 12.0 |
| A-n38-k5 | 538 | 538 | 9.3 | 1 | 9.3 |
| A-n39-k5 | 548 | 547 | 11.9 | 3 | 16.3 |
| A-n39-k6 | 548 | 548 | 9.8 | 1 | 9.8 |
| A-n44-k6 | 716 | 716 | 6.8 | 1 | 6.8 |
| A-n45-k6 | 721 | 715 | 15.8 | 3 | 23.1 |
| A-n45-k7 | 876 | 876 | 7.2 | 3 | 8.5 |
| A-n46-k7 | 709 | 709 | 16.7 | 1 | 16.7 |
| A-n48-k7 | 711 | 711 | 10.2 | 1 | 10.2 |
| A-n53-k7 | 747 | 747 | 128.8 | 1 | 128.8 |
| A-n54-k7 | 849 | 849 | 195.1 | 1 | 195.1 |
| A-n55-k9 | 805 | 797 | 13.9 | 11 | 74.0 |
| A-n60-k9 | 1000 | 1000 | 18.7 | 1 | 18.7 |
| A-n61-k9 | 762 | 759 | 35.2 | 7 | 117.0 |
| A-n63-k9 | 1196 | 1196 | 14.6 | 1 | 14.6 |
| A-n63-k10 | 892 | 892 | 33.6 | 1 | 33.6 |
| A-n62-k8 | 993 | 993 | 191.1 | 3 | 274.2 |
| A-n65-k9 | 857 | 854 | 54.9 | 3 | 97.5 |
| A-n69-k9 | 875 | 875 | 23.2 | 3 | 32.9 |
| A-n64-k9 | not solved (LB 1016) | 1009 | 33.8 | 21 | limit 600 |
| A-n80-k10 | not solved (LB 1188) | 1185 | 193.4 | 7 | limit 600 |
