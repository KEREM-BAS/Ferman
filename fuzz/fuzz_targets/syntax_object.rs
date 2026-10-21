//! The object parser (`ferman_core::syntax`): a direct object and an indirect object on arbitrary
//! bytes.
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_core::fuzzing::syntax_object(input);
});
