//! The incremental writer: a script of changes to a file, written twice over and read back.
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_core::fuzzing::writer_round_trip(input);
});
