#ifndef CVRP_MODEL_H
#define CVRP_MODEL_H

#include <bcModelPointerC.hpp>

#include "App.h"
#include "Data.h"

namespace cvrp
{
/// The model of src/model.jl, built with the C++ interface of BaPCod as VrpSolver.jl builds it: one integer variable
/// per edge, degree 2 for each customer, one pricing graph with the capacity resource (and the duration resource when
/// the instance has a maximum route duration), rounded capacity cuts, rank-1 cuts, branching on the edges and on the
/// clusters of customers (option -B), and the edge cuts of option -e.
class Model : public BcModel
{
   public:
    /// ub: the solver looks for solutions of cost below it (set as by set_cutoff! of VrpSolver.jl)
    Model(const BcInitialisation &init, const Data &data, const App &app, double ub);
};
} // namespace cvrp

#endif
