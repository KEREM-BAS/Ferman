//! What a file is when it is not a PDF (a1-9c): the sentence is always "That file isn't a PDF.",
//! and the kind goes into the technical details.

/// How far into a file the PDF header may start, as PDFium looks for it.
pub const HEADER_WINDOW: usize = 1024;

/// What a file that is not a PDF looks like.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum FileKind {
    /// No bytes at all.
    Empty,
    /// A ZIP archive: Word, Excel and PowerPoint since 2007, OpenDocument, or a plain archive.
    Zip,
    /// A compound file: Word, Excel and PowerPoint before 2007.
    CompoundFile,
    /// Rich Text Format.
    Rtf,
    /// A PNG image.
    Png,
    /// A JPEG image.
    Jpeg,
    /// A GIF image.
    Gif,
    /// A TIFF image.
    Tiff,
    /// A WebP image.
    Webp,
    /// A BMP image.
    Bmp,
    /// A HEIF or HEIC image.
    Heif,
    /// A PostScript file.
    PostScript,
    /// An HTML page.
    Html,
    /// Anything else.
    Unknown,
}

/// Where the PDF header `%PDF-` starts, if it is in the first [`HEADER_WINDOW`] bytes.
#[must_use]
pub fn header_offset(bytes: &[u8]) -> Option<usize> {
    let window = bytes.get(..bytes.len().min(HEADER_WINDOW.saturating_add(5)))?;
    window.windows(5).position(|five| five == b"%PDF-")
}

/// What `bytes` look like, for a file without a PDF header.
#[must_use]
pub fn kind(bytes: &[u8]) -> FileKind {
    let starts = |magic: &[u8]| bytes.starts_with(magic);
    if bytes.is_empty() {
        FileKind::Empty
    } else if starts(b"PK\x03\x04") || starts(b"PK\x05\x06") {
        FileKind::Zip
    } else if starts(&[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) {
        FileKind::CompoundFile
    } else if starts(b"{\\rtf") {
        FileKind::Rtf
    } else if starts(&[0x89, b'P', b'N', b'G']) {
        FileKind::Png
    } else if starts(&[0xFF, 0xD8, 0xFF]) {
        FileKind::Jpeg
    } else if starts(b"GIF87a") || starts(b"GIF89a") {
        FileKind::Gif
    } else if starts(b"II*\0") || starts(b"MM\0*") {
        FileKind::Tiff
    } else if starts(b"RIFF") && bytes.get(8..12) == Some(b"WEBP") {
        FileKind::Webp
    } else if starts(b"BM") {
        FileKind::Bmp
    } else if bytes.get(4..8) == Some(b"ftyp")
        && bytes
            .get(8..12)
            .is_some_and(|brand| [&b"heic"[..], b"heix", b"mif1", b"heif"].contains(&brand))
    {
        FileKind::Heif
    } else if starts(b"%!PS") {
        FileKind::PostScript
    } else if looks_like_html(bytes) {
        FileKind::Html
    } else {
        FileKind::Unknown
    }
}

fn looks_like_html(bytes: &[u8]) -> bool {
    let head: Vec<u8> = bytes
        .iter()
        .take(256)
        .skip_while(|byte| byte.is_ascii_whitespace())
        .map(u8::to_ascii_lowercase)
        .collect();
    head.starts_with(b"<!doctype html") || head.starts_with(b"<html")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_header_may_follow_junk_within_the_window() {
        assert_eq!(header_offset(b"%PDF-1.7\n"), Some(0));
        let mut junk = vec![b' '; 1000];
        junk.extend_from_slice(b"%PDF-1.4");
        assert_eq!(header_offset(&junk), Some(1000));
        let mut far = vec![b' '; 2000];
        far.extend_from_slice(b"%PDF-1.4");
        assert_eq!(header_offset(&far), None);
        assert_eq!(header_offset(b""), None);
    }

    #[test]
    fn office_and_image_files_are_named() {
        assert_eq!(kind(b""), FileKind::Empty);
        assert_eq!(kind(b"PK\x03\x04word/document.xml"), FileKind::Zip);
        assert_eq!(
            kind(&[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0]),
            FileKind::CompoundFile
        );
        assert_eq!(kind(b"{\\rtf1\\ansi"), FileKind::Rtf);
        assert_eq!(kind(&[0x89, b'P', b'N', b'G', 13, 10]), FileKind::Png);
        assert_eq!(kind(&[0xFF, 0xD8, 0xFF, 0xE0]), FileKind::Jpeg);
        assert_eq!(kind(b"GIF89a"), FileKind::Gif);
        assert_eq!(kind(b"II*\0"), FileKind::Tiff);
        assert_eq!(kind(b"RIFF\0\0\0\0WEBPVP8 "), FileKind::Webp);
        assert_eq!(kind(b"BM\0\0"), FileKind::Bmp);
        assert_eq!(kind(b"\0\0\0\x18ftypheic"), FileKind::Heif);
        assert_eq!(kind(b"%!PS-Adobe-3.0"), FileKind::PostScript);
        assert_eq!(kind(b"\n <!DOCTYPE html><html>"), FileKind::Html);
        assert_eq!(kind(b"just text"), FileKind::Unknown);
    }
}
