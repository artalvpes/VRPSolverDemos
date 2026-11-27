#ifndef PWJTJ_SOLUTION_H
#define PWJTJ_SOLUTION_H

#include <string>
#include <utility>
#include <vector>

#include "Data.h"
#include "Model.h"

namespace pwjtj
{
struct Solution
{
    double cost = 0.0;
    /// each machine schedule is an ordered list of (job, completion time) pairs
    std::vector<std::vector<std::pair<int, int>>> schedules;
};

/// A Float64 printed as Julia prints it (shortest round-trip form; 1.0e7 above 1e6)
std::string juliaFloat(double v);
/// getsolution of solution.jl: the schedules from the x values of the arcs of graph.A
Solution getSolution(const Graph &graph, const std::vector<double> &xval, double objval);
/// checksolution_x of solution.jl: checks x of value z against the definition of the problem (throws an error)
void checkSolutionX(const Data &data, const Graph &graph, const std::vector<double> &xval, double z);
void printSchedules(const Data &data, const Solution &solution);
void writeSolution(const std::string &path, const Solution &solution);
} // namespace pwjtj

#endif
