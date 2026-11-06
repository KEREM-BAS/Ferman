//! The recovery journal's reader and the manifest parser on arbitrary bytes.
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_core::fuzzing::recovery_journal(input);
});
