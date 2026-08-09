use shared_helpers::helpers::*;

use std::io::{self, Write};

fn main() {
    let mut state = RunState{
        prefix: false,
        imm8: false,
        imm16: false,
        imm: None
    };
    let input = io::stdin();
    let mut buf = String::new();

    loop {
        match input.read_line(&mut buf) {
            Ok(0) |
            Ok(1) |
            Err(_) => break,
            Ok(_) => println!("{}", state.decode(buf.trim()))
        }
        buf.clear();
        io::stdout().flush().expect("should not happen");
    }

}
