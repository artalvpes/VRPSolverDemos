cmake_minimum_required(VERSION 3.20)

# Standalone build against an installed BaPCod (BAPCOD_ROOT, see README.md); inside the BapcodFramework tree
# (Applications/), add_application() is already defined.
if (NOT COMMAND add_application)
    include("$ENV{BAPCOD_ROOT}/CMake/AddApplication.cmake")
endif ()

# CMAKE_DL_LIBS: dlopen, used to load the optional HGS-CVRP library at run time
add_application(CVRPDemo RCSP LIBRARIES ${CMAKE_DL_LIBS})
