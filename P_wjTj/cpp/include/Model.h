#ifndef PWJTJ_MODEL_H
#define PWJTJ_MODEL_H

#include <utility>
#include <vector>

#include <bcModelPointerC.hpp>

#include "Data.h"

namespace pwjtj
{
/// The time-indexed graph of model.jl: node 0 is the source and the sink; node k >= 1 is the completion of job
/// nodeJob[k] at time nodeT[k]. Nodes are numbered in the order of the breadth-first search of model.jl.
struct Graph
{
    std::vector<int> nodeJob = {0}, nodeT = {0};
    std::vector<std::vector<int>> jobNodes;   ///< nodes of each job 1..n
    std::vector<std::pair<int, int>> A;       ///< arcs (tail node, head node), in the order of model.jl
    std::vector<double> nodeCost = {0.0};     ///< cost of the arcs entering each node

    int nbNodes() const { return (int)nodeJob.size(); }
    void build(const Data &data);
};

/// The model of model.jl, built as VrpSolver.jl builds it in BaPCod, with the extended capacity cuts of cuts.jl.
/// The cutoff ub is set at the end (set_cutoff! of VrpSolver.jl).
class Model : public BcModel
{
   public:
    std::vector<int> arcIndex; ///< index in graph.A of each BaPCod arc id

    Model(const BcInitialisation &init, const Data &data, const Graph &graph, double ub);
};

/// x of each arc of graph.A in a solution (the sum of the multiplicities of the paths that use it), as the values of
/// the variables given by VrpSolver.jl
std::vector<double> arcValues(BcSolution &solution, const Model &model, std::size_t nbArcs);
} // namespace pwjtj

#endif
