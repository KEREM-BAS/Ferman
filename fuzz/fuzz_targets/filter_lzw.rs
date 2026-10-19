//! LZWDecode, with `/DecodeParms` from the first four bytes on arbitrary bytes.
#![no_main]

use ferman_core::filters::Filter;
use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    let (params, data) = ferman_fuzz::split_params(input);
    ferman_fuzz::check_filter(Filter::Lzw, &params, data);
});
