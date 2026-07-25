use crate::{reg::{Flags, R16, R8}};

use std::fmt::{Debug, Display, Formatter, Result};

enum InstTypes {
	Misc,
	ControlFlow,
	Load8bit,
	Load16bit,
	Arith8bit,
	Arith16bit,
	Invalid
}

impl Display for InstTypes {
	fn fmt(&self, f: &mut Formatter) -> Result {
		write!(f, "?{}?", match self {
			Misc => "RosyBrown4",
			ControlFlow => "yellow4",
			Load8bit => "DarkOliveGreen3",
			Load16bit => "DarkOliveGreen4",
			Arith8bit => "DodgerBlue3",
			Arith16bit => "DodgerBlue4",
			Invalid => "DarkRed"
		})
	}
}

struct Instruction {
	mnemonic: String,
	itype: InstTypes
}

impl Display for Instruction {
	fn fmt(&self, f: &mut Formatter) -> Result {
		write!(f, "{}{}", self.itype, self.mnemonic)
	}
}

impl Debug for Instruction {
	fn fmt(&self, f: &mut Formatter) -> Result {
		write!(f, "{}", self.mnemonic)
	}
}

pub fn hex_to_u8(hex: &str) -> Option<u8> {
	match u8::from_str_radix(hex, 16) {
		Ok(num) => Some(num),
		_ => None
	}
}

pub fn hex_to_u16(hex: &str) -> u16 {
	u16::from_str_radix(hex, 16).unwrap()
}



pub fn getbits(num: u8, msb: u8, lsb: u8) -> u8 {
	if (msb > 7) || (lsb > 7) || (lsb > msb) {
		panic!("Invalid indexing: msb({msb}), lsb({lsb})")
	} else {
		(num >> lsb) & !( 0xff << (msb - lsb + 1))
	}
}

pub struct RunState {
	pub prefix: bool,
	pub imm8: bool,
	pub imm16: bool,
	pub imm: Option<String>
}

use InstTypes::*;

macro_rules! invalid {
	($inst:expr) => {
		Instruction { 
			mnemonic: format!("{:0>8b} not valid instruction", $inst), 
			itype: Invalid 
		}
	};
}

macro_rules! unimp {
	($inst:expr) => {
		Instruction {
			mnemonic: format!("{:0>8b} not yet implemented", $inst),
			itype: Invalid
		}
	};
}

impl RunState {
	pub fn decode(&mut self, inst: &str) -> String {
		match hex_to_u8(inst) {
			Some(val) 	=> 
				format!("{}", 
					if self.prefix 	{self.pdecode_xxxxxxxx(val)}
					else 			{self.decode_xxxxxxxx(val)}
				),
			None 		=> format!("???")
		}
		// format!("{}", self.decode_xxxxxxxx(hex_to_u8(inst)))
	}

	fn decode_xxxxxxxx(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 7, 6) {
			0b00 => self.decode_00_xxxxxx(inst),
			0b01 => self.decode_01_xxxxxx(inst),
			0b10 => self.decode_10_xxx_xxx(inst),
			0b11 => self.decode_11_xxx_xxx(inst),
			_ => unimp!(inst)
		}
	}

	fn decode_00_xxxxxx(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 2, 0) {
			0b000 => self.decode_00_xxx_000(inst),
			0b001 => self.decode_00_xxx_001(inst),
			0b010 => self.decode_00_xxx_010(inst),
			0b011 => self.decode_00_xxx_011(inst),
			0b100 => Instruction { 
				mnemonic: format!("inc {}", R8::r8(getbits(inst, 5, 3))), 
				itype: Arith8bit
			},
			0b101 => Instruction { 
				mnemonic: format!("dec {}", R8::r8(getbits(inst, 5, 3))), 
				itype: Arith8bit
			},
			0b110 => {
				self.imm8 = true;
				Instruction {
					mnemonic: format!("ld {}, imm8", R8::r8(getbits(inst, 5, 3))),
					itype: Load8bit
				}
			}
			0b111 => self.decode_00_xxx_111(inst),
			_ => panic!("Should not happen!")
		}
	}

	fn decode_00_xxx_000(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 5, 3) {
			0b000 => Instruction { 
				mnemonic: String::from("nop"), 
				itype: Misc 
			},
			0b001 => {
				self.imm16 = true;
				Instruction { 
					mnemonic: String::from("ld [imm16], sp"), 
					itype: Load16bit 
				}
			},
			0b010 => Instruction { 
				mnemonic: String::from("stop"), 
				itype: Misc 
			},
			0b011 => {
				self.imm8 = true;
				Instruction { 
					mnemonic: String::from("jr imm8"), 
					itype: ControlFlow 
				}
			}
			0b100..=0b111 => {
				self.imm8 = true;
				Instruction { 
					mnemonic: format!("jr {}, imm8", Flags::cond(getbits(inst, 4, 3))),
					itype: ControlFlow
				}
			}
			_ => invalid!(inst)
		}
	}

	fn decode_00_xxx_001(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 3, 3) {
			0b0 => {
				self.imm16 = true;
				Instruction{
					mnemonic: format!("ld {}, imm16", R16::r16(getbits(inst, 5, 4))),
					itype: Load16bit
				}
			},
			0b1 => Instruction {
				mnemonic: format!("add hl, {}", R16::r16(getbits(inst, 5, 4))),
				itype: Arith16bit
			},
			_ => invalid!(inst)
		}
	}

	fn decode_00_xxx_010(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 3, 3) {
			0b0 => Instruction { 
				mnemonic: format!("ld [{}], a", R16::r16mem(getbits(inst, 5, 4))), 
				itype: Load8bit 
			},
			0b1 => Instruction { 
				mnemonic: format!("ld a, [{}]", R16::r16mem(getbits(inst, 5, 4))), 
				itype: Load8bit 
			},
			_ => invalid!(inst)
		}
	}

	fn decode_00_xxx_011(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 3, 3) {
			0b0 => Instruction { 
				mnemonic: format!("inc {}", R16::r16(getbits(inst, 5, 4))), 
				itype: Arith16bit
			},
			0b1 => Instruction { 
				mnemonic: format!("dec {}", R16::r16(getbits(inst, 5, 4))), 
				itype: Arith16bit
			},
			_ => invalid!(inst)
		}
	}

	fn decode_00_xxx_111(&mut self, inst: u8) -> Instruction {
		Instruction { 
			mnemonic: String::from(match getbits(inst, 5, 3) {
				0b000 => "rlca",
				0b001 => "rrca",
				0b010 => "rla",
				0b011 => "rra",
				0b100 => "daa",
				0b101 => "cpl",
				0b110 => "scf",
				0b111 => "ccf",
				_ => panic!("Should not happen!")
			}), 
			itype: Arith8bit 
		}
	}

	fn decode_01_xxxxxx(&mut self, inst: u8) -> Instruction {
		if getbits(inst, 5, 3) == 0b110 && getbits(inst, 2, 0) == 0b110 {
			Instruction {
				mnemonic: String::from("halt"),
				itype: Misc
			}
		} else {
			self.decode_01_xxx_xxx(inst)
		}
	}

	fn decode_01_xxx_xxx(&mut self, inst: u8) -> Instruction {
		Instruction { 
			mnemonic: format!("ld {}, {}",
					R8::r8(getbits(inst, 5, 3)),
					R8::r8(getbits(inst, 2, 0))
				), 
			itype: Load8bit
		}
	}

	fn decode_10_xxx_xxx(&mut self, inst: u8) -> Instruction {
		Instruction { 
			mnemonic: format!("{} a, {}",
				match getbits(inst, 5, 3) {
					0b000 => "add",
					0b001 => "adc",
					0b010 => "sub",
					0b011 => "sbc",
					0b100 => "and",
					0b101 => "xor",
					0b110 => "or",
					0b111 => "cp",
					_ => panic!("Should not happen!")
				},
				R8::r8(getbits(inst, 2, 0))
			), 
			itype: Arith8bit
		}
	}

	fn decode_11_xxx_xxx(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 2, 0) {
			0b000 => self.decode_11_xxx_000(inst),
			0b001 => self.decode_11_xxx_001(inst),
			0b010 => self.decode_11_xxx_010(inst),
			0b011 => self.decode_11_xxx_011(inst),
			0b100 => self.decode_11_xxx_100(inst),
			0b101 => self.decode_11_xxx_101(inst),
			0b110 => self.decode_11_xxx_110(inst),
			0b111 => self.decode_11_xxx_111(inst),
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_xxx_000(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 5, 5) {
			0b0 => Instruction { 
				mnemonic: format!("ret {}", Flags::cond(getbits(inst, 4, 3))), 
				itype: ControlFlow 
			},
			0b1 => self.decode_11_1_xx_000(inst),
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_1_xx_000(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 4, 3) {
			0b00 => Instruction { 
				mnemonic: String::from("ldh [imm8], a"), 
				itype: Load8bit
			},
			0b01 => Instruction { 
				mnemonic: String::from("add sp, imm8"), 
				itype: Arith8bit
			},
			0b10 => Instruction { 
				mnemonic: String::from("ldh a, [imm8]"), 
				itype: Load8bit
			},
			0b11 => Instruction { 
				mnemonic: String::from("ld hl, sp + imm8"), 
				itype: Load8bit
			},
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_xxx_001(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 3, 3) {
			0b0 => Instruction { 
				mnemonic: format!("pop {}", R16::r16stk(getbits(inst, 5, 4))), 
				itype: Load16bit
			},
			0b1 => self.decode_11_xx_1_001(inst),
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_xx_1_001(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 5, 4) {
			0b00 => Instruction { 
				mnemonic: String::from("ret"), 
				itype: ControlFlow 
			},
			0b01 => Instruction { 
				mnemonic: String::from("reti"), 
				itype: ControlFlow 
			},
			0b10 => Instruction { 
				mnemonic: String::from("jp hl"), 
				itype: ControlFlow 
			},
			0b11 => Instruction { 
				mnemonic: String::from("ld sp, hl"), 
				itype: Load16bit
			},
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_xxx_010(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 5, 5) {
			0b0 => self.decode_11_0_xx_010(inst),
			0b1 => self.decode_11_1_xx_010(inst),
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_0_xx_010(&mut self, inst: u8) -> Instruction {
		Instruction { 
			mnemonic: format!("jp {}, imm16", Flags::cond(getbits(inst, 4, 3))), 
			itype: ControlFlow
		}
	}

	fn decode_11_1_xx_010(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 4, 3) {
			0b00 => Instruction { 
				mnemonic: String::from("ldh [c], a"), 
				itype: Load8bit 
			},
			0b01 => Instruction { 
				mnemonic: String::from("ld [imm16], a"), 
				itype: Load16bit
			},
			0b10 => Instruction { 
				mnemonic: String::from("ldh a, [c]"), 
				itype: Load8bit
			},
			0b11 => Instruction { 
				mnemonic: String::from("ld a, [imm16]"), 
				itype: Load16bit
			},
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_xxx_011(&mut self, inst:u8) -> Instruction {
		match getbits(inst, 5, 3) {
			0b000 => Instruction { 
				mnemonic: String::from("jp imm16"), 
				itype: ControlFlow
			},
			0b001 => {
				self.prefix = true;
				Instruction { 
					mnemonic: String::from("prefix"), 
					itype: Misc 
				}
			},
			0b010 |
			0b011 |
			0b100 |
			0b101 => invalid!(inst),
			0b110 => Instruction { 
				mnemonic: String::from("di"), 
				itype: ControlFlow 
			},
			0b111 => Instruction { 
				mnemonic: String::from("ei"), 
				itype: ControlFlow 
			},
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_xxx_100(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 5, 5) {
			0b0 => Instruction { 
				mnemonic: format!("call {}, imm16",
					Flags::cond(getbits(inst, 4, 3))), 
				itype: ControlFlow
			},
			0b1 => invalid!(inst),
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_xxx_101(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 3, 3) {
			0b0 => Instruction { 
				mnemonic: format!("push {}",
					R16::r16stk(getbits(inst, 5, 4))), 
				itype: Load16bit 
			},
			0b1 => match getbits(inst, 5, 4) {
				0b00 => Instruction { 
					mnemonic: String::from("call imm16"), 
					itype: ControlFlow
				},
				0b01 |
				0b10 |
				0b11 => invalid!(inst),
				_ => panic!("Should not happen!")
			},
			_ => panic!("Should not happen!")
		}
	}

	fn decode_11_xxx_110(&mut self, inst: u8) -> Instruction {
		Instruction { 
			mnemonic: format!("{} a, imm8",
				match getbits(inst, 5, 3) {
					0b000 => "add",
					0b001 => "adc",
					0b010 => "sub",
					0b011 => "sbc",
					0b100 => "and",
					0b101 => "xor",
					0b110 => "or",
					0b111 => "cp",
					_ => panic!("Should not happen!")
				}
			), 
			itype: Arith8bit 
		}
	}

	fn decode_11_xxx_111(&mut self, inst: u8) -> Instruction {
		Instruction {
			mnemonic: format!("rst 0x{:X}", getbits(inst, 5, 3) * 8),
			itype: ControlFlow
		}
	}

	fn pdecode_xxxxxxxx(&mut self, inst: u8) -> Instruction {
		self.prefix = false;
		let reg = R8::r8(getbits(inst, 2, 0));
		match getbits(inst, 7, 6) {
			0b00 => Instruction { 
				mnemonic: format!("{} {}",
					match getbits(inst, 5, 3) {
						0b000 => "rlc",
						0b001 => "rrc",
						0b010 => "rl",
						0b011 => "rr",
						0b100 => "sla",
						0b101 => "sra",
						0b110 => "swap",
						0b111 => "srl",
						_ => panic!("Should not happen!")
					},
					reg
				), 
				itype: Arith8bit 
			},
			0b01 => Instruction { 
				mnemonic: format!("bit {}, {}",
					getbits(inst, 5, 3),
					reg), 
				itype: Arith8bit 
			},
			0b10 => Instruction { 
				mnemonic: format!("res {}, {}",
					getbits(inst, 5, 3),
					reg), 
				itype: Arith8bit 
			},
			0b11 => Instruction { 
				mnemonic: format!("set {}, {}",
					getbits(inst, 5, 3),
					reg), 
				itype: Arith8bit 
			},
			_ => panic!("Should not happen!")
		}
	}

}