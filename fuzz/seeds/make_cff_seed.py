#!/usr/bin/env python3
"""Writes seeds/fonts/tiny-cff: `font_case`'s whole-font prefix and a small OpenType/CFF font.

The outlines are two rectangles drawn here, so the seed holds nothing from a third-party font.
"""
import pathlib
import struct


def be(fmt, *values):
    return struct.pack(">" + fmt, *values)


def index(items):
    if not items:
        return be("H", 0)
    offsets, at = [], 1
    for item in items:
        offsets.append(at)
        at += len(item)
    offsets.append(at)
    return be("HB", len(items), 2) + b"".join(be("H", o) for o in offsets) + b"".join(items)


def dict_int(value):
    return b"\x1d" + be("i", value)


def cs_int(value):
    return b"\x1c" + be("h", value)


def rectangle(width, height):
    return (
        cs_int(50) + cs_int(0) + b"\x15"  # rmoveto
        + cs_int(width) + b"\x06"  # hlineto
        + cs_int(height) + b"\x07"  # vlineto
        + cs_int(-width) + b"\x06"  # hlineto
        + b"\x0e"  # endchar
    )


def cff():
    head = bytes([1, 0, 4, 1])
    names = index([b"FermanSeed"])
    strings = index([])
    subrs = index([])
    glyphs = index([b"\x0e", rectangle(400, 700), rectangle(300, 500)])
    charset = b"\x00" + be("HH", 34, 89)  # the standard strings A and x
    private = dict_int(500) + b"\x14"  # defaultWidthX
    top_size = len(dict_int(0)) * 4 + 1 + 1 + 1
    top_index_size = len(index([bytes(top_size)]))
    at = len(head) + len(names) + top_index_size + len(strings) + len(subrs)
    charset_at, glyphs_at = at, at + len(charset)
    private_at = glyphs_at + len(glyphs)
    top = (
        dict_int(charset_at) + b"\x0f"
        + dict_int(glyphs_at) + b"\x11"
        + dict_int(len(private)) + dict_int(private_at) + b"\x12"
    )
    assert len(top) == top_size
    return head + names + index([top]) + strings + subrs + charset + glyphs + private


def name_table():
    records = [(1, "Ferman Seed"), (2, "Regular"), (4, "Ferman Seed"), (6, "FermanSeed")]
    data, entries = b"", b""
    for name_id, text in records:
        raw = text.encode("utf-16-be")
        entries += be("HHHHHH", 3, 1, 0x409, name_id, len(raw), len(data))
        data += raw
    return be("HHH", 0, len(records), 6 + len(entries)) + entries + data


def cmap_table():
    ends, starts = [0x41, 0x78, 0xFFFF], [0x41, 0x78, 0xFFFF]
    deltas = [(1 - 0x41) & 0xFFFF, (2 - 0x78) & 0xFFFF, 1]
    arrays = (
        b"".join(be("H", e) for e in ends) + be("H", 0)
        + b"".join(be("H", s) for s in starts)
        + b"".join(be("H", d) for d in deltas)
        + be("HHH", 0, 0, 0)
    )
    # format, length, language, segCountX2; searchRange, entrySelector, rangeShift
    sub = be("HHHH", 4, 14 + len(arrays), 0, 6) + be("HHH", 4, 1, 2) + arrays
    return be("HH", 0, 1) + be("HHI", 3, 1, 12) + sub


def os2_table():
    os2 = bytearray(78)
    struct.pack_into(">HhHH", os2, 0, 0, 500, 400, 5)
    struct.pack_into(">hhhHH", os2, 68, 800, -200, 0, 800, 200)
    return bytes(os2)


def font():
    head = (
        be("IIIIHH", 0x00010000, 0x00010000, 0, 0x5F0F3CF5, 0, 1000)
        + bytes(16)
        + be("hhhh", 0, 0, 450, 700)
        + be("HHhhh", 0, 8, 2, 0, 0)
    )
    hhea = be("IhhhHhhh", 0x00010000, 800, -200, 0, 500, 0, 0, 450) + be("hhh", 1, 0, 0) + bytes(8) + be("hH", 0, 3)
    tables = {
        b"CFF ": cff(),
        b"OS/2": os2_table(),
        b"cmap": cmap_table(),
        b"head": head,
        b"hhea": hhea,
        b"hmtx": be("HhHhHh", 500, 0, 500, 50, 500, 50),
        b"maxp": be("IH", 0x00005000, 3),
        b"name": name_table(),
        b"post": be("I", 0x00030000) + bytes(28),
    }
    out = b"OTTO" + be("HHHH", len(tables), 128, 3, len(tables) * 16 - 128)
    at = 12 + 16 * len(tables)
    body = b""
    for tag, data in tables.items():
        padded = data + bytes(-len(data) % 4)
        total = sum(struct.unpack(">%dI" % (len(padded) // 4), padded)) & 0xFFFFFFFF
        out += tag + be("III", total, at + len(body), len(data))
        body += padded
    return out + body


path = pathlib.Path(__file__).parent / "fonts" / "tiny-cff"
path.parent.mkdir(exist_ok=True)
path.write_bytes(b"\x01\x00\x00" + font())
