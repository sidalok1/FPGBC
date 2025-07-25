use std::fmt::{Display, Formatter, Result};

pub enum R8 {
	B,
	C,
	D,
	E,
	H,
	L,
	A,
	M,
}

impl Display for R8 {
	fn fmt(&self, f: &mut Formatter) -> Result {
		write!(f, "{}", match self {
			R8::B => "b",
			R8::C => "c",
			R8::D => "d",
			R8::E => "e",
			R8::H => "h",
			R8::L => "l",
			R8::A => "a",
			R8::M => "[hl]",
		})
	}
}

impl R8 {
	pub fn r8(idx: u8) -> R8 {
		match idx {
			0b000 => R8::B,
			0b001 => R8::C,
			0b010 => R8::D,
			0b011 => R8::E,
			0b100 => R8::H,
			0b101 => R8::L,
			0b110 => R8::M,
			0b111 => R8::A,
			_ => panic!("Invalid r8 idx: {idx}")
		}
	}
}

pub enum R16 {
	BC,
	DE,
	HL,
	AF,
	SP,
	PC,
	HLp,
	HLm
}

impl R16 {
	pub fn r16(idx: u8) -> R16 {
		match idx {
			0b00 => R16::BC,
			0b01 => R16::DE,
			0b10 => R16::HL,
			0b11 => R16::SP,
			_ => panic!("Invalid r16 idx: {idx}")
		}
	}
	pub fn r16stk(idx: u8) -> R16 {
		if idx == 0b11 {
			R16::AF
		} else {
			R16::r16(idx)
		}
	}
	pub fn r16mem(idx: u8) -> R16 {
		match idx {
			0b10 => R16::HLp,
			0b11 => R16::HLm,
			_ => R16::r16(idx)
		}
	}
}

impl Display for R16 {
	fn fmt(&self, f: &mut Formatter) -> Result {
		write!(f, "{}", match self {
			R16::BC => "bc",
			R16::DE => "de",
			R16::HL => "hl",
			R16::AF => "af",
			R16::SP => "sp",
			R16::PC => "pc",
			R16::HLp => "hl+",
			R16::HLm => "hl-"
		})
	}
}

pub enum Flags {
	NZ,
	Z,
	NC,
	C
}

impl Display for Flags {
	fn fmt(&self, f: &mut Formatter) -> Result {
		write!(f, "{}", match self {
			Flags::NZ => "nz",
			Flags::Z => "z",
			Flags::NC => "nc",
			Flags::C => "c"
		})
	}
}

impl Flags {
	pub fn cond(idx: u8) -> Flags {
		match idx {
			0b00 => Flags::NZ,
			0b01 => Flags::Z,
			0b10 => Flags::NC,
			0b11 => Flags::C,
			_ => panic!("Invalid cond idx: {idx}")
		}
	}
}