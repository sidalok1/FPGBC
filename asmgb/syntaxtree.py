"""
Transformer and Syntax Tree Nodes

"""

from lark import Transformer
from lark.visitors import Interpreter, Discard
from asmclasses import r8, r16, cond

class ASMTransformer(Transformer):

	def __init__(self, visit_tokens: bool = True) -> None:
		super().__init__(visit_tokens)
		self.instructions = list()
		self.labels = dict()


	def BINNUM(self, num):
		return int(num, base=2)
	
	def HEXNUM(self, num):
		return int(num, base=16)
	
	def DECNUM(self, num):
		return int(num)
	
	def LABEL(self, label):
		return label.rstrip(':')
	
	def COND(self, cc):
		return cond(cc.value.lower())
	
	def r8(self, reg):
		return r8(reg[0].type)
	
	def r16(self, reg):
		return r16(reg[0].type)
	
	def r16mem(self, reg):
		return r16(reg[0].type)
	
	def label(self, label):
		self.labels[label[0]] = len(self.instructions)
		return Discard
	
	def CNAME(self, name):
		return name.value
		
	def instruction(self, inst):
		if isinstance(inst[0], list):
			self.instructions.extend(inst[0])
			return inst[0]
		else:
			self.instructions.append(inst[0])
			return [inst[0]]
	
	def NOP(self, _):
		return 0b00000000
	
	def STOP(self, _):
		return 0b00010000
	
	def HALT(self, _):
		return 0b01_110_110
	
	def RLCA(self, _):
		return 0b00_000_111
	
	def RRCA(self, _):
		return 0b00_001_111
	
	def RLA(self, _):
		return 0b00_010_111
	
	def RRA(self, _):
		return 0b00_011_111
	
	def DAA(self, _):
		return 0b00_100_111
	
	def CPL(self, _):
		return 0b00_101_111
	
	def SCF(self, _):
		return 0b00_110_111
	
	def CCF(self, _):
		return 0b00_111_111
	
	@staticmethod
	def imm8(i):
		if (i >= 2**8):
			raise ValueError(f"Immediate {i} is larger than 8 bits")
		elif (i < 0):
			return i + 2**8
		else:
			return i
		
	@staticmethod
	def imm16(i):
		if ( i >= 2**16):
			raise ValueError(f"Immediate {i} is larger than 8 bits")
		if (i < 0):
			i += 2**8
		return [i % 2**8, i // 2**8] # little endian

	def increment(self, inst):
		if isinstance(inst[1], r8):
			return 0b00_000_100 | (inst[1].byte() << 3)
		elif isinstance(inst[1], r16):
			return 0b00_00_0011 | (inst[1].byte() << 4)
		else:
			raise TypeError()
		
	def decrement(self, inst):
		if isinstance(inst[1], r8):
			return 0b00_000_101 | (inst[1].byte() << 3)
		elif isinstance(inst[1], r16):
			return 0b00_00_1011 | (inst[1].byte() << 4)
		else:
			raise TypeError()
		
	def jump_rel(self, inst):
		if isinstance(inst[1], int):
			inst[1] = self.imm8(inst[1])
		else:
			inst[1] = inst[1]
		return [0b00_011_000, inst[1]]
	
	def load_r8_r8(self, inst):
		return 0b01_000_000 | (inst[1].byte() << 3) | inst[2].byte()
	
	def load_imm16(self, inst):
		bytes = list()
		bytes.append(0b00_000_001 | (inst[1].byte() << 4))
		# 16 bit immediates are added little endian
		bytes.extend(self.imm16(inst[2]))
		return bytes

	def load_imm8(self, inst):
		bytes = list()
		bytes.append(0b00_000_110 | (inst[1].byte() << 3))
		bytes.append(self.imm8(inst[2]))
		return bytes
	
	def load_r16_a(self, inst):
		return 0b00_00_0010 | (inst[1].byte() << 4)
	
	def load_a_r16(self, inst):
		return 0b00_00_1010 | (inst[2].byte() << 4)
	
	def load_dir_sp(self, inst):
		bytes = [0b00_00_1000]
		bytes.extend(self.imm16(inst[1]))

	def add_hl_r16(self, inst):
		return 0b00_00_1001 | (inst[2].byte() << 4)
	
	def jump_rel_cd(self, inst):
		bytes = [
			0b_00_100_000 | (inst[1].byte() << 3),
			inst[2]
		]
		return bytes

	def line_list(self, _):
		for label, addr in self.labels.items():
			for idx in range(len(self.instructions)):
				if self.instructions[idx] == label: 
					self.instructions[idx] = self.imm8(addr - (idx + 1))
		return self.instructions

	