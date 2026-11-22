# Upper bound of the VRPSolver model computed by GenericILS (NILS metaheuristic). GenericILS reads the VRPSolver model
# (graph, resources, variables of the arcs) and the C++ files of the custom resource (meta_solver), so the model is the
# only description of the problem and the heuristic uses exactly the resource of the BCP.
module Heuristic

using GenericILS, Random, HiGHS

"""
Run the heuristic on `model` for about `time` seconds and return the routes of the best feasible solution found, as lists
of customers (the ids of the model), or `nothing` if it found none.
"""
function solve(model; cppDir::String, time::Float64, seed::Int)
    h = heuristicModelFromVRPSolver(model; cppDir = cppDir)
    try
        algorithm = NILSAlgorithm(h.res;
            acceptCriteria = NILS.MetropolisTimed(100.0, 100.0, time, 2.0),
            stopCriteria = NILS.ByTemperature(0.0001),
            diversification = NILS.Diversification(outerShift = 4, outerSwap = 4, innerShift = 2, innerSwap = 2),
            innerIterMax = 5,
            timeLimitSP = min(60.0, time)
        )
        penaltyManager = TargetRatePenaltyManager(
            penaltyCustom = 100.0,
            penaltyCustomIncrease = 0.4,
            penaltyCustomDecrease = 0.2,
            penaltyStandard1 = 1.0,
            penaltyStandard1Increase = 0.4,
            penaltyStandard1Decrease = 0.2,
            penaltyStandard2 = 1.0,
            penaltyStandard2Increase = 0.4,
            penaltyStandard2Decrease = 0.2,
            targetFeasRate = 0.7,
            feasRateTolerance = 0.05,
            updatePeriod = 100
        )
        solver = Solver(
            res = h.res,
            data = h.data,
            neighborhoods = (
                TwoOptStar(),
                IntraShift(),
                InterShift{1}(),
                InterShift{2}(),
                InterSwap{1,1}(),
                InterSwap{2,1}(),
                InterSwap{2,2}()
            ),
            algorithm = algorithm,
            penaltyManager = penaltyManager,
            MIPSolver = HiGHS.Optimizer
        )
        setSeed!(solver, Random.MersenneTwister(seed))
        solve!(solver)
        solver.bestFeasSol.cost == Inf && return nothing
        return [[h.userIds[v+1] for v in r.visits[2:end-1]] for r in getBestRoutes(solver) if length(r.visits) > 2]
    finally
        freeCppResource!(h.res.customResource)
    end
end

end # module
