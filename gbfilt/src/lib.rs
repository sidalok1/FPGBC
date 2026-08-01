use extism_pdk::{FnResult, plugin_fn};
pub use surfer_translation_types::plugin_types::TranslateParams;
use surfer_translation_types::{
    TranslationPreference, TranslationResult, ValueKind, ValueRepr, VariableInfo, VariableMeta, VariableValue
};
pub mod helpers;
pub mod reg;
use crate::helpers::RunState;
// use std::sync::Mutex;

// static COUNT: Mutex<i32> = Mutex::new(0);

#[plugin_fn]
pub fn new() -> FnResult<()> {
    Ok(())
}

#[plugin_fn]
pub fn name() -> FnResult<String> {
    Ok(String::from("GameBoy CPU ISA Translator"))
}

#[plugin_fn]
pub fn translates(variable: VariableMeta<(), ()>) -> FnResult<TranslationPreference> {
    match variable.num_bits {
        Some(num_bits) => {
            if num_bits == 9 {
                Ok(TranslationPreference::Yes)
            } else {
                Ok(TranslationPreference::No)
            }
        }
        None => Ok(TranslationPreference::No)
    }
}

#[plugin_fn]
pub fn translate(
    TranslateParams { variable, value }: TranslateParams,
) -> FnResult<TranslationResult> {
    let binary_digits = match value {
        VariableValue::BigUint(big_uint) => {
            let raw = format!("{big_uint:b}");
            let padding = (0..((variable.num_bits.unwrap_or_default() as usize)
                .saturating_sub(raw.len())))
                .map(|_| "0")
                .collect::<Vec<_>>()
                .join("");

            format!("{padding}{raw}")
        }
        VariableValue::String(v) => v.clone(),
    };
    let prefixed = binary_digits.chars().nth(0) == Some('1');
    let hex = String::from(format!("{:02X}", u8::from_str_radix(&binary_digits[1..9], 2).unwrap()));
    let mut state = RunState{
        prefix: prefixed,
        imm8: false,
        imm16: false,
        imm: None
    };
    let instruction = state.decode(&hex);
    Ok(TranslationResult { 
        val: ValueRepr::String(instruction.to_string()), 
        subfields: vec![], 
        kind: ValueKind::Custom(instruction.get_color())
    })
}

#[plugin_fn]
pub fn variable_info(_variable: VariableMeta<(), ()>) -> FnResult<VariableInfo> {
    Ok(VariableInfo::String)
}