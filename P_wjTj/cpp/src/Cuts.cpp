// Extended capacity cut (ECC) separator for P||sum w_j T_j: port of cuts.jl (itself translated from CutGenerator.cpp
// and roundEccSep.cpp)

#include "Cuts.h"

#include <cmath>
#include <map>
#include <numeric>
#include <set>
#include <sstream>
#include <stdexcept>

#include <bcModelSolutionC.hpp>

namespace pwjtj
{
static const double ECC_VIOLATED_EPS = 0.05;
static const double ECC_CONNECT_EPS = 0.01;
static const double COL_EXPAND_EPS = 1e-6;
static const long MAX_CAP_HECC = 3000;
static const double ECC_CHECK_EPS = 1e-4;

// Fractional part in [0,1) that handles negative numerators correctly
static double eccfrac(long num, long den)
{
    if (den == 0) throw std::runtime_error("eccfrac: den=0");
    long d = num / den; // truncation, as div of Julia
    if (d * den == num) return 0.0;
    return num > 0 ? (double)num / den - d : (double)num / den - d + 1.0;
}

// One entry of the reversed LP solution used for the separation (see cuts.jl): an original arc (u, v) becomes
// (i, j, d) = (job(v), job(u), t(u))
struct LpArcCap
{
    int i, j, d;
    double val;
};

// A rational number num/den in lowest terms, den > 0 (as Rational{Int} of Julia)
struct Rational
{
    long num, den;
    Rational(long n, long d)
    {
        long g = std::gcd(n, d);
        if (g == 0) g = 1;
        num = n / g;
        den = d / g;
        if (den < 0)
        {
            num = -num;
            den = -den;
        }
    }
    bool operator<(const Rational &o) const { return (__int128)num * o.den < (__int128)o.num * den; }
};
using RationalMap = std::map<Rational, double>;

static void rmapUpdate(RationalMap &rmap, long numer, long denom, double delta)
{
    if (denom == 0) return;
    Rational r(numer, denom);
    auto it = rmap.find(r);
    double v = (it == rmap.end() ? 0.0 : it->second) + delta;
    if (std::abs(v) < COL_EXPAND_EPS)
    {
        if (it != rmap.end()) rmap.erase(it);
    }
    else if (it == rmap.end())
        rmap.emplace(r, v);
    else
        it->second = v;
}

struct YZChange
{
    std::vector<int> demY;
    std::vector<double> valY;
    std::vector<int> demZ;
    std::vector<double> valZ;
    int prevSetDem;
};

// RECC_DoRoundings: updates the maps and finds the best multiplier bestNum/bestDen
static void reccDoRoundings(const YZChange &chg, RationalMap &incBefore, RationalMap &incAfter, long cap,
                            long setDemand, long &bestNum, long &bestDen)
{
    // update incAfter: remove the contribution of prevSetDem to the right-hand side, add setDemand
    for (long i = 0; i <= chg.prevSetDem - 1; ++i)
    {
        if (i * cap > chg.prevSetDem * MAX_CAP_HECC) break;
        rmapUpdate(incAfter, i, chg.prevSetDem, 1.0);
    }
    for (long i = 0; i <= setDemand - 1; ++i)
    {
        if (i * cap > setDemand * MAX_CAP_HECC) break;
        rmapUpdate(incAfter, i, setDemand, -1.0);
    }
    // update incAfter for the y variables (arcs with both endpoints changing status)
    for (std::size_t idx = 0; idx < chg.demY.size(); ++idx)
    {
        long q = chg.demY[idx];
        for (long i = 0; i <= q - 1; ++i)
        {
            if (i * cap > q * MAX_CAP_HECC) break;
            rmapUpdate(incAfter, i, q, chg.valY[idx]);
        }
    }
    // update incBefore for the z variables (crossing arcs)
    for (std::size_t idx = 0; idx < chg.demZ.size(); ++idx)
    {
        long q = chg.demZ[idx];
        for (long i = 1; i <= q - 1; ++i)
        {
            if (i * cap > q * MAX_CAP_HECC) break;
            rmapUpdate(incBefore, i, q, -chg.valZ[idx]);
        }
    }

    // best multiplier by a merge of the two sorted maps: the entries of incBefore are evaluated just before their key
    // (left limit), those of incAfter just after it (right limit)
    double lhs = 0.0;
    auto ib = incBefore.begin(), ia = incAfter.begin();
    bestNum = 0;
    bestDen = 1;
    double bestViol = -2.0 * cap;
    while (ib != incBefore.end() || ia != incAfter.end())
    {
        bool useBefore = false, useAfter = false;
        if (ib != incBefore.end() && ia != incAfter.end())
        {
            const Rational &rb = ib->first, &ra = ia->first;
            __int128 m1 = (__int128)rb.num * ra.den, m2 = (__int128)ra.num * rb.den;
            useBefore = m1 <= m2;
            useAfter = m2 <= m1;
        }
        else if (ib != incBefore.end())
            useBefore = true;
        else
            useAfter = true;

        if (useBefore)
        {
            const Rational r = ib->first;
            lhs += ib->second;
            ++ib;
            double viol = -lhs;
            if (viol > bestViol)
            {
                bestViol = viol;
                bestNum = r.num;
                bestDen = r.den;
            }
        }
        if (useAfter)
        {
            const Rational r = ia->first;
            lhs += ia->second;
            ++ia;
            // step just past this multiplier by adding a small fraction
            long maxDen2 = std::max(cap, setDemand);
            long iStep = cap * maxDen2 / r.den + 1;
            long num2 = r.num * iStep + 1;
            long den2 = r.den * iStep;
            double viol = -lhs;
            if (viol > bestViol)
            {
                bestViol = viol;
                bestNum = num2;
                bestDen = den2;
            }
        }
    }
}

struct ECCCut
{
    std::vector<char> S; ///< S[j] for the jobs j = 0..n; S[0] = false (the source)
    long cap = 0;
    std::vector<double> incapcoeff;  ///< [d] for d = 0..cap: coefficient of the arcs entering S
    std::vector<double> outcapcoeff; ///< [d]: coefficient of the arcs leaving S
    double rhs = 0.0;
    double violation = 0.0;          ///< rhs - lhs (positive: violated)
};

// genSingleECCCut: returns whether the cut of the set and multiplier num/den is violated by more than minViolation
static bool genSingleEccCut(const std::vector<LpArcCap> &arcsCap, long num, long den, const std::vector<int> &setList,
                            int n, long cap, const std::vector<int> &demands, double minViolation, ECCCut &cut)
{
    cut.S.assign(n + 1, 0);
    long demand = 0;
    for (int jb : setList)
    {
        cut.S[jb] = 1;
        demand += demands[jb];
    }
    double rhsFrac = eccfrac(demand * num, den);
    cut.rhs = rhsFrac > 0.0 ? 1.0 - rhsFrac : 0.0;
    cut.cap = cap;
    cut.incapcoeff.resize(cap + 1);
    cut.outcapcoeff.resize(cap + 1);
    for (long d = 0; d <= cap; ++d)
    {
        double f = eccfrac(d * num, den);
        cut.incapcoeff[d] = f == 0.0 ? 0.0 : 1.0 - f;
        f = eccfrac(-d * num, den);
        cut.outcapcoeff[d] = f == 0.0 ? 0.0 : 1.0 - f;
    }
    double lhs = 0.0;
    for (const auto &ac : arcsCap)
    {
        if (ac.d > cap) continue;
        if (!cut.S[ac.i] && cut.S[ac.j])
            lhs += cut.incapcoeff[ac.d] * ac.val;
        else if (cut.S[ac.i] && !cut.S[ac.j])
            lhs += cut.outcapcoeff[ac.d] * ac.val;
    }
    cut.violation = cut.rhs - lhs;
    return cut.violation > minViolation;
}

// extCapCutGenByHeur: returns the violated cuts found (at most cutBatch)
static std::vector<ECCCut> extCapCutGenByHeur(const std::vector<LpArcCap> &arcsCap, int n, long cap,
                                              const std::vector<int> &demands, std::size_t cutBatch,
                                              int &nextEccVertex)
{
    // symmetric adjacency lists over the jobs 1..n
    std::vector<std::vector<int>> adjVertex(n + 1);
    std::vector<std::vector<double>> adjValue(n + 1);
    auto addAdj = [&](int a, int b, double val) {
        for (std::size_t pos = 0; pos < adjVertex[a].size(); ++pos)
            if (adjVertex[a][pos] == b)
            {
                adjValue[a][pos] += val;
                return;
            }
        adjVertex[a].push_back(b);
        adjValue[a].push_back(val);
    };
    for (const auto &ac : arcsCap)
    {
        if (ac.val < ECC_CONNECT_EPS) continue;
        if (ac.i == 0 || ac.j == 0) continue;
        addAdj(ac.i, ac.j, ac.val);
        addAdj(ac.j, ac.i, ac.val);
    }
    // arcs adjacent to each node 0..n
    std::vector<std::vector<int>> adjCapArcs(n + 1);
    for (std::size_t k = 0; k < arcsCap.size(); ++k)
    {
        adjCapArcs[arcsCap[k].i].push_back((int)k);
        adjCapArcs[arcsCap[k].j].push_back((int)k);
    }

    std::vector<ECCCut> cuts;
    std::set<std::vector<char>> seenSets;
    ECCCut cut, trial;
    for (int iter = 0; iter < n; ++iter)
    {
        int v = nextEccVertex;
        nextEccVertex = v % n + 1; // cycles through 1..n

        std::vector<char> inSet(n + 1, 0);
        inSet[v] = 1;
        std::vector<int> vertexSet = {v};
        std::vector<int> candidates = adjVertex[v];
        int lastVertex = v;
        long setDemand = demands[v];
        RationalMap incBefore, incAfter;
        long bestNum = 0, bestDen = 1;

        while (true)
        {
            // the change of lastVertex having just been added to S
            YZChange chg;
            chg.prevSetDem = (int)(setDemand - demands[lastVertex]);
            for (int k : adjCapArcs[lastVertex])
            {
                const auto &ac = arcsCap[k];
                if (ac.i == lastVertex)
                {
                    if (inSet[ac.j])
                    {
                        chg.demY.push_back(ac.d);
                        chg.valY.push_back(-ac.val);
                    }
                    else
                    {
                        chg.demZ.push_back(ac.d);
                        chg.valZ.push_back(ac.val);
                    }
                }
                else if (ac.j == lastVertex)
                {
                    if (inSet[ac.i])
                    {
                        chg.demZ.push_back(ac.d);
                        chg.valZ.push_back(-ac.val);
                    }
                    else
                    {
                        chg.demY.push_back(ac.d);
                        chg.valY.push_back(ac.val);
                    }
                }
            }
            reccDoRoundings(chg, incBefore, incAfter, cap, setDemand, bestNum, bestDen);

            // the cut of the current set
            bool violated = genSingleEccCut(arcsCap, bestNum, bestDen, vertexSet, n, cap, demands, ECC_VIOLATED_EPS, cut);
            seenSets.insert(inSet);
            if (violated)
            {
                cuts.push_back(cut);
                if (cuts.size() >= cutBatch) return cuts;
            }

            // the best candidate to add to S
            int bestCand = 0, bestPos = -1;
            double bestViolC = -2.0 * (cap + (long)vertexSet.size());
            for (std::size_t k = 0; k < candidates.size(); ++k)
            {
                int ci = candidates[k];
                inSet[ci] = 1;
                if (seenSets.count(inSet))
                {
                    inSet[ci] = 0;
                    continue;
                }
                setDemand += demands[ci];
                vertexSet.push_back(ci);
                genSingleEccCut(arcsCap, bestNum, bestDen, vertexSet, n, cap, demands, 1.1, trial); // never kept
                double viol = trial.violation;
                if (viol < 0.0)
                {
                    viol = -2.0 * vertexSet.size();
                    for (std::size_t kk = 0; kk < adjVertex[ci].size(); ++kk)
                        if (inSet[adjVertex[ci][kk]]) viol += adjValue[ci][kk];
                }
                if (viol > bestViolC)
                {
                    bestViolC = viol;
                    bestCand = ci;
                    bestPos = (int)k;
                }
                inSet[ci] = 0;
                setDemand -= demands[ci];
                vertexSet.pop_back();
            }
            if (bestCand == 0) break;

            // remove bestCand from the candidates; add its new neighbours
            if (bestPos < (int)candidates.size() - 1) candidates[bestPos] = candidates.back();
            candidates.pop_back();
            for (int nb : adjVertex[bestCand])
                if (!inSet[nb] && std::find(candidates.begin(), candidates.end(), nb) == candidates.end())
                    candidates.push_back(nb);
            inSet[bestCand] = 1;
            setDemand += demands[bestCand];
            vertexSet.push_back(bestCand);
            lastVertex = bestCand;
        }
    }
    return cuts;
}

ECCSeparation::ECCSeparation(const Data &data, const Graph &graph, std::vector<BcVar> x, double ub)
    : data(data), graph(graph), x(std::move(x)), ub(ub), demands(data.n + 1, 0)
{
    for (int j = 1; j <= data.n; ++j) demands[j] = data.jobs[j].p;
    for (std::size_t a = 0; a < graph.A.size(); ++a)
        arcOf[(long)graph.A[a].first * graph.nbNodes() + graph.A[a].second] = (int)a;
}

int ECCSeparation::operator()(BcFormulation form, BcSolution &primalSol, double &, std::list<BcConstr> &cutList)
{
    const auto &A = graph.A;
    // x of the arcs, as value() in the Julia callback (the solution of the subproblem is aggregated, so the values
    // come from the variables, not from the paths)
    std::vector<double> xval(A.size(), 0.0);
    std::set<BcVar> vars;
    primalSol.extractVar("x", vars);
    for (const BcVar &var : vars)
        xval[arcOf.at((long)var.id().first() * graph.nbNodes() + var.id().second())] += var.solVal();

    // no separation once the relaxation reaches the cutoff (no integer solution below ub)
    double relax = 0.0;
    for (std::size_t a = 0; a < A.size(); ++a) relax += graph.nodeCost[A[a].second] * xval[a];
    if (relax >= ub - 1.0 - ECC_CHECK_EPS) return 0;

    std::vector<LpArcCap> arcsCap;
    for (std::size_t a = 0; a < A.size(); ++a)
    {
        if (xval[a] < 1e-8) continue;
        auto [u, v] = A[a];
        arcsCap.push_back({graph.nodeJob[v], graph.nodeJob[u], graph.nodeT[u], xval[a]});
    }
    std::vector<ECCCut> cuts = extCapCutGenByHeur(arcsCap, data.n, data.T, demands, 100, nextEccVertex);

    BcCutConstrArray userCuts(form, "UserCuts0");
    int added = 0;
    for (const auto &cut : cuts)
    {
        // over all the arcs (not only those with a nonzero value)
        std::vector<std::size_t> arcs;
        std::vector<double> coeffs;
        for (std::size_t a = 0; a < A.size(); ++a)
        {
            auto [u, v] = A[a];
            int i = graph.nodeJob[v], j = graph.nodeJob[u], d = graph.nodeT[u];
            if (d > cut.cap) continue;
            double coeff = 0.0;
            if (!cut.S[i] && cut.S[j])
                coeff = cut.incapcoeff[d];
            else if (cut.S[i] && !cut.S[j])
                coeff = cut.outcapcoeff[d];
            if (std::abs(coeff) < 1e-10) continue;
            arcs.push_back(a);
            coeffs.push_back(coeff);
        }
        // check_ecc_violation: the violation recomputed from the values of x
        double lhs = 0.0;
        for (std::size_t k = 0; k < arcs.size(); ++k) lhs += coeffs[k] * xval[arcs[k]];
        double violation = cut.rhs - lhs;
        if (std::abs(violation - cut.violation) > ECC_CHECK_EPS)
        {
            std::ostringstream msg;
            msg << "ECC violation mismatch: recomputed=" << violation << ", reported=" << cut.violation
                << ", diff=" << std::abs(violation - cut.violation);
            throw std::runtime_error(msg.str());
        }
        if (arcs.empty()) continue;
        BcConstr c = userCuts(cutCount++);
        for (std::size_t k = 0; k < arcs.size(); ++k) c += coeffs[k] * x[arcs[k]];
        c >= cut.rhs;
        cutList.push_back(c);
        ++added;
    }
    return added;
}
} // namespace pwjtj
