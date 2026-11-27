#include "Model.h"

#include <iostream>
#include <stdexcept>

#include <bcModelCutConstrC.hpp>
#include <bcModelFormulationC.hpp>
#include <bcModelingLanguageC.hpp>
#include <bcModelMasterC.hpp>
#include <bcModelSolutionC.hpp>
#include <rcsp/bcModelFunctorRCSP.hpp>
#include <rcsp/bcModelNetworkBasedCuts.hpp>
#include <rcsp/bcModelNetworkFlow.hpp>

#include "Cuts.h"

namespace pwjtj
{
// floor and ceiling of a / b for b > 0, as div and cld of Julia
static long floorDiv(long a, long b) { return a >= 0 ? a / b : -((-a + b - 1) / b); }
static long ceilDiv(long a, long b) { return -floorDiv(-a, b); }

void Graph::build(const Data &data)
{
    const int n = data.n, m = data.m, T = data.T;
    const auto &jobs = data.jobs;
    jobNodes.assign(n + 1, {});
    // node of (j, t), 0 if not created; only the pairs reachable from the source get a node
    std::vector<std::vector<int>> id(n + 1, std::vector<int>(T + 1, 0));
    auto registerNode = [&](int j, int t) {
        int k = (int)nodeJob.size();
        nodeJob.push_back(j);
        nodeT.push_back(t);
        id[j][t] = k;
        jobNodes[j].push_back(k);
        return k;
    };

    // type 1: source -> (j, p_j) (job j is the first of its machine, starting at time 0)
    for (int j = 1; j <= n; ++j)
    {
        if (jobs[j].p > T) continue;
        A.emplace_back(0, registerNode(j, jobs[j].p));
    }
    // type 2, breadth-first search: (i, t) -> (j, t + p_j) (job j immediately follows job i)
    for (int k = 1; k < (int)nodeJob.size(); ++k)
    {
        int i = nodeJob[k], t = nodeT[k];
        int pi = jobs[i].p;
        for (int j = 1; j <= n; ++j)
        {
            if (i == j) continue;
            int tj = t + jobs[j].p;
            if (tj > T) continue;
            // Proposition 2: the arc is removed if swapping i and j gives a schedule that is not worse
            long delta = data.jobCost(i, t) + data.jobCost(j, tj) - data.jobCost(j, tj - pi) - data.jobCost(i, tj);
            if (jobs[i].p < jobs[j].p && delta > 0) continue;
            if (jobs[i].p > jobs[j].p && delta >= 0) continue;
            if (i < j && jobs[i].p == jobs[j].p && delta > 0) continue;
            if (i > j && jobs[i].p == jobs[j].p && delta >= 0) continue;
            int kj = id[j][tj];
            if (kj == 0) kj = registerNode(j, tj);
            A.emplace_back(k, kj);
        }
    }
    // type 3: (j, t) -> sink, for t in the completion window of the last job of a machine (see model.jl). The nodes
    // are taken in the order of their numbers (model.jl takes them in the order of a Dict).
    long psum = 0, pmax = 0;
    for (int j = 1; j <= n; ++j)
    {
        psum += jobs[j].p;
        pmax = std::max(pmax, (long)jobs[j].p);
    }
    for (int k = 1; k < (int)nodeJob.size(); ++k)
    {
        int j = nodeJob[k], t = nodeT[k];
        if (t >= ceilDiv(psum - (m - 1) * pmax, m) && t <= floorDiv(psum - jobs[j].p, m) + jobs[j].p)
            A.emplace_back(k, 0);
    }
    nodeCost.assign(nodeJob.size(), 0.0);
    for (int k = 1; k < (int)nodeJob.size(); ++k) nodeCost[k] = (double)data.jobCost(nodeJob[k], nodeT[k]);
}

Model::Model(const BcInitialisation &init, const Data &data, const Graph &graph, double ub)
    : BcModel(init, data.name, BcObjStatus::minInt)
{
    const int n = data.n;
    std::cout << "The model uses a graph with " << graph.A.size() << " arcs!" << std::endl;

    BcObjective objective(*this);
    objective.setMinMaxStatus(BcObjStatus::minInt); // the costs are integer

    BcMaster master(*this);
    // each job is processed exactly once: the sum of x over the arcs entering a node of job j is 1
    BcConstrArray cover(master, "cover");
    for (int j = 1; j <= n; ++j) cover(j) == 1;

    // one graph with exactly m paths
    BcColGenSpArray subproblems(*this);
    BcFormulation sp = subproblems(0);
    sp <= data.m;
    sp >= data.m;

    // x, one variable per arc (named x[(u, v)] as in Julia); as in VrpSolver.jl, its master branching priority is
    // the default of BaPCod and it is not used for branching in the subproblem
    BcVarArray x(sp, "x");
    x.type('I');
    x.priorityForSubproblemBranching(-1);
    x.defineIndexNames(MultiIndexNames('u', 'v'));
    std::vector<BcVar> xa;
    xa.reserve(graph.A.size());
    for (auto [u, v] : graph.A)
    {
        BcVar var = x(u, v);
        xa.push_back(var);
        objective += graph.nodeCost[v] * var;
        if (v != 0) cover[graph.nodeJob[v]] += var;
    }

    // pricing graph: the nodes of the graph and a copy of the source as the sink (as VrpSolver.jl does when the
    // source is the sink); the automatic main resource of VrpSolver.jl (no resource is defined in model.jl)
    const int sink = graph.nbNodes();
    BcNetwork network(sp, n, n);
    BcStandardMainResource res(network, 0, 1.0);
    for (int k = 0; k <= sink; ++k)
    {
        BcVertex vertex = network.createVertex();
        res.setVertexParameters(vertex, StandardResourceVertexParameters(-1e12, 1e12));
        if (k == 0)
            network.setPathSource(vertex);
        else if (k == sink)
            network.setPathSink(vertex);
        else
        {
            // packing sets: the nodes of each job form one set
            vertex.addToPackingSet(graph.nodeJob[k] - 1);
            vertex.addToElementaritySet(graph.nodeJob[k] - 1);
        }
    }
    arcIndex.assign(graph.A.size(), -1);
    for (std::size_t a = 0; a < graph.A.size(); ++a)
    {
        auto [u, v] = graph.A[a];
        BcArc arc = network.createArc(u, v == 0 ? sink : v, 0.0);
        res.setArcParameters(arc, StandardResourceArcParameters(0.0, 0.0, 0.0));
        arc.addVarAssociation(xa[a]);
        if (arc.ref() >= (int)arcIndex.size()) arcIndex.resize(arc.ref() + 1, -1);
        arcIndex[arc.ref()] = (int)a;
    }
    // distance matrix of the elementarity sets (ng-neighbourhoods): |d_i - d_j|
    std::vector<std::vector<double>> dist(n, std::vector<double>(n));
    for (int i = 1; i <= n; ++i)
        for (int j = 1; j <= n; ++j) dist[i - 1][j - 1] = std::abs(data.jobs[i].d - data.jobs[j].d);
    network.setElemSetsDistanceMatrix(dist);
    sp.attach(new BcRCSPFunctor(sp));

    // y[(i, j)]: the sum of x over the arcs from job i to job j (0 = source/sink), used for branching (priority 1)
    std::vector<std::vector<std::vector<int>>> arcsPerPair(n + 1, std::vector<std::vector<int>>(n + 1));
    for (std::size_t a = 0; a < graph.A.size(); ++a)
        arcsPerPair[graph.nodeJob[graph.A[a].first]][graph.nodeJob[graph.A[a].second]].push_back((int)a);
    BcBranchingConstrArray y(master, "y", SelectionStrategy::MostFractional, 1.0);
    for (int i = 0; i <= n; ++i)
        for (int j = 0; j <= n; ++j)
        {
            if (arcsPerPair[i][j].empty()) continue;
            y(i, j);
            for (int a : arcsPerPair[i][j]) y[i][j] += xa[a];
        }

    // rank-1 cuts (VrpSolver.jl adds them when packing sets are defined)
    BcLimMemRankOneCutConstrArray rank1Cuts(master);

    // the extended capacity cuts of cuts.jl, by a cut callback (registered as VrpSolver.jl registers its callbacks)
    BcCutConstrArray userCuts(master, "UserCuts0", 'C', 3.0, 1.0, false);
    userCuts.defineIndexNames(MultiIndexNames('i'));
    userCuts.attach(new ECCSeparation(data, graph, xa, ub));

    // the cutoff, set as by set_cutoff! of VrpSolver.jl once the model is built
    objective <= ub;
    objective.setArtCostValue(std::abs(ub) < 10000.0 ? 10000.0 : std::abs(ub));
}

std::vector<double> arcValues(BcSolution &solution, const Model &model, std::size_t nbArcs)
{
    std::vector<double> xval(nbArcs, 0.0);
    for (BcSolution path = solution.next(); path.defined(); path = path.next())
    {
        double mult = path.getMultiplicity();
        for (int arcId : path.orderedIds()) xval[model.arcIndex[arcId]] += mult;
    }
    return xval;
}
} // namespace pwjtj
