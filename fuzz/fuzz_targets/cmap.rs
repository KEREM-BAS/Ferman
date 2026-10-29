//! The CMap reader (`ferman_fonts::cmap`): an encoding or ToUnicode CMap from arbitrary bytes, then
//! the same bytes split into codes, each looked up. Every byte belongs to one code.
#![no_main]

use ferman_fonts::CMap;
use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    let cmap = CMap::parse(input);
    let mut length = 0_usize;
    for (code, size) in cmap.codes(input) {
        assert!((1..=4).contains(&size), "a code of {size} bytes");
        length += size;
        let _ = (cmap.cid(code, size), cmap.text(code));
    }
    assert_eq!(length, input.len(), "the codes do not cover the string");
});
