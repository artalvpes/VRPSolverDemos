#include "Data.h"

#include <fstream>
#include <sstream>
#include <stdexcept>

namespace pwjtj
{
void Data::read(const std::string &path)
{
    // instance file name format: wt{n}-{m}m-{inst}.txt
    std::string base = path.substr(path.find_last_of('/') + 1);
    std::size_t dot = base.find_last_of('.');
    name = dot == std::string::npos ? base : base.substr(0, dot);
    std::vector<std::string> parts;
    std::stringstream ss(name);
    for (std::string part; std::getline(ss, part, '-');) parts.push_back(part);
    if (parts.size() < 2 || parts[0].size() < 3 || parts[1].size() < 2)
        throw std::runtime_error("the instance file name must be wt{n}-{m}m-{k}: " + name);
    n = std::stoi(parts[0].substr(2));                     // "wt40" -> 40
    m = std::stoi(parts[1].substr(0, parts[1].size() - 1)); // "2m" -> 2

    std::ifstream in(path);
    if (!in) throw std::runtime_error("cannot open the instance " + path);
    std::string line;
    std::getline(in, line); // first line is n (discarded; n is read from the file name)
    std::vector<std::vector<int>> rows(3);
    for (auto &row : rows)
    {
        if (!std::getline(in, line)) throw std::runtime_error("missing line in the instance " + path);
        std::istringstream ls(line);
        for (int v; ls >> v;) row.push_back(v);
        if ((int)row.size() < n) throw std::runtime_error("less than n values in a line of the instance " + path);
    }
    jobs.assign(n + 1, Job());
    for (int i = 1; i <= n; ++i) jobs[i] = Job{rows[0][i - 1], rows[1][i - 1], rows[2][i - 1]};

    int psum = 0, pmax = 0;
    for (int i = 1; i <= n; ++i)
    {
        psum += jobs[i].p;
        pmax = std::max(pmax, jobs[i].p);
    }
    // time horizon: no idle times between jobs, idle only at the end if needed
    T = m == 1 ? psum : (psum - pmax) / m + pmax;
}
} // namespace pwjtj
