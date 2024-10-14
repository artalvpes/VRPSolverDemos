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

using CVRPSolverDemo

if isempty(ARGS)
    main(["--help"])
else
    main(ARGS)
end
