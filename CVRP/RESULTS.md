# CVRP: computational results of the batches

Results of the CVRP demo on its batches (CVRPLIB sets A, B, E, M, F, P, X), with the upper bound `-u` = optimal cost + 1 and the number of routes of each batch line.

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
| `A.batch` | 22 | 22 | 51 s | 1.8 s | 6.8 s |
| `B.batch` | 20 | 20 | 100 s | 3.3 s | 28.5 s |
| `EM.batch` | 10 | 9 | 691 s | 6.6 s | 23.8 s |
| `F.batch` | 3 | 2 | 617 s | 6.5 s | 14.0 s |
| `P.batch` | 23 | 23 | 105 s | 1.2 s | 55.5 s |
| `X.batch` | 11 | 11 | 428 s | 25.0 s | 85.6 s |

Unsolved instances count as 600 s in the total time; the geometric mean and the maximum are over the solved ones.

## Notes

- M-n200-k17 (`EM`) and F-n135-k7 (`F`) are not solved in 600 s; they are now commented out in the batches.
- Some runs print `BaPCod WARNING : objVal = ... does not correspond to the cost of the best column`, with differences up to 5e-5. They come from dual values below 1e-6 that BaPCod drops when it computes the reduced costs given to the pricing; they do not affect the results, and a BaPCod change in preparation removes them.

## `A.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| A-n37-k5 | 669 | 669 | 0.6 | 1 | 0.6 |
| A-n37-k6 | 949 | 949 | 2.0 | 1 | 2.0 |
| A-n38-k5 | 730 | 730 | 0.8 | 1 | 0.8 |
| A-n39-k5 | 822 | 822 | 1.0 | 1 | 1.0 |
| A-n39-k6 | 831 | 831 | 1.5 | 1 | 1.5 |
| A-n44-k6 | 937 | 937 | 0.7 | 1 | 0.7 |
| A-n45-k6 | 944 | 944 | 0.6 | 1 | 0.6 |
| A-n45-k7 | 1146 | 1146 | 0.9 | 1 | 0.9 |
| A-n46-k7 | 914 | 914 | 0.6 | 1 | 0.6 |
| A-n48-k7 | 1073 | 1073 | 0.8 | 1 | 0.8 |
| A-n53-k7 | 1010 | 1010 | 2.9 | 1 | 2.9 |
| A-n54-k7 | 1167 | 1167 | 3.4 | 1 | 3.4 |
| A-n55-k9 | 1073 | 1073 | 1.0 | 1 | 1.0 |
| A-n61-k9 | 1034 | 1034 | 3.1 | 1 | 3.1 |
| A-n60-k9 | 1354 | 1354 | 3.0 | 1 | 3.0 |
| A-n62-k8 | 1288 | 1288 | 4.5 | 1 | 4.5 |
| A-n63-k9 | 1616 | 1616 | 3.7 | 1 | 3.7 |
| A-n63-k10 | 1314 | 1314 | 3.6 | 1 | 3.6 |
| A-n64-k9 | 1401 | 1401 | 6.8 | 1 | 6.8 |
| A-n65-k9 | 1174 | 1174 | 3.0 | 1 | 3.0 |
| A-n69-k9 | 1159 | 1159 | 3.5 | 1 | 3.5 |
| A-n80-k10 | 1763 | 1763 | 3.2 | 1 | 3.2 |

## `B.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| B-n38-k6 | 805 | 805 | 1.6 | 1 | 1.6 |
| B-n39-k5 | 549 | 549 | 1.5 | 1 | 1.5 |
| B-n41-k6 | 829 | 829 | 1.1 | 1 | 1.1 |
| B-n43-k6 | 742 | 742 | 5.3 | 1 | 5.3 |
| B-n44-k7 | 909 | 909 | 1.5 | 1 | 1.5 |
| B-n45-k5 | 751 | 751 | 3.6 | 1 | 3.6 |
| B-n45-k6 | 678 | 678 | 1.4 | 1 | 1.4 |
| B-n50-k7 | 741 | 741 | 3.3 | 1 | 3.3 |
| B-n50-k8 | 1312 | 1312 | 10.7 | 1 | 10.7 |
| B-n51-k7 | 1032 | 1032 | 6.5 | 1 | 6.5 |
| B-n52-k7 | 747 | 747 | 1.3 | 1 | 1.3 |
| B-n56-k7 | 707 | 707 | 1.4 | 1 | 1.4 |
| B-n57-k7 | 1153 | 1153 | 5.2 | 1 | 5.2 |
| B-n57-k9 | 1598 | 1598 | 1.9 | 1 | 1.9 |
| B-n63-k10 | 1496 | 1496 | 2.4 | 1 | 2.4 |
| B-n64-k9 | 861 | 861 | 2.2 | 1 | 2.2 |
| B-n66-k9 | 1316 | 1316 | 7.8 | 1 | 7.8 |
| B-n67-k10 | 1032 | 1032 | 6.8 | 1 | 6.8 |
| B-n78-k10 | 1221 | 1221 | 6.3 | 1 | 6.3 |
| B-n68-k9 | 1272 | 1272 | 28.5 | 1 | 28.5 |

## `EM.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| E-n51-k5 | 521 | 521 | 0.7 | 1 | 0.7 |
| E-n76-k7 | 682 | 682 | 9.2 | 1 | 9.2 |
| E-n76-k8 | 735 | 735 | 8.4 | 1 | 8.4 |
| E-n76-k10 | 830 | 830 | 8.7 | 1 | 8.7 |
| E-n76-k14 | 1021 | 1021 | 3.9 | 1 | 3.9 |
| E-n101-k14 | 1067 | 1067 | 17.1 | 1 | 17.1 |
| E-n101-k8 | 815 | 815 | 23.8 | 1 | 23.8 |
| M-n101-k10 | 820 | 820 | 1.6 | 1 | 1.6 |
| M-n121-k7 | 1034 | 1034 | 17.9 | 1 | 17.9 |
| M-n200-k17 | not solved (LB 1272) | 1272 | 459.7 | 1 | limit 600 |

## `F.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| F-n45-k4 | 724 | 724 | 3.0 | 1 | 3.0 |
| F-n72-k4 | 237 | 237 | 14.0 | 1 | 14.0 |
| F-n135-k7 | not solved (LB 1158) | 1158 | 600.5 | 1 | limit 600 |

## `P.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| P-n19-k2 | 212 | 212 | 0.4 | 1 | 0.4 |
| P-n20-k2 | 216 | 216 | 0.4 | 1 | 0.4 |
| P-n21-k2 | 211 | 211 | 0.4 | 1 | 0.4 |
| P-n22-k2 | 216 | 216 | 0.4 | 1 | 0.4 |
| P-n22-k8 | 603 | 603 | 0.3 | 1 | 0.3 |
| P-n23-k8 | 529 | 529 | 0.3 | 1 | 0.3 |
| P-n40-k5 | 458 | 458 | 0.5 | 1 | 0.5 |
| P-n45-k5 | 510 | 510 | 1.1 | 1 | 1.1 |
| P-n50-k10 | 696 | 696 | 0.5 | 1 | 0.5 |
| P-n50-k7 | 554 | 554 | 1.5 | 1 | 1.5 |
| P-n50-k8 | 631 | 631 | 3.2 | 1 | 3.2 |
| P-n51-k10 | 741 | 741 | 0.5 | 1 | 0.5 |
| P-n55-k10 | 694 | 694 | 2.1 | 1 | 2.1 |
| P-n55-k15 | 989 | 989 | 0.5 | 1 | 0.5 |
| P-n55-k7 | 568 | 568 | 2.5 | 1 | 2.5 |
| P-n55-k8 | 588 | 588 | 2.0 | 1 | 2.0 |
| P-n60-k10 | 744 | 744 | 0.8 | 1 | 0.8 |
| P-n60-k15 | 968 | 968 | 0.4 | 1 | 0.4 |
| P-n65-k10 | 792 | 792 | 1.0 | 1 | 1.0 |
| P-n70-k10 | 827 | 827 | 4.1 | 1 | 4.1 |
| P-n76-k4 | 593 | 593 | 10.8 | 1 | 10.8 |
| P-n76-k5 | 627 | 627 | 15.7 | 1 | 15.7 |
| P-n101-k4 | 681 | 681 | 55.5 | 1 | 55.5 |

## `X.batch`

| Instance | Optimum | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| X-n101-k25 | 27591 | 27591 | 3.2 | 1 | 3.3 |
| X-n115-k10 | 12747 | 12747 | 29.7 | 1 | 29.7 |
| X-n125-k30 | 55539 | 55539 | 51.1 | 1 | 51.1 |
| X-n148-k46 | 43448 | 43448 | 7.4 | 1 | 7.4 |
| X-n129-k18 | 28940 | 28910 | 36.6 | 3 | 85.2 |
| X-n157-k13 | 16876 | 16876 | 15.8 | 1 | 15.8 |
| X-n172-k51 | 45607 | 45560 | 29.9 | 3 | 45.5 |
| X-n219-k73 | 117595 | 117595 | 5.3 | 1 | 5.3 |
| X-n195-k51 | 44225 | 44162 | 26.7 | 3 | 85.6 |
| X-n275-k28 | 21245 | 21245 | 57.6 | 1 | 57.6 |
| X-n317-k53 | 78355 | 78355 | 41.0 | 1 | 41.0 |
