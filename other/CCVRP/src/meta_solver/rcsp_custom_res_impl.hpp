/**
 * Customized Resource for BaPCod/RCSP implementing the Cumulative Cost Resource
 *
 * @author Artur Pessoa <arturpessoa@id.uff.br>,
 * @author Teobaldo Bulhoes <tbulhoes@ci.ufpb.br>,

 * Inria, France, All Rights Reserved. [LICENCE]
 */

#ifndef RCSP_CUSTOM_RES_IMPL_H_
#define RCSP_CUSTOM_RES_IMPL_H_

#include <vector>

namespace rcsp_custom_res
{

struct CustomResArcParameters
{
    double t;
    double w;

    CustomResArcParameters() { w = t = 0.0; }

    CustomResArcParameters(double w_, double t_)
    {
        w = w_;
        t = t_;
    }
};

struct CustomResVertexParameters
{
};

struct CustomResConstParameters
{
    double Wmax;
    double Tmax;

    CustomResConstParameters(double w, double t)
    {
        Wmax = w;
        Tmax = t;
    }
    CustomResConstParameters()
    {
        Wmax = 0.0;
        Tmax = 0.0;
    }
};

struct CustomResParameters
{
    std::vector<double> t;
    std::vector<double> w;
    double Wmax;
    double Tmax;

    void setDimensions(int n, int m);
    void setArcParameter(int a, const CustomResArcParameters &value);
    void setVertexParameter(int v, const CustomResVertexParameters &value);
    void setConstParameter(const CustomResConstParameters &value);
};

struct ForwardState
{
    double S;
    double T;
};

struct BackwardState
{
    double S;
    double W;
};

bool symmetric(const CustomResParameters &Rcc);

void initState(const CustomResParameters &Rcc, ForwardState &state);

void initState(const CustomResParameters &Rcc, BackwardState &state);

double extendToVertex(const CustomResParameters &Rcc, ForwardState &state, int v);

double extendAlongArc(const CustomResParameters &Rcc, ForwardState &state, int a);

double extendToVertex(const CustomResParameters &Rcc, BackwardState &state, int v);

double extendAlongArc(const CustomResParameters &Rcc, BackwardState &state, int a);

double dominationCost(const CustomResParameters &Rcc, int v, const ForwardState &dominating,
                      const ForwardState &dominated);

double dominationCost(const CustomResParameters &Rcc, int v, const BackwardState &dominating,
                      const BackwardState &dominated);

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const BackwardState &bwd);

double concatenationCost(const CustomResParameters &Rcc, int v, const ForwardState &fwd,
                         const ForwardState &bwd);

bool isCostResource();

} // namespace rcsp_custom_res

#endif // RCSP_CUSTOM_RES_IMPL_H_
