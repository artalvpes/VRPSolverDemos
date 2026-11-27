#ifndef CVRP_HGS_H
#define CVRP_HGS_H

#include <vector>

#include "Data.h"

namespace cvrp
{
/// Runs HGS-CVRP (Vidal 2022, https://github.com/vidalt/HGS-CVRP) through its C interface, as src/hgs.jl. The shared
/// library libhgscvrp is loaded at run time from the path in the environment variable HGS_CVRP_LIB, so the demo does
/// not depend on HGS-CVRP to be built. HGS receives the distance matrix of the demo (the costs of the model), the
/// coordinates (for its SWAP* neighbourhood), the demands, the capacity, the duration limit with the service times,
/// and at most maxr routes; if it returns fewer than minr routes, the longest routes are split. Returns false if no
/// solution was obtained; otherwise the routes and their cost.
bool runHGS(const Data &data, int minr, int maxr, double timeLimit, int seed, int nbGranular,
            std::vector<std::vector<int>> &routes, double &cost);
} // namespace cvrp

#endif
