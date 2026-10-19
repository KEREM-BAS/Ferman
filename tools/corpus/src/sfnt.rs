//! Adds a `cmap` table to a TrueType subset. subsetter leaves it out, because a CID font in a
//! PDF does not need it, but a simple TrueType font with `/WinAnsiEncoding` does: a reader maps
//! each code to a character and then through the (3,1) `cmap` to a glyph.

use std::collections::BTreeMap;

fn be16(data: &[u8], at: usize) -> Option<u16> {
    Some(u16::from_be_bytes([*data.get(at)?, *data.get(at + 1)?]))
}

fn be32(data: &[u8], at: usize) -> Option<u32> {
    Some(u32::from_be_bytes([
        *data.get(at)?,
        *data.get(at + 1)?,
        *data.get(at + 2)?,
        *data.get(at + 3)?,
    ]))
}

/// The OpenType table checksum: the sum of the big-endian `u32`s, zero padded.
fn checksum(data: &[u8]) -> u32 {
    data.chunks(4).fold(0u32, |sum, chunk| {
        let mut word = [0u8; 4];
        word[..chunk.len()].copy_from_slice(chunk);
        sum.wrapping_add(u32::from_be_bytes(word))
    })
}

/// A `cmap` table with one (3,1) format 4 subtable for `map` (character → glyph). Characters
/// outside the Basic Multilingual Plane are left out; every segment holds one character.
fn cmap_table(map: &BTreeMap<char, u16>) -> Result<Vec<u8>, String> {
    let mut segments: Vec<(u16, u16)> = map
        .iter()
        .filter_map(|(c, gid)| u16::try_from(u32::from(*c)).ok().map(|code| (code, *gid)))
        .filter(|(code, _)| *code != 0xFFFF)
        .collect();
    segments.push((0xFFFF, 0));
    let count = u16::try_from(segments.len()).map_err(|_| "cmap: too many characters")?;
    let mut search = 1u16;
    let mut selector = 0u16;
    while search * 2 <= count {
        search *= 2;
        selector += 1;
    }
    let length = 16 + 8 * usize::from(count);
    let mut sub = Vec::with_capacity(length);
    for value in [
        4,
        u16::try_from(length).map_err(|_| "cmap: too long")?,
        0,
        count * 2,
        search * 2,
        selector,
        count * 2 - search * 2,
    ] {
        sub.extend_from_slice(&value.to_be_bytes());
    }
    for (code, _) in &segments {
        sub.extend_from_slice(&code.to_be_bytes());
    }
    sub.extend_from_slice(&0u16.to_be_bytes());
    for (code, _) in &segments {
        sub.extend_from_slice(&code.to_be_bytes());
    }
    for (code, gid) in &segments {
        let delta = if *code == 0xFFFF {
            1
        } else {
            gid.wrapping_sub(*code)
        };
        sub.extend_from_slice(&delta.to_be_bytes());
    }
    for _ in &segments {
        sub.extend_from_slice(&0u16.to_be_bytes());
    }
    let mut table = Vec::with_capacity(12 + sub.len());
    for value in [0u16, 1, 3, 1] {
        table.extend_from_slice(&value.to_be_bytes());
    }
    table.extend_from_slice(&12u32.to_be_bytes());
    table.extend_from_slice(&sub);
    Ok(table)
}

/// `font` with a (3,1) `cmap` for `map`, replacing any `cmap` it has, with the table directory,
/// checksums and `head.checkSumAdjustment` rewritten.
///
/// # Errors
///
/// A message when `font` is not a single TrueType font.
pub fn with_cmap(font: &[u8], map: &BTreeMap<char, u16>) -> Result<Vec<u8>, String> {
    let malformed = || "sfnt: malformed font".to_owned();
    let version = be32(font, 0).ok_or_else(malformed)?;
    let tables = be16(font, 4).ok_or_else(malformed)?;
    let mut entries: BTreeMap<[u8; 4], Vec<u8>> = BTreeMap::new();
    for index in 0..usize::from(tables) {
        let record = 12 + 16 * index;
        let tag: [u8; 4] = font
            .get(record..record + 4)
            .and_then(|tag| tag.try_into().ok())
            .ok_or_else(malformed)?;
        let offset = usize::try_from(be32(font, record + 8).ok_or_else(malformed)?)
            .map_err(|_| malformed())?;
        let length = usize::try_from(be32(font, record + 12).ok_or_else(malformed)?)
            .map_err(|_| malformed())?;
        let data = font.get(offset..offset + length).ok_or_else(malformed)?;
        entries.insert(tag, data.to_vec());
    }
    entries.insert(*b"cmap", cmap_table(map)?);
    if let Some(head) = entries.get_mut(b"head") {
        head.get_mut(8..12).ok_or_else(malformed)?.fill(0);
    }

    let count = u16::try_from(entries.len()).map_err(|_| malformed())?;
    let mut search = 1u16;
    let mut selector = 0u16;
    while search * 2 <= count {
        search *= 2;
        selector += 1;
    }
    let mut out = Vec::new();
    out.extend_from_slice(&version.to_be_bytes());
    for value in [count, search * 16, selector, count * 16 - search * 16] {
        out.extend_from_slice(&value.to_be_bytes());
    }
    let mut offset = 12 + 16 * entries.len();
    let mut head_at = None;
    for (tag, data) in &entries {
        out.extend_from_slice(tag);
        out.extend_from_slice(&checksum(data).to_be_bytes());
        out.extend_from_slice(
            &u32::try_from(offset)
                .map_err(|_| malformed())?
                .to_be_bytes(),
        );
        out.extend_from_slice(
            &u32::try_from(data.len())
                .map_err(|_| malformed())?
                .to_be_bytes(),
        );
        if tag == b"head" {
            head_at = Some(offset);
        }
        offset += data.len().div_ceil(4) * 4;
    }
    for data in entries.values() {
        out.extend_from_slice(data);
        out.resize(out.len().div_ceil(4) * 4, 0);
    }
    if let Some(at) = head_at {
        let adjustment = 0xB1B0_AFBAu32.wrapping_sub(checksum(&out));
        out.get_mut(at + 8..at + 12)
            .ok_or_else(malformed)?
            .copy_from_slice(&adjustment.to_be_bytes());
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use skrifa::raw::FontRead as _;

    #[test]
    fn the_cmap_maps_each_character() {
        let map: BTreeMap<char, u16> = [('A', 1), ('ü', 2)].into_iter().collect();
        let table = cmap_table(&map).unwrap_or_default();
        // Three segments: A, ü and the final 0xFFFF.
        assert_eq!(be16(&table, 12 + 6), Some(6));
        let font = skrifa::raw::tables::cmap::Cmap4::read(skrifa::raw::FontData::new(&table[12..]));
        assert!(font.is_ok());
        let cmap4 = font.unwrap_or_else(|_| unreachable!());
        assert_eq!(cmap4.map_codepoint('A').map(|g| g.to_u32()), Some(1));
        assert_eq!(cmap4.map_codepoint('ü').map(|g| g.to_u32()), Some(2));
        assert_eq!(cmap4.map_codepoint('B'), None);
    }
}
