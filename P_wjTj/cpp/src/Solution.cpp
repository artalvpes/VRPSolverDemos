#include "Solution.h"

#include <charconv>
#include <cmath>
#include <fstream>
#include <iostream>
#include <map>
#include <set>
#include <sstream>
#include <stdexcept>

namespace pwjtj
{
std::string juliaFloat(double v)
{
    if (v == 0.0) return std::signbit(v) ? "-0.0" : "0.0";
    char buf[64];
    auto res = std::to_chars(buf, buf + sizeof(buf), v, std::chars_format::scientific); // shortest round-trip
    std::string s(buf, res.ptr);
    std::size_t e = s.find('e');
    std::string mant = s.substr(0, e);
    int exp10 = std::stoi(s.substr(e + 1));
    bool neg = mant[0] == '-';
    if (neg) mant = mant.substr(1);
    std::string digits;
    for (char ch : mant)
        if (ch != '.') digits += ch;
    std::string out;
    double a = std::abs(v);
    if (a >= 1e6 || a < 1e-4) // scientific notation, as Julia: 1.0e7, 1.234567e6, 2.5e-5
        out = digits.substr(0, 1) + "." + (digits.size() > 1 ? digits.substr(1) : "0") + "e" + std::to_string(exp10);
    else if (exp10 >= 0)
    {
        std::string intPart = digits.substr(0, std::min((std::size_t)exp10 + 1, digits.size()));
        while ((int)intPart.size() < exp10 + 1) intPart += '0';
        std::string frac = (int)digits.size() > exp10 + 1 ? digits.substr(exp10 + 1) : "0";
        out = intPart + "." + frac;
    }
    else
        out = "0." + std::string(-exp10 - 1, '0') + digits;
    return (neg ? "-" : "") + out;
}

static std::string jt(const Graph &graph, int k)
{
    return "(" + std::to_string(graph.nodeJob[k]) + ", " + std::to_string(graph.nodeT[k]) + ")";
}

// Follows the arcs with value > 0.5 from the source (node 0) along each machine path
Solution getSolution(const Graph &graph, const std::vector<double> &xval, double objval)
{
    std::map<int, std::vector<int>> adj;
    for (std::size_t a = 0; a < graph.A.size(); ++a)
        if (xval[a] > 0.5) adj[graph.A[a].first].push_back(graph.A[a].second);
    Solution sol;
    sol.cost = objval;
    for (int start : adj[0])
    {
        std::vector<std::pair<int, int>> schedule;
        int cur = start;
        while (cur != 0)
        {
            int j = graph.nodeJob[cur], t = graph.nodeT[cur];
            schedule.emplace_back(j, t);
            const auto &nexts = adj[cur];
            if (nexts.size() != 1)
                throw std::runtime_error("Node " + std::to_string(cur) + " (job " + std::to_string(j) + ", t=" +
                                         std::to_string(t) + ") has " + std::to_string(nexts.size()) +
                                         " outgoing arcs in solution.");
            cur = nexts[0];
        }
        sol.schedules.push_back(schedule);
    }
    return sol;
}

// Checks the solution x of the model with value z against the definition of P||sum w_j T_j, assuming nothing about
// how it was obtained (see Note 6.12 of the book "Optimizing with Column Generation"). The nodes of the arcs are
// interpreted as (job, completion time) pairs; everything else is checked from the job data: x_a binary; flow
// conservation at every node; the paths from the source give at most m machine schedules; every job is processed
// exactly once; on each machine the jobs do not overlap and start at time >= 0 (idle times are allowed); and z is
// the sum over the jobs of w_j max(0, C_j - d_j). Throws an error otherwise.
void checkSolutionX(const Data &data, const Graph &graph, const std::vector<double> &xval, double z)
{
    const double tol = 1e-6;
    const int src = 0;
    auto arcName = [&](std::size_t a) {
        return "(" + std::to_string(graph.A[a].first) + ", " + std::to_string(graph.A[a].second) + ")";
    };
    for (std::size_t a = 0; a < xval.size(); ++a)
        if (std::abs(xval[a]) > tol && std::abs(xval[a] - 1) > tol)
        {
            std::ostringstream msg;
            msg << "x[" << arcName(a) << "] = " << juliaFloat(xval[a]) << " is not binary";
            throw std::runtime_error(msg.str());
        }
    std::map<int, std::vector<int>> succ;
    std::map<int, int> indeg;
    for (std::size_t a = 0; a < xval.size(); ++a)
    {
        if (xval[a] <= 0.5) continue;
        succ[graph.A[a].first].push_back(graph.A[a].second);
        indeg[graph.A[a].second] += 1;
    }
    for (auto [nid, d] : indeg)
    {
        if (nid == src) continue;
        std::size_t nout = succ.count(nid) ? succ[nid].size() : 0;
        if (d != 1 || nout != 1)
            throw std::runtime_error("Node " + std::to_string(nid) + " " + jt(graph, nid) + " has in-degree " +
                                     std::to_string(d) + " and out-degree " + std::to_string(nout));
    }
    std::vector<int> starts = succ[src];
    if ((int)starts.size() > data.m)
        throw std::runtime_error("The solution uses " + std::to_string(starts.size()) + " machines, more than m = " +
                                 std::to_string(data.m));
    std::vector<int> done(data.n + 1, 0);
    double cost = 0.0;
    std::set<int> reached;
    for (std::size_t k = 0; k < starts.size(); ++k)
    {
        int cur = starts[k], prevEnd = 0;
        while (cur != src)
        {
            if (reached.count(cur)) throw std::runtime_error("Node " + std::to_string(cur) + " is reached twice");
            reached.insert(cur);
            int j = graph.nodeJob[cur], t = graph.nodeT[cur];
            const Job &job = data.jobs[j];
            done[j] += 1;
            if (t - job.p < prevEnd)
                throw std::runtime_error("On machine " + std::to_string(k + 1) + ", job " + std::to_string(j) +
                                         " starts at " + std::to_string(t - job.p) +
                                         ", before the previous job ends (" + std::to_string(prevEnd) + ")");
            cost += std::max(0L, (long)job.w * (t - job.d));
            prevEnd = t;
            cur = succ[cur][0];
        }
    }
    std::string unreached;
    for (auto [nid, d] : indeg)
        if (nid != src && !reached.count(nid)) unreached += (unreached.empty() ? "" : ", ") + std::to_string(nid);
    if (!unreached.empty())
        throw std::runtime_error("The nodes [" + unreached + "] are not on a path from the source (cycles)");
    for (int j = 1; j <= data.n; ++j)
        if (done[j] != 1)
            throw std::runtime_error("Job " + std::to_string(j) + " is processed " + std::to_string(done[j]) +
                                     " times, not once");
    if (std::abs(cost - z) > 1e-6 * std::max(1.0, std::abs(z)))
        throw std::runtime_error("The total weighted tardiness (" + juliaFloat(cost) +
                                 ") is different from the objective value (" + juliaFloat(z) + ")");
}

void printSchedules(const Data &data, const Solution &solution)
{
    for (std::size_t k = 0; k < solution.schedules.size(); ++k)
    {
        std::cout << "Machine #" << k + 1 << ":";
        for (auto [j, t] : solution.schedules[k])
            std::cout << " [job " << j << ", start=" << t - data.jobs[j].p << ", end=" << t
                      << ", tard=" << std::max(0, t - data.jobs[j].d) << "]";
        std::cout << "\n";
    }
}

void writeSolution(const std::string &path, const Solution &solution)
{
    std::ofstream f(path);
    if (!f) throw std::runtime_error("cannot write the solution file " + path);
    for (std::size_t k = 0; k < solution.schedules.size(); ++k)
    {
        f << "Machine #" << k + 1 << ":";
        for (auto [j, t] : solution.schedules[k]) f << " " << j << "(" << t << ")";
        f << "\n";
    }
    f << "Cost " << juliaFloat(solution.cost) << "\n";
}
} // namespace pwjtj
