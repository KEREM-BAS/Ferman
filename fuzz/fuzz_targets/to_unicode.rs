//! ToUnicode writing (`ferman_fonts::with_text`): entries added to a new CMap or to arbitrary bytes
//! as the original. Read back, an added code has its text and an original code keeps its own, or
//! copying and search break on the edited text.
#![no_main]

use ferman_fonts::{CMap, with_text};
use libfuzzer_sys::fuzz_target;

/// Each entry of `input`: a length byte (one to four bytes of code), the code, and three bytes
/// that make its one character. Two codes never share a number: `CMap::text` looks up by number.
fn entries(mut input: &[u8]) -> Vec<(u32, Vec<u8>, String)> {
    let mut out: Vec<(u32, Vec<u8>, String)> = Vec::new();
    while let Some((&length, rest)) = input.split_first() {
        let length = usize::from(length % 4) + 1;
        let Some((code, rest)) = rest.split_at_checked(length) else {
            break;
        };
        let Some((&[a, b, c], rest)) = rest.split_first_chunk::<3>() else {
            break;
        };
        input = rest;
        let number = code.iter().fold(0, |sum, &byte| sum << 8 | u32::from(byte));
        let value = u32::from_be_bytes([0, a & 0x1F, b, c]);
        if let Some(text) = char::from_u32(value)
            && out.iter().all(|(other, ..)| *other != number)
        {
            out.push((number, code.to_vec(), text.to_string()));
        }
    }
    out
}

fn added(list: &[(u32, Vec<u8>, String)]) -> Vec<(Vec<u8>, String)> {
    list.iter()
        .map(|(_, code, text)| (code.clone(), text.clone()))
        .collect()
}

fuzz_target!(|input: &[u8]| {
    let Some((&[high, low], rest)) = input.split_first_chunk::<2>() else {
        return;
    };
    let at = usize::from(u16::from_be_bytes([high, low])).min(rest.len());
    let (original, rest) = rest.split_at(at);
    let list = entries(rest);

    let written = CMap::parse(&with_text(None, &added(&list)));
    for (number, code, text) in &list {
        assert_eq!(
            written.text(*number).as_ref(),
            Some(text),
            "new CMap, code {code:?}"
        );
    }

    // `with_text` promises nothing for a code the original already maps.
    let before = CMap::parse(original);
    let fresh: Vec<_> = list
        .into_iter()
        .filter(|(number, ..)| before.text(*number).is_none())
        .collect();
    let after = CMap::parse(&with_text(Some(original), &added(&fresh)));
    for (number, code, text) in &fresh {
        assert_eq!(
            after.text(*number).as_ref(),
            Some(text),
            "added code {code:?}"
        );
    }
    for (code, _) in before.codes(original).take(256) {
        if let Some(text) = before.text(code) {
            assert_eq!(after.text(code), Some(text), "original code {code}");
        }
    }
});
