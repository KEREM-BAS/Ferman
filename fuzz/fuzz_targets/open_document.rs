//! The whole open path on arbitrary bytes: header, cross-reference data, repair, security, lopdf
//! and the structure scan.
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_core::fuzzing::open_document(input);
});
