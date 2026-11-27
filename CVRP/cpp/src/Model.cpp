#include "Model.h"

#include <algorithm>
#include <cmath>
#include <iostream>
#include <numeric>

#include <bcModelCutConstrC.hpp>
#include <bcModelingLanguageC.hpp>
#include <rcsp/bcModelFunctorRCSP.hpp>
#include <rcsp/bcModelNetworkBasedCuts.hpp>
#include <rcsp/bcModelNetworkFlow.hpp>

namespace cvrp
{
// Edge cuts of option -e (the cut callback of model.jl): x_e <= 1 for an edge between two customers with x_e > 1
class EdgeCutSeparation : public BcCutSeparationFunctor
{
    int cutCount = 0;

   public:
    int operator()(BcFormulation form, BcSolution &primalSol, double &maxViolation, std::list<BcConstr> &cutList) override
    {
        std::set<BcVar> vars;
        primalSol.extractVar("X", vars);
        BcCutConstrArray edgeCuts(form, "UserCuts0");
        int added = 0;
        for (const BcVar &var : vars)
        {
            int i = var.id().first(), j = var.id().second();
            if (i != 0 && var.solVal() > 1.001)
            {
                std::cout << "Adding edge ub cut for e = (" << i << ", " << j << ")" << std::endl;
                BcConstr cut = edgeCuts(cutCount++);
                cut <= 1.0;
                cut += var;
                cutList.push_back(cut);
                maxViolation = (std::max)(maxViolation, var.solVal() - 1.0);
                ++added;
            }
        }
        return added;
    }
};

// Clusters of customers of add_cluster_branching! (branching.jl): edges between customers by increasing cost are
// added to a forest, first to compute the average cost and its standard deviation, then only up to the threshold
// average + deviation. Returns the cluster of each customer (1..m) and m.
static std::vector<int> clusters(const Data &data, int &m)
{
    const int n = data.n;
    std::vector<std::tuple<double, int, int>> edgeCosts;
    for (auto [i, j] : data.E)
        if (i != 0) edgeCosts.emplace_back(data.c[i][j], i, j);
    std::sort(edgeCosts.begin(), edgeCosts.end());
    std::vector<int> parent;
    std::function<int(int)> find = [&](int i) { return parent[i] == i ? i : parent[i] = find(parent[i]); };
    double threshold = INFINITY;
    for (int phase = 1; phase <= 2; ++phase)
    {
        parent.resize(n + 1);
        std::iota(parent.begin(), parent.end(), 0);
        int groups = n;
        double sum = 0.0, sumSq = 0.0;
        for (std::size_t pos = 0; groups > 1 && pos < edgeCosts.size(); ++pos)
        {
            auto [c, i, j] = edgeCosts[pos];
            if (c > threshold) break;
            if (find(i) != find(j))
            {
                sum += c;
                sumSq += c * c;
                parent[find(i)] = find(j);
                --groups;
            }
        }
        if (phase == 1) threshold = sum / (n - 1) + std::sqrt(sumSq / (n - 1));
    }
    std::vector<int> id(n + 1, -1), rootId(n + 1, -1);
    m = 0;
    for (int i = 1; i <= n; ++i)
    {
        int r = find(i);
        if (rootId[r] == -1) rootId[r] = ++m;
        id[i] = rootId[r];
    }
    return id;
}

Model::Model(const BcInitialisation &init, const Data &data, const App &app, double ub)
    : BcModel(init, data.name, data.round ? BcObjStatus::minInt : BcObjStatus::minFloat)
{
    const int n = data.n;
    if (app.strongKPathCuts)
        throw std::runtime_error("VRPSolver error: This function is currently disabled and will be restored in a "
                                 "future release. To use this feature now, please refer to the legacy Docker installation");

    BcObjective objective(*this);
    // integer objective when the distances are rounded (set in the model and in the objective, as VrpSolver.jl does)
    objective.setMinMaxStatus(data.round ? BcObjStatus::minInt : BcObjStatus::minFloat);

    BcMaster master(*this);
    BcConstrArray deg(master, "deg");
    for (int i = 1; i <= n; ++i) deg(i) == 2;

    // one graph: between max(minr, lower bound on the number of vehicles) and min(maxr, n) paths
    BcColGenSpArray subproblems(*this);
    BcFormulation sp = subproblems(0);
    sp <= (std::min)(app.maxr, n);
    sp >= (std::max)(app.minr, data.lowerBoundNbVehicles());

    BcVarArray x(sp, "X");
    x.type('I');
    x.priorityForMasterBranching(app.lowEdgePriority ? 1.0 : 2.0); // branching on the edges
    x.priorityForSubproblemBranching(-1);
    x.defineIndexNames(MultiIndexNames('i', 'j'));
    for (auto [i, j] : data.E)
    {
        BcVar var = x(i, j);
        objective += data.c[i][j] * var;
        if (i != 0) deg[i] += var;
        deg[j] += var;
    }

    // branching on the clusters of customers (option -B, enabled by default): the number of edges leaving each
    // cluster (omega) and the number of edges between two clusters (Psi), with priority 2
    if (app.clusterBranching != 0.0)
    {
        int m = 0;
        std::vector<int> cl = clusters(data, m);
        if (m > 1)
        {
            BcBranchingConstrArray omega(master, "omega", SelectionStrategy::MostFractional, 2.0);
            BcBranchingConstrArray psi(master, "Psi", SelectionStrategy::MostFractional, 2.0);
            for (int k = 1; k <= m; ++k)
            {
                omega(k);
                for (int l = k + 1; l <= m; ++l) psi(k, l);
            }
            for (auto [i, j] : data.E)
            {
                BcVar var = (BcVar)x[i][j];
                for (int k = 1; k <= m; ++k)
                    if ((i != 0 && cl[i] == k) != (cl[j] == k)) omega[k] += var;
                if (i != 0 && cl[i] != cl[j])
                    psi[(std::min)(cl[i], cl[j])][(std::max)(cl[i], cl[j])] += var;
            }
        }
    }

    // pricing graph: vertex 0 is the source (the depot), 1..n the customers, n + 1 the sink (the depot again)
    BcNetwork network(sp, n + 1, n + 1);
    const bool hasCap = (data.D == 0) || !app.singleResource;
    BcStandardMainResource capRes, distRes;
    int capResId = -1, distResId = -1, nextResId = 0;
    if (hasCap)
    {
        capResId = nextResId++;
        capRes = BcStandardMainResource(network, capResId, 0.0);
    }
    if (data.D > 0)
    {
        distResId = nextResId++;
        distRes = BcStandardMainResource(network, distResId, 0.0);
    }
    for (int v = 0; v <= n + 1; ++v)
    {
        BcVertex vertex = network.createVertex();
        if (hasCap) capRes.setVertexParameters(vertex, StandardResourceVertexParameters(0, data.Q));
        if (data.D > 0) distRes.setVertexParameters(vertex, StandardResourceVertexParameters(0, data.D));
        if (v == 0)
            network.setPathSource(vertex);
        else if (v == n + 1)
            network.setPathSink(vertex);
        else
        {
            vertex.setElementaritySet(v);
            vertex.setPackingSet(v);
        }
    }
    // two arcs per edge, both mapped to its variable; the load of an arc is (d_i + d_j)/2 (a symmetric graph), its
    // duration the time of the edge
    for (auto [i, j] : data.E)
        for (int dir = 0; dir < 2; ++dir)
        {
            int tail = dir == 0 ? i : j, head = dir == 0 ? j : i;
            BcArc arc = network.createArc(tail, head == 0 ? n + 1 : head, 0.0);
            arc.addVarAssociation((BcVar)x[i][j]);
            if (hasCap) capRes.setArcParameters(arc, StandardResourceArcParameters(0.5 * (data.d[i] + data.d[j])));
            if (data.D > 0) distRes.setArcParameters(arc, StandardResourceArcParameters(data.time(i, j)));
        }
    std::vector<std::vector<double>> dist(n + 1, std::vector<double>(n + 1, 1e12));
    for (int i = 1; i <= n; ++i)
        for (int j = 1; j <= n; ++j) dist[i][j] = data.c[i][j];
    network.setElemSetsDistanceMatrix(dist);
    sp.attach(new BcRCSPFunctor(sp));

    // rounded capacity cuts (with the parameters of VrpSolver.jl); with a duration limit, also on the durations
    std::vector<int> demands(n + 1, 0), services(n + 1, 0);
    for (int i = 1; i <= n; ++i)
    {
        demands[i] = (int)data.d[i];
        services[i] = (int)data.S;
    }
    BcCapacityCutConstrArray capacityCuts(master, (int)data.Q, demands, false, true, -1, 3.0, 1.0);
    if (data.D > 0)
        BcCapacityCutConstrArray durationCuts(master, (int)data.D, services, false, true, distResId, 3.0, 1.0);
    BcLimMemRankOneCutConstrArray rank1Cuts(master);

    if (app.edgeCuts)
    {
        // registered as VrpSolver.jl registers its cut callbacks (core cuts named UserCuts0)
        BcCutConstrArray edgeCuts(master, "UserCuts0", 'C', 3.0, 1.0, false);
        edgeCuts.defineIndexNames(MultiIndexNames('i'));
        edgeCuts.attach(new EdgeCutSeparation());
    }

    // the cutoff, set as by set_cutoff! of VrpSolver.jl once the model is built: with the master already created, the
    // upper bound becomes the incumbent value of BaPCod, so a run that finds nothing below it ends as optimal
    objective <= ub;
    objective.setArtCostValue(std::abs(ub) < 10000.0 ? 10000.0 : std::abs(ub));
}
} // namespace cvrp
