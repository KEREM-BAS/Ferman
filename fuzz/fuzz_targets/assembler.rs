//! The assembler's walk across documents (`ferman_core::assemble`): cycles and deep trees stop at a
//! limit, and what it writes opens with the pages it was given.
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_core::fuzzing::assembler(input);
});
