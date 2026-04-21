/**
 * Customized Resource for BaPCod/RCSP implementing the Cumulative Cost Resource
 *
 * @author Artur Pessoa <arturpessoa@id.uff.br>,
 * @author Teobaldo Bulhoes <tbulhoes@ci.ufpb.br>,

 * Inria, France, All Rights Reserved. [LICENCE]
 */

#include <iostream>

#include "rcsp_custom_res_impl.hpp"
#include <algorithm>

namespace rcsp_custom_res
{

void CustomResParameters::setDimensions(int n, int m)
{
    t.resize(m);
    w.resize(m);
}

void CustomResParameters::setArcParameter(int a, const CustomResArcParameters &value)
{
    t[a] = value.t;
    w[a] = value.w;
}

void CustomResParameters::setVertexParameter(int v, const CustomResVertexParameters &value) {}

void CustomResParameters::setConstParameter(const CustomResConstParameters &value)
{
    Tmax = value.Tmax;
    Wmax = value.Wmax;
}

bool symmetric(const CustomResParameters &Rcc)
{
    return false;
}

void initState(const CustomResParameters &Rcc, ForwardState &state)
{
    state.S = 0.0;
    state.T = 0.0;
}

void initState(const CustomResParameters &Rcc, BackwardState &state)
{
    state.S = 0.0;
    state.W = 0.0;
}

double extendToVertex(const CustomResParameters &Rcc, ForwardState &state, int v)
{
    return 0.0;
}

double extendAlongArc(const CustomResParameters &Rcc, ForwardState &state, int a)
{
    state.S += Rcc.w[a] * (state.T + Rcc.t[a]);
    state.T += Rcc.t[a];
    return Rcc.w[a] * state.T;
}

double extendAlongArc(const CustomResParameters &Rcc, BackwardState &state, int a)
{
    state.S += (state.W + Rcc.w[a]) * Rcc.t[a];
    state.W += Rcc.w[a];
    return state.W * Rcc.t[a];
}

double extendToVertex(const CustomResParameters &Rcc, BackwardState &state, int a)
{
    return 0.0;
}

double dominationCost(const CustomResParameters &Rcc, int v, const ForwardState &dominating,
                      const ForwardState &dominated)
{
    return dominating.S - dominated.S + std::max(0.0, dominating.T - dominated.T) * Rcc.Wmax;
}

double dominationCost(const CustomResParameters &Rcc, int v, const BackwardState &dominating,
                      const BackwardState &dominated)
{
    return dominating.S - dominated.S + std::max(0.0, dominating.W - dominated.W) * Rcc.Tmax;
}

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const BackwardState &bwd)
{
    return fwd.T * bwd.W;
}

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const ForwardState &bwd)
{
    return 0.0;
}

bool isCostResource()
{
    return true;
}

} // namespace rcsp_custom_res
