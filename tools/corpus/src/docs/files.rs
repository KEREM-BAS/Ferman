//! Files the documents attach or show: a small spreadsheet (a zip with stored entries) and
//! greyscale JPEGs whose 8×8 blocks each hold one grey level, enough for a photocopy-like
//! picture without a full JPEG encoder.

/// The DOS time and date of every zip entry: 13 October 2026, 09:30.
const DOS_TIME: u16 = (9 << 11) | (30 << 5);
const DOS_DATE: u16 = ((2026 - 1980) << 9) | (10 << 5) | 13;

/// The CRC-32 of zip (IEEE 802.3, reflected).
fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xFFFF_FFFFu32;
    for &byte in data {
        crc ^= u32::from(byte);
        for _ in 0..8 {
            let mask = (crc & 1).wrapping_neg();
            crc = (crc >> 1) ^ (0xEDB8_8320 & mask);
        }
    }
    !crc
}

fn push16(out: &mut Vec<u8>, value: u16) {
    out.extend_from_slice(&value.to_le_bytes());
}

fn push32(out: &mut Vec<u8>, value: u32) {
    out.extend_from_slice(&value.to_le_bytes());
}

/// A zip archive of `entries` (name, bytes), stored without compression.
///
/// # Errors
///
/// A message when an entry or the archive is too large for a zip without zip64.
pub fn zip(entries: &[(&str, Vec<u8>)]) -> Result<Vec<u8>, String> {
    let too_large = |_| "zip: too large".to_owned();
    let mut out = Vec::new();
    let mut central = Vec::new();
    for (name, data) in entries {
        let offset = u32::try_from(out.len()).map_err(too_large)?;
        let size = u32::try_from(data.len()).map_err(too_large)?;
        let name_len = u16::try_from(name.len()).map_err(too_large)?;
        let crc = crc32(data);
        push32(&mut out, 0x0403_4B50);
        for value in [20, 0x0800, 0, DOS_TIME, DOS_DATE] {
            push16(&mut out, value);
        }
        for value in [crc, size, size] {
            push32(&mut out, value);
        }
        push16(&mut out, name_len);
        push16(&mut out, 0);
        out.extend_from_slice(name.as_bytes());
        out.extend_from_slice(data);

        push32(&mut central, 0x0201_4B50);
        for value in [20, 20, 0x0800, 0, DOS_TIME, DOS_DATE] {
            push16(&mut central, value);
        }
        for value in [crc, size, size] {
            push32(&mut central, value);
        }
        for value in [name_len, 0, 0, 0, 0] {
            push16(&mut central, value);
        }
        push32(&mut central, 0);
        push32(&mut central, offset);
        central.extend_from_slice(name.as_bytes());
    }
    let count = u16::try_from(entries.len()).map_err(too_large)?;
    let central_offset = u32::try_from(out.len()).map_err(too_large)?;
    let central_size = u32::try_from(central.len()).map_err(too_large)?;
    out.extend_from_slice(&central);
    push32(&mut out, 0x0605_4B50);
    for value in [0, 0, count, count] {
        push16(&mut out, value);
    }
    push32(&mut out, central_size);
    push32(&mut out, central_offset);
    push16(&mut out, 0);
    Ok(out)
}

/// A spreadsheet cell.
#[derive(Debug, Clone, Copy)]
pub enum Cell<'a> {
    /// Text.
    Text(&'a str),
    /// A number.
    Number(f64),
}

fn xml_escape(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

/// The column letter of a zero-based index below 26.
fn column(index: usize) -> char {
    char::from(b'A' + u8::try_from(index % 26).unwrap_or(0))
}

/// An Office Open XML workbook with one sheet of `rows`.
///
/// # Errors
///
/// A message when the archive cannot be written.
pub fn xlsx(sheet: &str, rows: &[Vec<Cell<'_>>]) -> Result<Vec<u8>, String> {
    const HEAD: &str = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#;
    const MAIN: &str = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    const RELS: &str = "http://schemas.openxmlformats.org/package/2006/relationships";
    const DOC: &str = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
    let types = format!(
        r#"{HEAD}<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>"#
    );
    let root_rels = format!(
        r#"{HEAD}<Relationships xmlns="{RELS}"><Relationship Id="rId1" Type="{DOC}/officeDocument" Target="xl/workbook.xml"/></Relationships>"#
    );
    let workbook = format!(
        r#"{HEAD}<workbook xmlns="{MAIN}" xmlns:r="{DOC}"><sheets><sheet name="{}" sheetId="1" r:id="rId1"/></sheets></workbook>"#,
        xml_escape(sheet)
    );
    let workbook_rels = format!(
        r#"{HEAD}<Relationships xmlns="{RELS}"><Relationship Id="rId1" Type="{DOC}/worksheet" Target="worksheets/sheet1.xml"/></Relationships>"#
    );
    let mut data = String::new();
    for (row_index, row) in rows.iter().enumerate() {
        let number = row_index + 1;
        data.push_str(&format!(r#"<row r="{number}">"#));
        for (col_index, cell) in row.iter().enumerate() {
            let reference = format!("{}{number}", column(col_index));
            match cell {
                Cell::Text(text) => data.push_str(&format!(
                    r#"<c r="{reference}" t="inlineStr"><is><t>{}</t></is></c>"#,
                    xml_escape(text)
                )),
                Cell::Number(value) => {
                    data.push_str(&format!(r#"<c r="{reference}"><v>{value}</v></c>"#));
                }
            }
        }
        data.push_str("</row>");
    }
    let worksheet =
        format!(r#"{HEAD}<worksheet xmlns="{MAIN}"><sheetData>{data}</sheetData></worksheet>"#);
    zip(&[
        ("[Content_Types].xml", types.into_bytes()),
        ("_rels/.rels", root_rels.into_bytes()),
        ("xl/workbook.xml", workbook.into_bytes()),
        ("xl/_rels/workbook.xml.rels", workbook_rels.into_bytes()),
        ("xl/worksheets/sheet1.xml", worksheet.into_bytes()),
    ])
}

/// Writes bits most significant first, with JPEG's byte stuffing.
struct Bits {
    out: Vec<u8>,
    byte: u8,
    count: u8,
}

impl Bits {
    fn push(&mut self, value: u32, length: u8) {
        for shift in (0..length).rev() {
            let bit = u8::from((value >> shift) & 1 == 1);
            self.byte = (self.byte << 1) | bit;
            self.count += 1;
            if self.count == 8 {
                self.out.push(self.byte);
                if self.byte == 0xFF {
                    self.out.push(0);
                }
                self.byte = 0;
                self.count = 0;
            }
        }
    }

    fn finish(mut self) -> Vec<u8> {
        while self.count != 0 {
            self.push(1, 1);
        }
        self.out
    }
}

/// The standard luminance DC table (ITU T.81 Table K.3): code lengths per category 0 to 11.
const DC_COUNTS: [u8; 16] = [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];

/// Canonical Huffman codes (code, length) for categories 0 to 11 from [`DC_COUNTS`].
fn dc_codes() -> [(u32, u8); 12] {
    let mut codes = [(0u32, 0u8); 12];
    let mut code = 0u32;
    let mut symbol = 0usize;
    for (index, count) in DC_COUNTS.iter().enumerate() {
        let length = u8::try_from(index + 1).unwrap_or(16);
        for _ in 0..*count {
            if let Some(slot) = codes.get_mut(symbol) {
                *slot = (code, length);
            }
            code += 1;
            symbol += 1;
        }
        code <<= 1;
    }
    codes
}

/// A baseline greyscale JPEG of `width` × `height` pixels (multiples of 8) at `dpi`, each 8×8
/// block the mean of `pixel` over it. Only DC coefficients are coded; every block ends with an
/// end-of-block code from a two-code AC table.
///
/// # Errors
///
/// A message when a size is not a multiple of 8 or does not fit.
pub fn jpeg(
    width: u16,
    height: u16,
    dpi: u16,
    pixel: impl Fn(u32, u32) -> u8,
) -> Result<Vec<u8>, String> {
    if !width.is_multiple_of(8) || !height.is_multiple_of(8) || width == 0 || height == 0 {
        return Err("jpeg: the size must be a positive multiple of 8".to_owned());
    }
    let mut out = vec![0xFF, 0xD8];
    // JFIF with the density in dots per inch.
    out.extend_from_slice(&[0xFF, 0xE0, 0x00, 0x10, b'J', b'F', b'I', b'F', 0, 1, 1, 1]);
    out.extend_from_slice(&dpi.to_be_bytes());
    out.extend_from_slice(&dpi.to_be_bytes());
    out.extend_from_slice(&[0, 0]);
    // One quantisation table of 16s.
    out.extend_from_slice(&[0xFF, 0xDB, 0x00, 0x43, 0x00]);
    out.extend_from_slice(&[16u8; 64]);
    // Baseline frame, one component.
    out.extend_from_slice(&[0xFF, 0xC0, 0x00, 0x0B, 0x08]);
    out.extend_from_slice(&height.to_be_bytes());
    out.extend_from_slice(&width.to_be_bytes());
    out.extend_from_slice(&[0x01, 0x01, 0x11, 0x00]);
    // DC table 0 and AC table 0 (end of block "00", zero run "01").
    out.extend_from_slice(&[0xFF, 0xC4, 0x00, 0x1F, 0x00]);
    out.extend_from_slice(&DC_COUNTS);
    out.extend_from_slice(&[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    out.extend_from_slice(&[0xFF, 0xC4, 0x00, 0x15, 0x10, 0, 2]);
    out.extend_from_slice(&[0u8; 14]);
    out.extend_from_slice(&[0x00, 0xF0]);
    // Scan.
    out.extend_from_slice(&[0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00]);
    let codes = dc_codes();
    let mut bits = Bits {
        out: Vec::new(),
        byte: 0,
        count: 0,
    };
    let mut previous = 0i32;
    for block_y in 0..u32::from(height / 8) {
        for block_x in 0..u32::from(width / 8) {
            let mut sum = 0u32;
            for y in 0..8 {
                for x in 0..8 {
                    sum += u32::from(pixel(block_x * 8 + x, block_y * 8 + y));
                }
            }
            // DC = 8 × (mean − 128), quantised by 16: (sum / 64 − 128) / 2.
            let mean = i32::try_from(sum / 64).unwrap_or(128);
            let quantised = (mean - 128) / 2;
            let diff = quantised - previous;
            previous = quantised;
            let magnitude = diff.unsigned_abs();
            let category = u8::try_from(32 - magnitude.leading_zeros()).unwrap_or(11);
            let (code, length) = codes[usize::from(category)];
            bits.push(code, length);
            if category > 0 {
                let value = if diff < 0 {
                    u32::try_from(diff - 1 + (1 << category)).unwrap_or(0)
                } else {
                    magnitude
                };
                bits.push(value, category);
            }
            bits.push(0, 2);
        }
    }
    out.extend(bits.finish());
    out.extend_from_slice(&[0xFF, 0xD9]);
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn crc32_matches_the_check_value() {
        assert_eq!(crc32(b"123456789"), 0xCBF4_3926);
    }

    #[test]
    fn a_zip_ends_with_its_directory() {
        let archive = zip(&[("a.txt", b"hello".to_vec())]).unwrap_or_default();
        assert_eq!(&archive[..4], &[0x50, 0x4B, 0x03, 0x04]);
        assert_eq!(
            &archive[archive.len() - 22..archive.len() - 18],
            &[0x50, 0x4B, 0x05, 0x06]
        );
    }

    #[test]
    fn the_dc_codes_are_the_standard_ones() {
        let codes = dc_codes();
        assert_eq!(codes[0], (0b00, 2));
        assert_eq!(codes[1], (0b010, 3));
        assert_eq!(codes[6], (0b1110, 4));
        assert_eq!(codes[11], (0b1_1111_1110, 9));
    }

    #[test]
    fn a_jpeg_has_its_markers() {
        let image = jpeg(16, 8, 300, |x, _| if x < 8 { 255 } else { 0 }).unwrap_or_default();
        assert_eq!(&image[..2], &[0xFF, 0xD8]);
        assert_eq!(&image[image.len() - 2..], &[0xFF, 0xD9]);
        assert!(jpeg(10, 8, 300, |_, _| 0).is_err());
    }
}
