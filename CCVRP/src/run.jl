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
# A file is copied only when its content differs, and it gets the current modification time (not the one of the
# demo file), so that make always sees the change: with cp -p, an old time could leave the library built with
# another implementation (e.g. the unimplemented template shipped with the library)
for (file, dir) in [("rcsp_custom_res_impl.hpp", "include_dev"), ("rcsp_custom_res_impl.cpp", "src")]
    src = joinpath("src", "meta_solver", file)
    dst = joinpath(bapcod_root, "Tools", "rcsp", dir, file)
    if !isfile(dst) || read(src) != read(dst)
        cp(src, dst; force=true)
        touch(dst)
    end
end
base_dir = pwd()
cd(build_path)
run(`make -j4 bapcod-shared`)
cd(base_dir)

# Load the VrpSolver package
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
if !haskey(Pkg.project().dependencies, "VrpSolver") || !isnothing(findfirst(isequal("--update"), ARGS))
    Pkg.add(url="https://github.com/tbulhoes/VrpSolver.jl", rev="update_rcsp_interface")
    Pkg.instantiate()
end

# Load the application module
using CCVRPSolverDemo

# Run the application
if isempty(ARGS)
    main(["--help"])
else
    main(ARGS)
end
