#ifndef CVRP_SOLVER_H
#define CVRP_SOLVER_H

#include <string>
#include <vector>

#include "App.h"
#include "Data.h"

namespace cvrp
{
/// The result of one VRPSolver run
struct RunResult
{
    bool optimal = false;        ///< :Optimal of VrpSolver.jl: the best bound reaches the best value (or the cutoff)
    bool solutionFound = false;
    double objVal = 0.0;
    std::vector<double> xval;    ///< value of x for each edge of data.E
    double rootDb = 0.0;
    double bestDb = 0.0;
};

/// Solves the model once with the cutoff ub (solve_cvrp of CVRPSolverDemo.jl), and prints the statistics line of
/// VrpSolver.jl. rootOnly: only the root node.
RunResult solveCVRP(const Data &data, const App &app, double ub, bool rootOnly = false);
/// Tentative upper bounds (solve_cvrp_tentative of CVRPSolverDemo.jl)
RunResult solveCVRPTentative(const Data &data, const App &app, double ubMax);
} // namespace cvrp

#endif
