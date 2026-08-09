set default-list := true
BUILD_DIR := "build"
BUILD_TYPE := "Release"
OUTPUT_DIR := "./_out"

[private]
output_dir:
    mkdir -p {{OUTPUT_DIR}}

configure:
    cmake -B {{BUILD_DIR}} -DCMAKE_BUILD_TYPE={{BUILD_TYPE}}

build: configure
    cmake --build {{BUILD_DIR}}

asm_main: output_dir
    rgbasm -o {{OUTPUT_DIR}}/main.o src/main.asm -I include
    rgblink -o {{OUTPUT_DIR}}/main.gb {{OUTPUT_DIR}}/main.o
    python3 bintoascii.py {{OUTPUT_DIR}}/main.gb -o roms/main.mem

asm_boot: output_dir
    rgbasm -o {{OUTPUT_DIR}}/boot.o src/boot.asm -I include
    rgblink -o {{OUTPUT_DIR}}/boot.gb {{OUTPUT_DIR}}/boot.o
    python3 bintoascii.py {{OUTPUT_DIR}}/boot.gb -o roms/testboot.mem -n 2304

run:
    ./{{BUILD_DIR}}/gbc_sim

sim: sim_surfer

sim_surfer:
    surfer  {{OUTPUT_DIR}}/dump.fst -s .surfer/sim.state

sim_gtkwave:
    gtkwave {{OUTPUT_DIR}}/dump.fst config/sim.sav
    
clean: clean_build

clean_build:
    rm -rf {{BUILD_DIR}}

clean_out:
    rm -rf {{OUTPUT_DIR}}