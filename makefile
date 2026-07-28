BUILD_DIR := build
.PHONY: all configure build run clean sim

all: build

configure: ./CMakeLists.txt
	cmake -B $(BUILD_DIR) -DCMAKE_BUILD_TYPE=Debug

build: configure
	cmake --build $(BUILD_DIR) -j$(shell nproc)

roms/main.mem: src/main.asm
# 	rgbasm -o _out/main.o src/main.asm -I include
# 	rgblink -o _out/main.gb _out/main.o
# 	python3 bintoascii.py _out/main.gb -o roms/main.mem

roms/testboot.mem: src/boot.asm
	rgbasm -o _out/boot.o src/boot.asm -I include
	rgblink -o _out/boot.gb _out/boot.o
	python3 bintoascii.py _out/boot.gb -o roms/testboot.mem -n 2304

run: build roms/main.mem roms/testboot.mem
	./$(BUILD_DIR)/gbc_sim

_out/dump.fst: run

clean:
	rm -rf $(BUILD_DIR)

config/sim.sav:
	touch config/sim.sav

sim: _out/dump.fst config/sim.sav
	gtkwave _out/dump.fst config/sim.sav


# TOP=tb.v
# # SAVE=config/reg.sav
# SAVE=config/tb.sav
# VPATH=src:test
# PYTHON=./.venv/bin/python3

# default: sim

# sim: _out/waveform.fst $(SAVE) mem filt
# 	gtkwave _out/waveform.fst $(SAVE)

# mem: test/rom.mem

# filt: gbfilt/target/release/gbfilt

# gbfilt/target/release/gbfilt: $(wildcard gbfilt/src/*.rs)
# 	cd gbfilt && \
# 		cargo build --release --manifest-path Cargo.toml

# $(SAVE):
# 	touch $(SAVE)

# _out/waveform.fst: _out/run.vvp
# 	vvp -l _out/log.vvp _out/run.vvp -fst
# 	mv dump.fst _out/waveform.fst

# _out/run.vvp: $(wildcard src/*.v) $(wildcard test/*.v) test/rom.mem _out
# 	iverilog -o _out/run.vvp -Y .vh -y src -y test -I src -I test test/$(TOP)

# _out:
# 	mkdir _out

# test/rom.mem: src/main.asm $(wildcard asmgb/*.py) asmgb/gb.lark
# 	$(PYTHON) ./asmgb/asmgb.py src/main.asm -o test/rom.mem

# clean:
# 	rm -rf _out