from enum import StrEnum

class r8(StrEnum):
	A = "A"
	B = "B"
	C = "C"
	D = "D"
	E = "E"
	H = "H"
	L = "L"
	HL = "HLR8"

	def __repr__(self) -> str:
		if self.name == r8.HL:
			return "[hl]"
		else:
			return self.name.lower()
		
	def byte(self) -> int:
		match self:
			case r8.B:
				return 0b000
			case r8.C:
				return 0b001
			case r8.D:
				return 0b010
			case r8.E:
				return 0b011
			case r8.H:
				return 0b100
			case r8.L:
				return 0b101
			case r8.HL:
				return 0b110
			case r8.A:
				return 0b111
			


class r16(StrEnum):
	BC = "BC"
	DE = "DE"
	HL = "HL"
	HLI = "HLI"
	SP = "SP"
	HLD = "HLD"

	def __repr__(self) -> str:
		return self.name.lower()
	
	def byte(self) -> int:
		match self:
			case r16.BC:
				return 0b00
			case r16.DE:
				return 0b01
			case r16.HL | r16.HLI:
				return 0b10
			case r16.SP | r16.HLD:
				return 0b11
			
	
class cond(StrEnum):
	Z = "z"
	NZ = "nz"
	C = "c"
	NC = "nc"

	def __repr__(self) -> str:
		return self.name.lower()

	def byte(self) -> int:
		match self:
			case cond.NZ:
				return 0b00
			case cond.Z:
				return 0b01
			case cond.NC:
				return 0b10
			case cond.C:
				return 0b11