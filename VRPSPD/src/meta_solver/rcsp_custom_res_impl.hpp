/**
 * Resource Constrained Shortest Path Solver
 * Designed to be used by Branch-Cut-and-Price algorithms
 *
 * VRP with simultaneous pickup and delivery. A vehicle leaves the depot with the sum of the deliveries of its route and
 * serves each customer by delivering and then picking up, so that after the k-th customer its load is
 *     (pickups of the customers 1..k) + (deliveries of the customers k+1..end)
 * and it must not exceed the capacity Q in any position. The resource only decides feasibility, the cost of the route
 * is the distance of its arcs (variables of the arcs in the model).
 */

#ifndef RCSP_CUSTOM_RES_IMPL_H_
#define RCSP_CUSTOM_RES_IMPL_H_

#include <vector>

namespace rcsp_custom_res
{

struct CustomResArcParameters
{
    double p; // pickup demand of the head of the arc (0 for the depot)
    double d; // delivery demand of the head of the arc (0 for the depot)

    CustomResArcParameters() { p = d = 0.0; }

    CustomResArcParameters(double p_, double d_)
    {
        p = p_;
        d = d_;
    }
};

struct CustomResVertexParameters
{
};

struct CustomResConstParameters
{
    double Q; // vehicle capacity

    CustomResConstParameters(double q) { Q = q; }
    CustomResConstParameters() { Q = 0.0; }
};

struct CustomResParameters
{
    std::vector<double> p;
    std::vector<double> d;
    double Q;

    void setDimensions(int n, int m);
    void setArcParameter(int a, const CustomResArcParameters &value);
    void setVertexParameter(int v, const CustomResVertexParameters &value);
    void setConstParameter(const CustomResConstParameters &value);
};

struct CustomResSolution
{

    int compare(const CustomResSolution &custom_res_solution) const
    {
        return 0; // no fields to compare
    }
};

// Forward (prefix up to the end vertex, included):
//   P is the sum of the pickups of the prefix,
//   D is the largest sum of deliveries that the rest of the route can have without exceeding Q in the prefix.
struct ForwardState
{
    double P;
    double D;
};

// Backward (suffix after the start vertex):
//   D is the sum of the deliveries of the suffix,
//   P is the largest sum of pickups that the rest of the route can have without exceeding Q in the suffix.
struct BackwardState
{
    double P;
    double D;
};

bool symmetric(const CustomResParameters &Rcc);

void initState(const CustomResParameters &Rcc, ForwardState &state);

void initState(const CustomResParameters &Rcc, BackwardState &state);

double extendToVertex(const CustomResParameters &Rcc, ForwardState &state, int v);

double extendAlongArc(const CustomResParameters &Rcc, ForwardState &state, int a);

double extendToVertex(const CustomResParameters &Rcc, BackwardState &state, int v);

double extendAlongArc(const CustomResParameters &Rcc, BackwardState &state, int a);

double dominationCost(const CustomResParameters &Rcc, int v, const ForwardState &dominating,
                      const ForwardState &dominated);

double dominationCost(const CustomResParameters &Rcc, int v, const BackwardState &dominating,
                      const BackwardState &dominated);

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const BackwardState &bwd);

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const ForwardState &bwd);

bool isCostResource();

} // namespace rcsp_custom_res

#endif // RCSP_CUSTOM_RES_IMPL_H_
