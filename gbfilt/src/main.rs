pub mod reg;
pub mod helpers;

use text_io::read;

use crate::helpers::RunState;

fn main() {
    let mut state = RunState{
        prefix: false,
        imm8: false,
        imm16: false,
        imm: None
    };
    loop {
        let line: String = read!("{}\n");
        state.decode(&line);
    }
}
