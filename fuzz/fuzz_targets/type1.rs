//! The Type1 parser (`ferman_fonts::type1`): a font program's built-in encoding from arbitrary
//! bytes, as a PFB file or a FontFile's clear text. Codes come out once each, in order.
#![no_main]

use ferman_fonts::{BuiltinEncoding, builtin_encoding};
use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    if let Ok(Some(BuiltinEncoding::Codes(codes))) = builtin_encoding(input) {
        assert!(
            codes.windows(2).all(|pair| pair[0].0 < pair[1].0),
            "codes out of order or repeated"
        );
    }
});
