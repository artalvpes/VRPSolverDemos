/**
 * Resource Constrained Shortest Path Solver
 * Designed to be used by Branch-Cut-and-Price algorithms
 *
 * Heterogeneous fleet VRP, see the header.
 *
 * The cost of a route with load L and distance D is F(L, D) = fixed[k] + factor[k] * D, with k the first type that
 * carries L (infeasible if there is none). The cost returned by every step is the increase of F, so that the sum of
 * the costs of a forward path, of a backward path, or of a forward and a backward path joined by concatenationCost, is
 * F(load, distance) of the whole route. Infeasibility is signaled with 1e12.
 */

#include <iostream>

#include "rcsp_custom_res_impl.hpp"
#include <algorithm>

namespace rcsp_custom_res
{

namespace
{
const double INF = 1e12;
// Set to false to turn off the dominance of the states (no state dominates another one): the pricing is slower, and
// the optimal values must not change. It helps to check a change of this file.
const bool USE_DOMINATION = true;
const double TOL = 1e-4;  // tolerance of the capacity
const double EPS = 1e-9;  // tolerance of the comparison of states

// F(L, D); INF if no type carries L
double routeCost(const CustomResParameters &Rcc, double load, double dist)
{
    for (int k = 0; k < Rcc.nTypes; k++)
        if (load < Rcc.cap[k] + TOL)
            return Rcc.fixed[k] + Rcc.factor[k] * dist;
    return INF;
}
} // namespace

void CustomResParameters::setDimensions(int n, int m)
{
    d.resize(m);
    c.resize(m);
}

void CustomResParameters::setArcParameter(int a, const CustomResArcParameters &value)
{
    d[a] = value.d;
    c[a] = value.c;
}

void CustomResParameters::setVertexParameter(int v, const CustomResVertexParameters &value) {}

void CustomResParameters::setConstParameter(const CustomResConstParameters &value)
{
    nTypes = std::min((int)(value.nTypes + 0.5), MAX_TYPES);
    maxFactor = 0.0;
    for (int k = 0; k < MAX_TYPES; k++)
    {
        cap[k] = value.cap[k];
        fixed[k] = value.fixed[k];
        factor[k] = value.factor[k];
        if (k < nTypes)
            maxFactor = std::max(maxFactor, factor[k]);
    }
}

bool symmetric(const CustomResParameters &Rcc)
{
    return false;
}

void initState(const CustomResParameters &Rcc, ForwardState &state)
{
    state.load = state.dist = state.cost = 0.0;
}

void initState(const CustomResParameters &Rcc, BackwardState &state)
{
    state.load = state.dist = state.cost = 0.0;
}

double extendToVertex(const CustomResParameters &Rcc, ForwardState &state, int v)
{
    return 0.0;
}

// The arc (i, j) adds the demand of its head j going forward, and so does the arc (cur, next) going backward (the
// vertex next joins the suffix).
double extendAlongArc(const CustomResParameters &Rcc, ForwardState &state, int a)
{
    state.load += Rcc.d[a];
    state.dist += Rcc.c[a];
    double cost = routeCost(Rcc, state.load, state.dist);
    if (cost >= INF)
        return INF;
    double step = cost - state.cost;
    state.cost = cost;
    return step;
}

double extendToVertex(const CustomResParameters &Rcc, BackwardState &state, int v)
{
    return 0.0;
}

double extendAlongArc(const CustomResParameters &Rcc, BackwardState &state, int a)
{
    state.load += Rcc.d[a];
    state.dist += Rcc.c[a];
    double cost = routeCost(Rcc, state.load, state.dist);
    if (cost >= INF)
        return INF;
    double step = cost - state.cost;
    state.cost = cost;
    return step;
}

// A completion that is feasible for the dominated state is feasible for the dominating one if it has no more load,
// and then its type is not larger. The total cost F of the route grows with the load, and with the distance at a rate of
// at most maxFactor per unit, so the total cost with the dominating state exceeds that with the dominated one by at
// most maxFactor * max(0, D1 - D2) (this needs the fixed costs and the factors to be sorted with the capacities).
double dominationCost(const CustomResParameters &Rcc, int v, const ForwardState &dominating,
                      const ForwardState &dominated)
{
    if (!USE_DOMINATION)
        return INF;
    if (dominating.load > dominated.load + EPS)
        return INF;
    return Rcc.maxFactor * std::max(0.0, dominating.dist - dominated.dist);
}

double dominationCost(const CustomResParameters &Rcc, int v, const BackwardState &dominating,
                      const BackwardState &dominated)
{
    if (!USE_DOMINATION)
        return INF;
    if (dominating.load > dominated.load + EPS)
        return INF;
    return Rcc.maxFactor * std::max(0.0, dominating.dist - dominated.dist);
}

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const BackwardState &bwd)
{
    double cost = routeCost(Rcc, fwd.load + bwd.load, fwd.dist + bwd.dist);
    if (cost >= INF)
        return INF;
    return cost - fwd.cost - bwd.cost;
}

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const ForwardState &bwd)
{
    return 0.0;
}

bool isCostResource()
{
    return true;
}

} // namespace rcsp_custom_res
