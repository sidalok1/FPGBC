cmake_minimum_required(VERSION 3.25)
cmake_policy(SET CMP0144 NEW)
project(gbc_sim CXX)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
FetchContent_Declare(
    argparse
    GIT_REPOSITORY https://github.com/p-ranav/argparse.git
)
FetchContent_MakeAvailable(argparse)

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
add_executable(gbc_sim sim/main.cpp sim/cartridge.cpp)
# target_link_options(gbc_sim PRIVATE "-Wl,-rpath,/opt/gcc-16/lib64")
include_directories(include)

set(HDL_SOURCES
    src/System.v
)

verilate(gbc_sim
    SOURCES       ${HDL_SOURCES}
    VERILATOR_ARGS
        --x-assign fast --x-initial fast --no-assert
        -y "include"
        -y "roms" 
        -y "src"
        -y "src/APU_Channels"
        -y "src/CPU_core_submodules"
        # --threads 1
        -Wall
        -Werror-LATCH
        -Wno-EOFNEWLINE
        -Wno-UNUSED
        -Wno-UNSIGNED
        -Wno-PROCASSINIT
        -Wno-WIDTHTRUNC
        -Wno-TIMESCALEMOD
        --report-unoptflat
        # --prof-cfuncs
        # --prof-exec
        # --public
        # --trace-max-array 0
        # --trace-max-width 0
        # -CFLAGS "-ggdb -O3"
        -CFLAGS "-O3"
        # -DDEBUG
        # -CFLAGS "-D DEBUG -O3"
        # -LDFLAGS "-ggdb"
        # --valgrind
        # --gdb
        # --gdbbt
        # --runtime-debug
        # -no-decoration
    OPT_FAST      "-march=native -O3"
    TOP_MODULE    System
    # TRACE_FST
    PREFIX        Vgbc
)

include(CheckCXXCompilerFlag)
check_cxx_compiler_flag(-Wdeprecated-variadic-comma-omission COMMA_OMISSION)

if (COMMA_OMISSION)
    target_compile_options(gbc_sim PRIVATE -Wno-deprecated-variadic-comma-omission)
endif (COMMA_OMISSION)

# Target compile and link profiling options
# target_compile_options(gbc_sim PRIVATE -pg)
# target_link_options(gbc_sim PRIVATE -pg)

target_link_libraries(gbc_sim PRIVATE ${SDL3_TARGET})
target_link_libraries(gbc_sim PRIVATE argparse)
