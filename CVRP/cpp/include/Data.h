#ifndef CVRP_DATA_H
#define CVRP_DATA_H

#include <string>
#include <utility>
#include <vector>

namespace cvrp
{
/// A CVRPLIB instance, read as by src/data.jl: vertex 0 is the depot, vertices 1..n are the customers
struct Data
{
    std::string name;
    int n = 0;                 ///< number of customers
    double Q = 0.0;            ///< vehicle capacity
    double D = 0.0;            ///< maximum route duration (0: none)
    double S = 0.0;            ///< service time of each customer
    bool coord = false;        ///< the instance has coordinates
    bool round = true;         ///< distances rounded to the nearest integer
    std::vector<double> x, y;  ///< coordinates of the vertices
    std::vector<double> d;     ///< demands (d[0] = 0)
    std::vector<std::pair<int, int>> E;  ///< edges (i, j), i < j, in the order of data.jl
    std::vector<std::vector<double>> c;  ///< c[i][j] = distance

    bool read(const std::string &fileName, bool noround);
    double distance(int i, int j) const { return c[i][j]; }
    /// time of the edge (i, j), i < j: its distance plus the service times (S/2 at the depot, as in data.jl)
    double time(int i, int j) const { return c[i][j] + (i == 0 ? S / 2 : S); }
    int lowerBoundNbVehicles() const;
};
} // namespace cvrp

#endif
