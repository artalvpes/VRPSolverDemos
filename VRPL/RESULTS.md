# VRPL: computational results of the batches

Results of the VRPL demo on `VRPDA.batch` (the 100 VRPDA instances, alpha = 1, k = 3), without a given upper bound: the heuristic of the demo gives it.

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
| `VRPDA.batch` | 100 | 81 | 15060 s | 7.0 s | 461.4 s |

Unsolved instances count as 600 s in the total time; the geometric mean and the maximum are over the solved ones.

## Notes

- 19 instances are not solved in 600 s (`not solved` in the table, with the lower bound reached); they are now commented out in the batch.
- Some runs print `BaPCod WARNING : objVal = ... does not correspond to the cost of the best column`, with differences up to 4e-6. They come from dual values below 1e-6 that BaPCod drops when it computes the reduced costs given to the pricing; they do not affect the results, and a BaPCod change in preparation removes them.

## `VRPDA.batch`

| Instance | Best solution | Root LB | Root time | Nodes | Time |
|---|---|---|---|---|---|
| s10k20_1 | 862.93 | 862.93 | 0.5 | 1 | 0.5 |
| s10k20_2 | 830.35 | 830.35 | 0.5 | 1 | 0.5 |
| s10k20_3 | 769.93 | 769.93 | 0.5 | 1 | 0.5 |
| s10k20_4 | 929.56 | 929.56 | 0.5 | 1 | 0.5 |
| s10k20_5 | 790.73 | 790.73 | 0.4 | 1 | 0.4 |
| s10k30_1 | 1081.06 | 1081.06 | 0.6 | 1 | 0.6 |
| s10k30_2 | 1123.85 | 1123.85 | 1.1 | 1 | 1.1 |
| s10k30_3 | 995.61 | 995.61 | 8.6 | 1 | 8.6 |
| s10k30_5 | 1149.90 | 1149.90 | 2.5 | 1 | 2.5 |
| s10k40_1 | 1490.06 | 1480.28 | 20.7 | 3 | 32.1 |
| s10k40_2 | 1529.39 | 1529.39 | 48.5 | 1 | 48.5 |
| s10k30_4 | 1320.74 | 1318.32 | 379.6 | 3 | 461.4 |
| s10k40_4 | 1399.70 | 1399.70 | 150.6 | 1 | 150.6 |
| s10k40_5 | 1499.22 | 1499.22 | 0.9 | 1 | 0.9 |
| s10k50_1 | 2013.51 | 2013.51 | 1.8 | 1 | 1.8 |
| s10k40_3 | not solved (LB 1609.98) | 1600.11 | 1.8 | 17 | limit 600 |
| s10k50_3 | 1560.29 | 1560.29 | 1.4 | 1 | 1.4 |
| s10k50_4 | 1818.93 | 1818.93 | 3.6 | 1 | 3.6 |
| s10k50_5 | 1753.09 | 1753.09 | 9.8 | 1 | 9.8 |
| s25k20_1 | 689.42 | 689.42 | 0.5 | 1 | 0.5 |
| s25k20_2 | 683.33 | 683.33 | 0.5 | 1 | 0.5 |
| s25k20_3 | 837.24 | 837.24 | 1.3 | 1 | 1.3 |
| s25k20_4 | 701.69 | 701.69 | 0.6 | 1 | 0.6 |
| s25k20_5 | 706.73 | 706.73 | 0.5 | 1 | 0.5 |
| s25k30_1 | 935.73 | 935.73 | 3.3 | 1 | 3.3 |
| s25k30_2 | 913.24 | 913.24 | 0.7 | 1 | 0.7 |
| s25k30_3 | 1004.84 | 1004.84 | 0.6 | 1 | 0.6 |
| s25k30_4 | 996.08 | 996.08 | 0.7 | 1 | 0.7 |
| s25k30_5 | 1074.25 | 1074.25 | 0.7 | 1 | 0.7 |
| s25k40_1 | 1108.71 | 1108.71 | 1.1 | 1 | 1.1 |
| s25k40_2 | 1223.77 | 1220.59 | 5.4 | 5 | 14.4 |
| s25k40_3 | 1193.83 | 1193.83 | 1.0 | 1 | 1.0 |
| s25k40_4 | 1282.49 | 1282.49 | 8.2 | 1 | 8.2 |
| s25k40_5 | 1210.96 | 1210.96 | 1.0 | 1 | 1.0 |
| s25k50_1 | 1504.94 | 1504.94 | 10.4 | 1 | 10.4 |
| s25k50_2 | 1518.07 | 1512.75 | 6.7 | 11 | 38.0 |
| s25k50_3 | 1350.45 | 1350.45 | 2.1 | 1 | 2.1 |
| s25k50_4 | 1439.96 | 1439.96 | 12.5 | 1 | 12.5 |
| s10k50_2 | not solved (LB 1877.24) | 1877.24 | 464.1 | 3 | limit 600 |
| s35k40_1 | 1101.63 | 1101.63 | 1.4 | 1 | 1.4 |
| s35k40_2 | 1120.66 | 1102.49 | 5.1 | 7 | 19.1 |
| s35k40_3 | 1108.41 | 1108.41 | 1.1 | 1 | 1.1 |
| s35k40_4 | 1177.38 | 1177.38 | 1.2 | 1 | 1.2 |
| s35k40_5 | 1164.72 | 1164.72 | 1.0 | 1 | 1.0 |
| s35k50_1 | 1288.89 | 1267.56 | 17.9 | 3 | 29.0 |
| s35k50_2 | 1282.07 | 1280.48 | 10.7 | 3 | 33.1 |
| s35k50_3 | 1362.04 | 1362.04 | 1.3 | 1 | 1.3 |
| s35k50_4 | 1254.82 | 1254.82 | 9.3 | 1 | 9.3 |
| s35k50_5 | 1295.95 | 1295.95 | 5.0 | 1 | 5.0 |
| s35k60_1 | 1411.83 | 1411.83 | 2.4 | 1 | 2.4 |
| s35k60_2 | 1514.00 | 1514.00 | 21.7 | 1 | 21.7 |
| s25k50_5 | 1452.73 | 1447.33 | 308.1 | 3 | 405.7 |
| s35k60_3 | 1391.39 | 1375.35 | 31.1 | 9 | 149.8 |
| s35k60_4 | 1497.86 | 1483.59 | 13.0 | 13 | 114.7 |
| s35k60_5 | 1643.15 | 1643.15 | 149.5 | 1 | 149.5 |
| s35k70_2 | 1675.20 | 1665.29 | 31.8 | 17 | 415.2 |
| s35k70_3 | 1551.27 | 1551.27 | 15.8 | 1 | 15.8 |
| s35k70_1 | not solved (LB 1753.92) | 1747.27 | 55.8 | 9 | limit 600 |
| s35k70_5 | 1622.81 | 1622.81 | 12.0 | 1 | 12.0 |
| s40k50_1 | 1255.31 | 1246.09 | 23.2 | 3 | 50.7 |
| s40k50_2 | 1210.76 | 1209.81 | 7.9 | 3 | 10.2 |
| s40k50_3 | 1187.64 | 1187.64 | 3.3 | 1 | 3.3 |
| s40k50_4 | 1304.94 | 1304.94 | 1.4 | 1 | 1.4 |
| s40k50_5 | 1289.31 | 1289.31 | 3.1 | 1 | 3.1 |
| s35k70_4 | not solved (LB 1682.42) | 1672.86 | 35.8 | 23 | limit 600 |
| s40k60_2 | 1418.91 | 1418.91 | 10.2 | 1 | 10.2 |
| s40k60_3 | 1411.83 | 1411.83 | 7.8 | 1 | 7.8 |
| s40k60_4 | 1579.25 | 1579.25 | 3.2 | 1 | 3.2 |
| s40k60_5 | 1546.38 | 1531.55 | 19.1 | 3 | 36.3 |
| s40k70_1 | 1632.96 | 1632.96 | 4.8 | 1 | 4.8 |
| s40k60_1 | not solved (LB 1455.37) | 1447.83 | 28.5 | 9 | limit 600 |
| s40k70_2 | 1659.17 | 1649.61 | 79.4 | 5 | 255.4 |
| s40k70_4 | 1554.44 | 1554.44 | 22.2 | 1 | 22.2 |
| s40k70_5 | 1596.72 | 1595.13 | 27.4 | 3 | 37.8 |
| s40k70_3 | not solved (LB 1639.21) | 1633.89 | 19.5 | 17 | limit 600 |
| s40k80_1 | not solved (LB 1866.79) | 1864.00 | 96.3 | 5 | limit 600 |
| s40k80_2 | not solved (LB 1816.29) | 1811.92 | 242.4 | 5 | limit 600 |
| s40k80_4 | 1765.40 | 1765.40 | 18.9 | 1 | 18.9 |
| s40k80_3 | not solved (LB 1909.98) | 1904.54 | 60.3 | 13 | limit 600 |
| s40k80_5 | 1768.04 | 1747.40 | 21.9 | 17 | 246.5 |
| s50k60_1 | 1356.61 | 1354.25 | 16.4 | 3 | 22.9 |
| s50k60_3 | 1408.32 | 1408.32 | 26.6 | 1 | 26.6 |
| s50k60_4 | 1370.00 | 1370.00 | 2.8 | 1 | 2.8 |
| s50k60_5 | 1546.70 | 1546.70 | 5.6 | 1 | 5.6 |
| s50k70_1 | 1531.80 | 1531.80 | 10.4 | 1 | 10.4 |
| s50k60_2 | not solved (LB 1407.28) | 1400.01 | 26.7 | 31 | limit 600 |
| s50k70_2 | not solved (LB 1586.57) | 1580.67 | 32.3 | 31 | limit 600 |
| s50k70_4 | 1531.78 | 1531.78 | 17.8 | 1 | 17.8 |
| s50k70_5 | 1575.25 | 1569.56 | 16.6 | 9 | 77.7 |
| s50k80_1 | 1742.75 | 1742.75 | 33.4 | 1 | 33.4 |
| s50k80_2 | 1759.18 | 1746.81 | 30.4 | 25 | 263.9 |
| s50k70_3 | not solved (LB 1622.34) | 1612.15 | 33.7 | 17 | limit 600 |
| s50k80_3 | not solved (LB 1854.67) | 1841.59 | 51.7 | 13 | limit 600 |
| s50k80_4 | not solved (LB 1749.49) | 1743.04 | 125.0 | 15 | limit 600 |
| s50k80_5 | not solved (LB 1736.89) | 1731.30 | 28.8 | 15 | limit 600 |
| s50k90_1 | not solved (LB 1932.70) | 1926.31 | 50.1 | 19 | limit 600 |
| s50k90_3 | 1954.79 | 1946.47 | 91.2 | 9 | 275.5 |
| s50k90_2 | not solved (LB 2052.64) | 2049.98 | 165.5 | 5 | limit 600 |
| s50k90_4 | not solved (LB 1925.85) | 1920.14 | 44.3 | 9 | limit 600 |
| s50k90_5 | not solved (LB 2100.18) | 2096.28 | 27.5 | 23 | limit 600 |
