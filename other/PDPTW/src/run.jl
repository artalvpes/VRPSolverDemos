if haskey(ENV, "JULIA_LOAD_PATH")
    println("Please unset the JULIA_LOAD_PATH environment variable.")
end
if !haskey(ENV, "BAPCOD_RCSP_LIB")
    println(
        "Please set the environment variable BAPCOD_RCSP_LIB to the complete file path of the BaPCod/RCSP library.",
    )
    println("Linux/MacOS: export BAPCOD_RCSP_LIB=/path/to/BaPCod_RCSP")
    println("Windows: set BAPCOD_RCSP_LIB=C:\\path\\to\\BaPCod_RCSP")
    exit(1)
end

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.add(url = "https://github.com/atoptima/Coluna.jl.git", rev = "master")
# Pkg.add(url = "https://github.com/atoptima/ColunaVrpSolver.jl.git", rev = "using_bapcod")
Pkg.instantiate()


using PDPTWSolverDemo

if isempty(ARGS)
    main(["--help"])
else
    main(ARGS)
end
