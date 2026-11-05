"""The widths of the twelve Latin standard 14 fonts, for ferman-text.

A PDF may name Courier, Helvetica or Times without embedding them and without /Widths
(ISO 32000-2 §9.6.2.2); a reader then takes the standard metrics. Ferman positions text with
the widths PDFium draws, so this script measures them with the pinned PDFium library: for
each font it draws every character of the Latin tables Ferman's encodings know (Basic Latin,
Latin-1, Latin Extended-A and the other characters of StandardEncoding, WinAnsiEncoding and
MacRomanEncoding) twice on a line at 100 points through a /Differences name `uniXXXX`, reads
the two origins back through PDFium's text API and writes the advance in thousandths of an em.
A character the font does not have draws `.notdef`; its advance and box are measured too, and
such characters are left out. PDFium's standard fonts are metric-compatible with Adobe's Core14
AFM files, so the numbers are the AFM widths.

It uses only the Python standard library and ctypes. Run it in isolated mode:

    python3 -I tools/standard14/generate.py <absolute path to libpdfium> [output]

The output defaults to crates/ferman-text/src/standard14.rs. Symbol and ZapfDingbats are not
measured: their built-in encodings arrive with the fonts that need them.
"""

from __future__ import annotations

import ctypes
import pathlib
import sys

FONTS = [
    "Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique",
    "Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique",
    "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic",
]

# Every character Ferman's simple encodings can name (crates/ferman-fonts/src/encoding.rs).
CHARS = (
    [chr(c) for c in range(0x20, 0x7F)]
    + [chr(c) for c in range(0xA0, 0x180)]
    + list("ƒˆˇ˘˙˚˛˜˝–—‘’‚“”„†‡•…‰‹›⁄€™−∆∏∑√∞∫≈≠≤≥∂◊ΩπﬁﬂŸ")
)
CHARS = sorted(set(CHARS))

SIZE = 100
PITCH = 120
PER_PAGE = 110
NOTDEF = "zzzz.notdef.probe"


def pdf(font: str, names: list[str]) -> bytes:
    """One page drawing each glyph name twice on its own line."""
    diffs = " ".join("/" + name for name in names)
    lines = [
        "BT /F1 %d Tf 10 %d Td <%02X%02X> Tj ET" % (SIZE, 14000 - PITCH * i, i + 1, i + 1)
        for i in range(len(names))
    ]
    content = "\n".join(lines).encode()
    objects = [
        b"<</Type/Catalog/Pages 2 0 R>>",
        b"<</Type/Pages/Kids[3 0 R]/Count 1>>",
        b"<</Type/Page/Parent 2 0 R/MediaBox[0 0 1000 14400]"
        b"/Resources<</Font<</F1 5 0 R>>>>/Contents 4 0 R>>",
        b"<</Length %d>>stream\n" % len(content) + content + b"\nendstream",
        (
            "<</Type/Font/Subtype/Type1/BaseFont/%s"
            "/Encoding<</Type/Encoding/Differences[1 %s]>>>>" % (font, diffs)
        ).encode(),
    ]
    out = b"%PDF-1.4\n"
    offsets = []
    for number, body in enumerate(objects, 1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % number + body + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    out += b"".join(b"%010d 00000 n \n" % offset for offset in offsets)
    out += b"trailer\n<</Size %d/Root 1 0 R>>\nstartxref\n%d\n%%%%EOF\n" % (
        len(objects) + 1,
        xref,
    )
    return out


class Pdfium:
    def __init__(self, path: str) -> None:
        lib = ctypes.CDLL(path)
        lib.FPDF_InitLibrary()
        lib.FPDF_LoadMemDocument.restype = ctypes.c_void_p
        lib.FPDF_LoadMemDocument.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p]
        lib.FPDF_CloseDocument.argtypes = [ctypes.c_void_p]
        lib.FPDF_LoadPage.restype = ctypes.c_void_p
        lib.FPDF_LoadPage.argtypes = [ctypes.c_void_p, ctypes.c_int]
        lib.FPDF_ClosePage.argtypes = [ctypes.c_void_p]
        lib.FPDFText_LoadPage.restype = ctypes.c_void_p
        lib.FPDFText_LoadPage.argtypes = [ctypes.c_void_p]
        lib.FPDFText_ClosePage.argtypes = [ctypes.c_void_p]
        lib.FPDFText_CountChars.argtypes = [ctypes.c_void_p]
        double = ctypes.POINTER(ctypes.c_double)
        lib.FPDFText_GetCharOrigin.argtypes = [ctypes.c_void_p, ctypes.c_int, double, double]
        lib.FPDFText_GetCharBox.argtypes = [ctypes.c_void_p, ctypes.c_int] + [double] * 4
        self.lib = lib

    def measure(self, font: str, names: list[str]) -> list[tuple[int, tuple[float, ...]]]:
        """Each name's advance in thousandths of an em and its first glyph's box from its origin."""
        lib = self.lib
        data = pdf(font, names)
        doc = lib.FPDF_LoadMemDocument(data, len(data), None)
        if not doc:
            raise SystemExit("PDFium could not open the probe for %s" % font)
        page = lib.FPDF_LoadPage(doc, 0)
        text = lib.FPDFText_LoadPage(page)
        rows: dict[float, list[tuple[float, tuple[float, ...]]]] = {}
        for i in range(lib.FPDFText_CountChars(text)):
            x, y = ctypes.c_double(), ctypes.c_double()
            lib.FPDFText_GetCharOrigin(text, i, ctypes.byref(x), ctypes.byref(y))
            box = [ctypes.c_double() for _ in range(4)]
            lib.FPDFText_GetCharBox(text, i, *[ctypes.byref(v) for v in box])
            left, right, bottom, top = (v.value for v in box)
            rows.setdefault(round(y.value, 2), []).append(
                (x.value, (left - x.value, right - x.value, bottom - y.value, top - y.value))
            )
        lib.FPDFText_ClosePage(text)
        lib.FPDF_ClosePage(page)
        lib.FPDF_CloseDocument(doc)
        out = []
        for i in range(len(names)):
            row = rows.get(round(14000.0 - PITCH * i, 2))
            if not row:
                raise SystemExit("no text for line %d of %s" % (i, font))
            x0, box = row[0]
            later = [x for x, _ in row if x > x0 + 1e-3]
            if not later:
                raise SystemExit("no advance for line %d of %s" % (i, font))
            out.append((round((min(later) - x0) * 1000 / SIZE), tuple(round(v, 1) for v in box)))
        return out


def widths(pdfium: Pdfium, font: str) -> list[tuple[str, int]]:
    notdef = pdfium.measure(font, [NOTDEF])[0]
    found = []
    for start in range(0, len(CHARS), PER_PAGE):
        chunk = CHARS[start:start + PER_PAGE]
        measured = pdfium.measure(font, ["uni%04X" % ord(c) for c in chunk])
        for c, (width, box) in zip(chunk, measured):
            if (width, box) != notdef or c == " ":
                found.append((c, width))
    return found


def literal(c: str) -> str:
    if c in "\\'":
        return "'\\%s'" % c
    if c.isprintable() and c != " " and c != "­":
        return "'%s'" % c
    return "'\\u{%X}'" % ord(c)


def render(tables: dict[str, list[tuple[str, int]]]) -> str:
    names: dict[tuple, str] = {}
    statics = []
    rows = []
    for font in FONTS:
        table = tuple(tables[font])
        if table not in names:
            name = font.upper().replace("-", "_")
            names[table] = name
            entries = ["(%s, %d)" % (literal(c), w) for c, w in table]
            body = "\n".join(
                "    " + ", ".join(entries[i:i + 8]) + "," for i in range(0, len(entries), 8)
            )
            statics.append(
                "#[rustfmt::skip]\nstatic %s: [(char, u16); %d] = [\n%s\n];\n"
                % (name, len(table), body)
            )
        rows.append('    ("%s", &%s),' % (font, names[table]))
    return (
        "//! The advance widths of the twelve Latin standard 14 fonts in thousandths of an em, by\n"
        "//! character, sorted: generated by `tools/standard14/generate.py` from the pinned PDFium\n"
        "//! (chromium/7881), whose standard fonts match Adobe's Core14 AFM metrics. Do not edit;\n"
        "//! rerun the script (THIRD_PARTY_NOTICES.md, docs/DEPENDENCIES.md).\n\n"
        "/// Each font's `/BaseFont` and its widths.\n"
        "static FONTS: [(&str, &[(char, u16)]); %d] = [\n%s\n];\n\n%s\n%s"
        % (len(FONTS), "\n".join(rows), LOOKUP, "\n".join(statics))
    )


LOOKUP = '''/// The widths of the standard 14 font `base_font` names, a subset tag before the name or not.
pub(crate) fn widths(base_font: Option<&str>) -> Option<&'static [(char, u16)]> {
    let name = base_font?;
    let name = name.split_once('+').map_or(name, |(_, name)| name);
    FONTS
        .iter()
        .find(|(font, _)| *font == name)
        .map(|(_, widths)| *widths)
}

/// The width of `c` in `widths`, in thousandths of an em.
pub(crate) fn width(widths: &[(char, u16)], c: char) -> Option<f32> {
    let at = widths.binary_search_by_key(&c, |&(c, _)| c).ok()?;
    widths.get(at).map(|&(_, width)| f32::from(width))
}
'''


def main() -> None:
    if len(sys.argv) not in (2, 3) or not pathlib.Path(sys.argv[1]).is_absolute():
        raise SystemExit(__doc__)
    root = pathlib.Path(__file__).resolve().parents[2]
    output = pathlib.Path(sys.argv[2]) if len(sys.argv) == 3 else (
        root / "crates" / "ferman-text" / "src" / "standard14.rs"
    )
    pdfium = Pdfium(sys.argv[1])
    output.write_text(render({font: widths(pdfium, font) for font in FONTS}), encoding="utf-8")


if __name__ == "__main__":
    main()
