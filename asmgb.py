"""Script for turning gameboy asm files into ascii read by readmemb verilog
 directive
 
	python3 asmgb.py file -o outfile

	Options:
	file: input asm file
	-o file: output file. stdout if not specified.
		
"""

import argparse
import io
import os

r8 = {
	"b": (0, 0, 0),
	"c": (0, 0, 1),
	"d": (0, 1, 0),
	"e": (0, 1, 1),
	"h": (1, 0, 0),
	"l": (1, 0, 1),
	"[hl]": (1, 1, 0),
	"a": (1, 1, 1),
}
r16 = {
	"bc": (0, 0),
	"[bc]": (0, 0),
	"de": (0, 1),
	"[de]": (0, 1),
	"hl": (1, 0),
	"[hl+]": (1, 0),
	"sp": (1, 1),
	"af": (1, 1),
	"[hl-]": (1, 1),
}
cond = {
	"nz": (0, 0),
	"z": (0, 1),
	"nc": (1, 0),
	"c": (1, 1),
}

class ParseError(Exception):
	def __init__(self, line, lineno, colno=None, context=None):
		linelabel = f"{lineno}: "
		prefix = "Encountered invalid token while parsing"
		if colno is not None and colno > 0:
			suffix = "^".rjust(colno + len(linelabel))
		else:
			suffix = ""
		message = "\n".join([prefix, linelabel + line, suffix, context or ""])
		super().__init__(message)
  
def immToBits(imm: str, bytes = 2):
	if not imm.lstrip('-').isdecimal():
		raise ValueError(f"Invalid immediate value: {imm}")
	value = int(imm)
	if value < 0:
		value = value + (2**(bytes*8))
	if bytes == 1:
		bitstring = f"{value:08b}"
	elif bytes == 2:
		bitstring = f"{value:016b}"
		bitstring = bitstring[8:16] + bitstring[0:8]
	else: raise ValueError(f"Immediate must be 1 or 2 bytes, not {value}")
	return tuple(int(bit) for bit in bitstring)

def main():
	parser = argparse.ArgumentParser(description="Translate GB ASM to .mem")
	parser.add_argument('file', nargs=1, type=argparse.FileType(mode="r"), help='GB ASM file to translate')
	parser.add_argument("-o", nargs=1, type=argparse.FileType(mode="w"), default=None)
	args = parser.parse_args()
	bitstream = list()
	with args.file[0] as f:
		lineno = 0
		for line in f:
			line = line.strip()
			words = line.split()
			if len(words) == 0 or words[0].startswith('#'):
				lineno += 1
				continue
			match (words[0]):
				case 'ld':
					if len(words) < 3:
						raise ParseError(line, lineno, None, "Not enough operands")
					if len(words) > 3:
						raise ParseError(line, lineno, line.rfind(words[3]) + 1, "Too many operands")
					if words[1].startswith('['):
						if not words[1].strip(',').endswith(']'):
							raise ParseError(line, lineno, line.rfind(words[1]) + len(words[1]), "Expected ']' at end of operand")
						if words[1].strip(',') in r16:
							if words[2] != "a":
								raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Expected 'a' as second operand")
							bitstream.extend([0, 0, *r16[words[1].strip(',')], 0, 0, 1, 0])
						elif words[1].strip('-[],').isdigit():
							if words[2] != "sp":
								raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Expected 'sp' as second operand")
							bitstream.extend([0, 0, 0, 0, 1, 0, 0, 0, *immToBits(words[1].strip("[],"))])
						else:
							raise ParseError(line, lineno, line.rfind(words[1]) + 2, "Memory index must be r16 relative of decimal direct")
					elif words[1].strip(',') in r16:
						if not words[2].lstrip('-').isdigit():
							raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Expected a decimal number as second operand")
						bitstream.extend([0, 0, *r16[words[1].strip(',')], 0, 0, 0, 1, *immToBits(words[2])])
					elif words[1].strip(',') in r8:
						if words[2] in r16:
							if not words[2].startswith('[') or not words[2].endswith(']'):
								raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Second operand must be r16 relative")
							if words[1].strip(',') != "a":
								raise ParseError(line, lineno, line.rfind(words[1]) + 1, "not implemented")
							bitstream.extend([0, 0, *r16[words[2]], 1, 0, 1, 0])
						else:
							bitstream.extend([0, 0, *r8[words[1].strip(',')], 1, 1, 0, *immToBits(words[2], 1)])
				case 'add':
					if len(words) < 3:
						raise ParseError(line, lineno, None, "Not enough operands")
					if len(words) > 3:
						raise ParseError(line, lineno, line.rfind(words[3]) + 1, "Too many operands")
					if words[1].strip(',') != "hl":
						raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Expected 'hl' as first operand")
					if words[2].strip(',') not in r16:
						raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Expected one of 'bc', 'de', 'hl', 'sp' as second operand")
					bitstream.extend([0, 0, *r16[words[2]], 1, 0, 0, 1])
				case "jr":
					if len(words) == 2:
						if not words[1].strip('-').isdigit():
							raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Expected a decimal number as operand")
						bitstream.extend([0, 0, 0, 1, 1, 0, 0, 0, *immToBits(words[1], 1)])
					elif len(words) == 3:
						if not words[2].strip('-').isdigit():
							raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Expected a decimal number as operand")
						bitstream.extend([0, 0, 1, *cond[words[1].strip(',')], 0, 0, 0, *immToBits(words[2], 1)])
					elif len(words) < 2:
						raise ParseError(line, lineno, None, "Not enough operands")
					elif len(words) > 3:
						raise ParseError(line, lineno, line.rfind(words[3]) + 1, "Too many operands")
				case "nop":
					if len(words) != 1:
						raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Too many operands")
					bitstream.extend([0, 0, 0, 0, 0, 0, 0, 0])
				case "stop":
					if len(words) != 1:
						raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Too many operands")
					bitstream.extend([0, 0, 0, 1, 0, 0, 0, 0])
				case "inc":
					if len(words) < 2:
						raise ParseError(line, lineno, None, "Not enough operands")
					elif len(words) > 2:
						raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Too many operands")
					elif words[1] in r8:
						bitstream.extend([0, 0, *r8[words[1]], 1, 0, 0])
					elif words[1] in r16:
						bitstream.extend([0, 0, *r16[words[1]], 0, 0, 1, 1])
				case "dec":
					if len(words) < 2:
						raise ParseError(line, lineno, None, "Not enough operands")
					elif len(words) > 2:
						raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Too many operands")
					elif words[1] in r8:
						bitstream.extend([0, 0, *r8[words[1]], 1, 0, 1])
					elif words[1] in r16:
						bitstream.extend([0, 0, *r16[words[1]], 1, 0, 1, 1])
			lineno += 1
		bytestream = [bitstream[i:i+8] for i in range(0, len(bitstream), 8)]
		bytestrings = ["".join([str(bit) for bit in byte]) + '\n' for byte in bytestream]
		with args.o[0] as out:
			out: io.TextIOWrapper
			out.writelines(bytestrings)
if __name__=="__main__":
    # print(immToBits("32"));
    # print(immToBits("-33"));
    # print(immToBits("5", 1));
    # print(immToBits("-10", 1));
    main()