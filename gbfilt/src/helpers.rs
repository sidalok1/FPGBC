use crate::{reg::{Flags, R16, R8}};

use std::fmt::{Display, Formatter, Result, Debug};

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

pub fn hex_to_u8(hex: &str) -> u8 {
	u8::from_str_radix(hex, 16).unwrap()
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
		// if self.imm8 {
		// 	self.imm8 = false;
		// 	String::from(inst)
		// } else if self.imm16 {
		// 	match &self.imm {
		// 		Some(s) => {
		// 			let imm_str = format!("{}{}", s, inst);
		// 			self.imm16 = false;
		// 			self.imm = None;
		// 			imm_str
		// 		},
		// 		None => {
		// 			self.imm = Some(String::from(inst));
		// 			String::new()
		// 		}
		// 	}
		// } else if self.prefix {
		// 	self.prefix = false;
		// 	String::from("Prefixed insts not implemented")
		// } else {
		// 	format!("{}", self.decode_xxxxxxxx(hex_to_u8(inst)))
		// }
		// IR register holds only instructions, not immediates
		// The prefix part might still be necessary in the future
		format!("{}", self.decode_xxxxxxxx(hex_to_u8(inst)))
	}

	fn decode_xxxxxxxx(&mut self, inst: u8) -> Instruction {
		match getbits(inst, 7, 6) {
			0b00 => self.decode_00_xxxxxx(inst),
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
			_ => unimp!(inst)
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
				mnemonic: format!("inc {}", R16::r16mem(getbits(inst, 5, 4))), 
				itype: Arith16bit
			},
			0b1 => Instruction { 
				mnemonic: format!("dec {}", R16::r16mem(getbits(inst, 5, 4))), 
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
				_ => panic!("getbits returned more than 3 bit uint!")
			}), 
			itype: Arith8bit 
		}
	}

	
}