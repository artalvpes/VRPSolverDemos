/**
 * Resource Constrained Shortest Path Solver
 * Designed to be used by Branch-Cut-and-Price algorithms
 *
 * Heterogeneous fleet VRP (fleet size and mix, unlimited number of vehicles of each type). The types are sorted by
 * capacity, and so by fixed cost and by cost per unit of distance. A route uses the first (cheapest) type that carries
 * its load, so its cost is  fixed[k] + factor[k] * distance,  with k the type of the load of the route.
 * The whole cost of the route is in the resource (cost variable of the model); the arcs have no cost.
 */

#ifndef RCSP_CUSTOM_RES_IMPL_H_
#define RCSP_CUSTOM_RES_IMPL_H_

#include <vector>

namespace rcsp_custom_res
{

const int MAX_TYPES = 8;

struct CustomResArcParameters
{
    double d; // demand of the head of the arc (0 for the depot)
    double c; // distance of the arc

    CustomResArcParameters() { d = c = 0.0; }

    CustomResArcParameters(double d_, double c_)
    {
        d = d_;
        c = c_;
    }
};

struct CustomResVertexParameters
{
};

struct CustomResConstParameters
{
    double nTypes;
    double cap[MAX_TYPES];    // capacity of each type
    double fixed[MAX_TYPES];  // fixed cost of each type
    double factor[MAX_TYPES]; // cost per unit of distance of each type

    CustomResConstParameters()
    {
        nTypes = 0.0;
        for (int k = 0; k < MAX_TYPES; k++)
            cap[k] = fixed[k] = factor[k] = 0.0;
    }
};

struct CustomResParameters
{
    std::vector<double> d;
    std::vector<double> c;
    int nTypes;
    double cap[MAX_TYPES];
    double fixed[MAX_TYPES];
    double factor[MAX_TYPES];
    double maxFactor; // largest cost per unit of distance

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

// Load and distance of the prefix (forward) or of the suffix (backward) and the cost already returned by the resource.
struct ForwardState
{
    double load;
    double dist;
    double cost;
};

struct BackwardState
{
    double load;
    double dist;
    double cost;
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
