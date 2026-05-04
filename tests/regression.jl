#!/usr/bin/env julia

using Pkg
using TOML

# Repository root:
#   VRPSolverDemos/
#     tests/regression.jl
#     tests/cases.toml
#     CVRP/
#     GAP/
#     ...
const ROOT = abspath(joinpath(@__DIR__, ".."))
const CASES_FILE = joinpath(@__DIR__, "cases.toml")

const VRPSOLVER_DEV_PATH = expanduser("~/.julia/dev/VrpSolver.jl")
const VRPSOLVER_REPO_URL = "https://github.com/tbulhoes/VrpSolver.jl"

const GREEN = "\033[32m"
const RED = "\033[31m"
const YELLOW = "\033[33m"
const RESET = "\033[0m"

struct TestResult
    name::String
    demo::String
    ok::Bool
    optimal::Union{Int, Nothing}
    expected_optimal::Union{Int, Nothing}
    value::Union{Float64, Nothing}
    optimum::Union{Float64, Nothing}
    tol::Union{Float64, Nothing}
    error_message::Union{String, Nothing}
end

function print_help()
    println("""
VRPSolverDemos regression runner

Usage:
  julia tests/regression.jl --source dev [--demo DEMO]
  julia tests/regression.jl --source <branch-name> [--demo DEMO]
  julia tests/regression.jl -h
  julia tests/regression.jl --help

Arguments:
  --source dev
      Use the local development checkout:
        $VRPSOLVER_DEV_PATH

  --source <branch-name>
      Use VrpSolver.jl from GitHub with the given branch:
        $VRPSOLVER_REPO_URL#<branch-name>

      Example:
        julia tests/regression.jl --source update_rcsp_interface

  --demo DEMO
      Optional. Run only cases whose 'demo' field in tests/cases.toml
      matches DEMO.

      Example:
        julia tests/regression.jl --source dev --demo CVRP

Environment:
  BAPCOD_RCSP_LIB must be set before running the tests.

      Example:
        export BAPCOD_RCSP_LIB=/path/to/BaPCod_RCSP

Cases file:
  Cases are read from:
    $CASES_FILE

Adding a case:
  Add a [[case]] block to tests/cases.toml.

  Example:
    [[case]]
    name = "CVRP-A-n37-k6"
    demo = "CVRP"
    cmd = ["src/run.jl", "data/A/A-n37-k6.vrp", "-m", "6", "-M", "6", "-u", "950"]
    optimum = 949
    optimal = 1
    tol = 1e-6

Fields:
  name
      Human-readable test name.

  demo
      Demo directory under VRPSolverDemos, e.g., CVRP, GAP, VRPTW, PDPTW.

  cmd
      Command arguments relative to the demo directory.
      The first entry is usually "src/run.jl".

  optimum
      Expected objective value.

  optimal
      Expected value of the Optimal flag. Optional; defaults to 1.

  tol
      Absolute tolerance. Optional; defaults to 1e-6.

Important:
  Do not put "--update" in cmd. The demo run.jl files use "--update"
  to force a specific VrpSolver.jl branch, which would override --source.

What the runner checks:
  It parses the demo output lines:

    statistics_cols: ...
    statistics: ...

  It selects all statistics rows with Optimal == 1 and returns the minimum
  numeric bcRecBestInc among them. This handles demos that print multiple
  statistics rows, such as PDPTW.
""")
end

function parse_args()
    source = nothing
    demo_filter = nothing

    if isempty(ARGS)
        print_help()
        exit(0)
    end

    i = 1
    while i <= length(ARGS)
        arg = ARGS[i]

        if arg == "-h" || arg == "--help"
            print_help()
            exit(0)

        elseif arg == "--source"
            if i == length(ARGS)
                error("Missing value after --source. Use --source dev or --source <branch-name>.")
            end
            source = ARGS[i + 1]
            i += 2

        elseif arg == "--demo"
            if i == length(ARGS)
                error("Missing value after --demo. Example: --demo CVRP.")
            end
            demo_filter = ARGS[i + 1]
            i += 2

        else
            error("Unknown argument: $arg. Use --help for usage.")
        end
    end

    if source === nothing
        error("Missing --source. Use: julia tests/regression.jl --source dev OR --source <branch-name>")
    end

    return source, demo_filter
end

function print_source(source::String)
    if source == "dev"
        println("Source: local dev")
        println("Path:   $VRPSOLVER_DEV_PATH")
    else
        println("Source: GitHub branch")
        println("Repo:   $VRPSOLVER_REPO_URL")
        println("Branch: $source")
    end
end

function check_global_environment()
    if !haskey(ENV, "BAPCOD_RCSP_LIB")
        error(
            "BAPCOD_RCSP_LIB is not set. Set it before running the tests, e.g. " *
            "export BAPCOD_RCSP_LIB=/path/to/BaPCod_RCSP"
        )
    end
end

function assert_vrpsolver_source(tmp_demo_dir::String, source::String)
    manifest_file = joinpath(tmp_demo_dir, "Manifest.toml")

    if !isfile(manifest_file)
        error("Manifest.toml not found in temporary demo directory: $tmp_demo_dir")
    end

    manifest_text = read(manifest_file, String)

    if source == "dev"
        dev_path = abspath(VRPSOLVER_DEV_PATH)

        if !occursin(dev_path, manifest_text) && !occursin(VRPSOLVER_DEV_PATH, manifest_text)
            error(
                "VrpSolver source check failed. Expected local dev path:\n" *
                "  $VRPSOLVER_DEV_PATH\n" *
                "but it was not found in:\n" *
                "  $manifest_file"
            )
        end
    else
        expected_repo = VRPSOLVER_REPO_URL
        expected_rev = "repo-rev = \"$source\""

        if !occursin(expected_repo, manifest_text) || !occursin(expected_rev, manifest_text)
            error(
                "VrpSolver source check failed. Expected GitHub repo/rev:\n" *
                "  repo = $expected_repo\n" *
                "  rev  = $source\n" *
                "but this was not found in:\n" *
                "  $manifest_file"
            )
        end
    end
end

function prepare_temp_env(demo_dir::String, source::String)
    tmp_root = mktempdir()
    tmp_demo_dir = joinpath(tmp_root, basename(demo_dir))

    # Copy the whole demo because demo run.jl files activate their own parent
    # directory via Pkg.activate(joinpath(@__DIR__, "..")).
    cp(demo_dir, tmp_demo_dir; force=true)

    if source == "dev"
        if !isdir(VRPSOLVER_DEV_PATH)
            error("Dev path not found: $VRPSOLVER_DEV_PATH")
        end

        println("Using local VrpSolver.jl:")
        println("  $VRPSOLVER_DEV_PATH")

        Pkg.activate(tmp_demo_dir; io=devnull)
        Pkg.develop(PackageSpec(path=VRPSOLVER_DEV_PATH); io=devnull)
        Pkg.instantiate(; io=devnull)
    else
        branch = source

        println("Using VrpSolver.jl from GitHub:")
        println("  repo   = $VRPSOLVER_REPO_URL")
        println("  branch = $branch")

        Pkg.activate(tmp_demo_dir; io=devnull)
        Pkg.add(PackageSpec(url=VRPSOLVER_REPO_URL, rev=branch); io=devnull)
        Pkg.instantiate(; io=devnull)
    end

    println("Resolved VrpSolver.jl:")
    Pkg.status("VrpSolver"; mode=Pkg.PKGMODE_MANIFEST)
    println()

    # Fail early if the temporary Manifest does not point to the requested source.
    assert_vrpsolver_source(tmp_demo_dir, source)

    return tmp_demo_dir
end

function ensure_no_forbidden_args(case_name::String, cmd_parts::Vector{String})
    if any(==("--update"), cmd_parts)
        error(
            "Case $case_name contains --update in cmd. " *
            "This is forbidden because demo run.jl files may force a fixed " *
            "VrpSolver.jl branch when --update is present, overriding --source."
        )
    end
end

function extract_statistics(output::String)
    cols_line = nothing
    best_value = nothing

    for line in split(output, '\n')
        line = strip(line)

        if startswith(line, "statistics_cols:")
            cols_line = line
            continue
        end

        if startswith(line, "statistics:")
            if cols_line === nothing
                error("Found statistics line before statistics_cols line.")
            end

            cols_text = replace(cols_line, r"^statistics_cols:\s*" => "")
            cols_text = replace(cols_text, raw"\\" => "")
            cols = strip.(split(cols_text, "&"))

            # Example: ':Optimal' becomes 'Optimal'.
            cols = [replace(c, r"^:" => "") for c in cols]

            stats_text = replace(line, r"^statistics:\s*" => "")
            stats_text = replace(stats_text, raw"\\" => "")
            vals = strip.(split(stats_text, "&"))

            function get_col(colname::String)
                idx = findfirst(==(colname), cols)

                if idx === nothing
                    error("Could not find column $colname in statistics_cols. Columns found: $(join(cols, ", "))")
                end

                if idx > length(vals)
                    error("Column $colname has index $idx, but statistics line has only $(length(vals)) values.")
                end

                return vals[idx]
            end

            optimal_str = get_col("Optimal")

            # Ignore malformed/non-final rows defensively.
            optimal = try
                parse(Int, optimal_str)
            catch
                continue
            end

            if optimal != 1
                continue
            end

            value_str = get_col("bcRecBestInc")

            # Some rows may contain '--' instead of a numeric incumbent.
            value = try
                parse(Float64, value_str)
            catch
                continue
            end

            if best_value === nothing || value < best_value
                best_value = value
            end
        end
    end

    if best_value === nothing
        error("Could not find any statistics line with Optimal == 1 and numeric bcRecBestInc.")
    end

    return 1, best_value
end

function run_demo_command(command::Cmd, workdir::String)
    env = copy(ENV)

    # Demo run.jl files explicitly reject JULIA_LOAD_PATH.
    pop!(env, "JULIA_LOAD_PATH", nothing)

    buffer = PipeBuffer()

    proc = cd(workdir) do
        run(pipeline(setenv(command, env), stdout=buffer, stderr=buffer); wait=false)
    end

    wait(proc)

    output = String(take!(buffer))

    if !success(proc)
        error(
            "Demo command failed with exit code $(proc.exitcode).\n\n" *
            "Command:\n$command\n\n" *
            "Output:\n$output"
        )
    end

    return output
end

function print_test_result(result::TestResult)
    if result.ok
        println(
            "$(GREEN)PASS$(RESET): $(result.name) | " *
            "demo = $(result.demo) | " *
            "optimal = $(result.optimal) | " *
            "value = $(result.value) | " *
            "optimum = $(result.optimum) | " *
            "tol = $(result.tol)"
        )
    else
        if result.error_message === nothing
            println(
                "$(RED)FAIL$(RESET): $(result.name) | " *
                "demo = $(result.demo) | " *
                "optimal = $(result.optimal) | " *
                "expected_optimal = $(result.expected_optimal) | " *
                "value = $(result.value) | " *
                "optimum = $(result.optimum) | " *
                "tol = $(result.tol)"
            )
        else
            println(
                "$(RED)ERROR$(RESET): $(result.name) | " *
                "demo = $(result.demo) | " *
                "$(result.error_message)"
            )
        end
    end
end

function run_case(case, source::String)
    name = case["name"]
    demo = case["demo"]

    demo_dir = joinpath(ROOT, demo)

    if !isdir(demo_dir)
        error("Demo directory not found: $demo_dir")
    end

    tmp_demo_dir = prepare_temp_env(demo_dir, source)

    cmd_parts = String.(case["cmd"])

    if isempty(cmd_parts)
        error("Empty cmd field for case: $name")
    end

    ensure_no_forbidden_args(name, cmd_parts)

    script_relpath = cmd_parts[1]
    script_args = cmd_parts[2:end]

    script = joinpath(tmp_demo_dir, script_relpath)

    if !isfile(script)
        error("Script not found: $script")
    end

    command = `$(Base.julia_cmd()) --startup-file=no --project=$tmp_demo_dir $script $(script_args)`

    println("Running case: $name")
    println("Demo: $demo")
    println("Temporary demo directory: $tmp_demo_dir")
    println("Command: $command")
    println()

    output = run_demo_command(command, tmp_demo_dir)

    optimal, value = extract_statistics(output)

    expected_optimal = Int(get(case, "optimal", 1))
    optimum = Float64(case["optimum"])
    tol = Float64(get(case, "tol", 1e-6))

    ok = (optimal == expected_optimal) && (abs(value - optimum) <= tol + 1e-9)

    result = TestResult(
        name,
        demo,
        ok,
        optimal,
        expected_optimal,
        value,
        optimum,
        tol,
        nothing,
    )

    print_test_result(result)

    return result
end

function load_cases(demo_filter)
    if !isfile(CASES_FILE)
        error("Cases file not found: $CASES_FILE")
    end

    cases_data = TOML.parsefile(CASES_FILE)

    if !haskey(cases_data, "case")
        error("No [[case]] entries found in $CASES_FILE")
    end

    cases = cases_data["case"]

    if demo_filter !== nothing
        cases = [case for case in cases if get(case, "demo", "") == demo_filter]

        if isempty(cases)
            error("No cases found for demo: $demo_filter")
        end
    end

    return cases
end

function main()
    source, demo_filter = parse_args()

    check_global_environment()

    cases = load_cases(demo_filter)

    println("Running regression tests")
    print_source(source)
    println()

    if demo_filter !== nothing
        println("Demo filter: $demo_filter")
        println()
    end

    results = TestResult[]

    for case in cases
        println("="^80)

        result = try
            run_case(case, source)
        catch err
            case_name = haskey(case, "name") ? case["name"] : "<unnamed case>"
            demo_name = haskey(case, "demo") ? case["demo"] : "<unknown demo>"

            result = TestResult(
                case_name,
                demo_name,
                false,
                nothing,
                nothing,
                nothing,
                nothing,
                nothing,
                sprint(showerror, err),
            )

            print_test_result(result)

            result
        end

        push!(results, result)
    end

    n_pass = count(r -> r.ok, results)
    n_fail = length(results) - n_pass

    println("="^80)
    println("Final test results:")
    println()

    for result in results
        print_test_result(result)
    end

    println("="^80)
    println("Passed: $n_pass")
    println("Failed: $n_fail")

    if n_fail == 0
        println("$(GREEN)All tests passed$(RESET)")
        exit(0)
    else
        println("$(RED)Some tests failed$(RESET)")
        exit(1)
    end
end

main()