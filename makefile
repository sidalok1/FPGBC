TOP=tb_core.v
# SAVE=config/reg.sav
SAVE=config/tb.sav
VPATH=src:test
PYTHON=./.venv/bin/python3

default: sim

sim: _out/waveform.fst $(SAVE) mem filt
	gtkwave _out/waveform.fst $(SAVE)

mem: test/rom.mem

filt: gbfilt/target/release/gbfilt

gbfilt/target/release/gbfilt: $(wildcard gbfilt/src/*.rs)
	cd gbfilt && \
		cargo build --release --manifest-path Cargo.toml

$(SAVE):
	touch $(SAVE)

_out/waveform.fst: _out/run.vvp
	vvp -l _out/log.vvp _out/run.vvp -fst
	mv dump.fst _out/waveform.fst

_out/run.vvp: $(wildcard src/*.v) $(wildcard test/*.v) test/rom.mem _out
	iverilog -o _out/run.vvp -Y .vh -y src -y test -I src -I test test/$(TOP)

_out:
	mkdir _out

test/rom.mem: src/main.asm $(wildcard asmgb/*.py) asmgb/gb.lark
	$(PYTHON) ./asmgb/asmgb.py src/main.asm -o test/rom.mem

clean:
	rm -rf _out