//! The standard security handler: an encryption dictionary, password handling for revisions 2
//! to 6, and decryption of a string and a stream.
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_core::fuzzing::security_handler(input);
});
