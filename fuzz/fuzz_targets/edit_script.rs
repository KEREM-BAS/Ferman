//! Edit scripts: random operations on random blocks of corpus pages (`ferman_fuzz::edit_script`).
#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    ferman_fuzz::edit_script::run(input);
});
