TOP=tb_core.v
# SAVE=config/reg.sav
SAVE=_out/tb.sav
VPATH=src:test

default: sim

sim: _out/waveform.fst $(SAVE)
	gtkwave _out/waveform.fst $(SAVE)

$(SAVE):
	touch $(SAVE)

_out/waveform.fst: _out/run.vvp
	vvp -l _out/log.vvp _out/run.vvp -fst
	mv dump.fst _out/waveform.fst

_out/run.vvp: $(wildcard src/*.v) _out
	iverilog -o _out/run.vvp -Y .vh -y src -y test -I src -I test test/$(TOP)

_out:
	mkdir _out

clean:
	rm -rf _out