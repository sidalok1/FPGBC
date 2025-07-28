# FPGbA
## Field Programmable Gameboy Advance

### Intro
FPGbA is a project for emulating the Gameboy Advance on an FPGA. Currently, the
CPU core is being designed, still in simulation, but the target board as of now
is the Digilent cmod-a7.

```
/root
	/_out					<- Output products (cleaned by make clean)
		|waveform.fst		<- FST dumpfile generated for gtkwave by vvp
		|log.vvp			<- Logfile for vvp
		|run.vvp			<- iverilog output
		|...

	/config					<- Configurations, including sav and filter files
		|...
		
	/gbfilt					<- Rust project for a gtkwave disassembler
		/src				<- Rust source files
			|main.rs		<- Reads from stdin and write to stdout
			|reg.rs			<- Structs and enums specific to ISA
			|helpers.rs		<- All of the core logic, probably will be renamed

		|...				<- Files that cargo manages

	/src
		|main.asm			<- Assembly to be written to memory via readmemh
		|Core.v				<- Top level module as of now
		|ControUnit.v		<- Contains all decoding/control logic and FSM
		|RegisterFile.v		<- All general purpose and some special registers
		|ALU.v				<- Arithmetic Logic Unit
		|IDU.v				<- Increment/Decrement Unit
		|CondCheck.v		<- Checks flags for conditional jumps
		|*.vh				<- Various header files

	/test
		|tb_core.v			<- Top level test bench
		|Testmem.v			<- Model of memory/DMA
		|rom.mem			<- ASCII hex for readmemh

	|makefile				<- Build script for project
	|asmbg.py				<- Simple assembler that generate bin in ascii hex
	|...					<- Repo specific files
```

### ISA

#### Operations tested

- nop
- stop*

- ld r16, imm16
- ld [r16mem], a
- ld a, [r16mem]
- ld [imm16], sp
- ld r8, imm8
- inc r8
- dec r8
- inc r16
- dec r16
- add hl, r16

- rlca
- rrca
- rla
- rra
- cpl
- scf
- ccf

- jr imm8
- jr cond, imm8
- daa

- ld r8, r8
- halt*

- add a, r8
- adc a, r8
- sub a, r8
- sbc a, r8
- and a, r8
- xor a, r8
- or a, r8
- cp a, r8

#### Operations implemented



#### Operations todo next

*implementation may not be correct

### Modules

#### Dependancies
1. IcarusVerilog + GTKWave
2. Python 3.12
3. Cargo
4. Make
5. Vivado

#### Makefile
A simple makefile is being used for building the project.

---
```Make
make
```
Will build everything currently developed or under development.

---
```Make
make sim
```
Will compile rtl, assemble any asm in src/main.asm, and compiler the rust
filter process for disassembling the instructions.

Likewise,
```Make
make mem
make filt
```
Will invoke the python assembler and the rust compiler respectively.

---

#### RTL
Instead of an HLS solution, I've opted to attempt one in the Verilog HDL. All 
of the written HDL should follow the IEEE 1364-2001 standard, save for the
testbenches, which may use SystemVerilog (IEEE 1800-2009) features.

##### Simulation
Currently, IcarusVerilog and GTKWave are being used for simulation. I am doing
the bulk of the development in wsl on a surface pro 11 (ARM based) and Xilinx
does not provide an ARM64 build of Vivado, hence no xsim.

The python script and rust projects are utilities for simulation, more info on
them below

##### Synthesis/Implementation
All IP integration, Synthesis, Implementation/PnR, and Bitstream generation
will be done through a vivado tcl script.

#### asmgb.py
Many gameboy assemblers exist already, most better than this python script,
but for the fun of it I wrote a very simple assembler (no linker, logic may
be somewhat incorrect surrounding relative jumps). If this proves too
restrictive, I may switch to an existing gb assembler.

#### gbfilt
Translation Filter Process that disassembles instructions into their mnemonic
for gtkwave, written in rust. Perhaps writing this in c may have been easier
since the gtkwave documentation gives example code, but I've also been meaning
to learn rust and this seemed like a good excuse.