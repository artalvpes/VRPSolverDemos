#include "App.h"

#include <iostream>
#include <map>
#include <stdexcept>

#include "Solution.h"

namespace pwjtj
{
static const char *USAGE =
    "usage: PwjTjDemo [instance] [--update] [-c CFG] [-u UB] [--noheur] [-T DELTA1 DELTA2] [-o OUT] [-n]\n"
    "                 [-b BATCH]\n"
    "\n"
    "  instance          Instance file path\n"
    "  --update          Accepted for compatibility with the Julia demo\n"
    "  -c, --cfg         Configuration file path (default config/PwjTj.cfg)\n"
    "  -u, --ub          Upper bound (best known solution cost + 1). If not given, the heuristic gives it.\n"
    "  --noheur          Without --ub, do not run the heuristic (no upper bound)\n"
    "  -t, -T, --tentative\n"
    "                    Tentative upper bounds DELTA1 DELTA2: solve the root with the upper bound to get its\n"
    "                    lower bound LB, then solve with the upper bounds LB + DELTA1, LB + DELTA1 + DELTA2,\n"
    "                    LB + DELTA1 + 2 DELTA2, ... (never above the upper bound) until a solution is found\n"
    "  -o, --out         Path to write the solution found\n"
    "  -n, --nosolve     Does not call the VRPSolver (dry run)\n"
    "  -b, --batch       Batch file path\n"
    "  -h, --help        Show this help\n";

bool parseCommandLine(const std::vector<std::string> &args, App &app)
{
    static const std::map<std::string, std::string> shortNames = {
        {"-c", "--cfg"}, {"-u", "--ub"},      {"-t", "--tentative"}, {"-T", "--tentative"},
        {"-o", "--out"}, {"-n", "--nosolve"}, {"-b", "--batch"},     {"-h", "--help"}};
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
            else if (a == "--tentative") { double d1 = std::stod(value()); double d2 = std::stod(value()); app.tentative = {d1, d2}; }
            else if (a == "--out") app.out = value();
            else if (a == "--nosolve") app.nosolve = true;
            else if (a == "--batch") app.batch = value();
            else if (a == "--update") app.update = true;
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
              << "  ub  =>  " << (app.hasUb ? juliaFloat(app.ub) : "nothing") << "\n"
              << "  noheur  =>  " << (app.noheur ? "true" : "false") << "\n  tentative  =>  ";
    if (app.tentative.empty())
        std::cout << "Float64[]";
    else
        std::cout << "[" << juliaFloat(app.tentative[0]) << ", " << juliaFloat(app.tentative[1]) << "]";
    std::cout << "\n  out  =>  " << (app.out.empty() ? "nothing" : "\"" + app.out + "\"")
              << "\n  nosolve  =>  " << (app.nosolve ? "true" : "false")
              << "\n  batch  =>  " << (app.batch.empty() ? "nothing" : "\"" + app.batch + "\"") << std::endl;
}
} // namespace pwjtj
