// Simple heuristic for P||sum w_j T_j, used to obtain an initial upper bound (port of heuristic.jl).
//
// Construction: list scheduling. The machine that becomes free first receives the unscheduled job of highest
// priority, for several rules: ATC (apparent tardiness cost) with K in {0.5, 1, 2, 4}, WSPT and EDD.
// Local search (first improvement, until no improvement): move a job to any position of any machine, and swap two
// jobs. Then an iterated local search perturbs the best solution with random moves (the random numbers are not those
// of Julia, so this part may find another solution).
// A solution is a vector of machine sequences; there is no idle time.

#include "Heuristic.h"

#include <cmath>
#include <functional>
#include <limits>
#include <random>

namespace pwjtj
{
static long machineCost(const Data &data, const std::vector<int> &seq)
{
    long t = 0, c = 0;
    for (int j : seq)
    {
        t += data.jobs[j].p;
        c += data.jobCost(j, (int)t);
    }
    return c;
}

long scheduleCost(const Data &data, const std::vector<std::vector<int>> &sched)
{
    long c = 0;
    for (const auto &s : sched) c += machineCost(data, s);
    return c;
}

static std::vector<std::vector<int>> listSchedule(const Data &data, const std::function<double(int, int)> &priority)
{
    std::vector<std::vector<int>> sched(data.m);
    std::vector<int> free(data.m, 0);
    std::vector<char> left(data.n + 1, 1);
    for (int count = 0; count < data.n; ++count)
    {
        int k = 0; // the first machine that becomes free
        for (int l = 1; l < data.m; ++l)
            if (free[l] < free[k]) k = l;
        int t = free[k];
        int best = 0; // highest priority, then smallest index
        double bestPrio = 0.0;
        for (int j = 1; j <= data.n; ++j)
        {
            if (!left[j]) continue;
            double prio = priority(j, t);
            if (best == 0 || prio > bestPrio)
            {
                best = j;
                bestPrio = prio;
            }
        }
        sched[k].push_back(best);
        free[k] = t + data.jobs[best].p;
        left[best] = 0;
    }
    return sched;
}

static void localSearch(const Data &data, std::vector<std::vector<int>> &sched)
{
    const int m = data.m;
    std::vector<long> costs(m);
    for (int a = 0; a < m; ++a) costs[a] = machineCost(data, sched[a]);
    bool improved = true;
    while (improved)
    {
        improved = false;
        // move a job to any position of any machine
        for (int a = 0; a < m && !improved; ++a)
            for (std::size_t i = 0; i < sched[a].size() && !improved; ++i)
            {
                int j = sched[a][i];
                std::vector<int> sa = sched[a];
                sa.erase(sa.begin() + i);
                long ca = machineCost(data, sa);
                for (int b = 0; b < m && !improved; ++b)
                    for (std::size_t pos = 0; pos < sched[b].size() + (a == b ? 0 : 1); ++pos)
                    {
                        if (a == b && pos == i) continue;
                        std::vector<int> sb = a == b ? sa : sched[b];
                        sb.insert(sb.begin() + pos, j);
                        long cb = machineCost(data, sb);
                        long delta = a == b ? cb - costs[a] : ca + cb - costs[a] - costs[b];
                        if (delta < 0)
                        {
                            if (a == b)
                            {
                                sched[a] = sb;
                                costs[a] = cb;
                            }
                            else
                            {
                                sched[a] = sa;
                                costs[a] = ca;
                                sched[b] = sb;
                                costs[b] = cb;
                            }
                            improved = true;
                            break;
                        }
                    }
            }
        if (improved) continue;
        // swap two jobs
        for (int a = 0; a < m && !improved; ++a)
            for (std::size_t i = 0; i < sched[a].size() && !improved; ++i)
                for (int b = a; b < m && !improved; ++b)
                    for (std::size_t i2 = 0; i2 < sched[b].size(); ++i2)
                    {
                        if (a == b && i2 <= i) continue;
                        std::vector<int> sa = sched[a];
                        std::vector<int> sb = a == b ? std::vector<int>() : sched[b];
                        std::vector<int> &tb = a == b ? sa : sb;
                        int ja = sched[a][i], jb = sched[b][i2];
                        sa[i] = jb;
                        tb[i2] = ja;
                        long ca = machineCost(data, sa);
                        long cb = a == b ? ca : machineCost(data, sb);
                        long delta = a == b ? ca - costs[a] : ca + cb - costs[a] - costs[b];
                        if (delta < 0)
                        {
                            sched[a] = sa;
                            costs[a] = ca;
                            if (a != b)
                            {
                                sched[b] = sb;
                                costs[b] = cb;
                            }
                            improved = true;
                            break;
                        }
                    }
    }
}

long pwjtjHeuristic(const Data &data, std::vector<std::vector<int>> &best, int ilsIterations, int seed)
{
    const auto &jobs = data.jobs;
    double pbar = 0.0;
    for (int j = 1; j <= data.n; ++j) pbar += jobs[j].p;
    pbar /= data.n;
    std::vector<std::function<double(int, int)>> rules = {
        [&](int j, int) { return -(double)jobs[j].d; },
        [&](int j, int) { return (double)jobs[j].w / jobs[j].p; }};
    for (double K : {0.5, 1.0, 2.0, 4.0})
        rules.push_back([&, K](int j, int t) {
            return (double)jobs[j].w / jobs[j].p * std::exp(-std::max(0, jobs[j].d - jobs[j].p - t) / (K * pbar));
        });
    long bestCost = std::numeric_limits<long>::max();
    for (const auto &rule : rules)
    {
        auto sched = listSchedule(data, rule);
        localSearch(data, sched);
        long c = scheduleCost(data, sched);
        if (c < bestCost)
        {
            best = sched;
            bestCost = c;
        }
    }
    std::mt19937 rng(seed);
    auto randInt = [&](int lo, int hi) { return std::uniform_int_distribution<int>(lo, hi)(rng); };
    for (int it = 0; it < ilsIterations; ++it)
    {
        if (bestCost == 0) break;
        auto sched = best;
        for (int r = 0; r < 3; ++r) // perturbation: three random moves
        {
            std::vector<int> nonEmpty;
            for (int a = 0; a < data.m; ++a)
                if (!sched[a].empty()) nonEmpty.push_back(a);
            int a = nonEmpty[randInt(0, (int)nonEmpty.size() - 1)];
            int pos = randInt(0, (int)sched[a].size() - 1);
            int j = sched[a][pos];
            sched[a].erase(sched[a].begin() + pos);
            int b = randInt(0, data.m - 1);
            sched[b].insert(sched[b].begin() + randInt(0, (int)sched[b].size()), j);
        }
        localSearch(data, sched);
        long c = scheduleCost(data, sched);
        if (c < bestCost)
        {
            best = sched;
            bestCost = c;
        }
    }
    return bestCost;
}
} // namespace pwjtj
