# tools/corpus

Makes and checks Ferman's test corpus in [`tests/corpus/`](../../tests/corpus/README.md)
([ADR 0020](../../docs/adr/0020-test-corpus.md)):

- **The generators:** deterministic generators for the design's sample documents, all with invented
  data.
- **The check:** every corpus file has its README row.
- **The PDFium oracle:** every generated file opens or fails in PDFium as its generator says.

This is a Rust workspace of its own, which the root `Cargo.toml` excludes. It is never shipped. It
builds with the root's stable toolchain.

```sh
bash tools/corpus/fetch-fonts.sh                                          # once: the fonts Ferman does not bundle
cargo run --manifest-path tools/corpus/Cargo.toml --locked -- generate   # write the generated files that changed (the default)
cargo run --manifest-path tools/corpus/Cargo.toml --locked -- check      # exit 1 if a file and its row or generator disagree
cargo run --manifest-path tools/corpus/Cargo.toml --locked -- list       # the generators
cargo test --manifest-path tools/corpus/Cargo.toml --locked
FERMAN_PDFIUM_PATH="$PWD/build/pdfium/<id>/lib/libpdfium.<so|dylib>" cargo test --manifest-path tools/corpus/Cargo.toml --locked --test oracle -- --ignored
```

Options:

- `--only <name>` limits `generate` and the generator part of `check` to one generator. It can be
  repeated.
- `--root <dir>` points at another checkout.

Exit codes:

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Problems found (`check`) |
| 2 | The tool could not run: the README is unreadable, a generator failed, or a file could not be written |
| 64 | Bad usage |

## The generators

The first wave of ADR 0020 and the edit corpus of M3 (ROADMAP §7), in the order of the README's rows. `tests/corpus/README.md` says what
each file covers.

| Generator | Module | What it is |
|---|---|---|
| `kira-tr`, `kira-tr-damaged`, `kira-tr-restricted` | `docs/kira.rs` | The rental contract of `DocKira`, its older damaged copy, and the contract with an owner password |
| `truncated`, `disagree-pages` | `docs/damaged.rs` | A scan cut off after 18 KB; a file whose page count depends on the reader |
| `payslip-aes256`, `payslip-rc4-40`, `payslip-rc4-128`, `payslip-aes128` | `docs/payslip.rs` | The payslip of `a1-8`, in the four encryption methods |
| `xfa-visa`, `form-aks1-tr`, `form-aks1-flat` | `docs/forms.rs` | An XFA-only form; the e-Devlet form of `DocForm` with and without its fields |
| `mietvertrag-de`, `nda-en` | `docs/contracts.rs` | A German lease; an English NDA with a signature's structure |
| `report-ar` | `docs/report.rs` | The 12-page Arabic annual report of `a2-15`, right to left |
| `letter-ja-vertical` | `docs/letter.rs` | The Japanese letter of `a3-15` in vertical text |
| `tez-tr` | `docs/tez.rs` | A 64-page tagged thesis with an outline and page labels |
| `ocg-plan` | `docs/plan.rs` | The floor plan of `DocPlan` in layers, with a measuring scale |
| `js-openaction` | `docs/scripts.rs` | A notice with document JavaScript |
| `scan-tr`, `quote-ja-scan` | `docs/scans.rs` | Image-only scans: the rent-increase letter of `a3-11` and a Japanese quotation |
| `long-500`, `imar-2400` | `docs/long.rs` | The long files of the performance budgets (not committed) |
| `fatura-tr` | `docs/invoice.rs` | A Turkish invoice with a right-aligned amount column and its totals (E07) |
| `fa-zwnj`, `he-para`, `zh-hans`, `zh-hant`, `ko-para` | `docs/paragraphs.rs` | One-page notices in Persian with ZWNJ, Hebrew, Simplified and Traditional Chinese and Korean (E10 to E12) |
| `edit-e04-differences`, `edit-e05-fstype`, `edit-e15-helvetica`, `edit-e16-type3`, `edit-macroman`, `edit-90ms-rksj`, `edit-cff-cid` | `docs/encodings.rs` | The font and encoding cases: a glyph outside the encoding, a restricted `fsType`, standard 14 Helvetica, Type3, MacRoman, a predefined CMap, a CID-keyed CFF font |
| `edit-e19-rotate`, `edit-e20-form-twice`, `edit-e21-actualtext`, `edit-e22-split-contents`, `edit-e23-shared-contents`, `edit-e26-inline-image` | `docs/edits.rs` | The structure cases: a turned page, a Form XObject placed twice, `/ActualText`, split and shared content streams, an inline image |
| `annots-other-producer` | `docs/annotations.rs` | A contract review with every annotation type `a4-1` draws, as another program writes them |
| `cert-p1`, `cert-p2`, `cert-p3`, `form-signed`, `form-hybrid-xfa`, `form-need-appearances`, `form-script`, `form-lists-comb` | `docs/form_cases.rs` | Certified at each DocMDP level; a signed form with FieldMDP; AcroForm with XFA; no `/AP`; scripts that would change values; list boxes and comb fields |
| `combine-outline` | `docs/combine.rs` | The Combine fixture: a 2-page PDF with an outline, and `combine-photo.jpg`, a standalone JPEG (an extra, with its own row) |
| `images-compress` | `docs/images.rs` | The Compress fixture: every kind of image, one per slot |
| `annots-other-producer` | `docs/annotations.rs` | A contract review with every annotation type `a4-1` draws, as another program writes them |
| `cert-p1`, `cert-p2`, `cert-p3`, `form-signed`, `form-hybrid-xfa`, `form-need-appearances`, `form-script`, `form-lists-comb` | `docs/form_cases.rs` | Certified at each DocMDP level; a signed form with FieldMDP; AcroForm with XFA; no `/AP`; scripts that would change values; list boxes and comb fields |
| `combine-outline` | `docs/combine.rs` | The Combine fixture: a 2-page PDF with an outline, and `combine-photo.jpg`, a standalone JPEG (an extra, with its own row) |
| `images-compress` | `docs/images.rs` | The Compress fixture: every kind of image, one per slot |

The generators share a small PDF writer:

- **`pdf.rs`:** objects, compressed streams, pages, the information dictionary and a fixed `/ID`,
  on lopdf.
- **`font.rs`, `sfnt.rs`:** the kinds of font producers write:
  - composite `Identity-H` and `Identity-V` subsets, shaped by harfrust in the text's direction:
    `CIDFontType2`, or `CIDFontType0` with a CID-keyed `CIDFontType0C` program for a CFF face;
  - simple TrueType WinAnsi or MacRoman subsets, with the `cmap` that subsetter leaves out put
    back, optionally keeping glyphs no code shows or with a patched `OS/2.fsType`;
  - simple Type3 fonts whose glyph procedures fill a face's outlines;
  - fonts named but not embedded, with widths or, for a standard 14 font, without.
- **`text.rs`:** lines, justification with `Tw` or `TJ`, page flow, marked content and the expected
  text. Right-to-left paragraphs get their levels from unicode-bidi and each line is drawn in visual
  order; text without spaces breaks at U+200B.
- **`vertical.rs`, `kinsoku.rs`:** vertical columns in `Identity-V` fonts, with tate-chu-yoko, and
  the Japanese line-breaking rules for columns and lines.
- **`raster.rs`:** the scanner: glyph outlines and rectangles filled into a greyscale bitmap, the
  page turned slightly, and the image written greyscale with PNG predictors or at one bit per pixel.
- **`crypt.rs`:** the standard security handler, with seeded initialisation vectors and salts.
- **`docs/files.rs`:** the attachments: a stored zip for the spreadsheet, and JPEGs (grey, YCbCr or
  CMYK) coded with DC coefficients only.

## The fonts

The generators read IBM Plex from `app/assets/fonts/`, pinned by `tools/fonts/fonts.lock`. Fonts
Ferman does not bundle are listed in [`fonts.lock`](fonts.lock), all OFL-1.1: EB Garamond, Noto Serif JP
and Noto Sans SC, TC and KR from google/fonts, and Source Sans 3 from adobe-fonts/source-sans, as
google/fonts has no font with CFF outlines. A variable font is used at one instance (`FontFile::variations`): its
metrics, its shaping and its subset take the same variations, and subsetter instances the subset. `fetch-fonts.sh` downloads them into `build/corpus-fonts/` (gitignored); a file already
there with the right hash is kept. Every font is checked against its pinned SHA-256 before use, so a
generator fails rather than make other bytes. The PDFs embed subsets, which the fonts' licences allow.
CI caches the folder by the hash of `fonts.lock`.

## What a generator makes

Each generator writes two or three files to `tests/corpus/generated/`, and a fixture may add a file of another kind with a README row of its own (`combine-photo.jpg`):

- **`<name>.pdf`:** the document.
- **`<name>.expected.txt`:** the text a reader should extract, one page per form feed (U+000C), in
  drawing order and, for right-to-left text, in logical order. It shares the PDF's row in the
  README. A scan's pages have no text, so its file holds only the form feeds.
- **`<name>.blocks.json`:** the block ground truth of ROADMAP §7 step 1, which ferman-text's
  `tests/layout.rs` holds the text model to: per page, `empty` (`"image"` for a scan) and the
  blocks in reading order, each with its `align` (`left`, `right`, `center` or `justified`; a
  vertical column's start is `left`), its `justify` for a justified block (`tw` when a line uses
  `Tw`, else `tj` for `TJ` adjustments after the spaces; `null` otherwise), its `column` (its rank from the left among the blocks whose
  extent in y overlaps its own), its table `cell` (`[table, row, column]`) and its lines (`text` in
  logical order, the baseline's `start` and `end` points in user space, `size`, `vertical`). It
  shares the PDF's row. `text.rs` records it as it draws: a paragraph is a block, joined to the
  block above when a reader cannot tell them apart (the same frame, alignment and size, neither
  justified, at most `BLOCK_PITCH` ems below at an even leading, nothing between), and a generator
  groups the lines it draws one by one (`PageText::group`), marks table cells (`PageText::cell`)
  and reorders blocks it draws out of reading order (a running head drawn last). `form-aks1-tr`,
  `form-aks1-flat`, `ocg-plan`, `truncated` and M4's forms, annotations, combine and image files have none yet; the test skips `disagree-pages`,
  whose page count depends on the reader, and the files too large to commit.

The output is the same bytes on every run and every system:

- no timestamps and no random numbers;
- a fixed `/ID`;
- seeded AES initialisation vectors and salts;
- no paths from the machine that ran it;
- no transcendental floating-point functions, whose last bits can differ between C libraries.

`.gitattributes` keeps `tests/corpus/generated/` from line-ending conversion. A generator whose PDF
is up to 1 MB has its files committed. A larger one has none: the same command regenerates them,
the PDF is checked against the SHA-256 of its row, and all are listed in `generated/.gitignore`.

## What `check` proves

CI runs `check` on macOS, Windows and Linux. It reports a problem when:

- a file in `tests/corpus/` other than the README has no row, or its SHA-256 differs from its row;
- a row names a file that is not there, except one a generator makes above 1 MB;
- a row's SHA-256 is not 64 lowercase hex digits, or a file has two rows;
- a generator makes different bytes on two runs;
- a generator's PDF has no row;
- a generator's committed files differ from what it makes now;
- a PDF over 1 MB that a generator makes has a hash other than its row's, or it or its text is not
  in `generated/.gitignore`;
- a file in `generated/` is one no generator makes.

Hidden files, such as a `.gitignore`, are not corpus files.

## What the oracle proves

`tests/oracle.rs` is ignored by default because it needs PDFium (`tools/pdfium/fetch.sh`); CI runs it
on the three systems with `FERMAN_PDFIUM_PATH`. For every generator it checks the result in PDFium, a
reader independent of lopdf:

- **A file that should open** opens, with its password when it has one. It has one page per page of
  its expected text, and each page's text equals the expected text once whitespace is removed
  (PDFium inserts its own spaces and line breaks).
- **A file with right-to-left or vertical text** (`Expect::OpensUnordered`: `report-ar`,
  `letter-ja-vertical`) has the same characters on each page, in any order. PDFium guesses the order
  of such text: it reverses the text of Arabic ligature glyphs, moves neutral characters at the edge
  of numbers and orders vertical columns its own way.
- **An encrypted file** does not open without its password.
- **A file that should not open** (`truncated`) does not.

It also renders `images-compress` and holds the centre of every image to its colour, so JPX, CMYK and the masks are known to paint.

A second test renders `images-compress` and holds the centre of every image to its colour, so JPX, CMYK and the masks are known to paint.

`FERMAN_CORPUS_ONLY=<name>` limits a run to one generator. The unit tests in `src/docs/mod.rs`
check the damage itself with lopdf: `disagree-pages` has two pages for lopdf, `truncated` stops
inside object 13, and every offset of `kira-tr-damaged` is two bytes early.
