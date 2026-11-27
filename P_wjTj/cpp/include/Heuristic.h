#ifndef PWJTJ_HEURISTIC_H
#define PWJTJ_HEURISTIC_H

#include <vector>

#include "Data.h"

namespace pwjtj
{
/// pwjtj_heuristic of heuristic.jl: list scheduling with several rules, local search, iterated local search. Returns
/// the best schedule found (one job sequence per machine, without idle time) and its cost.
long pwjtjHeuristic(const Data &data, std::vector<std::vector<int>> &best, int ilsIterations = 200, int seed = 1);
long scheduleCost(const Data &data, const std::vector<std::vector<int>> &sched);
} // namespace pwjtj

#endif
