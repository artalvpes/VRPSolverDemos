# GAP: results on the classic instances

Results of `classic.batch` on the OR-Library instances of type D, with ub = optimum + 1 and `config/GAP_Classic.cfg`.
The optimal values are those of Posta et al. (2012). The last columns reproduce the times (in seconds) of Table 5.1 of
the book *Optimizing with Column Generation* (p. 246); those are the original times, obtained on different processors.

| Instance | Optimum | Root LB | Nodes | Time (s) | Pessoa et al. (2020) | Posta et al. (2012) | Avella et al. (2010) | Pigatti et al. (2005) |
|---|---|---|---|---|---|---|---|---|
| D-5-100 | 6353 | 6351 | 3 | 15 | 10.7 | 1.28 | 13.3 | 96.3 |
| D-5-200 | 12742 | 12741 | 7 | 132 | | | | |
| D-10-100 | 6347 | 6343 | 11 | 16 | 23.6 | 13.4 | 385 | 818 |
| D-10-200 | 12430 | 12427 | 167 | 929 | | | | |
| D-20-100 | 6185 | 6177 | 117 | 128 | 239 | 2425 | 27783 | 1043 |

Root LB is the root lower bound rounded up. All the solutions were checked by the solution checker of the demo.

D-20-200 is commented out in the batch and was not run: Posta et al. (2012) did not solve it to optimality in 24 hours
(best known solution 12244).

## Setup

- Laptop with an Intel Core i7-12800H and 32 GB of memory, November 2026. D-10-200 needs about 9 GB of memory.
- Julia 1.10.11, VrpSolver.jl branch `update_rcsp_interface`, CPLEX 20.1.
- BaPCod master c11ec6c plus MR !33, RCSP master ede92a1 plus MR !35. D-20-100 was run with the BaPCod/RCSP library
  of the repository (without these MRs, which do not change the GAP, as it does not use Ryan&Foster branching).
- Each run had a time limit of 3600 s, not reached.

## References

- A. Pessoa, R. Sadykov, E. Uchoa, F. Vanderbeck. A generic exact solver for vehicle routing and related problems.
  Mathematical Programming 183:483-523, 2020.
- M. Posta, J. A. Ferland, P. Michelon. An exact method with variable fixing for solving the generalized assignment
  problem. Computational Optimization and Applications 52:629-644, 2012.
- P. Avella, M. Boccia, I. Vasilyev. A computational study of exact knapsack separation for the generalized assignment
  problem. Computational Optimization and Applications 45:543-555, 2010.
- A. Pigatti, M. Poggi de Aragão, E. Uchoa. Stabilized branch-and-cut-and-price for the generalized assignment problem.
  Electronic Notes in Discrete Mathematics 19:389-395, 2005.
