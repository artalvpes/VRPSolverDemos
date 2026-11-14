# P||ΣwjTj: weighted tardiness on identical parallel machines

There are n jobs, job j with processing time p_j, weight w_j and due date d_j, and m identical machines. Each job is
processed without interruption on one machine; C_j is its completion time and T_j = max(0, C_j - d_j) its tardiness.
The goal is to minimize Σ_j w_j T_j.

The demo is an example of a scheduling problem solved as a routing problem over a **time-indexed** graph: a path is
the sequence of jobs of one machine.

## Instances

`instances/WT<n>-<m>m/wt<n>-<m>m-<k>.txt`: the OR-Library weighted tardiness instances with n = 40, 50 or 100 jobs,
for m = 2, 4 or 10 machines (25 instances per folder, as used by Pessoa et al. 2010), and `instances/toy` (10 jobs,
2 machines). The file gives n, then the lines of p_j, w_j and d_j; n and m are read from the file name.

## Model

Arc-time-indexed formulation of Pessoa, Uchoa, Poggi de Aragão and Rodrigues (2010):

- Graph: one vertex per pair (j, t), job j completed at time t, plus the vertex 0 (source and sink). Arcs: from 0 to
  (j, p_j) (j is the first job of a machine), from (i, t) to (j, t + p_j) (j right after i, no idle time), and from
  (j, t) back to 0 (j is the last job). The cost of an arc is the weighted tardiness of the job it reaches. Only the
  vertices reachable from 0 within the horizon are created.
- Reductions: an arc (i, t) → (j, t + p_j) is removed when swapping i and j gives a schedule that is not worse
  (Proposition 2 of the paper), and the last job of a machine must complete within a window derived from Σ p_j,
  max p_j and m.
- No resource: the time is in the vertices. Exactly m paths (one per machine).
- Master: each job covered once (the sum of x over the arcs entering its vertices is 1). One packing set per job
  (all its vertices), ng-neighbourhoods based on the due dates, extended capacity cuts (`src/cuts.jl`).
- Branching on y_ij = sum of x over the arcs from job i to job j; if every y is integral, x is integral.

The graphs are large (about 0.7 million arcs for 50 jobs and 4 machines), and an instance can take several GB of
memory, especially with 2 machines.

## Running

From the `P_wjTj` folder, with `BAPCOD_RCSP_LIB` set to the VRPSolver library:

```bash
julia src/run.jl instances/WT40-10m/wt40-10m-1.txt -u 502            # with an upper bound
julia src/run.jl instances/WT40-10m/wt40-10m-1.txt                   # the heuristic gives the upper bound
julia src/run.jl instances/WT40-10m/wt40-10m-1.txt -T 1 1            # tentative upper bounds from the root bound
julia src/run.jl -b wt40-10m.batch &> out/wt40-10m.out               # a whole batch in one process
bash wt40-10m.sh                                                     # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-u` | upper bound (the solver looks for a solution of cost below it) |
| `--noheur` | without `-u`, no heuristic: no upper bound |
| `-T D1 D2` (or `-t`) | tentative upper bounds: solve the root, then try ub = LB + D1, LB + D1 + D2, ... until a solution is found |
| `-o` | write the solution |
| `-c` | configuration file (default `config/PwjTj.cfg`) |
| `-b` | batch file: one line of options per instance |

Every solution is checked against the definition of the problem (each job once, no overlap on a machine, cost). The
batches give the optimal costs + 1 as upper bounds; run the batches with many jobs and few machines one instance per
process (`.sh`), since the memory is not released between the instances of a batch. Results: `RESULTS.md`.
