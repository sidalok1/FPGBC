use std::fmt::{Display, Formatter, Result};

#[derive(strum_macros::Display)]
pub enum R8 {
	b,
	c,
	d,
	e,
	h,
	l,
	a,
	m,
}

impl R8 {
	pub fn r8(idx: u8) -> R8 {
		match idx {
			0b000 => R8::b,
			0b001 => R8::c,
			0b010 => R8::d,
			0b011 => R8::e,
			0b100 => R8::h,
			0b101 => R8::l,
			0b110 => R8::m,
			0b111 => R8::a,
			_ => panic!("Invalid r8 idx: {idx}")
		}
	}
}
#[derive(strum_macros::Display)]
pub enum R16 {
	bc,
	de,
	hl,
	af,
	sp,
	pc,
	hli,
	hld
}

impl R16 {
	pub fn r16(idx: u8) -> R16 {
		match idx {
			0b00 => R16::bc,
			0b01 => R16::de,
			0b10 => R16::hl,
			0b11 => R16::sp,
			_ => panic!("Invalid r16 idx: {idx}")
		}
	}
	pub fn r16stk(idx: u8) -> R16 {
		if idx == 0b11 {
			R16::af
		} else {
			R16::r16(idx)
		}
	}
	pub fn r16mem(idx: u8) -> R16 {
		match idx {
			0b10 => R16::hli,
			0b11 => R16::hld,
			_ => R16::r16(idx)
		}
	}
}

#[derive(strum_macros::Display)]
pub enum Flags {
	nz,
	z,
	nc,
	c
}

impl Flags {
	pub fn cond(idx: u8) -> Flags {
		match idx {
			0b00 => Flags::nz,
			0b01 => Flags::z,
			0b10 => Flags::nc,
			0b11 => Flags::c,
			_ => panic!("Invalid cond idx: {idx}")
		}
	}
}

pub enum IMM8 {
	Signed(i8),
	Unsigned(u8)
}

impl Display for IMM8 {
	fn fmt(&self, f: &mut Formatter<'_>) -> Result {
		let val = match self {
			IMM8::Signed(x) => format!("{x:#X}"),
			IMM8::Unsigned(y) => format!("{y:#X}")
		};
		write!(f, "{}" , val)
	}
}

pub struct  IMM16 {
	VAL: u16
}

impl Display for IMM16 {
	fn fmt(&self, f: &mut Formatter<'_>) -> Result {
		write!(f, "{:#X}", self.VAL)
	}
}

pub struct B3 {
	VAL: u8
}

impl Display for B3 {
	fn fmt(&self, f: &mut Formatter<'_>) -> Result {
		write!(f, "{}", self.VAL)
	}
}

pub struct VEC {
	VAL: u8
}

impl Display for VEC {
	fn fmt(&self, f: &mut Formatter<'_>) -> Result {
		let addr: u8 = self.VAL * 8;
		write!(f, "{:#X}", addr)
	}
}