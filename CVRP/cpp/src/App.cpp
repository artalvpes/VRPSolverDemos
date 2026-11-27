#include "App.h"

#include <iostream>
#include <map>
#include <stdexcept>

namespace cvrp
{
static const char *USAGE =
    "usage: CVRPDemo [instance] [-c CFG] [-u UB] [--noheur] [-H] [--heur_time T] [--heur_neighbors K]\n"
    "                [--heur_seed S] [--hgs] [-T DELTA1 DELTA2] [-m MINR] [-M MAXR] [-r] [-f] [--update]\n"
    "                [-s SOL] [-o OUT] [-t TIKZ] [-n] [-b BATCH] [-e] [-k] [-B VALUE] [-R] [-l]\n"
    "\n"
    "  instance                 Instance file path\n"
    "  -c, --cfg                Configuration file path (default config/CVRP.cfg)\n"
    "  -u, --ub                 Upper bound (primal bound): the solver looks for solutions of cost below it\n"
    "  --hgs                    Use HGS-CVRP (Vidal 2022) to obtain the upper bound (its cost; if no cheaper\n"
    "                           solution exists, the HGS solution is optimal), by default when neither --ub nor\n"
    "                           --tentative is given; the environment variable HGS_CVRP_LIB gives the path of\n"
    "                           the shared library libhgscvrp\n"
    "  -H, --heuristic          With --hgs, run HGS-CVRP also with --ub or --tentative\n"
    "  --heur_time              Time limit of HGS-CVRP in seconds (default: min(20, 2 + 0.1 n))\n"
    "  --heur_neighbors         Granular neighbourhood size of HGS-CVRP (default 20)\n"
    "  --heur_seed              Random seed of HGS-CVRP (default 1)\n"
    "  --noheur                 Accepted for compatibility with the Julia demo (no heuristic of its own here)\n"
    "  -T, --tentative          Tentative upper bounds DELTA1 DELTA2: solve the root with the upper bound to get\n"
    "                           its lower bound LB, then solve with the upper bounds LB + DELTA1,\n"
    "                           LB + DELTA1 + DELTA2, ... (never above the upper bound) until a solution is found\n"
    "  -m, --minr               Minimum number of routes in the solution (default 1)\n"
    "  -M, --maxr               Maximum number of routes in the solution (default 999)\n"
    "  -r, --noround            Does not round the distance matrix\n"
    "  -f, --show_complete_form Not available in the C++ demo (it uses HiGHS through JuMP in Julia)\n"
    "  --update                 Accepted for compatibility with the Julia demo\n"
    "  -s, --sol                Solution file path (CVRPLIB format)\n"
    "  -o, --out                Path to write the solution found\n"
    "  -t, --tikz               Path to write the TikZ figure of the solution found\n"
    "  -n, --nosolve            Does not call the VRPSolver. Only to check or draw a given solution\n"
    "  -b, --batch              Batch file path\n"
    "  -e, --edge_cuts          Use edge cuts via cut callback\n"
    "  -k, --strong_kpath_cuts  Use strong k-path cuts (disabled in the current VRPSolver, as in Julia)\n"
    "  -B, --cluster_branching  Cluster branching parameter value (0 = disabled; default 1)\n"
    "  -R, --single_resource    Use a single resource (omit the capacity resource if distance constrained)\n"
    "  -l, --low_edge_priority  Set a low priority to edge branching\n"
    "  -h, --help               Show this help\n";

bool parseCommandLine(const std::vector<std::string> &args, App &app)
{
    static const std::map<std::string, std::string> shortNames = {
        {"-c", "--cfg"},      {"-u", "--ub"},     {"-H", "--heuristic"}, {"-T", "--tentative"},
        {"-m", "--minr"},     {"-M", "--maxr"},   {"-r", "--noround"},   {"-f", "--show_complete_form"},
        {"-s", "--sol"},      {"-o", "--out"},    {"-t", "--tikz"},      {"-n", "--nosolve"},
        {"-b", "--batch"},    {"-e", "--edge_cuts"}, {"-k", "--strong_kpath_cuts"},
        {"-B", "--cluster_branching"}, {"-R", "--single_resource"}, {"-l", "--low_edge_priority"},
        {"-h", "--help"}};
    try
    {
        for (std::size_t k = 0; k < args.size(); ++k)
        {
            std::string a = args[k];
            if (a.empty()) continue;
            if (a[0] != '-')
            {
                if (!app.instance.empty()) throw std::runtime_error("too many arguments: " + a);
                app.instance = a;
                continue;
            }
            auto it = shortNames.find(a);
            if (it != shortNames.end()) a = it->second;
            auto value = [&]() -> std::string {
                if (k + 1 >= args.size()) throw std::runtime_error("option " + a + " requires an argument");
                return args[++k];
            };
            if (a == "--help") { std::cout << USAGE; return false; }
            else if (a == "--cfg") app.cfg = value();
            else if (a == "--ub") { app.ub = std::stod(value()); app.hasUb = true; }
            else if (a == "--noheur") app.noheur = true;
            else if (a == "--heuristic") app.heuristic = true;
            else if (a == "--heur_time") { app.heurTime = std::stod(value()); app.hasHeurTime = true; }
            else if (a == "--heur_neighbors") app.heurNeighbors = std::stoi(value());
            else if (a == "--heur_seed") app.heurSeed = std::stoi(value());
            else if (a == "--hgs") app.hgs = true;
            else if (a == "--tentative") { double d1 = std::stod(value()); double d2 = std::stod(value()); app.tentative = {d1, d2}; }
            else if (a == "--minr") app.minr = std::stoi(value());
            else if (a == "--maxr") app.maxr = std::stoi(value());
            else if (a == "--noround") app.noround = true;
            else if (a == "--show_complete_form") app.showCompleteForm = true;
            else if (a == "--update") app.update = true;
            else if (a == "--sol") app.sol = value();
            else if (a == "--out") app.out = value();
            else if (a == "--tikz") app.tikz = value();
            else if (a == "--nosolve") app.nosolve = true;
            else if (a == "--batch") app.batch = value();
            else if (a == "--edge_cuts") app.edgeCuts = true;
            else if (a == "--strong_kpath_cuts") app.strongKPathCuts = true;
            else if (a == "--cluster_branching") app.clusterBranching = std::stod(value());
            else if (a == "--single_resource") app.singleResource = true;
            else if (a == "--low_edge_priority") app.lowEdgePriority = true;
            else throw std::runtime_error("unrecognized option " + args[k]);
        }
    }
    catch (const std::exception &e)
    {
        std::cerr << e.what() << "\n" << USAGE;
        return false;
    }
    return true;
}

void printApp(const App &app)
{
    std::cout << "Application parameters:\n"
              << "  instance  =>  \"" << app.instance << "\"\n  cfg  =>  \"" << app.cfg << "\"\n"
              << "  ub  =>  " << (app.hasUb ? std::to_string(app.ub) : "nothing") << "\n"
              << "  hgs  =>  " << app.hgs << "\n  heuristic  =>  " << app.heuristic << "\n"
              << "  heur_time  =>  " << (app.hasHeurTime ? std::to_string(app.heurTime) : "nothing") << "\n"
              << "  heur_neighbors  =>  " << app.heurNeighbors << "\n  heur_seed  =>  " << app.heurSeed << "\n"
              << "  tentative  =>  ";
    if (app.tentative.empty()) std::cout << "[]";
    else std::cout << "[" << app.tentative[0] << ", " << app.tentative[1] << "]";
    std::cout << "\n  minr  =>  " << app.minr << "\n  maxr  =>  " << app.maxr << "\n  noround  =>  " << app.noround
              << "\n  sol  =>  " << (app.sol.empty() ? "nothing" : app.sol) << "\n  out  =>  "
              << (app.out.empty() ? "nothing" : app.out) << "\n  tikz  =>  " << (app.tikz.empty() ? "nothing" : app.tikz)
              << "\n  nosolve  =>  " << app.nosolve << "\n  edge_cuts  =>  " << app.edgeCuts
              << "\n  cluster_branching  =>  " << app.clusterBranching << "\n  single_resource  =>  "
              << app.singleResource << "\n  low_edge_priority  =>  " << app.lowEdgePriority << std::endl;
}
} // namespace cvrp
