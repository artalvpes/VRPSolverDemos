cmake_minimum_required(VERSION 3.20)

# Standalone build against an installed BaPCod (BAPCOD_ROOT, see README.md); inside the BapcodFramework tree
# (Applications/), add_application() is already defined.
if (NOT COMMAND add_application)
    include("$ENV{BAPCOD_ROOT}/CMake/AddApplication.cmake")
endif ()

add_application(PwjTjDemo RCSP)
