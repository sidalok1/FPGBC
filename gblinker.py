import argparse

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
		prefix = "Parse error: "
		if colno is not None and colno > 0:
			suffix = "^".rjust(colno + len(linelabel))
		else:
			suffix = ""
		message = "\n".join(prefix, linelabel + line, suffix, context or "")
		super().__init__(message)
  
def immToBits(imm):
	if not imm.isdecimal():
		raise ValueError(f"Invalid immediate value: {imm}")
	value = int(imm)
	if value < 0 or value > 2**8 - 1:
		raise ValueError(f"Immediate value out of range: {value}")
	return [int(bit) for bit in f"{value:08b}"]

def main():
	parser = argparse.ArgumentParser(description="Translate GB ASM to .mem")
	parser.add_argument('file', nargs=1, help='GB ASM file to translate')
	args = parser.parse_args()
	bitstream = list()
	with open(args.file[0], 'r') as f:
		lineno = 0
		for line in f:
			line = line.strip()
			words = line.split()
			if len(words) == 0 or words[0].startswith('#'):
				continue
			match (words[0]):
				case 'ld':
					if len(words) < 3:
						raise ParseError(line, lineno, None, "Not enough operands")
					if len(words) > 3:
						raise ParseError(line, lineno, line.rfind(words[3]) + 1, "Too many operands")
					if words[1].startswith('['):
						if not words[1].endswith(']'):
							raise ParseError(line, lineno, line.rfind(words[1]) + len(words[1]), "Expected ']' at end of operand")
						if words[1] in r16:
							if words[2] != "a":
								raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Expected 'a' as second operand")
							bitstream.extend(0, 0, *r16[words[1].strip(',')], 0, 0, 1, 0)
						elif words[1].strip('[]').isdecimal():
							if words[2] != "sp":
								raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Expected 'sp' as second operand")
							bitstream.extend(0, 0, 0, 0, 1, 0, 0, 0)
						else:
							raise ParseError(line, lineno, line.rfind(words[1]) + 2, "Memory index must be r16 relative of decimal direct")
					elif words[1].strip(',') in r16:
						if not words[2].isdecimal():
							raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Expected a decimal number as second operand")
						bitstream.extend(0, 0, *r16[words[1].strip(',')], 0, 0, 0, 1, *immToBits(words[2]))
					elif words[1].strip(',') in r8:
						if words[2] in r16:
							if not words[2].startswith('[') or not words[2].endswith(']'):
								raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Second operand must be r16 relative")
							if words[1] != "a":
								raise ParseError(line, lineno, line.rfind(words[1]) + 1, "not implemented")
							bitstream.extend(0, 0, *r16[words[2]], 1, 0, 1, 0)
						else:
							bitstream.extend(0, 0, *r8[words[1].strip(',')], 1, 1, 0, *immToBits(words[2]))
				case 'add':
					if len(words) < 3:
						raise ParseError(line, lineno, None, "Not enough operands")
					if len(words) > 3:
						raise ParseError(line, lineno, line.rfind(words[3]) + 1, "Too many operands")
					if words[1].strip(',') != "hl":
						raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Expected 'hl' as first operand")
					if words[2].strip(',') not in r16:
						raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Expected one of 'bc', 'de', 'hl', 'sp' as second operand")
					bitstream.extend(0, 0, *r16[words[2]], 1, 0, 0, 1)
				case "jr":
					if len(words) == 2:
						if not words[1].isdigit():
							raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Expected a decimal number as operand")
						bitstream.extend(0, 0, 0, 1, 1, 0, 0, 0, *immToBits(words[1]))
					elif len(words) == 3:
						if not words[2].isdigit():
							raise ParseError(line, lineno, line.rfind(words[2]) + 1, "Expected a decimal number as operand")
						bitstream.extend(0, 0, 1, *cond[words[1]], 0, 0, 0, *immToBits(words[2]))
					elif len(words) < 2:
						raise ParseError(line, lineno, None, "Not enough operands")
					elif len(words) > 3:
						raise ParseError(line, lineno, line.rfind(words[3]) + 1, "Too many operands")
				case "nop":
					if len(words) != 1:
						raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Too many operands")
					bitstream.extend(0, 0, 0, 0, 0, 0, 0, 0)
				case "stop":
					if len(words) != 1:
						raise ParseError(line, lineno, line.rfind(words[1]) + 1, "Too many operands")
					bitstream.extend(0, 0, 0, 1, 0, 0, 0, 0)
