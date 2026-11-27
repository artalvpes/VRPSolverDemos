#include "Data.h"

#include <cmath>
#include <fstream>
#include <iostream>
#include <sstream>

namespace cvrp
{
bool Data::read(const std::string &fileName, bool noround)
{
    std::ifstream in(fileName);
    if (!in)
    {
        std::cerr << "Cannot open the instance file " << fileName << std::endl;
        return false;
    }
    std::string base = fileName.substr(fileName.find_last_of("/\\") + 1);
    name = base.substr(0, base.find('.'));
    round = !noround;
    // tokens separated by spaces, ':' and line breaks (and the other control characters)
    std::stringstream ss;
    ss << in.rdbuf();
    std::string text = ss.str();
    for (char &ch : text)
        if (ch == ':' || (unsigned char)ch <= 32) ch = ' ';
    std::istringstream ts(text);
    std::vector<std::string> aux;
    for (std::string tok; ts >> tok;) aux.push_back(tok);

    int dim = 0;
    auto has = [](const std::string &tok, const char *key) { return tok.find(key) != std::string::npos; };
    for (std::size_t i = 0; i < aux.size(); ++i)
    {
        if (has(aux[i], "DIMENSION")) dim = std::stoi(aux[i + 1]);
        else if (has(aux[i], "CAPACITY")) Q = std::stod(aux[i + 1]);
        else if (has(aux[i], "DISTANCE")) D = std::stod(aux[i + 1]);
        else if (has(aux[i], "SERVICE_TIME")) S = std::stod(aux[i + 1]);
        else if (has(aux[i], "NODE_COORD_SECTION"))
        {
            coord = true;
            for (std::size_t j = i + 1; aux[j] != "DEMAND_SECTION"; j += 3)
            {
                x.push_back(std::stod(aux[j + 1]));
                y.push_back(std::stod(aux[j + 2]));
            }
        }
        else if (has(aux[i], "DEMAND_SECTION"))
        {
            d.assign(x.size(), 0.0);
            for (std::size_t j = i + 1; aux[j] != "DEPOT_SECTION"; j += 2)
                d[std::stoi(aux[j]) - 1] = std::stod(aux[j + 1]);
            break;
        }
    }
    if (!coord || x.empty() || d.size() != x.size() || Q <= 0)
    {
        std::cerr << "The file " << fileName << " is not a CVRPLIB instance with coordinates" << std::endl;
        return false;
    }
    (void)dim;
    n = (int)x.size() - 1;
    c.assign(n + 1, std::vector<double>(n + 1, 0.0));
    for (int i = 0; i <= n; ++i)
        for (int j = 0; j <= n; ++j)
        {
            double dist = std::sqrt((x[j] - x[i]) * (x[j] - x[i]) + (y[j] - y[i]) * (y[j] - y[i]));
            c[i][j] = round ? std::floor(dist + 0.5) : dist;
        }
    // E = {{i,j} : i < j}, in the order of data.jl: for each customer i, the edge (0, i), then the edges (i, j), j > i
    for (int i = 1; i <= n; ++i)
    {
        E.emplace_back(0, i);
        for (int j = i + 1; j <= n; ++j) E.emplace_back(i, j);
    }
    return true;
}

int Data::lowerBoundNbVehicles() const
{
    double sum = 0.0;
    for (double di : d) sum += di;
    return (int)std::ceil(sum / Q);
}
} // namespace cvrp
