cmake_minimum_required(VERSION 3.20)
cmake_policy(SET CMP0144 NEW)
project(gbc_sim CXX)

set(CMAKE_CXX_STANDARD 17)


# ---------------------------------------------------------------------------
# Find Verilator
# ---------------------------------------------------------------------------
find_package(verilator HINTS $ENV{VERILATOR_ROOT} /usr/share/verilator)
if (NOT verilator_FOUND)
    message(FATAL_ERROR
        "Verilator not found. Install it with:\n"
        "  sudo apt install verilator\n"
        "or set VERILATOR_ROOT to your install prefix.")
endif()

# ---------------------------------------------------------------------------
# Find SDL3
# ---------------------------------------------------------------------------
find_package(SDL3 QUIET)
if (NOT SDL3_FOUND)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(SDL3 REQUIRED IMPORTED_TARGET sdl3)
    set(SDL3_TARGET PkgConfig::SDL3)
else()
    set(SDL3_TARGET SDL3::SDL3)
endif()

# ---------------------------------------------------------------------------
# Verilate the RTL and create a simulation executable
# ---------------------------------------------------------------------------
add_executable(gbc_sim sim/main.cpp)

set(HDL_SOURCES
    src/System.v
    src/MBC.v
    src/SoC.v
    src/ClockDivider.v
    src/PPU.v
    src/MAC.v
    src/Core.v
    src/ControlUnit.v
    src/ALU.v
    src/RegisterFile.v
    src/IDU.v
    src/CondCheck.v
    src/PriorityEncoder.v
    src/PriorityEncoder5.v
    src/PriorityEncoder10.v
)

verilate(gbc_sim
    SOURCES       ${HDL_SOURCES}
    VERILATOR_ARGS
        -O3 --x-assign fast --x-initial fast --no-assert
        -y "include"
        -y "roms" 
        -Wall 
        -Wno-EOFNEWLINE
        -Wno-UNUSED
        -Wno-UNSIGNED
        -Wno-PROCASSINIT
        -Wno-WIDTHTRUNC
        --report-unoptflat
        --prof-cfuncs
        # --prof-exec
    OPT_FAST      "-O3 -march=native"
    TOP_MODULE    System
    TRACE_FST
    PREFIX        Vgbc
)
# Target compile and link profiling options
target_compile_options(gbc_sim PRIVATE -pg)
target_link_options(gbc_sim PRIVATE -pg)

target_link_libraries(gbc_sim PRIVATE ${SDL3_TARGET})