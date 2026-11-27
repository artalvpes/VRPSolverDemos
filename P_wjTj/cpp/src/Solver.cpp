#include "Solver.h"

#include <chrono>
#include <cmath>
#include <cstdio>
#include <iostream>

#include <bcControlParameters.hpp>
#include <bcModelFormulationC.hpp>
#include <bcModelMasterC.hpp>
#include <bcModelPointerC.hpp>
#include <bcModelSolutionC.hpp>
#include <rcsp/bcModelNetworkFlow.hpp>

#include "Solution.h"

namespace pwjtj
{
RunResult solvePwjTj(const Data &data, const Graph &graph, const App &app, double ub, bool rootOnly)
{
    // the parameters that VrpOptimizer of VrpSolver.jl always passes on the command line (they override the
    // configuration file)
    std::vector<std::string> args = {"",
                                     "--MaxNbOfStagesInColGenProcedure", "3",
                                     "--colGenSubProbSolMode", "3",
                                     "--MipSolverMultiThread", "1",
                                     "--ApplyStrongBranchingEvaluation", "true",
                                     "--RCSPrankOneCutsTypeToSeparate", "1",
                                     "-t", "BaPTree.dot",
                                     "--ComputeDissagregateSpSol", "false",
                                     "--RCSPuseMetaSolver", "1"};
    if (rootOnly) args.insert(args.end(), {"--MaxNbOfBBtreeNodeTreated", "1"}); // only the root node
    std::vector<char *> argv;
    for (auto &a : args) argv.push_back(a.data());

    BcInitialisation init((int)argv.size(), argv.data(), app.cfg, false, true);
    // the extended capacity cuts use the upper bound, so the model is built with the cutoff of this run
    Model model(init, data, graph, ub);
    BcSolution solution(model.master());
    solution = model.solve();

    RunResult res;
    res.rootDb = init.getStatisticValue("bcRecRootDb");
    res.bestDb = init.getStatisticValue("bcRecBestDb");
    double bestInc = init.getStatisticValue("bcRecBestInc");
    double ogt = init.param().optimalityGapTolerance();
    res.optimal = (res.bestDb - ogt <= bestInc) && (bestInc <= res.bestDb + ogt);
    res.solutionFound = solution.defined();
    if (res.solutionFound)
    {
        res.xval = arcValues(solution, model, graph.A.size());
        // the objective value as get_objective_value of VrpSolver.jl: the sum of c_a x_a in the order of the
        // variables, rounded (the objective is integer)
        for (std::size_t a = 0; a < graph.A.size(); ++a) res.objVal += graph.nodeCost[graph.A[a].second] * res.xval[a];
        res.objVal = std::round(res.objVal);
    }

    // the statistics line of VrpSolver.jl
    std::printf("statistics_cols: instance & :Optimal & cutoff & :bcRecRootDb & :bcTimeRootEval & :bcCountNodeProc & "
                ":bcRecBestDb & :bcRecBestInc & :bcTimeMain \\\\\n");
    std::printf("statistics: %s & %d & %s & %.2f & %.2f & %ld & %.2f & ", data.name.c_str(), res.optimal ? 1 : 0,
                juliaFloat(ub).c_str(), res.rootDb, init.getStatisticTime("bcTimeRootEval") / 100,
                (long)init.getStatisticCounter("bcCountNodeProc"), res.bestDb);
    if (res.solutionFound)
        std::printf("%lld & ", std::llround(bestInc));
    else
        std::printf("-- & ");
    std::printf("%.2f \\\\\n", init.getStatisticTime("bcTimeMain") / 100);
    std::fflush(stdout);
    return res;
}

// Valid lower bound after a run with the cutoff ub (run_lower_bound of PwjTjSolverDemo.jl)
static double runLowerBound(const RunResult &res, double ub)
{
    if (res.optimal) return res.solutionFound ? res.objVal : ub;
    return std::min(res.bestDb, ub);
}

RunResult solvePwjTjTentative(const Data &data, const Graph &graph, const App &app, double ubMax)
{
    double delta1 = app.tentative[0], delta2 = app.tentative[1];
    if (!(delta2 > 0)) throw std::runtime_error("the second value of --tentative (delta2) must be positive");
    auto t0 = std::chrono::steady_clock::now();
    std::cout << "Tentative upper bounds: solving the root node with ub = " << juliaFloat(ubMax) << std::endl;
    RunResult res = solvePwjTj(data, graph, app, ubMax, true);
    if (res.optimal) return res; // solved (or proved infeasible) at the root
    double rootLb = res.rootDb;
    if (!(rootLb > -1e11)) // the root lower bound was not computed (time limit): no tentative upper bounds
    {
        std::cout << "Tentative upper bounds: the root lower bound is not available; solving with ub = "
                  << juliaFloat(ubMax) << std::endl;
        return solvePwjTj(data, graph, app, ubMax);
    }
    double base = std::ceil(rootLb - 1e-6);
    double bestLb = runLowerBound(res, ubMax);
    for (int k = 0;; ++k)
    {
        double ub = std::min(base + delta1 + k * delta2, ubMax);
        std::cout << "Tentative upper bounds: run " << k + 1 << " with ub = " << juliaFloat(ub) << " (root lower bound "
                  << juliaFloat(rootLb) << ")" << std::endl;
        res = solvePwjTj(data, graph, app, ub);
        bestLb = std::max(bestLb, runLowerBound(res, ub));
        if (res.solutionFound || !res.optimal || ub >= ubMax)
        {
            double t = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
            std::printf("Tentative upper bounds: finished after %d run(s) with ub = %s, total time %.2f s, valid lower "
                        "bound %s\n", k + 1, juliaFloat(ub).c_str(), t, juliaFloat(bestLb).c_str());
            return res;
        }
        std::cout << "Tentative upper bounds: no solution with cost below " << juliaFloat(ub) << std::endl;
    }
}
} // namespace pwjtj
