//! Cross-reference tables and streams, `/Prev` chains, and repair by scanning: a rebuilt table
//! must read back clean from the copy lopdf gets.
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_core::fuzzing::xref_repair(input);
});
