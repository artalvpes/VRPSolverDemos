#ifndef PWJTJ_APP_H
#define PWJTJ_APP_H

#include <string>
#include <vector>

namespace pwjtj
{
/// The command line options, the same as those of the Julia demo (src/PwjTjSolverDemo.jl)
struct App
{
    std::string instance;
    std::string cfg = "config/PwjTj.cfg";
    bool hasUb = false;
    double ub = 0.0;
    bool noheur = false;            ///< without --ub, do not run the heuristic
    std::vector<double> tentative;  ///< DELTA1 DELTA2 (empty: no tentative upper bounds)
    std::string out, batch;
    bool nosolve = false;
    bool update = false;            ///< accepted for compatibility (nothing to update)
};

/// Parses the arguments (args[0] is not the program name). Returns false after printing the error or the help.
bool parseCommandLine(const std::vector<std::string> &args, App &app);
void printApp(const App &app);
} // namespace pwjtj

#endif
