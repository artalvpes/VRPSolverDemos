#ifndef CVRP_SOLUTION_H
#define CVRP_SOLUTION_H

#include <string>
#include <vector>

#include "Data.h"

namespace cvrp
{
/// A solution as in src/solution.jl: its cost (an integer when the distances are rounded) and its routes
struct Solution
{
    double cost = 0.0;
    bool integerCost = true;
    std::vector<std::vector<int>> routes;
};

/// A number printed as Julia prints a Float64 (shortest form, e.g. 1074.0, 1.0e7)
std::string juliaFloat(double v);
/// The cost as printed by the Julia demo: an integer, or a Float64
std::string costString(const Solution &sol);

/// Routes from the values of x (aligned with data.E), as getsolution of solution.jl. Throws on inconsistent values.
Solution getSolution(const Data &data, const std::vector<double> &xval, double objval, bool noround);
/// checksolution_x of solution.jl: x integer, degrees, no subtour, capacity, duration, number of routes, cost
void checkSolutionX(const Data &data, const std::vector<double> &xval, double z, int minr, int maxr);
/// checksolution of solution.jl: the routes against the definition of the problem
void checkSolution(const Data &data, const Solution &sol, int minr, int maxr);
Solution readSolution(const std::string &path, bool noround);
void writeSolution(const std::string &path, const Solution &sol);
void drawSolution(const std::string &path, const Data &data, const Solution &sol);
void printRoutes(const Solution &sol);
} // namespace cvrp

#endif
