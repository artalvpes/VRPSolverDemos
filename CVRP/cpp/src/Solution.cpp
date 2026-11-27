#include "Solution.h"

#include <charconv>
#include <cmath>
#include <fstream>
#include <functional>
#include <iostream>
#include <map>
#include <sstream>
#include <stdexcept>

namespace cvrp
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
        std::string intPart = digits.substr(0, (std::min)((std::size_t)exp10 + 1, digits.size()));
        while ((int)intPart.size() < exp10 + 1) intPart += '0';
        std::string frac = (int)digits.size() > exp10 + 1 ? digits.substr(exp10 + 1) : "0";
        out = intPart + "." + frac;
    }
    else
        out = "0." + std::string(-exp10 - 1, '0') + digits;
    return (neg ? "-" : "") + out;
}

std::string costString(const Solution &sol)
{
    return sol.integerCost ? std::to_string(std::llround(sol.cost)) : juliaFloat(sol.cost);
}

static std::runtime_error recoverError(const std::string &msg)
{
    return std::runtime_error("Problem trying to recover the route from the x values. " + msg);
}

Solution getSolution(const Data &data, const std::vector<double> &xval, double objval, bool noround)
{
    const int dim = data.n + 1;
    std::vector<std::vector<int>> adj(dim);
    for (std::size_t k = 0; k < data.E.size(); ++k)
    {
        auto [i, j] = data.E[k];
        double val = xval[k];
        if (val > 0.5)
        {
            adj[i].push_back(j);
            adj[j].push_back(i);
            if (val > 1.5)
            {
                adj[i].push_back(j);
                adj[j].push_back(i);
            }
        }
    }
    std::vector<bool> visited(dim, false);
    Solution sol;
    for (int i : adj[0])
    {
        if (visited[i]) continue;
        std::vector<int> r{i};
        visited[i] = true;
        if (adj[i].size() != 2)
            throw recoverError("Customer " + std::to_string(i) + " has " + std::to_string(adj[i].size()) +
                               " incident edges.");
        int prev = 0;
        int next = (adj[i][0] == prev) ? adj[i][1] : adj[i][0];
        prev = i;
        int it = 0;
        while (next != 0 && it < dim)
        {
            if (adj[next].size() != 2)
                throw recoverError("Customer " + std::to_string(next) + " has " + std::to_string(adj[next].size()) +
                                   " incident edges.");
            r.push_back(next);
            visited[next] = true;
            int aux = next;
            next = (adj[next][0] == prev) ? adj[next][1] : adj[next][0];
            prev = aux;
            ++it;
        }
        if (it == dim)
            throw recoverError("Some route can not be recovered because the return to depot is never reached");
        sol.routes.push_back(r);
    }
    for (int i = 1; i < dim; ++i)
        if (!visited[i])
            throw recoverError("At least one customer was not visited or there are subtours in the solution x.");
    sol.integerCost = !noround;
    sol.cost = noround ? objval : (double)(long long)std::llround(objval);
    return sol;
}

void checkSolutionX(const Data &data, const std::vector<double> &xval, double z, int minr, int maxr)
{
    const int n = data.n;
    const double tol = 1e-6;
    std::vector<int> xint(data.E.size());
    std::map<std::pair<int, int>, int> xof;
    for (std::size_t k = 0; k < data.E.size(); ++k)
    {
        auto [i, j] = data.E[k];
        double v = xval[k];
        std::string e = "(" + std::to_string(i) + ", " + std::to_string(j) + ")";
        if (std::abs(v - std::round(v)) > tol)
            throw std::runtime_error("x[" + e + "] = " + juliaFloat(v) + " is not integer");
        int ub = (i == 0) ? 2 : 1;
        if (std::round(v) < 0 || std::round(v) > ub)
            throw std::runtime_error("x[" + e + "] = " + juliaFloat(v) + " is not in {0, ..., " + std::to_string(ub) + "}");
        xint[k] = (int)std::round(v);
        xof[{i, j}] = xint[k];
    }
    std::vector<int> degree(n + 1, 0);
    for (std::size_t k = 0; k < data.E.size(); ++k)
    {
        auto [i, j] = data.E[k];
        if (i > 0) degree[i] += xint[k];
        degree[j] += xint[k];
    }
    for (int i = 1; i <= n; ++i)
        if (degree[i] != 2)
            throw std::runtime_error("Customer " + std::to_string(i) + " has degree " + std::to_string(degree[i]) + ", not 2");
    // routes = connected components of the customers through the edges between customers
    std::vector<int> parent(n + 1);
    for (int i = 0; i <= n; ++i) parent[i] = i;
    std::function<int(int)> find = [&](int i) { return parent[i] == i ? i : parent[i] = find(parent[i]); };
    for (std::size_t k = 0; k < data.E.size(); ++k)
    {
        auto [i, j] = data.E[k];
        if (xint[k] > 0 && i > 0) parent[find(i)] = find(j);
    }
    std::map<int, std::vector<int>> comps;
    for (int i = 1; i <= n; ++i) comps[find(i)].push_back(i);
    for (auto &[root, r] : comps)
    {
        int depotEdges = 0;
        double demand = 0.0;
        for (int i : r)
        {
            depotEdges += xof[{0, i}];
            demand += data.d[i];
        }
        if (depotEdges != 2)
            throw std::runtime_error("The customers of a route are linked to the depot by " + std::to_string(depotEdges) +
                                     " edges, not 2 (subtour)");
        if (demand > data.Q + tol)
            throw std::runtime_error("A route has demand " + juliaFloat(demand) + " > Q = " + juliaFloat(data.Q));
        if (data.D > 0)
        {
            std::vector<bool> in(n + 1, false);
            for (int i : r) in[i] = true;
            double len = 0.0;
            for (std::size_t k = 0; k < data.E.size(); ++k)
            {
                auto [i, j] = data.E[k];
                if ((in[i] || i == 0) && in[j]) len += data.c[i][j] * xint[k];
            }
            double dur = len + data.S * r.size();
            if (dur > data.D + tol)
                throw std::runtime_error("A route has duration " + juliaFloat(dur) + " > D = " + juliaFloat(data.D));
        }
    }
    int nroutes = (int)comps.size();
    if (nroutes < minr || nroutes > maxr)
        throw std::runtime_error("The solution has " + std::to_string(nroutes) + " routes, not in [" + std::to_string(minr) +
                                 ", " + std::to_string(maxr) + "]");
    double cost = 0.0;
    for (std::size_t k = 0; k < data.E.size(); ++k) cost += data.c[data.E[k].first][data.E[k].second] * xint[k];
    if (std::abs(cost - z) > 1e-6 * (std::max)(1.0, std::abs(z)))
        throw std::runtime_error("Cost calculated from x (" + juliaFloat(cost) + ") is different from the objective value (" +
                                 juliaFloat(z) + ")");
}

void checkSolution(const Data &data, const Solution &sol, int minr, int maxr)
{
    const int n = data.n;
    std::vector<int> visits(n + 1, 0);
    double sumCost = 0.0;
    for (std::size_t k = 0; k < sol.routes.size(); ++k)
    {
        const auto &r = sol.routes[k];
        std::string rid = "Route #" + std::to_string(k + 1);
        if (r.empty()) throw std::runtime_error(rid + " is empty");
        double demand = 0.0, len = 0.0;
        int prev = 0;
        for (int j : r)
        {
            if (j < 1 || j > n) throw std::runtime_error(rid + " visits " + std::to_string(j) + ", which is not a customer");
            if (++visits[j] > 1) throw std::runtime_error("Customer " + std::to_string(j) + " is visited more than once");
            len += data.c[prev][j];
            demand += data.d[j];
            prev = j;
        }
        len += data.c[prev][0];
        sumCost += len;
        if (demand > data.Q)
            throw std::runtime_error(rid + " is violating the capacity constraint. Sum of the demands is " +
                                     juliaFloat(demand) + " and Q is " + juliaFloat(data.Q));
        if (data.D > 0 && len + data.S * r.size() > data.D + 1e-6)
            throw std::runtime_error(rid + " has duration " + juliaFloat(len + data.S * r.size()) + " > D = " + juliaFloat(data.D));
    }
    std::string notVisited;
    for (int i = 1; i <= n; ++i)
        if (visits[i] == 0) notVisited += (notVisited.empty() ? "" : ", ") + std::to_string(i);
    if (!notVisited.empty()) throw std::runtime_error("The following customers were not visited: [" + notVisited + "]");
    int nroutes = (int)sol.routes.size();
    if (nroutes < minr || nroutes > maxr)
        throw std::runtime_error("The solution has " + std::to_string(nroutes) + " routes, not in [" + std::to_string(minr) +
                                 ", " + std::to_string(maxr) + "]");
    if (std::abs(sol.cost - sumCost) > 0.001)
        throw std::runtime_error("Cost calculated from the routes (" + juliaFloat(sumCost) +
                                 ") is different from that passed as argument (" + costString(sol) + ").");
}

static std::string lower(std::string s)
{
    for (char &ch : s) ch = (char)std::tolower((unsigned char)ch);
    return s;
}

Solution readSolution(const std::string &path, bool noround)
{
    std::ifstream in(path);
    if (!in) throw std::runtime_error("Cannot open the solution file " + path);
    std::stringstream ss;
    ss << in.rdbuf();
    std::string text = ss.str();
    for (char &ch : text)
        if (ch == ':' || ch == '\t' || ch == '\r' || ch == '\n') ch = ' ';
    std::istringstream ts(text);
    std::vector<std::string> aux;
    for (std::string tok; ts >> tok;) aux.push_back(tok);
    Solution sol;
    sol.integerCost = !noround;
    std::size_t j = 2; // skip "Route" and "#1"
    while (j < aux.size())
    {
        std::vector<int> r;
        while (j < aux.size())
        {
            r.push_back(std::stoi(aux[j]));
            ++j;
            if (j >= aux.size() || lower(aux[j]).find("cost") != std::string::npos ||
                lower(aux[j]).find("route") != std::string::npos)
                break;
        }
        sol.routes.push_back(r);
        if (j < aux.size() && lower(aux[j]).find("cost") != std::string::npos)
        {
            sol.cost = noround ? std::stod(aux[j + 1]) : (double)std::stoll(aux[j + 1]);
            return sol;
        }
        j += 2; // skip "Route" and "#j"
    }
    throw std::runtime_error("The solution file was not read successfully. The file must be in the CVRPLIB format.");
}

void writeSolution(const std::string &path, const Solution &sol)
{
    std::ofstream f(path);
    for (std::size_t k = 0; k < sol.routes.size(); ++k)
    {
        f << "Route #" << k + 1 << ": ";
        for (int j : sol.routes[k]) f << j << " ";
        f << "\n";
    }
    f << "Cost " << costString(sol) << "\n";
}

void printRoutes(const Solution &sol)
{
    for (std::size_t k = 0; k < sol.routes.size(); ++k)
    {
        std::cout << "Route #" << k + 1 << ": ";
        for (int j : sol.routes[k]) std::cout << j << " ";
        std::cout << "\n";
    }
}

void drawSolution(const std::string &path, const Data &data, const Solution &sol)
{
    static const char *colors[] = {"blue", "red!80!black", "green!50!black", "orange!90!black", "violet",
                                   "teal", "brown", "magenta", "olive", "cyan!60!black"}; // one colour per route
    std::ofstream f(path);
    f << "\\documentclass[crop,tikz]{standalone}\n\\begin{document}\n";
    double maxCoord = -INFINITY;
    for (int i = 0; i <= data.n; ++i) maxCoord = (std::max)({maxCoord, data.x[i], data.y[i]});
    double scale = 1 / (maxCoord / 10);
    f << "\\begin{tikzpicture}[thick, scale=1, every node/.style={scale=0.3}]\n";
    for (int i = 0; i <= data.n; ++i)
    {
        std::string xs = juliaFloat(scale * data.x[i]), ys = juliaFloat(scale * data.y[i]);
        if (i == 0)
            f << "\t\\node[draw, line width=0.1mm, rectangle, fill=yellow, inner sep=0.05cm, scale=1.4] (v0) at (" << xs
              << "," << ys << ") {\\footnotesize 0};\n";
        else
            f << "\t\\node[draw, line width=0.1mm, circle, fill=white, inner sep=0.05cm] (v" << i << ") at (" << xs << ","
              << ys << ") {\\footnotesize " << i << "};\n";
    }
    for (std::size_t k = 0; k < sol.routes.size(); ++k)
    {
        std::string col = colors[k % 10];
        int prev = 0;
        for (int i : sol.routes[k])
        {
            f << "\t\\draw[" << col << (prev == 0 ? ",-,line width=0.5pt" : ",-,line width=0.9pt") << "] (v" << prev
              << ") -- (v" << i << ");\n";
            prev = i;
        }
        f << "\t\\draw[" << col << ",-,line width=0.5pt] (v0) -- (v" << prev << ");\n";
    }
    f << "\\end{tikzpicture}\n\\end{document}\n";
}
} // namespace cvrp
