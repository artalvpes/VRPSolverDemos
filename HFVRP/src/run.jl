if haskey(ENV, "JULIA_LOAD_PATH")
    println("Please unset the JULIA_LOAD_PATH environment variable.")
    exit()
end
if !haskey(ENV, "BAPCOD_RCSP_LIB")
    println(
        "Please set the environment variable BAPCOD_RCSP_LIB to the complete file path of the BaPCod/RCSP library.",
    )
    println("Linux/MacOS: export BAPCOD_RCSP_LIB=/path/to/BaPCod_RCSP")
    println("Windows: set BAPCOD_RCSP_LIB=C:\\path\\to\\BaPCod_RCSP")
    exit(1)
end

# Copy the custom resource implementation files to the BaPCod/RCSP library and compile it
build_path = splitdir(splitdir(ENV["BAPCOD_RCSP_LIB"])[1])[1]
bapcod_root = splitdir(build_path)[1]
run(`cp src/meta_solver/rcsp_custom_res_impl.hpp $bapcod_root/Tools/rcsp/include_dev`)
run(`cp src/meta_solver/rcsp_custom_res_impl.cpp $bapcod_root/Tools/rcsp/src`)
base_dir = pwd()
cd(build_path)
run(`make -j4 bapcod-shared`)
cd(base_dir)

# Load the VrpSolver and GenericILS packages. GenericILS computes the upper bound given to the VRPSolver; it reads the
# model and compiles the same C++ files (src/meta_solver) with the C++ compiler of the system (CXX, g++, clang++ or c++).
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
update = !isnothing(findfirst(isequal("--update"), ARGS))
if !haskey(Pkg.project().dependencies, "VrpSolver") || update
    Pkg.add(url="https://github.com/tbulhoes/VrpSolver.jl", rev="update_rcsp_interface")
    Pkg.instantiate()
end
if !haskey(Pkg.project().dependencies, "GenericILS") || update
    Pkg.add(url="https://github.com/brunomattos1/GenericILS", rev="main")
    Pkg.instantiate()
end

# Load the application module
using HFVRPSolverDemo

# Run the application
if isempty(ARGS)
    main(["--help"])
else
    main(ARGS)
end
