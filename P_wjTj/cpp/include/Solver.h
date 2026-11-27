#ifndef PWJTJ_SOLVER_H
#define PWJTJ_SOLVER_H

#include <string>
#include <vector>

#include "App.h"
#include "Data.h"
#include "Model.h"

namespace pwjtj
{
/// The result of one VRPSolver run
struct RunResult
{
    bool optimal = false;     ///< :Optimal of VrpSolver.jl: the best bound reaches the best value (or the cutoff)
    bool solutionFound = false;
    double objVal = 0.0;
    std::vector<double> xval; ///< value of x for each arc of graph.A
    double rootDb = 0.0;
    double bestDb = 0.0;
};

/// Solves the model once with the cutoff ub (solve_pwjtj of PwjTjSolverDemo.jl), and prints the statistics line of
/// VrpSolver.jl. rootOnly: only the root node.
RunResult solvePwjTj(const Data &data, const Graph &graph, const App &app, double ub, bool rootOnly = false);
/// Tentative upper bounds (solve_pwjtj_tentative of PwjTjSolverDemo.jl)
RunResult solvePwjTjTentative(const Data &data, const Graph &graph, const App &app, double ubMax);
} // namespace pwjtj

#endif
