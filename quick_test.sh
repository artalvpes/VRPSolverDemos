#!/bin/bash
# Quick test of all the demos: one instance per demo, each solved in a few seconds (plus the start of Julia), with the
# upper bound of its batch (optimum + 1, or + 0.1). Run from the root of VRPSolverDemos:
#
#   bash quick_test.sh                                   # all the demos except CCVRP
#   CCVRP_LIB=<path>/libbapcod-shared.so bash quick_test.sh   # also CCVRP, with a library built with its custom resource
#
# BAPCOD_RCSP_LIB must be set to the VRPSolver library. The output of each demo goes to <demo>/out/quick_test.out;
# a summary is printed at the end (optimal or not, the cost found and the elapsed time). The script returns 1 if a demo
# fails or does not reach the optimum.

cd "$(dirname "$0")"
results=()
failed=0

run() { # run <demo folder> <arguments of src/run.jl>
    local demo=$1; shift
    if [ ! -d "$demo" ]; then
        results+=("$(printf '%-7s skipped (no %s folder in this branch)' "$demo" "$demo")"); return
    fi
    mkdir -p "$demo/out"
    echo "== $demo: julia src/run.jl $*"
    local t0=$SECONDS
    (cd "$demo" && julia src/run.jl "$@" &> out/quick_test.out)
    local time=$((SECONDS - t0))
    local out="$demo/out/quick_test.out"
    # statistics line: instance & optimal & cutoff & root DB & root time & nodes & best DB & best solution & time
    local st=$(grep -h '^statistics:' "$out" | tail -1)
    local stat=$(echo "$st" | cut -d'&' -f2 | tr -d ' ')
    local cost=$(echo "$st" | cut -d'&' -f8 | tr -d ' ')
    # PDPTW (Ropke) solves one problem per fleet size: its last statistics line is the run that proves that one vehicle
    # less is infeasible, without a solution; the cost is then taken from the printed solution
    [ "$cost" = "--" ] && cost=$(grep -h '^Cost' "$out" | tail -1 | awk '{printf "%.2f", $2}')
    if [ "$stat" = "1" ] && [ -n "$cost" ] && [ "$cost" != "--" ] && ! grep -q 'ERROR:' "$out"; then
        results+=("$(printf '%-7s optimal  cost %-10s %4d s (with the start of Julia)' "$demo" "$cost" "$time")")
    else
        results+=("$(printf '%-7s FAILED (see %s)' "$demo" "$out")"); failed=1
    fi
}

# day 1 of the course
run CVRP   data/A/A-n55-k9.vrp -m 9 -M 9 -u 1074
run VRPTW  data/200/C1_2_6.TXT -u 2695 --cfg config/VRPTW_set_1.cfg
run VSBPP  data/test/zc_K5_n50_u2_s1.txt -u 63149
run GAP    data/Nauss/gapD-25-90-e5.txt -u 5622 --cfg config/GAP_Nauss.cfg
# day 2
run PDPTW  data/Ropke/AA40.txt -m 1 -M 3 -u 31516.0 --fixed 10000
run TOP    data/p4.4.i.txt --cfg config/TOP.cfg -u -656
run P_wjTj instances/WT40-10m/wt40-10m-21.txt -u 12061
run VRPL   data/VRPDA/s10k20_5.vdap
run CRSP   data/A/A-n32-k5.vrp -p 25 -k 3 -a 0.5
# day 3: CCVRP needs a library built with its custom resource (see CCVRP/README.md)
if [ -n "$CCVRP_LIB" ]; then
    default_lib=$BAPCOD_RCSP_LIB
    export BAPCOD_RCSP_LIB="$CCVRP_LIB"
    run CCVRP data/B/B-n38-k6.vrp -m 6 -M 6 -u 28509
    export BAPCOD_RCSP_LIB="$default_lib"
else
    results+=("$(printf '%-7s skipped (set CCVRP_LIB to a library built with its custom resource)' CCVRP)")
fi

echo
echo "Summary:"
printf '%s\n' "${results[@]}"
exit $failed
