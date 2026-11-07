# fuzz

Ferman's [cargo-fuzz](https://github.com/rust-fuzz/cargo-fuzz) targets: one per parser, from the
first parser in M2 ([ARCHITECTURE.md §13.6](../docs/ARCHITECTURE.md#136-fuzz-targets)). Every PDF
is untrusted input, and a target is how a parser proves it fails with an error, never a crash.

This is a Cargo workspace of its own, which the root `Cargo.toml` excludes. libfuzzer-sys vendors
LLVM's libFuzzer under NCSA, which the owner approved for this workspace only
([Q17](../docs/QUESTIONS.md#q17)), so it never enters the shipped dependency graph. Nothing here
ships.

## Requirements

- **The pinned nightly:** `rust-toolchain.toml` in this folder names it, and rustup installs it on
  first use. cargo-fuzz needs nightly for the sanitizers.
- **cargo-fuzz 0.13.2:** `cargo install --locked cargo-fuzz@0.13.2`.
- **A system:** Linux or macOS. cargo-fuzz's Windows support needs MSVC's AddressSanitizer and has
  limits, so CI fuzzes on Linux.

## Commands

Run them from this folder, so rustup picks the nightly:

```sh
cargo fuzz list                                         # the targets
cargo fuzz run filter_flate -- -max_total_time=60       # fuzz one target for 60 s
cargo fuzz run filter_flate artifacts/filter_flate/<file>   # replay a crash
cargo fuzz build                                        # build every target (AddressSanitizer)
```

From the repository root, formatting and Clippy use the stable toolchain:

```sh
cargo fmt --manifest-path fuzz/Cargo.toml --check
cargo clippy --manifest-path fuzz/Cargo.toml --all-targets --locked -- -D warnings
cargo deny --manifest-path fuzz/Cargo.toml check
```

`corpus/`, `artifacts/` and `coverage/` here are cargo-fuzz's working folders and are gitignored.

## Targets

| Target | Parser | Input |
|---|---|---|
| `filter_ascii_hex` | ASCIIHexDecode (`ferman_core::filters`) | the stream data |
| `filter_ascii85` | ASCII85Decode | the stream data |
| `filter_lzw` | LZWDecode and its predictors | `/DecodeParms` from the first four bytes, then the data |
| `filter_flate` | FlateDecode and its predictors | `/DecodeParms` from the first four bytes, then the data |
| `filter_run_length` | RunLengthDecode | the stream data |
| `syntax_object` | ferman-core's object parser: a direct object, then an indirect one with its stream | arbitrary bytes |
| `xref_repair` | cross-reference tables and streams, `/Prev` chains, and repair by scanning | arbitrary bytes, as a file from its `%PDF-` header |
| `security_handler` | the standard security handler: the encryption dictionary, passwords for revisions 2 to 6, decryption | a length byte, the password, an encryption dictionary, then the data to decrypt |
| `cmap` | ferman-fonts' CMap reader: codespace, CIDs and ToUnicode text, then splitting and looking up codes | arbitrary bytes as a CMap, and as a string to split |
| `type1` | ferman-fonts' Type1 parser: PFB segments, the clear text before `eexec`, the built-in encoding | arbitrary bytes as a font program |
| `subsetting` | ferman-fonts' subsetter (through the crate subsetter): the kept glyphs, new ids, widths and text | a font (below), then glyphs with their text |
| `shaping` | ferman-fonts' shaping (through harfrust): every direction, a script, language and features, then clusters to text | a font (below), a control byte, then text |
| `line_breaking` | ferman-text's line breaks: UAX #14 with the kinsoku and Hangul tailoring | arbitrary bytes as UTF-8 and as mixed scripts |
| `interpreter` | ferman-core's text interpreter: graphics and text state, shows, forms drawing themselves, the limits | arbitrary bytes as a page's content and as a form it draws |
| `content_lexer` | ferman-core's content-stream lexer: operators, operands, spans and inline images | arbitrary bytes as a content stream |
| `reencode` | text back to codes: `SimpleEncoding` with `/Differences` and CMaps with `usecmap`; a code found reads back as the text or CID | arbitrary bytes as both |
| `to_unicode` | ToUnicode writing (`with_text`): added codes read back with their text, the original's keep theirs | a length, an original CMap, then entries of code and character |
| `rewrite_block` | ferman-text's rewrite on a one-page file the target builds: every block's splices stay in the content, in order and apart | flags and lengths, then new text, shown bytes, CMap and font program |
| `font_program` | font programs: `FontProgram`, built-in encoding, shaping and subsetting; a subset reads back. Seed `corpus/font_program` with small fonts | arbitrary bytes as a font program |
| `type1_program` | Type1 through `FontProgram`, past `eexec`: the target encrypts the input's header text, `/Private` text and charstrings | a flags byte (PFB or not), then parts split on a zero byte |
| `open_document` | the whole open path: header, cross-reference data, repair, security, lopdf and the structure scan | arbitrary bytes as a file; the password `fuzz` when the first byte is odd |
| `recovery_journal` | the recovery journal's records and their objects, and the manifest parser, whose manifests must read back from the JSON they write | arbitrary bytes, as they are, framed as one record (the checksum random bytes never pass), and as a record's objects and a manifest |
| `writer_round_trip` | the incremental writer: changes, undo and redo over two generations; the file before stays a prefix, the update reopens without repair, every object written reads back | arbitrary bytes as a file when they open clean, and as a script of changes to it, or to the classic, modern or encrypted (AES-128, AES-256, RC4) file the first byte chooses |
| `assembler` | the assembler's walk from a page, weighing and copying: cycles and deep trees stop at a limit, and the new file opens with the pages it was given | arbitrary bytes as a file, and as objects from 10 on under a two-page file that points into them |
| `annotations` | the annotation reader and, on what it reads, the appearance generators (text boxes set in a bundled font), reply, resolve, delete and flatten: huge `/Annots`, cycles and deep `/IRT` chains stop at a limit; a reply's thread is in the list | arbitrary bytes as a file, and as objects from 10 on under a page whose `/Annots` is object 10 |
| `image_layer` | the image layer of ferman-ops and the `image` crate's decoders behind it: PNG, JPEG (with CMYK), TIFF, WebP and GIF, to a limit of 2^20 pixels; what comes out fits the size it reports | arbitrary bytes as a file, then as a JPEG; with `seeds/images` |
| `edit_script` | rewriting blocks of corpus pages through ferman-text and the splicer, undo, redo and saves: only the splices' bytes change, a saved file keeps the original as a prefix and reopens with the same content, undoing everything gives back the original | a corpus file from the first byte, then a script of operations on its pages and blocks, with the new text |

The filter targets' checks are in `src/lib.rs`:

- the code under test must not panic;
- it must not decode more than the limit (1 MiB, so a decompression bomb stops quickly);
- it may fail only with the errors a damaged stream can cause.

The open-path targets call ferman-core's hidden `fuzzing` module, behind the `fuzzing` feature
that only this workspace enables, with small limits (1 MiB per stream, 64 cross-reference
sections). Besides not panicking, they may fail with any error but an internal one or running out of
memory, and `xref_repair` checks that a rebuilt table reads back clean from the flat copy lopdf
gets. `open_document` runs lopdf too, so it finds lopdf's panics, which ferman-api catches as a
last resort; a panic found there is reported upstream and worked around in ferman-core where it
can be. Seed `corpus/open_document`, `corpus/xref_repair` and `corpus/writer_round_trip` with the PDFs
of `tests/corpus/`.

`subsetting` and `shaping` take their font from `font_case` in `src/lib.rs`: patches to a bundled
font (IBM Plex Sans Arabic, TrueType), so they get past the table directory without a seed, or a
whole font. `font_program` takes its font the same way. To reach CFF, CI and the nightly run pass
`seeds/fonts` to these three: `tiny-cff` is the bytes `01 00 00` followed by a small OpenType/CFF
font drawn by `seeds/make_cff_seed.py` for this purpose, with no third-party outlines. Run them by
hand with `cargo fuzz run font_program corpus/font_program seeds/fonts`. Their text comes from
`text_from`, so every script turns up.

`image_layer` starts from `seeds/images`, which CI and the nightly run pass to it: a few pixels each,
written by the `image` crate's encoders, and two CMYK JPEGs put together by hand as `handmade_jpeg`
in `crates/ferman-ops/src/images.rs` does, since that crate has no CMYK encoder. A test there loads
them all, and `crates/ferman-api/tests/images.rs` has PDFium draw them.

AddressSanitizer and libFuzzer's time and memory limits catch the rest.

## A crash

A crash becomes a regression test before it is fixed:

1. The input goes into `tests/corpus/` with a row in its README (source: the target and the date it
   was found).
2. A test in the crate replays it.
3. The fix makes that test pass.

## CI

Every pull request runs each target for 60 s on Linux (**Proposed** with the M2 plan). A nightly
run of one hour per target follows with M2's CI commit.
