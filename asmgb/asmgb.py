"""
Script for turning gameboy asm files into ascii read by readmemb verilog
 directive

"""
from lark import Lark
from pathlib import Path
import syntaxtree as syn

grammar_file = "gb.lark"

cwd = Path(__file__)

asm_parser = Lark.open(
	grammar_file, 
	rel_to = (cwd.as_posix()),
	start="program"
)

tfm = syn.ASMTransformer(visit_tokens=True)

def main():
	import argparse
	import sys
	argument_parser = argparse.ArgumentParser(
		prog = "asmgb",
		description= "Simple assembler for GameBoy assembly"
	)

	argument_parser.add_argument(  
		"file",
		type = argparse.FileType("r"),
		default = sys.stdin,
		help = "Assembly file for %(prog)s to parse",
		metavar = "infile",
	)

	argument_parser.add_argument(
		"-o",
		type = argparse.FileType("w"),
		default = sys.stdout,
		help = "File to write generated machine code to",
		metavar = "outfile",
		dest = "out"
	)

	argument_parser.add_argument(
		"-r", "--radix",
		type=int,
		default=16,
		choices=[2, 16],
		metavar="radix"
	)

	arg_nmsp = argument_parser.parse_args()

	tree = asm_parser.parse(arg_nmsp.file.read())

	assembly = syn.ASMTransformer(visit_tokens=True).transform(tree)

	bytestream = list()

	if arg_nmsp.radix == 16:
		bytestream = [f"{x:02X}\n" for x in assembly]
	elif arg_nmsp.radix == 2:
		bytestream = [f"{x:08b}\n" for x in assembly]

	arg_nmsp.out.writelines(bytestream)

if __name__=="__main__":
	main()