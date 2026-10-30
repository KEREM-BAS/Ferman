//! The content-stream lexer (`ferman_core::content`): operators, their operands and spans, and
//! inline images on arbitrary bytes.
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_core::fuzzing::content_lexer(input);
});
