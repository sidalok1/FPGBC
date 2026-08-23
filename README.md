# FPGbC
## Field Programmable Gameboy Color

### Intro
FPGbC is a project for emulating the Gameboy Color on an FPGA. The end goal of this
project is to have the hardware emulator running on the CMOD-A7 FPGA board.

```
/root
	/_out					<- Output products, can be safely cleaned
		|...

	/config					<- Configurations, including sav and filter files for gtkwave
		|...
	/.surfer				<- Surfer waveform viewer configuration files
		|...
		
	/gbfilt					<- Rust project for surfer translation filter processes
		|...				

	/include				<- Include files for C++ and Verilog
		|...

	/src
		/CPU_core_submodules
			|...
		/APU_Channels
			|...
		|System.v			<- Top level wrapper, can choose between hdl and software cartridge
		|Core.v				<- Gameboy's CPU core
		|MAC.v				<- Memory bus controller (abbreviated Access to not confuse with MBC)
		|MBC.v				<- HDL memory bank controller (software implementation preferred)
		|SoC.v				<- Everything but the Cartridge
		|...

	/roms
		|cgb_boot.mem		<- ASCII hex of the CGB bootrom, used with $readmemh

	/test					<- Was used when simulating with IcarusVerilog
		|...
	
	/sim					<- Verilator testbench and other C++ simulation files
		|main.cpp			<- Top level testbench
		|Cartridge.cpp		<- Software emulation of various MBCs

	|makefile				<- Build script for project
	|justfile				<- Does more or less the same things as the makefile
	|CmakeLists.txt
	|design_filt.py			<- Python script to design the bandpass filter for the gameboy audio
	|...					<- Anything else in the repo is not super important, may be removed
```

#### Dependancies
1. Verilator
2. C++20
3. SDL3
4. RGBDS
5. Cargo
6. Make
7. Just

#### RTL
All parts of the Gameboy color's SoC are designed in verilog. The cartridge MBC
is currently implemented in C++, but verilog implementations of those are in the
works.

#### Simulation
Simulation is done using Verilator to generate C++ files for the HDL system. This
verilated top level module is run and all of the SoC's I/O are handled in SDL3.
The C++ testbench also emulates cartridges (containing no MBC, MBC1, MBC5, and
limited support for MBC3). Changes to the CMakeLists.txt allow the testbench to
dump the simulation variables in FST format, various filters/translators for
gtkwave/surfer are included as well.



