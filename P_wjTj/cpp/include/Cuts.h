#ifndef PWJTJ_CUTS_H
#define PWJTJ_CUTS_H

#include <unordered_map>
#include <vector>

#include <bcModelCutConstrC.hpp>

#include "Data.h"
#include "Model.h"

namespace pwjtj
{
/// The extended capacity cut (ECC) separator of cuts.jl, called as the cut callback of model.jl
class ECCSeparation : public BcCutSeparationFunctor
{
    const Data &data;
    const Graph &graph;
    std::unordered_map<long, int> arcOf; ///< index in graph.A of the arc (u, v), by the key u * nbNodes + v
    std::vector<BcVar> x;              ///< variable of each arc of graph.A
    double ub;
    std::vector<int> demands;          ///< demands[j] = p_j (demands[0] = 0, the source/sink)
    int nextEccVertex = 1;             ///< first vertex of the heuristic, persists across the calls
    int cutCount = 0;

   public:
    ECCSeparation(const Data &data, const Graph &graph, std::vector<BcVar> x, double ub);
    int operator()(BcFormulation form, BcSolution &primalSol, double &maxViolation,
                   std::list<BcConstr> &cutList) override;
};
} // namespace pwjtj

#endif
