# CCVRP: cumulative capacitated vehicle routing

The CVRP with a load-dependent cost: a vehicle leaves the depot carrying the whole demand of its route, and each arc
costs its distance times the load on board. The return to the depot, made empty, costs nothing. Equivalently, the cost
of a route is the sum over its customers of the demand times the distance travelled from the depot to the customer.
Each route can be driven in both directions, which in general have different costs; the solution uses the cheaper one.

This demo is the example of a **custom resource**: the cumulative cost is not a standard VRPSolver resource, it is
computed by C++ code of the demo (`src/meta_solver/`) that must be **compiled into the BaPCod/RCSP library**. With the
library as distributed, the demo stops with an error (see "Building the library" below).

## Instances

`data/` holds the CVRPLIB instances of the CVRP demo (sets A, B, E, F, M, P) and `toy.vrp`. The number of routes is
given by the options `-m` (minimum) and `-M` (maximum); the batches use the number of routes of the CVRP batches.

## Model

- Graph: the depot (vertex 0, source and sink) and one vertex per customer, two arcs per edge, one for each direction.
  Each arc is mapped to the edge variable x_e.
- Resources: the capacity (main resource, consumption (d_i + d_j)/2 per arc) and the **cumulative custom resource**,
  whose cost is the master variable z (`add_resource!(G, custom=true, cost_var=z)`). The objective is min z.
- Master: degree 2 for each customer. One packing set per customer, ng-neighbourhoods based on the distances, rounded
  capacity cuts, rank-1 cuts, branching on x. A cut callback bounds x_e <= 1 on the edges between two customers.

### The custom resource (`src/meta_solver/rcsp_custom_res_impl.*`)

The RCSP meta-solver calls these functions while extending labels. The parameters are set from Julia
(`src/model.jl`): per arc, t = the distance of the arc and w = the demand of its head; constant, Wmax = Q and
Tmax = ub / (smallest demand), a bound on the distance of a route used in the dominance.

| Function | What it does here |
|---|---|
| `initState` | forward state (S = cost so far, T = distance so far) and backward state (S, W = load delivered) start at 0 |
| `extendAlongArc` (forward) | S += w·(T + t), T += t: the demand of the head times its arrival distance |
| `extendAlongArc` (backward) | S += (W + w)·t, W += w: the arc carries the load still to deliver |
| `dominationCost` | the extra cost the dominated label may still save, bounded with Wmax (forward) or Tmax (backward) |
| `concatenationCost` | T_forward · W_backward: the backward part is delayed by the forward distance |
| `isCostResource` | true: the resource gives the cost of the path (the variable z) |
| `computeSolution` | no data to record for a path (required by the current RCSP interface) |

To write another custom resource, start from these two files and keep the function signatures; the Julia side declares the parameter structs with `@register_custom_res_param_types`, in
the same order and with the same field types as the C++ structs.

## Building the library

The library holds one custom resource at a time: the one whose files are in `Tools/rcsp` when it is compiled. The
template shipped with RCSP defines `RCSP_CUSTOM_RESOURCE_IS_NOT_IMPLEMENTED`; a library built with it refuses any
model with a custom resource, with the message

```
RCSP meta-solver error : the model declares a custom resource (id=1), but rcsp_custom_res_impl.hpp/.cpp are still
the unimplemented template shipped with the library. ...
BaPCod error : cannot build the model
```

(the `Examples/custom_resource/` mentioned in the full message is not in the current RCSP; this demo is the example).

To build a library with the cumulative resource (from the root of the BaPCod sources, `bapcodframework`):

```bash
cp <VRPSolverDemos>/CCVRP/src/meta_solver/rcsp_custom_res_impl.hpp Tools/rcsp/include_dev/
cp <VRPSolverDemos>/CCVRP/src/meta_solver/rcsp_custom_res_impl.cpp Tools/rcsp/src/
touch Tools/rcsp/include_dev/rcsp_custom_res_impl.hpp Tools/rcsp/src/rcsp_custom_res_impl.cpp
make -C build -j4 bapcod-shared
```

- **The `touch` matters.** If the files are copied keeping their dates (`cp -p`, `cp -a`, a file manager, an
  archive), they may look older than the objects already compiled, `make` does not recompile them, and the library
  still has the template, with the error above.
- The other demos do not declare a custom resource and work with this library too. To keep the original library,
  build in another directory: `cmake -S . -B build_ccvrp -DCMAKE_BUILD_TYPE=Release`, then
  `make -C build_ccvrp -j4 bapcod-shared`.
- The demo uses the library given by the environment variable `BAPCOD_RCSP_LIB`; to choose it for one run:
  `BAPCOD_RCSP_LIB=<path>/Bapcod/libbapcod-shared.so julia src/run.jl ...`

## Running

From the `CCVRP` folder:

```bash
julia src/run.jl data/A/A-n37-k5.vrp -m 5 -M 5 -u 20006            # with an upper bound
julia src/run.jl data/A/A-n37-k5.vrp -m 5 -M 5                     # the heuristic gives the upper bound
julia src/run.jl data/A/A-n37-k5.vrp -m 5 -M 5 -T 1 1               # tentative upper bounds from the root bound
julia src/run.jl data/A/A-n37-k5.vrp -m 5 -M 5 -u 20006 -o A-n37-k5.sol -t A-n37-k5.tex
julia src/run.jl -b A.batch &> out/A.out                            # a whole batch in one process
bash A.sh                                                           # the same instances, one process each
```

| Option | Meaning |
|---|---|
| `-u` | upper bound (the solver looks for a solution of cost below it) |
| `--noheur` | without `-u`, no heuristic: no upper bound |
| `-T D1 D2` | tentative upper bounds: solve the root, then try ub = LB + D1, LB + D1 + D2, ... until a solution is found |
| `-m`, `-M` | minimum and maximum number of routes |
| `-r` | do not round the distances |
| `-o`, `-t` | write the solution (CVRPLIB format) and a TikZ figure |
| `-s`, `-n` | read a solution from a file; with `-n`, only check (and draw) it, without solving |
| `-c` | configuration file (default `config/CCVRP.cfg`) |
| `-b` | batch file: one line of options per instance |

Every solution is checked against the definition of the problem (routes, capacity, number of routes, cost). The
TikZ figure draws each route in its own colour, with arrows in the direction of the cost, and the return to the
depot dashed; to get a PDF: `pdflatex A-n37-k5.tex`.

`A.batch` and `B.batch` give the optimal costs + 1 as upper bounds; the instances not solved in 2 minutes are
commented out. Results: `RESULTS.md`.
