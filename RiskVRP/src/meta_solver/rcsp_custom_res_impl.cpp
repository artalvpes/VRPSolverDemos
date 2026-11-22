/**
 * Resource Constrained Shortest Path Solver
 * Designed to be used by Branch-Cut-and-Price algorithms
 *
 * Risk-constrained VRP, see the header.
 *
 * The risk of a route is sum_i demand(i) * (distance from i to the end of the route). Along the route, an arc (i, j)
 * adds (demand collected until i, i included) * distance(i, j). The same value is obtained by the backward extension,
 * that adds demand(i) * (distance from j to the end + distance(i, j)). Infeasibility is signaled with 1e12.
 */

#include <iostream>

#include "rcsp_custom_res_impl.hpp"
#include <algorithm>

namespace rcsp_custom_res
{

namespace
{
const double INF = 1e12;
const double TOL = 1e-5;  // tolerance of the risk limit
const double EPS = 1e-9;  // tolerance of the comparison of states
} // namespace

void CustomResParameters::setDimensions(int n, int m)
{
    dt.resize(m);
    c.resize(m);
}

void CustomResParameters::setArcParameter(int a, const CustomResArcParameters &value)
{
    dt[a] = value.dt;
    c[a] = value.c;
}

void CustomResParameters::setVertexParameter(int v, const CustomResVertexParameters &value) {}

void CustomResParameters::setConstParameter(const CustomResConstParameters &value)
{
    Rmax = value.Rmax;
}

bool symmetric(const CustomResParameters &Rcc)
{
    return false;
}

void initState(const CustomResParameters &Rcc, ForwardState &state)
{
    state.R = 0.0;
    state.D = 0.0;
}

void initState(const CustomResParameters &Rcc, BackwardState &state)
{
    state.R = 0.0;
    state.C = 0.0;
}

double extendToVertex(const CustomResParameters &Rcc, ForwardState &state, int v)
{
    return 0.0;
}

double extendAlongArc(const CustomResParameters &Rcc, ForwardState &state, int a)
{
    state.R += (state.D + Rcc.dt[a]) * Rcc.c[a];
    state.D += Rcc.dt[a];
    return (state.R > Rcc.Rmax + TOL) ? INF : 0.0;
}

double extendToVertex(const CustomResParameters &Rcc, BackwardState &state, int v)
{
    return 0.0;
}

double extendAlongArc(const CustomResParameters &Rcc, BackwardState &state, int a)
{
    state.R += (state.C + Rcc.c[a]) * Rcc.dt[a];
    state.C += Rcc.c[a];
    return (state.R > Rcc.Rmax + TOL) ? INF : 0.0;
}

// The risk of the completions grows with the risk and with the demand (forward) or the distance (backward) of the
// state, so a state dominates the states that are not better than it in these two values.
double dominationCost(const CustomResParameters &Rcc, int v, const ForwardState &dominating,
                      const ForwardState &dominated)
{
    if (dominating.R <= dominated.R + EPS && dominating.D <= dominated.D + EPS)
        return 0.0;
    return INF;
}

double dominationCost(const CustomResParameters &Rcc, int v, const BackwardState &dominating,
                      const BackwardState &dominated)
{
    if (dominating.R <= dominated.R + EPS && dominating.C <= dominated.C + EPS)
        return 0.0;
    return INF;
}

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const BackwardState &bwd)
{
    return (fwd.R + bwd.R + fwd.D * bwd.C > Rcc.Rmax + TOL) ? INF : 0.0;
}

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const ForwardState &bwd)
{
    return 0.0;
}

bool isCostResource()
{
    return false;
}

} // namespace rcsp_custom_res
