/**
  * Resource Constrained Shortest Path Solver
  * Designed to be used by Branch-Cut-and-Price algorithms
  *
  * @author Artur Pessoa <arturpessoa@id.uff.br>,
  * @author Teobaldo Bulhoes <tbulhoes@ci.ufpb.br>,

  * Inria, France, All Rights Reserved. [LICENCE]
  */

#ifndef RCSP_CUSTOM_RES_IMPL_H_
#define RCSP_CUSTOM_RES_IMPL_H_

#include <vector>

namespace rcsp_custom_res {

struct CustomResArcParameters {
  double t;
  double w;

  CustomResArcParameters() { w = t = 0.0; }

  CustomResArcParameters(double w_, double t_) {
    w = w_;
    t = t_;
  }
};

struct CustomResVertexParameters {};

struct CustomResConstParameters {
  double Wmax;
  double Tmax;

  CustomResConstParameters(double w, double t) {
    Wmax = w;
    Tmax = t;
  }
  CustomResConstParameters() {
    Wmax = 0.0;
    Tmax = 0.0;
  }
};

struct CustomResParameters {
  std::vector<double> t;
  std::vector<double> w;
  double Wmax;
  double Tmax;

  void setDimensions(int n, int m);
  void setArcParameter(int a, const CustomResArcParameters &value);
  void setVertexParameter(int v, const CustomResVertexParameters &value);
  void setConstParameter(const CustomResConstParameters &value);
};

struct CustomResSolution {
  double totalTime;
  double totalWeight;

  CustomResSolution() : totalTime(0.0), totalWeight(0.0) {}
  CustomResSolution(double t, double w) : totalTime(t), totalWeight(w) {}

  int compare(const CustomResSolution &other) const {
    if (totalTime < other.totalTime - 1e-9)
      return -1;
    if (totalTime > other.totalTime + 1e-9)
      return 1;
    if (totalWeight < other.totalWeight - 1e-9)
      return -1;
    if (totalWeight > other.totalWeight + 1e-9)
      return 1;
    return 0;
  }
};

struct ForwardState {
  double S;
  double T;
};

struct BackwardState {
  double S;
  double W;
};

bool symmetric(const CustomResParameters &Rcc);

void initState(const CustomResParameters &Rcc, ForwardState &state);

void initState(const CustomResParameters &Rcc, BackwardState &state);

double extendToVertex(const CustomResParameters &Rcc, ForwardState &state,
                      int v);

double extendAlongArc(const CustomResParameters &Rcc, ForwardState &state,
                      int a);

double extendToVertex(const CustomResParameters &Rcc, BackwardState &state,
                      int v);

double extendAlongArc(const CustomResParameters &Rcc, BackwardState &state,
                      int a);

double dominationCost(const CustomResParameters &Rcc, int v,
                      const ForwardState &dominating,
                      const ForwardState &dominated);

double dominationCost(const CustomResParameters &Rcc, int v,
                      const BackwardState &dominating,
                      const BackwardState &dominated);

double concatenationCost(const CustomResParameters &Rcc, int v,
                         const ForwardState &fwd, const BackwardState &bwd);

double concatenationCost(const CustomResParameters &Rcc, int v,
                         const ForwardState &fwd, const ForwardState &bwd);

bool isCostResource();

CustomResSolution computeSolution(const CustomResParameters &Rcc,
                                  const std::vector<int> &arcIds,
                                  const ForwardState &fwd,
                                  const BackwardState &bwd,
                                  double originalCost);

} // namespace rcsp_custom_res

#endif // RCSP_CUSTOM_RES_IMPL_H_
