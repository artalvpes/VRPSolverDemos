#ifndef CVRP_APP_H
#define CVRP_APP_H

#include <string>
#include <vector>

namespace cvrp
{
/// The command line options, the same as those of the Julia demo (src/CVRPSolverDemo.jl), except its own heuristic
struct App
{
    std::string instance;
    std::string cfg = "config/CVRP.cfg";
    bool hasUb = false;
    double ub = 0.0;
    bool noheur = false;             ///< accepted for compatibility (this demo has no heuristic of its own)
    bool heuristic = false;          ///< -H: run HGS-CVRP also with --ub or --tentative
    bool hasHeurTime = false;
    double heurTime = 0.0;           ///< time limit of HGS-CVRP (default min(20, 2 + 0.1 n))
    int heurNeighbors = 20;          ///< granular neighbourhood of HGS-CVRP (nbGranular)
    int heurSeed = 1;
    bool hgs = false;                ///< use HGS-CVRP to obtain an upper bound
    std::vector<double> tentative;   ///< DELTA1 DELTA2 (empty: no tentative upper bounds)
    int minr = 1;
    int maxr = 999;
    bool noround = false;
    bool showCompleteForm = false;   ///< accepted, not available in C++
    bool update = false;             ///< accepted for compatibility (nothing to update)
    std::string sol, out, tikz, batch;
    bool nosolve = false;
    bool edgeCuts = false;
    bool strongKPathCuts = false;
    double clusterBranching = 1.0;
    bool singleResource = false;
    bool lowEdgePriority = false;
};

/// Parses the arguments (args[0] is not the program name). Returns false after printing the error or the help.
bool parseCommandLine(const std::vector<std::string> &args, App &app);
void printApp(const App &app);
} // namespace cvrp

#endif
