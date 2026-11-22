/**
 * Resource Constrained Shortest Path Solver
 * Designed to be used by Branch-Cut-and-Price algorithms
 *
 * VRP with simultaneous pickup and delivery, see the header.
 *
 * Forward, extending to a customer j: the pickups accumulate, P' = P + p_j, and the deliveries of j and of the customers
 * that follow must fit in D, so j is feasible if d_j <= D and P' <= Q, and D' = min(D - d_j, Q - P').
 * Backward is the mirror: prepending a customer j, D' = D + d_j and P' = min(P - p_j, Q - D').
 * A prefix and a suffix join if the pickups of the prefix fit in the suffix (P_fwd <= P_bwd) and the deliveries of the
 * suffix fit in the prefix (D_bwd <= D_fwd). Infeasibility is signaled with 1e12.
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
const double TOL = 1e-5; // tolerance of the capacity
const double EPS = 1e-9; // tolerance of the comparison of states
} // namespace

void CustomResParameters::setDimensions(int n, int m)
{
    p.resize(m);
    d.resize(m);
}

void CustomResParameters::setArcParameter(int a, const CustomResArcParameters &value)
{
    p[a] = value.p;
    d[a] = value.d;
}

void CustomResParameters::setVertexParameter(int v, const CustomResVertexParameters &value) {}

void CustomResParameters::setConstParameter(const CustomResConstParameters &value)
{
    Q = value.Q;
}

bool symmetric(const CustomResParameters &Rcc)
{
    return false;
}

void initState(const CustomResParameters &Rcc, ForwardState &state)
{
    state.P = 0.0;
    state.D = Rcc.Q;
}

void initState(const CustomResParameters &Rcc, BackwardState &state)
{
    state.P = Rcc.Q;
    state.D = 0.0;
}

double extendToVertex(const CustomResParameters &Rcc, ForwardState &state, int v)
{
    return 0.0;
}

double extendAlongArc(const CustomResParameters &Rcc, ForwardState &state, int a)
{
    double P = state.P + Rcc.p[a];
    bool infeasible = P > Rcc.Q + TOL || Rcc.d[a] > state.D + TOL;
    state.D = std::min(state.D - Rcc.d[a], Rcc.Q - P);
    state.P = P;
    return infeasible ? INF : 0.0;
}

double extendToVertex(const CustomResParameters &Rcc, BackwardState &state, int v)
{
    return 0.0;
}

double extendAlongArc(const CustomResParameters &Rcc, BackwardState &state, int a)
{
    double D = state.D + Rcc.d[a];
    bool infeasible = D > Rcc.Q + TOL || Rcc.p[a] > state.P + TOL;
    state.P = std::min(state.P - Rcc.p[a], Rcc.Q - D);
    state.D = D;
    return infeasible ? INF : 0.0;
}

// Every extension, and the concatenation, are easier to satisfy with less pickup and more room for deliveries in the
// forward state (less delivery and more room for pickups in the backward one).
double dominationCost(const CustomResParameters &Rcc, int v, const ForwardState &dominating,
                      const ForwardState &dominated)
{
    if (!USE_DOMINATION)
        return INF;
    if (dominating.P <= dominated.P + EPS && dominating.D >= dominated.D - EPS)
        return 0.0;
    return INF;
}

double dominationCost(const CustomResParameters &Rcc, int v, const BackwardState &dominating,
                      const BackwardState &dominated)
{
    if (!USE_DOMINATION)
        return INF;
    if (dominating.D <= dominated.D + EPS && dominating.P >= dominated.P - EPS)
        return 0.0;
    return INF;
}

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const BackwardState &bwd)
{
    return (fwd.P > bwd.P + TOL || bwd.D > fwd.D + TOL) ? INF : 0.0;
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
