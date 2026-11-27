// CVRP demo of VRPSolver in C++: the same command line, configuration file and outputs as the Julia demo
// (../src/CVRPSolverDemo.jl), without its own heuristic (HGS-CVRP can give the upper bound, option --hgs).
// Run from the CVRP folder, e.g.:  cpp/build/bin/CVRPDemo data/A/A-n37-k6.vrp -m 6 -M 6 -u 950
// See cpp/README.md.

#include <chrono>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <sstream>

#include "App.h"
#include "Data.h"
#include "HGS.h"
#include "Solution.h"
#include "Solver.h"

using namespace cvrp;

static const char *LINE = "########################################################";

// run_cvrp of CVRPSolverDemo.jl
static void runCVRP(App app)
{
    printApp(app);
    Data data;
    if (!data.read(app.instance, app.noround)) throw std::runtime_error("cannot read the instance " + app.instance);
    if (app.showCompleteForm)
        std::cout << "The option -f (show_complete_form) is not available in the C++ demo" << std::endl;

    Solution sol;
    bool hasSol = false;
    if (!app.sol.empty())
    {
        sol = readSolution(app.sol, app.noround);
        checkSolution(data, sol, app.minr, app.maxr); // checks the solution feasibility
        app.ub = app.hasUb ? (std::min)(app.ub, sol.cost) : sol.cost; // update the upper bound
        app.hasUb = true;
        hasSol = true;
    }
    // HGS-CVRP runs by default when there is neither an upper bound nor tentative upper bounds, and always with -H.
    // Its cost is the upper bound: if the solver proves that there is no cheaper solution, the HGS solution is optimal
    // and is the answer (ub = optimum + 1 is for a solution not known yet).
    Solution heurSol;
    bool hasHeurSol = false;
    bool runHeur = !app.nosolve && app.hgs && (app.heuristic || (!app.hasUb && app.tentative.empty() && !app.noheur));
    if (runHeur)
    {
        double limit = app.hasHeurTime ? app.heurTime : (std::min)(20.0, 2.0 + 0.1 * data.n);
        std::vector<std::vector<int>> routes;
        double cost = 0.0;
        auto t0 = std::chrono::steady_clock::now();
        bool ok = runHGS(data, app.minr, (std::min)(app.maxr, data.n), limit, app.heurSeed, app.heurNeighbors, routes, cost);
        double t = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
        if (!ok)
            std::cout << "Heuristic: no solution found with the number of routes in [" << app.minr << ", " << app.maxr
                      << "]" << std::endl;
        else
        {
            Solution hs;
            hs.integerCost = !app.noround;
            hs.cost = app.noround ? cost : (double)std::llround(cost);
            hs.routes = routes;
            checkSolution(data, hs, app.minr, app.maxr);
            if (!app.hasUb || cost <= app.ub)
            {
                app.ub = cost;
                app.hasUb = true;
                heurSol = hs;
                hasHeurSol = true;
            }
            std::printf("HGS-CVRP solution of cost %s with %zu routes (%.2f s): ub = %s\n",
                        juliaFloat(std::round(cost * 100) / 100).c_str(), routes.size(), t, juliaFloat(app.ub).c_str());
        }
    }
    double ub = app.hasUb ? app.ub : 10000000.0;

    bool solutionFound = false;
    RunResult res;
    if (!app.nosolve)
    {
        res = app.tentative.empty() ? solveCVRP(data, app, ub) : solveCVRPTentative(data, app, ub);
        if (res.solutionFound)
        {
            // checks the values of x against the problem definition, then recovers the routes from them
            checkSolutionX(data, res.xval, res.objVal, app.minr, app.maxr);
            sol = getSolution(data, res.xval, res.objVal, app.noround);
            solutionFound = true;
        }
        else if (hasHeurSol)
        {
            // no solution of cost below the HGS one: it is optimal if the search was complete
            sol = heurSol;
            solutionFound = true;
            std::cout << (res.optimal ? "No solution of cost below " + juliaFloat(ub) + ": the heuristic solution is optimal"
                                      : std::string("No better solution found before the search stopped: the heuristic "
                                                    "solution is returned (not proven optimal)"))
                      << std::endl;
        }
    }

    std::cout << LINE << std::endl;
    if (solutionFound || hasSol)
    {
        checkSolution(data, sol, app.minr, app.maxr);
        printRoutes(sol);
        std::cout << "Cost " << costString(sol) << std::endl;
        if (!app.out.empty()) writeSolution(app.out, sol);
        if (!app.tikz.empty())
        {
            if (data.coord)
                drawSolution(app.tikz, data, sol); // write tikz figure
            else
                std::cout << "TikZ figure (" << app.tikz << ") will not be generated, since the instance has no coordinates."
                          << std::endl;
        }
    }
    else if (!app.nosolve)
        std::cout << (res.optimal ? "Problem infeasible" : "Solution not found") << std::endl;
    std::cout << LINE << std::endl;
}

int main(int argc, char **argv)
{
    std::vector<std::string> args(argv + 1, argv + argc);
    App app;
    if (!parseCommandLine(args, app)) return 1;
    try
    {
        if (!app.batch.empty())
        {
            std::ifstream in(app.batch);
            if (!in) throw std::runtime_error("cannot open the batch file " + app.batch);
            for (std::string line; std::getline(in, line);)
            {
                std::size_t p = line.find_first_not_of(" \t\r");
                if (p == std::string::npos || line[p] == '#') continue;
                std::istringstream ls(line);
                std::vector<std::string> lineArgs;
                for (std::string tok; ls >> tok;) lineArgs.push_back(tok);
                App lineApp;
                if (!parseCommandLine(lineArgs, lineApp)) return 1;
                runCVRP(lineApp);
            }
        }
        else
            runCVRP(app);
    }
    catch (const std::exception &e)
    {
        std::cout.flush();
        std::cerr << "ERROR: " << e.what() << std::endl;
        return 1;
    }
    return 0;
}
