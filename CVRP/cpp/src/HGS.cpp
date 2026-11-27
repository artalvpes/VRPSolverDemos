#include "HGS.h"

#include <algorithm>
#include <cstdlib>
#include <dlfcn.h>
#include <iostream>


namespace cvrp
{
// The structures of C_Interface.h and AlgorithmParameters.h of HGS-CVRP
struct AlgorithmParameters
{
    int nbGranular;
    int mu;
    int lambda;
    int nbElite;
    int nbClose;
    int nbIterPenaltyManagement;
    double targetFeasible;
    double penaltyDecrease;
    double penaltyIncrease;
    int seed;
    int nbIter;
    int nbIterTraces;
    double timeLimit;
    int useSwapStar;
};
struct SolutionRoute
{
    int length;
    int *path;
};
struct HGSSolution
{
    double cost;
    double time;
    int n_routes;
    SolutionRoute *routes;
};
using DefaultParametersFn = AlgorithmParameters (*)();
using SolveDistMtxFn = HGSSolution *(*)(int, double *, double *, double *, double *, double *, double, double, char,
                                        int, const AlgorithmParameters *, char);
using DeleteSolutionFn = void (*)(HGSSolution *);

bool runHGS(const Data &data, int minr, int maxr, double timeLimit, int seed, int nbGranular,
            std::vector<std::vector<int>> &routes, double &cost)
{
    const char *lib = std::getenv("HGS_CVRP_LIB");
    if (lib == nullptr)
    {
        std::cerr << "HGS: set the environment variable HGS_CVRP_LIB to the path of libhgscvrp" << std::endl;
        return false;
    }
    void *handle = dlopen(lib, RTLD_NOW);
    if (handle == nullptr)
    {
        std::cerr << "HGS: cannot load " << lib << ": " << dlerror() << std::endl;
        return false;
    }
    auto defaultParameters = (DefaultParametersFn)dlsym(handle, "default_algorithm_parameters");
    auto solve = (SolveDistMtxFn)dlsym(handle, "solve_cvrp_dist_mtx");
    auto deleteSolution = (DeleteSolutionFn)dlsym(handle, "delete_solution");
    if (!defaultParameters || !solve || !deleteSolution)
    {
        std::cerr << "HGS: " << lib << " does not have the C interface of HGS-CVRP" << std::endl;
        return false;
    }

    const int N = data.n + 1; // nodes, the depot being node 0
    std::vector<double> dist(N * N), dem(N), serv(N, 0.0), x(data.x), y(data.y);
    for (int i = 0; i < N; ++i)
    {
        dem[i] = data.d[i];
        if (i > 0 && data.D > 0) serv[i] = data.S;
        for (int j = 0; j < N; ++j) dist[N * i + j] = data.c[i][j]; // row-major
    }
    AlgorithmParameters ap = defaultParameters();
    ap.seed = seed;
    ap.timeLimit = timeLimit;
    ap.nbGranular = nbGranular;
    HGSSolution *sol = solve(N, x.data(), y.data(), dist.data(), serv.data(), dem.data(), data.Q,
                             data.D > 0 ? data.D : 1e30, data.D > 0 ? 1 : 0, maxr, &ap, 0);
    routes.clear();
    if (sol != nullptr)
    {
        for (int k = 0; k < sol->n_routes; ++k)
            routes.emplace_back(sol->routes[k].path, sol->routes[k].path + sol->routes[k].length);
        deleteSolution(sol);
    }
    dlclose(handle);
    if (routes.empty()) return false;
    // too few routes: split the longest routes
    while ((int)routes.size() < minr)
    {
        auto longest = std::max_element(routes.begin(), routes.end(),
                                        [](const std::vector<int> &a, const std::vector<int> &b) { return a.size() < b.size(); });
        if (longest->size() < 2) return false;
        routes.push_back({longest->back()});
        longest->pop_back();
    }
    cost = 0.0;
    for (const auto &r : routes)
    {
        int prev = 0;
        for (int i : r)
        {
            cost += data.c[prev][i];
            prev = i;
        }
        cost += data.c[prev][0];
    }
    return true;
}
} // namespace cvrp
