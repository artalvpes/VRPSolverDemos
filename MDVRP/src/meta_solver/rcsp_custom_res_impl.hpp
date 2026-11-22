/**
 * Resource Constrained Shortest Path Solver
 * Designed to be used by Branch-Cut-and-Price algorithms
 *
 * Multi-depot VRP (unlimited number of vehicles in each depot). The model has a single dummy depot, vertex 0, and the
 * customers 1..n. The cost of a route is the distance between its consecutive customers plus the cost of the round
 * trip from the depot that serves it,
 *     C0(first, last) = min over the depots k of  dist(k, first) + dist(last, k),
 * where first and last are the first and the last customer of the route. The whole cost of the route is in the
 * resource (cost variable of the model); the arcs have no cost.
 */

#ifndef RCSP_CUSTOM_RES_IMPL_H_
#define RCSP_CUSTOM_RES_IMPL_H_

#include <vector>

namespace rcsp_custom_res
{

const int MAX_DEPOTS = 16;

struct CustomResArcParameters
{
    double c;    // distance between the customers of the arc (not used if one of them is the dummy depot)
    double tail; // vertex that the arc leaves (0 is the dummy depot)
    double head; // vertex that the arc enters

    CustomResArcParameters() { c = tail = head = 0.0; }

    CustomResArcParameters(double c_, double tail_, double head_)
    {
        c = c_;
        tail = tail_;
        head = head_;
    }
};

struct CustomResVertexParameters
{
    double id; // vertex id in the model
    double x;  // coordinates of the customer
    double y;

    CustomResVertexParameters() { id = x = y = 0.0; }

    CustomResVertexParameters(double id_, double x_, double y_)
    {
        id = id_;
        x = x_;
        y = y_;
    }
};

struct CustomResConstParameters
{
    double nDepots;
    double rounded;              // 1.0 if the distances are rounded to the nearest integer
    double depotX[MAX_DEPOTS];   // coordinates of the real depots
    double depotY[MAX_DEPOTS];

    CustomResConstParameters()
    {
        nDepots = rounded = 0.0;
        for (int k = 0; k < MAX_DEPOTS; k++)
            depotX[k] = depotY[k] = 0.0;
    }
};

struct CustomResParameters
{
    std::vector<double> c;
    std::vector<int> tail;
    std::vector<int> head;
    std::vector<double> x; // coordinates of the vertices, by id
    std::vector<double> y;
    int nDepots;
    bool rounded;
    double depotX[MAX_DEPOTS];
    double depotY[MAX_DEPOTS];

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

// Forward: the first customer of the prefix (-1 if there is none), the cost of the prefix, and whether it is a complete
// route (it has returned to the depot, and the cost includes the round trip).
struct ForwardState
{
    int first;
    int closed;
    double S;
};

// Backward: the last customer of the suffix (-1 if there is none), the cost of the suffix, and whether it is a complete
// route.
struct BackwardState
{
    int last;
    int closed;
    double S;
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
