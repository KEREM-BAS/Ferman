//! ASCIIHexDecode on arbitrary bytes.
#![no_main]

use ferman_core::filters::{DecodeParams, Filter};
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    ferman_fuzz::check_filter(Filter::AsciiHex, &DecodeParams::default(), data);
});
