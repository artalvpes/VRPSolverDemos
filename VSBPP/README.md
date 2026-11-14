# VSBPP: variable-sized bin packing with penalties

There are J items, item j with length w_j and penalty p_j, and K stock types, type k with length W_k, availability
u_k and cost c_k per stock used. Each item is either cut from a stock or not produced, in which case its penalty is
paid. The items cut from a stock must fit in its length. The cost is the cost of the stocks used plus the penalties.

The demo is an example of a model that is not a vehicle routing problem: each path of the graph is a cutting pattern.

## Instances

The format is `J K`, then J lines `w_j p_j`, then K lines `W_k u_k c_k`; lines starting with `#` are comments.

- `data/toy`: five small instances; `toy1.txt` is the example of the course slides (optimum 8).
- `data/test`: random instances with K = 3 to 5 stock types and n = 20 to 100 items, of two classes: `vc` (stock cost
  7000·(W/10000)^0.8, concave in the length) and `zc` (stocks for free, only the penalties count).

## Model

Map decomposition model:

```
min  Σ_k c_k t_k + Σ_j p_j y_j
s.t. x_j + y_j = 1      j in J   (item j is produced or its penalty is paid)
     t_k <= u_k         k in K   (availability of stock type k)
```

where x_j and t_k are mapped to arcs of a single graph that generates the patterns of all stock types:

- vertices v_0, ..., v_J, v_{J+1}; between v_{j-1} and v_j, two parallel arcs: a_j+ (item j is cut, consumes w_j,
  mapped to x_j) and a_j- (item j is skipped); between v_J and v_{J+1}, one arc a_k per stock type, mapped to t_k,
  with the resource interval [0, W_k] on the arc.
- one resource, the length used, interval [0, max W_k];
- one packing set per item (arc a_j+), which enables rank-1 cuts and the enumeration of the patterns; one additional
  elementarity set per stock arc a_k, so that the same items cut from different stock types are different patterns
  for the enumeration (without these sets, wrong optima were obtained);
- branching on t_k (priority 3), then on x_j (priority 2), and the Ryan and Foster branching on pairs of items as the
  last resort.

y_j = 1 - x_j is a variable because VRPSolver does not accept a constant in the objective.

`arcflow/arcflow.jl` is an independent arc-flow MIP for the same problem (Valério de Carvalho's model, solved by
CPLEX), useful to check the optima on small instances: `julia --project=arcflow arcflow/arcflow.jl <instance>`.

## Running

From the `VSBPP` folder, with `BAPCOD_RCSP_LIB` set to the VRPSolver library:

```bash
julia src/run.jl data/toy/toy1.txt -u 9                      # with an upper bound
julia src/run.jl data/toy/toy1.txt                           # the heuristic gives the upper bound
julia src/run.jl data/test/vc_K5_n50_u11_s1.txt -T 1 1        # tentative upper bounds from the root bound
julia src/run.jl -b test.batch &> out/test.out               # a whole batch in one process
bash test.sh                                                 # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-u` | upper bound (the solver looks for a solution of cost below it) |
| `--noheur` | without `-u`, no heuristic: no upper bound |
| `-T D1 D2` (or `-t`) | tentative upper bounds: solve the root, then try ub = LB + D1, LB + D1 + D2, ... until a solution is found |
| `-c` | configuration file (default `config/VSBPP.cfg`) |
| `-b` | batch file: one line of options per instance |

Every solution is checked against the definition of the problem (each item cut at most once, the patterns fit in
their stocks, availabilities, cost). The batches `toy.batch` and `test.batch` give the optimal costs + 1 as upper
bounds. Results: `RESULTS.md`.
