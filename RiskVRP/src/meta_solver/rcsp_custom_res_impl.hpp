/**
 * Resource Constrained Shortest Path Solver
 * Designed to be used by Branch-Cut-and-Price algorithms
 *
 * Risk-constrained VRP: the risk of a route is the sum, over its customers, of the demand times the distance that is
 * travelled from the customer to the end of the route (the depot). It must not exceed Rmax. The resource only decides
 * feasibility, the cost of the route is the distance of its arcs (variables of the arcs in the model).
 */

#ifndef RCSP_CUSTOM_RES_IMPL_H_
#define RCSP_CUSTOM_RES_IMPL_H_

#include <vector>

namespace rcsp_custom_res
{

struct CustomResArcParameters
{
    double dt; // demand of the tail of the arc (0 for the depot)
    double c;  // distance of the arc

    CustomResArcParameters() { dt = c = 0.0; }

    CustomResArcParameters(double dt_, double c_)
    {
        dt = dt_;
        c = c_;
    }
};

struct CustomResVertexParameters
{
};

struct CustomResConstParameters
{
    double Rmax; // maximum risk of a route

    CustomResConstParameters(double r) { Rmax = r; }
    CustomResConstParameters() { Rmax = 0.0; }
};

struct CustomResParameters
{
    std::vector<double> dt;
    std::vector<double> c;
    double Rmax;

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

// Forward: R is the risk of the prefix, D the demand of the customers that precede the end of the prefix.
struct ForwardState
{
    double R;
    double D;
};

// Backward: R is the risk of the suffix, C the distance travelled by the suffix.
struct BackwardState
{
    double R;
    double C;
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
