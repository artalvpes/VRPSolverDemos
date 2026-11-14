# CRSP: capacitated ring star problem

There are a root (the depot), terminals T with demands, and optional Steiner points S. The solution is a set of
**rings**, cycles through the root, and **stars**: each terminal is either on a ring or connected by a star edge to a
point of a ring (a terminal or a Steiner point on that ring). Each Steiner point is on at most one ring, at most once.
The total demand of a ring, counting the terminals connected to it by stars, is at most W. The cost is the cost of
the ring edges plus the cost of the star edges.

The demo follows model (6.37) of Section 6.4.9 of the book *Optimizing with Column Generation* (Uchoa, Pessoa,
Moreno). It is an example of arcs that represent combinations (a point and the set of terminals connected to it), of
master variables used only by cuts, and of a cut callback with an exact separation by MIP.

## Instances

`data/A`: CVRPLIB instances of set A, turned into CRSP instances by options:

- `-p`: the percentage of the non-root vertices that are Steiner points (the first ones of the instance);
- `-k`: each point i may be connected by stars to its k closest terminals, the set T(i);
- `-a`: the star cost is b_ij = a × distance(i, j); the ring cost of an edge is its distance (rounded, `-r` to keep
  it exact).

The ring capacity W and the demands are those of the CVRPLIB instance. `A.batch` uses 25% of Steiner points, k = 3
and a = 0.5.

## Model

- Pricing graph: the root 0 (source and sink), and each point i split into an entry vertex v_in(i) and an exit vertex
  v_out(i). Star arcs (v_in(i), v_out(i), B), one for each subset B of T(i) with 0 < d(i, B) <= W, consuming d(i, B)
  (the demand of i if it is a terminal, plus the demands of B); ring arcs (v_out(i), v_in(i')) and the arcs to and
  from the root. One resource, the demand, interval [0, W].
- Master: the edge variables x_e of the rings and z_ij of the star connections; each terminal has degree 2 on a ring
  or exactly one star connection; each Steiner point has degree at most 2. The integer variables w_iB (one per star
  arc) are used only by the cuts.
- One arc packing set per terminal (all the star arcs that cover it; they overlap), additional elementarity sets for
  the Steiner points (option `-e` removes them), ng-neighbourhoods based on the distances.
- **Strengthened rounded capacity cuts** (Section 6.4.9), separated exactly by a MIP in a cut callback
  (`src/rcc_separation.jl`; option `-x` disables them).
- Branching on x (priority 3), then z (priority 2), and on w only as a last resort (priority 1).

Configuration: `config/CRSP.cfg` (meta-solver). `test/` has a random test that compares the demo with a
set-partitioning formulation solved by CPLEX (`test/test_random.jl`, with the configurations `test/CRSP*.cfg`).

## Running

From the `CRSP` folder, with `BAPCOD_RCSP_LIB` set to the VRPSolver library:

```bash
julia src/run.jl data/A/A-n32-k5.vrp -p 25 -k 3 -a 0.5                     # the heuristic gives the upper bound
julia src/run.jl data/A/A-n32-k5.vrp -p 25 -k 3 -a 0.5 -T 1 1              # tentative upper bounds
julia src/run.jl data/A/A-n32-k5.vrp -p 25 -k 3 -a 0.5 -o A-n32-k5.sol -t A-n32-k5.tex
julia src/run.jl -b A.batch &> out/A.out                                   # a whole batch in one process
bash A.sh                                                                  # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-p`, `-k`, `-a` | percentage of Steiner points, size of the sets T(i), star cost factor |
| `-u` | upper bound (the solver looks for a solution of cost below it) |
| `--noheur` | without `-u`, no heuristic: no upper bound |
| `-T D1 D2` | tentative upper bounds: solve the root, then try ub = LB + D1, LB + D1 + D2, ... until a solution is found |
| `-x`, `-e` | no capacity cuts, no elementarity sets for the Steiner points |
| `-r` | do not round the distances |
| `-o`, `-t` | write the solution and a TikZ figure |
| `-n` | only build and print the instance, without solving |
| `-c` | configuration file (default `config/CRSP.cfg`) |
| `-b` | batch file: one line of options per instance |

Every solution is checked against the definition of the problem. The TikZ figure draws each ring with its stars in its
own colour (stars dotted), the root as a yellow square and the Steiner points as diamonds (faded if unused); to get a
PDF: `pdflatex A-n32-k5.tex`. Results: `RESULTS.md`.
