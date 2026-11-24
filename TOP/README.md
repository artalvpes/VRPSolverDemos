# TOP: team orienteering problem

There are n customers with profits p_i and a fleet of F vehicles. Each vehicle leaves the start point, visits some
customers and ends at the end point within the maximum duration T. Each customer is visited at most once; the goal is
to maximize the total profit collected. The demo minimizes minus the profit, so the costs and upper bounds are
negative.

The demo is an example of a problem where visiting a customer is optional: the master has a variable y_i that says
whether customer i is visited.

## Instances

`data/`: the 60 instances of set 4 of Chao, Golden and Wasil (1996), `p4.F.x` with 100 customers, F = 2, 3 or 4
vehicles and 20 values of T (letters a to t), and a small `toy.txt`. The travel times are Euclidean distances, not
rounded.

## Model

```
min  - Σ_i p_i y_i
s.t. Σ_{a entering i} x_a = y_i      i a customer,   y_i binary
```

- Graph: the start point (vertex 0, source), the customers and the end point (vertex n + 1, sink), one arc per
  possible move, mapped to x_a. Between 0 and F paths.
- One resource, the time, interval [0, T].
- One packing set per customer, ng-neighbourhoods based on the travel times; branching on y and on x.

Configuration: `config/TOP.cfg`.

## Running

From the `TOP` folder, with `BAPCOD_RCSP_LIB` set to the VRPSolver library:

```bash
julia src/run.jl data/p4.2.a.txt -u -205 --cfg config/TOP.cfg        # with an upper bound (minus the profit)
julia src/run.jl data/p4.2.a.txt --cfg config/TOP.cfg                # the heuristic gives the upper bound
julia src/run.jl data/p4.2.a.txt -T 1 1 --cfg config/TOP.cfg         # tentative upper bounds from the root bound
julia src/run.jl -b chao.batch &> out/chao.out                       # a whole batch in one process
bash chao.sh                                                         # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-u` | upper bound on the cost (minus the profit); the solver looks for a solution of cost below it |
| `--noheur` | without `-u`, no heuristic: the empty solution gives the upper bound 1 |
| `-T D1 D2` (or `-t`) | tentative upper bounds: solve the root, then try ub = LB + D1, LB + D1 + D2, ... until a solution is found |
| `-c` | configuration file |
| `-b` | batch file: one line of options per instance |

Every solution is checked against the definition of the problem (each customer at most once, duration, number of
vehicles, profit). `chao.batch` gives minus the optimal profit + 1 as upper bound; the instances not solved in a few
minutes are commented out. Results: `RESULTS.md`.
