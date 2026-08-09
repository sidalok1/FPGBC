use::ecolor::Color32;
use extism_pdk::{FnResult, plugin_fn};
pub use surfer_translation_types::plugin_types::TranslateParams;
use surfer_translation_types::{
    TranslationPreference, TranslationResult, ValueKind, ValueRepr, VariableInfo, VariableMeta, VariableValue
};

#[plugin_fn]
pub fn new() -> FnResult<()> {
    Ok(())
}

#[plugin_fn]
pub fn name() -> FnResult<String> {
    Ok(String::from("GameBoy Address Bus Translator"))
}

#[plugin_fn]
pub fn translates(variable: VariableMeta<(), ()>) -> FnResult<TranslationPreference> {
    match variable.num_bits {
        Some(num_bits) => {
            if num_bits == 16 {
                Ok(TranslationPreference::Yes)
            } else {
                Ok(TranslationPreference::No)
            }
        }
        None => Ok(TranslationPreference::No)
    }
}

fn variable_to_u16(val: VariableValue) -> u16 {
    match val {
        VariableValue::BigUint(x) => {
            let bytevec = x.to_bytes_le();
            if  bytevec.len() >= 2 {
                (bytevec[0] as u16) | ((bytevec[1] as u16) << 8)
            }
            else {
                bytevec[0] as u16
            }
        }
        VariableValue::String(s) => u16::from_str_radix(s.as_str(), 2).unwrap()
    }
}

fn reg_result(name: &str, addr: u16) -> TranslationResult {
    TranslationResult { 
        val: ValueRepr::String(format!("{}: {:#04X}", name, addr)), 
        subfields: vec![], 
        kind: ValueKind::Custom(Color32::from_rgb(0x50, 0x00, 0x50)) 
    }
}

#[plugin_fn]
pub fn translate(
    TranslateParams { variable: _, value }: TranslateParams,
) -> FnResult<TranslationResult> {
    let num = variable_to_u16(value);
    Ok(
        if num <= 0x7FFF {
            TranslationResult { 
                val: ValueRepr::String(format!("EROM + {:#04X}", num)), 
                subfields: vec![], 
                kind: ValueKind::Custom(Color32::from_rgb(0x50, 0x50, 0x00))
            }
        } 
        else if num <= 0x9FFF {
            TranslationResult { 
                val: ValueRepr::String(format!("VRAM + {:#04X}", num - 0x8000)), 
                subfields: vec![], 
                kind: ValueKind::Custom(Color32::from_rgb(0x00, 0x50, 0x00))
            }
        }
        else if num <= 0xBFFF {
            TranslationResult { 
                val: ValueRepr::String(format!("ERAM + {:#04X}", num - 0xA000)), 
                subfields: vec![], 
                kind: ValueKind::Custom(Color32::from_rgb(0x00, 0x50, 0x50))
            }
        }
        else if num <= 0xDFFF {
            TranslationResult { 
                val: ValueRepr::String(format!("WRAM + {:#04X}", num - 0xC000)), 
                subfields: vec![], 
                kind: ValueKind::Custom(Color32::from_rgb(0x00, 0x50, 0x50))
            }
        }
        else if num <= 0xFDFF {
            TranslationResult { 
                val: ValueRepr::String(format!("ECHO + {:#04X}", num - 0xE000)), 
                subfields: vec![], 
                kind: ValueKind::Custom(Color32::from_rgb(0x50, 0x50, 0x50))
            }
        }
        else if num <= 0xFE9F {
            TranslationResult { 
                val: ValueRepr::String(format!("OAM  + {:#04X}", num - 0xFE00)), 
                subfields: vec![], 
                kind: ValueKind::Custom(Color32::from_rgb(0x00, 0x50, 0x50))
            }
        }
        else if num >= 0xFF80 && num <= 0xFFFE {
            TranslationResult { 
                val: ValueRepr::String(format!("HRAM + {:#04X}", num - 0xFF80)), 
                subfields: vec![], 
                kind: ValueKind::Custom(Color32::from_rgb(0x50, 0x50, 0x00))
            }
        }
        else {
            match num {
                0xFF00 => reg_result("JOYP", num),
                0xFF01 => reg_result("SB", num),
                0xFF02 => reg_result("SC", num),
                0xFF04 => reg_result("DIV", num),
                0xFF05 => reg_result("TIMA", num),
                0xFF06 => reg_result("TMA", num),
                0xFF07 => reg_result("TAC", num),
                0xFF0F => reg_result("IF", num),
                0xFF10 => reg_result("NR10 (SWEEP)", num),
                0xFF11 => reg_result("NR11 (LEN)", num),
                0xFF12 => reg_result("NR12 (ENV)", num),
                0xFF13 => reg_result("NR13 (LOW)", num),
                0xFF14 => reg_result("NR14 (HIGH)", num),
                0xFF16 => reg_result("NR21 (LEN)", num),
                0xFF17 => reg_result("NR22 (ENV)", num),
                0xFF18 => reg_result("NR23 (LOW)", num),
                0xFF19 => reg_result("NR24 (HIGH)", num),
                0xFF1A => reg_result("NR30 (ENA)", num),
                0xFF1B => reg_result("NR31 (LEN)", num),
                0xFF1C => reg_result("NR32 (LVL)", num),
                0xFF1D => reg_result("NR33 (LOW)", num),
                0xFF1E => reg_result("NR34 (HIGH)", num),
                0xFF20 => reg_result("NR41 (LEN)", num),
                0xFF21 => reg_result("NR42 (ENV)", num),
                0xFF22 => reg_result("NR43 (POLY)", num),
                0xFF23 => reg_result("NR44 (GO)", num),
                0xFF24 => reg_result("NR50 (VOL)", num),
                0xFF25 => reg_result("NR51 (TERM)", num),
                0xFF26 => reg_result("NR52 (MENA)", num),
                0xFF30 | 0xFF31 | 0xFF32 | 0xFF34 | 0xFF35 | 0xFF36 | 0xFF37 | 0xFF38 |
                0xFF39 | 0xFF3A | 0xFF3B | 0xFF3C | 0xFF3D | 0xFF3E | 0xFF3F => reg_result("SRAM", num - 0xFF30),
                0xFF40 => reg_result("LCDC", num),
                0xFF41 => reg_result("STAT", num),
                0xFF42 => reg_result("SCY", num),
                0xFF43 => reg_result("SCX", num),
                0xFF44 => reg_result("LY", num),
                0xFF45 => reg_result("LYC", num),
                0xFF46 => reg_result("ODMA", num),
                0xFF47 => reg_result("BGP", num),
                0xFF48 => reg_result("OBP0", num),
                0xFF49 => reg_result("OBP1", num),
                0xFF4A => reg_result("WY", num),
                0xFF4B => reg_result("WX", num),
                0xFF4C => reg_result("KEY0 (SYS)", num),
                0xFF4D => reg_result("KEY1 (SPD)", num),
                0xFF4F => reg_result("VBK", num),
                0xFF50 => reg_result("BANK", num),
                0xFF51 => reg_result("HDMA1 (SHIGH)", num),
                0xFF52 => reg_result("HDMA2 (SLOW)", num),
                0xFF53 => reg_result("HDMA3 (DHIGH)", num),
                0xFF54 => reg_result("HDMA4 (DLOW)", num),
                0xFF55 => reg_result("HDMA5 (LEN)", num),
                0xFF56 => reg_result("RP", num),
                0xFF68 => reg_result("BGPI", num),
                0xFF69 => reg_result("BGPD", num),
                0xFF6A => reg_result("OBPI", num),
                0xFF6B => reg_result("OBPD", num),
                0xFF6C => reg_result("OPRI", num),
                0xFF70 => reg_result("SVBK (WBK)", num),
                0xFF76 => reg_result("PCM12", num),
                0xFF77 => reg_result("PCM34", num),
                0xFFFF => reg_result("IE", num),
                _ => TranslationResult { 
                    val: ValueRepr::String(format!("INVALID: {:#04X}", num)), 
                    subfields: vec![], 
                    kind: ValueKind::Custom(Color32::from_rgb(0x50, 0x00, 0x00))
                }
            }
        }
    )
}

#[plugin_fn]
pub fn variable_info(_variable: VariableMeta<(), ()>) -> FnResult<VariableInfo> {
    Ok(VariableInfo::String)
}