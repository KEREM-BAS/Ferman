"""Coverage and naming report for the bundled IBM Plex fonts.

Reads every TTF under the fonts directory (default: app/assets/fonts) with the Python
standard library only, then:

  * lists each file's family and style from its name table, its OS/2 weight class,
    italic flag and font revision, which the pubspec.yaml declarations must use;
  * checks that each family's cmap covers the scripts Ferman's UI needs: Plex Sans
    covers Turkish, Vietnamese, Cyrillic and Greek; Plex Sans Arabic covers Arabic and
    Persian; Plex Sans Hebrew covers Hebrew; Plex Sans Devanagari covers Devanagari;
  * checks that the golden sample string of ROADMAP M1 step 5 resolves through the UI
    fallback chain without a missing character.

Run it in isolated mode so nothing is imported from the current directory:

    python3 -I tools/fonts/coverage.py [--pubspec] [fonts-dir]

With --pubspec it prints only the `fonts:` block for app/pubspec.yaml, built from the
files' name tables (family), OS/2 weight classes and italic flags.

Exit status: 0 when every check passes, 1 when a required character is missing, 2 on a
usage error.
"""

from __future__ import annotations

import pathlib
import struct
import sys

GOLDEN = "İMZALA ğ ş ı · Tiếng Việt · Русский · Ελληνικά · العربية · فارسی · עברית · हिन्दी"

# The UI fallback chain of fm-additions.css (--font-ui), limited to the bundled families.
FALLBACK_CHAIN = [
    "IBM Plex Sans",
    "IBM Plex Sans Arabic",
    "IBM Plex Sans Hebrew",
    "IBM Plex Sans Devanagari",
]

# Order of the families in the pubspec block; any other family follows alphabetically.
PUBSPEC_ORDER = [
    "IBM Plex Sans",
    "IBM Plex Serif",
    "IBM Plex Mono",
    "IBM Plex Sans Arabic",
    "IBM Plex Sans Hebrew",
    "IBM Plex Sans Devanagari",
]


def chars(text: str) -> list[int]:
    return [ord(c) for c in text]


def span(first: int, last: int, skip: tuple[int, ...] = ()) -> list[int]:
    return [cp for cp in range(first, last + 1) if cp not in skip]


# Every file of the family must map every listed code point.
REQUIRED: dict[str, list[tuple[str, list[int]]]] = {
    "IBM Plex Sans": [
        ("Turkish", chars("İıĞğŞşÇçÖöÜüÂâÎîÛû")),
        ("Vietnamese U+1EA0..U+1EF9", span(0x1EA0, 0x1EF9)),
        (
            "Vietnamese base letters and combining marks",
            chars("ĂăÂâĐđÊêÔôƠơƯư") + [0x0300, 0x0301, 0x0303, 0x0309, 0x0323],
        ),
        ("Cyrillic U+0400..U+045F", span(0x0400, 0x045F)),
        ("Cyrillic Ґ ґ", chars("Ґґ")),
        ("Greek letters", span(0x0391, 0x03A9, skip=(0x03A2,)) + span(0x03B1, 0x03C9)),
        ("Greek tonos and dialytika", chars("ΆΈΉΊΌΎΏΐΪΫάέήίΰϊϋόύώ")),
        ("UI punctuation and currency", chars("·–—‘’“”…€₺")),
    ],
    "IBM Plex Sans Arabic": [
        ("Arabic letters U+0621..U+064A", span(0x0621, 0x063A) + span(0x0641, 0x064A)),
        ("Arabic harakat U+064B..U+0652", span(0x064B, 0x0652)),
        ("Arabic-Indic digits", span(0x0660, 0x0669)),
        ("Persian letters پ چ ژ گ ک ی", chars("پچژگکی")),
        ("Persian digits", span(0x06F0, 0x06F9)),
        ("Arabic punctuation ، ؛ ؟", chars("،؛؟")),
    ],
    "IBM Plex Sans Hebrew": [
        ("Hebrew letters U+05D0..U+05EA", span(0x05D0, 0x05EA)),
        ("Hebrew points U+05B0..U+05BC", span(0x05B0, 0x05BC)),
        ("Hebrew punctuation ־ ׳ ״", chars("־׳״")),
    ],
    "IBM Plex Sans Devanagari": [
        ("Devanagari letters U+0904..U+0939", span(0x0904, 0x0939)),
        ("Devanagari signs and vowel signs U+093C..U+094D", span(0x093C, 0x094D)),
        ("Devanagari digits", span(0x0966, 0x096F)),
        ("Danda and double danda", chars("।॥")),
    ],
}

# Reported, not required: (family, label, code point).
INFO: list[tuple[str, str, int]] = [
    ("IBM Plex Sans Arabic", "ZERO WIDTH NON-JOINER (Persian)", 0x200C),
    ("IBM Plex Sans", "ZERO WIDTH NON-JOINER", 0x200C),
    ("IBM Plex Sans Devanagari", "ZERO WIDTH JOINER", 0x200D),
]


def u16(data: bytes, pos: int) -> int:
    return struct.unpack_from(">H", data, pos)[0]


def i16(data: bytes, pos: int) -> int:
    return struct.unpack_from(">h", data, pos)[0]


def u32(data: bytes, pos: int) -> int:
    return struct.unpack_from(">I", data, pos)[0]


class Font:
    """The parts of a TrueType file that the report needs."""

    def __init__(self, path: pathlib.Path) -> None:
        self.path = path
        self.data = path.read_bytes()
        if self.data[:4] not in (b"\x00\x01\x00\x00", b"true"):
            raise ValueError(f"{path}: not a TrueType file")
        self.tables: dict[str, tuple[int, int]] = {}
        for i in range(u16(self.data, 4)):
            record = 12 + 16 * i
            tag = self.data[record : record + 4].decode("latin-1")
            self.tables[tag] = (u32(self.data, record + 8), u32(self.data, record + 12))
        self.names = self._names()
        self.cmap = self._cmap()
        os2 = self.table("OS/2")
        self.weight_class = u16(os2, 4)
        self.italic = bool(u16(os2, 62) & 0x01)  # fsSelection bit 0
        self.revision = struct.unpack_from(">i", self.table("head"), 4)[0] / 65536

    @property
    def family(self) -> str:
        """The typographic family (name ID 16), else the legacy family (name ID 1)."""
        return self.names.get(16) or self.names.get(1, "?")

    @property
    def style(self) -> str:
        """The typographic subfamily (name ID 17), else the legacy subfamily (name ID 2)."""
        return self.names.get(17) or self.names.get(2, "?")

    def table(self, tag: str) -> bytes:
        offset, length = self.tables[tag]
        return self.data[offset : offset + length]

    def _names(self) -> dict[int, str]:
        data = self.table("name")
        count, strings = u16(data, 2), u16(data, 4)
        windows: dict[int, str] = {}
        mac: dict[int, str] = {}
        for i in range(count):
            platform, encoding, language, name_id, length, offset = struct.unpack_from(
                ">6H", data, 6 + 12 * i
            )
            raw = data[strings + offset : strings + offset + length]
            if platform == 3 and encoding in (0, 1) and language == 0x409:
                windows[name_id] = raw.decode("utf-16-be")
            elif platform == 1 and encoding == 0 and language == 0:
                mac[name_id] = raw.decode("mac_roman")
        return {**mac, **windows}

    def _cmap(self) -> set[int]:
        data = self.table("cmap")
        covered: set[int] = set()
        for i in range(u16(data, 2)):
            platform, encoding, offset = struct.unpack_from(">HHI", data, 4 + 8 * i)
            if not (platform == 0 or (platform == 3 and encoding in (1, 10))):
                continue
            fmt = u16(data, offset)
            if fmt == 4:
                covered |= cmap_format4(data, offset)
            elif fmt == 12:
                covered |= cmap_format12(data, offset)
        return covered


def cmap_format4(data: bytes, offset: int) -> set[int]:
    """Code points mapped to a glyph other than .notdef by a format 4 subtable."""
    segments = u16(data, offset + 6) // 2
    ends = offset + 14
    starts = ends + 2 * segments + 2
    deltas = starts + 2 * segments
    range_offsets = deltas + 2 * segments
    covered: set[int] = set()
    for s in range(segments):
        start, end = u16(data, starts + 2 * s), u16(data, ends + 2 * s)
        delta = i16(data, deltas + 2 * s)
        ro_pos = range_offsets + 2 * s
        range_offset = u16(data, ro_pos)
        for cp in range(start, min(end, 0xFFFE) + 1):
            if range_offset == 0:
                glyph = (cp + delta) & 0xFFFF
            else:
                glyph = u16(data, ro_pos + range_offset + 2 * (cp - start))
                glyph = (glyph + delta) & 0xFFFF if glyph else 0
            if glyph:
                covered.add(cp)
    return covered


def cmap_format12(data: bytes, offset: int) -> set[int]:
    """Code points mapped to a glyph other than .notdef by a format 12 subtable."""
    covered: set[int] = set()
    for g in range(u32(data, offset + 12)):
        start, end, glyph = struct.unpack_from(">III", data, offset + 16 + 12 * g)
        covered.update(cp for cp in range(start, end + 1) if glyph + cp - start)
    return covered


def describe(cps: list[int]) -> str:
    return " ".join(f"U+{cp:04X} {chr(cp)!r}" for cp in cps)


def group_by_family(fonts: list[Font]) -> dict[str, list[Font]]:
    groups: dict[str, list[Font]] = {}
    for font in fonts:
        groups.setdefault(font.family, []).append(font)
    return groups


def pubspec(fonts: list[Font], fonts_dir: pathlib.Path) -> str:
    """The `fonts:` block of the `flutter:` section of app/pubspec.yaml."""
    groups = group_by_family(fonts)

    def rank(family: str) -> tuple[int, str]:
        known = family in PUBSPEC_ORDER
        return (PUBSPEC_ORDER.index(family) if known else len(PUBSPEC_ORDER), family)

    lines = ["  fonts:"]
    for family in sorted(groups, key=rank):
        lines += [f"    - family: {family}", "      fonts:"]
        for font in sorted(groups[family], key=lambda f: (f.weight_class, f.italic)):
            asset = "assets/fonts/" + font.path.relative_to(fonts_dir).as_posix()
            lines += [f"        - asset: {asset}", f"          weight: {font.weight_class}"]
            if font.italic:
                lines.append("          style: italic")
    return "\n".join(lines)


def report_files(fonts: list[Font], fonts_dir: pathlib.Path) -> None:
    print("Files (family and style from the name table)")
    for font in fonts:
        rel = font.path.relative_to(fonts_dir).as_posix()
        print(
            f"  {rel:<58} {font.family!r:<27} {font.style!r:<11} "
            f"weight {font.weight_class} {'italic' if font.italic else 'normal':<6} "
            f"revision {font.revision:.3f}  {len(font.cmap):>4} code points  "
            f"{len(font.data):>7,} bytes"
        )
    total = sum(len(font.data) for font in fonts)
    print(f"  total {total:,} bytes in {len(fonts)} files")


def check_required(groups: dict[str, list[Font]]) -> int:
    print("\nRequired coverage")
    failures = 0
    for family, checks in REQUIRED.items():
        members = groups.get(family, [])
        if not members:
            print(f"  FAIL {family}: no file of this family is bundled")
            failures += 1
            continue
        for label, cps in checks:
            gaps = [(f.path.name, [cp for cp in cps if cp not in f.cmap]) for f in members]
            gaps = [(name, missing) for name, missing in gaps if missing]
            if gaps:
                failures += 1
                for name, missing in gaps:
                    print(f"  FAIL {family} / {label}: {name} lacks {describe(missing)}")
            else:
                print(f"  ok   {family} / {label} ({len(cps)} characters, {len(members)} files)")
    return failures


def check_golden(regular: dict[str, Font]) -> int:
    print("\nGolden sample through the fallback chain (regular weight of each family)")
    used: dict[str, list[str]] = {}
    missing: list[int] = []
    for c in dict.fromkeys(GOLDEN.replace(" ", "")):
        family = next(
            (f for f in FALLBACK_CHAIN if f in regular and ord(c) in regular[f].cmap), None
        )
        if family is None:
            missing.append(ord(c))
        else:
            used.setdefault(family, []).append(c)
    for family in FALLBACK_CHAIN:
        print(f"  {family:<26} {''.join(used.get(family, []))}")
    if missing:
        print(f"  FAIL not covered by any bundled family: {describe(missing)}")
        return 1
    print("  ok   every character of the sample is covered")
    return 0


def report_info(regular: dict[str, Font]) -> None:
    print("\nFor information")
    for family, label, cp in INFO:
        if family in regular:
            state = "mapped" if cp in regular[family].cmap else "not mapped"
            print(f"  {family} / {label} U+{cp:04X}: {state}")
    # The script families carry some Latin of their own, but not all of it, so Plex Sans
    # must follow them in every fallback chain.
    ascii_cps, latin1_cps, turkish = span(0x20, 0x7E), span(0xC0, 0xFF), chars("İıĞğŞş")
    for family in FALLBACK_CHAIN[1:]:
        if family in regular:
            cmap = regular[family].cmap
            print(
                f"  {family} / own Latin: ASCII {sum(cp in cmap for cp in ascii_cps)}/95, "
                f"Latin-1 letters {sum(cp in cmap for cp in latin1_cps)}/64, "
                f"Turkish İıĞğŞş {sum(cp in cmap for cp in turkish)}/6"
            )


def main(argv: list[str]) -> int:
    args = argv[1:]
    want_pubspec = "--pubspec" in args
    args = [a for a in args if a != "--pubspec"]
    if len(args) > 1 or (args and args[0].startswith("-")):
        print(__doc__, file=sys.stderr)
        return 2
    repo_root = pathlib.Path(__file__).resolve().parents[2]
    fonts_dir = pathlib.Path(args[0]) if args else repo_root / "app" / "assets" / "fonts"
    files = sorted(fonts_dir.rglob("*.ttf"))
    if not files:
        print(f"coverage: no .ttf files under {fonts_dir}", file=sys.stderr)
        return 2
    fonts = [Font(path) for path in files]

    if want_pubspec:
        print(pubspec(fonts, fonts_dir))
        return 0

    report_files(fonts, fonts_dir)
    regular = {f.family: f for f in fonts if f.weight_class == 400 and not f.italic}
    failures = check_required(group_by_family(fonts)) + check_golden(regular)
    report_info(regular)
    if failures:
        print(f"\ncoverage: {failures} check(s) failed", file=sys.stderr)
        return 1
    print("\ncoverage: all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
