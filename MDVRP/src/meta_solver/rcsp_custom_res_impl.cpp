/**
 * Resource Constrained Shortest Path Solver
 * Designed to be used by Branch-Cut-and-Price algorithms
 *
 * Multi-depot VRP, see the header.
 *
 * The cost of a route is  sum of c(i, j) over the arcs between customers  +  C0(first, last)  and the resource returns
 * the pieces: c(i, j) for each arc between customers, and C0(first, last) when the route is closed, which happens in the
 * forward extension along the arc that returns to the depot (last is its tail) and in the backward extension along the
 * arc that leaves the depot (first is its head). When a prefix and a suffix are joined, C0 is added by the
 * concatenation. Infeasibility is signaled with 1e12 (there is none in this resource).
 */

#include <cmath>
#include <iostream>

#include "rcsp_custom_res_impl.hpp"
#include <algorithm>

namespace rcsp_custom_res
{

namespace
{
const double INF = 1e12;

double euclid(const CustomResParameters &Rcc, double x1, double y1, double x2, double y2)
{
    double xSq = (x2 - x1) * (x2 - x1);
    double ySq = (y2 - y1) * (y2 - y1);
    return Rcc.rounded ? std::floor(std::sqrt(xSq + ySq) + 0.5) : std::sqrt(xSq + ySq);
}

// distance from the depot k to the customer i (and from the customer i to the depot k)
double depotDist(const CustomResParameters &Rcc, int k, int i)
{
    return euclid(Rcc, Rcc.depotX[k], Rcc.depotY[k], Rcc.x[i], Rcc.y[i]);
}

// cheapest round trip from a depot that serves the customer `first` first and the customer `last` last
double C0(const CustomResParameters &Rcc, int first, int last)
{
    double best = INF;
    for (int k = 0; k < Rcc.nDepots; k++)
        best = std::min(best, depotDist(Rcc, k, first) + depotDist(Rcc, k, last));
    return best;
}

// largest increase of  dist(k, i) - dist(k, j)  over the depots k
double maxDifference(const CustomResParameters &Rcc, int i, int j)
{
    double best = -INF;
    for (int k = 0; k < Rcc.nDepots; k++)
        best = std::max(best, depotDist(Rcc, k, i) - depotDist(Rcc, k, j));
    return best;
}
} // namespace

void CustomResParameters::setDimensions(int n, int m)
{
    c.resize(m);
    tail.resize(m);
    head.resize(m);
    x.assign(n, 0.0);
    y.assign(n, 0.0);
}

void CustomResParameters::setArcParameter(int a, const CustomResArcParameters &value)
{
    c[a] = value.c;
    tail[a] = (int)(value.tail + 0.5);
    head[a] = (int)(value.head + 0.5);
}

void CustomResParameters::setVertexParameter(int v, const CustomResVertexParameters &value)
{
    int id = (int)(value.id + 0.5);
    if (id >= (int)x.size())
    {
        x.resize(id + 1, 0.0);
        y.resize(id + 1, 0.0);
    }
    x[id] = value.x;
    y[id] = value.y;
}

void CustomResParameters::setConstParameter(const CustomResConstParameters &value)
{
    nDepots = std::min((int)(value.nDepots + 0.5), MAX_DEPOTS);
    rounded = value.rounded > 0.5;
    for (int k = 0; k < MAX_DEPOTS; k++)
    {
        depotX[k] = value.depotX[k];
        depotY[k] = value.depotY[k];
    }
}

bool symmetric(const CustomResParameters &Rcc)
{
    return false;
}

void initState(const CustomResParameters &Rcc, ForwardState &state)
{
    state.first = -1;
    state.closed = 0;
    state.S = 0.0;
}

void initState(const CustomResParameters &Rcc, BackwardState &state)
{
    state.last = -1;
    state.closed = 0;
    state.S = 0.0;
}

double extendToVertex(const CustomResParameters &Rcc, ForwardState &state, int v)
{
    return 0.0;
}

double extendAlongArc(const CustomResParameters &Rcc, ForwardState &state, int a)
{
    int tail = Rcc.tail[a], head = Rcc.head[a];
    double cost;
    if (tail == 0) // leaves the depot: head is the first customer
    {
        state.first = head;
        return 0.0;
    }
    if (head == 0) // returns to the depot: tail is the last customer
    {
        cost = C0(Rcc, state.first, tail);
        state.closed = 1;
    }
    else
        cost = Rcc.c[a];
    state.S += cost;
    return cost;
}

double extendToVertex(const CustomResParameters &Rcc, BackwardState &state, int v)
{
    return 0.0;
}

// The arc is (cur, next), in the direction of travel.
double extendAlongArc(const CustomResParameters &Rcc, BackwardState &state, int a)
{
    int tail = Rcc.tail[a], head = Rcc.head[a];
    double cost;
    if (head == 0) // the suffix ends here: tail is the last customer
    {
        state.last = tail;
        return 0.0;
    }
    if (tail == 0) // the route starts here: head is the first customer
    {
        cost = C0(Rcc, head, state.last);
        state.closed = 1;
    }
    else
        cost = Rcc.c[a];
    state.S += cost;
    return cost;
}

// total(completion) = S + (future inner costs) + C0(first, last), and only the last term depends on `first`:
// with k* the depot of the best round trip of the dominated state,
//     C0(f1, last) - C0(f2, last) <= dist(k*, f1) - dist(k*, f2) <= max over k of (dist(k, f1) - dist(k, f2)).
// The backward case is symmetric, with the last customer. The states of complete routes have no future.
double dominationCost(const CustomResParameters &Rcc, int v, const ForwardState &dominating,
                      const ForwardState &dominated)
{
    if (dominating.closed != dominated.closed)
        return INF;
    double diff = dominating.S - dominated.S;
    if (dominating.closed || dominating.first == dominated.first)
        return diff;
    if (dominating.first < 0 || dominated.first < 0)
        return INF;
    return diff + maxDifference(Rcc, dominating.first, dominated.first);
}

double dominationCost(const CustomResParameters &Rcc, int v, const BackwardState &dominating,
                      const BackwardState &dominated)
{
    if (dominating.closed != dominated.closed)
        return INF;
    double diff = dominating.S - dominated.S;
    if (dominating.closed || dominating.last == dominated.last)
        return diff;
    if (dominating.last < 0 || dominated.last < 0)
        return INF;
    return diff + maxDifference(Rcc, dominating.last, dominated.last);
}

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const BackwardState &bwd)
{
    if (fwd.closed || bwd.closed || fwd.first < 0 || bwd.last < 0)
        return 0.0;
    return C0(Rcc, fwd.first, bwd.last);
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
