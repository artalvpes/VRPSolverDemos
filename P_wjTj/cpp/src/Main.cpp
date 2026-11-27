// P||sum w_j T_j demo of VRPSolver in C++: the same command line, configuration file and outputs as the Julia demo
// (../src/PwjTjSolverDemo.jl). Run from the P_wjTj folder, e.g.:
//   cpp/build/bin/PwjTjDemo instances/WT40-4m/wt40-4m-1.txt -u 440
// See cpp/README.md.

#include <chrono>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <sstream>

#include "App.h"
#include "Data.h"
#include "Heuristic.h"
#include "Model.h"
#include "Solution.h"
#include "Solver.h"

using namespace pwjtj;

static const char *LINE = "########################################################";

// run_pwjtj of PwjTjSolverDemo.jl
static void runPwjTj(App app)
{
    printApp(app);
    Data data;
    data.read(app.instance);

    bool solutionFound = false;
    pwjtj::Solution sol;
    if (!app.hasUb)
    {
        app.ub = 10000000.0;
        if (!app.noheur && !app.nosolve)
        {
            auto t0 = std::chrono::steady_clock::now();
            std::vector<std::vector<int>> heurSched;
            long heurCost = pwjtjHeuristic(data, heurSched, 1000);
            double t = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
            std::vector<int> count(data.n + 1, 0);
            for (const auto &seq : heurSched)
                for (int j : seq) count[j] += 1;
            for (int j = 1; j <= data.n; ++j)
                if (count[j] != 1) throw std::runtime_error("The heuristic solution does not process every job once");
            std::printf("Heuristic solution of cost %ld (%.2f s)\n", heurCost, t);
            if (heurCost == 0)
            {
                // a solution of cost 0 is optimal: the solver is not called
                solutionFound = true;
                sol.cost = 0.0;
                for (const auto &seq : heurSched)
                {
                    std::vector<std::pair<int, int>> schedule;
                    int c = 0;
                    for (int j : seq) schedule.emplace_back(j, c += data.jobs[j].p);
                    sol.schedules.push_back(schedule);
                }
                app.nosolve = true;
            }
            else // ub = heuristic cost + 1: the solver must return a solution, at least as good as the heuristic one
                app.ub = heurCost + 1.0;
        }
        app.hasUb = true;
    }
    RunResult res;
    if (!app.nosolve)
    {
        Graph graph;
        graph.build(data);
        res = app.tentative.empty() ? solvePwjTj(data, graph, app, app.ub)
                                    : solvePwjTjTentative(data, graph, app, app.ub);
        if (res.solutionFound)
        {
            // checks the values of x against the problem definition, then recovers the schedules from them
            checkSolutionX(data, graph, res.xval, res.objVal);
            sol = getSolution(graph, res.xval, res.objVal);
            solutionFound = true;
        }
    }

    std::cout << LINE << std::endl;
    if (solutionFound)
    {
        printSchedules(data, sol);
        std::cout << "Cost " << juliaFloat(sol.cost) << std::endl;
        if (!app.out.empty()) writeSolution(app.out, sol);
    }
    else if (!app.nosolve)
        std::cout << (res.optimal ? "Problem infeasible" : "Solution not found") << std::endl;
    std::cout << LINE << std::endl;
}

int main(int argc, char **argv)
{
    std::vector<std::string> args(argv + 1, argv + argc);
    App app;
    if (args.empty()) args = {"--help"};
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
                runPwjTj(lineApp);
            }
        }
        else
            runPwjTj(app);
    }
    catch (const std::exception &e)
    {
        std::cout.flush();
        std::cerr << "ERROR: " << e.what() << std::endl;
        return 1;
    }
    return 0;
}
