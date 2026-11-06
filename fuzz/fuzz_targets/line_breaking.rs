//! Line breaking (`ferman_text::linebreak`): the breaks of arbitrary text ascend, fall between
//! characters, and the last is the end of the text, mandatory. As UTF-8 and as the mixed scripts
//! of `text_from`, where the kinsoku and Hangul tailoring apply.
#![no_main]

use ferman_fuzz::text_from;
use ferman_text::{Break, breaks};
use libfuzzer_sys::fuzz_target;

fn check(text: &str) {
    let found = breaks(text);
    assert_eq!(found.last(), Some(&(text.len(), Break::Mandatory)));
    assert!(
        found.windows(2).all(|pair| pair[0].0 < pair[1].0),
        "{found:?}"
    );
    assert!(found.iter().all(|&(at, _)| text.is_char_boundary(at)));
}

fuzz_target!(|input: &[u8]| {
    check(&String::from_utf8_lossy(input));
    check(&text_from(input));
});
