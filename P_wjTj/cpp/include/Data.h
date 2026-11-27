#ifndef PWJTJ_DATA_H
#define PWJTJ_DATA_H

#include <algorithm>
#include <string>
#include <vector>

namespace pwjtj
{
struct Job
{
    int p = 0; ///< processing time
    int w = 0; ///< weight
    int d = 0; ///< due date
};

/// The instance (src/data.jl): jobs 1..n (jobs[0] is not used), m machines, time horizon T
struct Data
{
    std::string name;
    int n = 0;
    int m = 0;
    std::vector<Job> jobs;
    int T = 0;

    /// Weighted tardiness cost of job j completing at time t
    long jobCost(int j, int t) const { return std::max(0L, (long)jobs[j].w * (t - jobs[j].d)); }
    /// readPwjTjData of data.jl: n and m come from the file name wt{n}-{m}m-{k}
    void read(const std::string &path);
};
} // namespace pwjtj

#endif
