//! The text interpreter (`ferman_core::interpret`): arbitrary bytes as a page's content and as a
//! form the page draws, which may draw itself.
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_core::fuzzing::interpreter(input);
});
