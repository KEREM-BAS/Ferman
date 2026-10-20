# ADR 0020: Test corpus and its generators

- **Status:** Accepted (owner, with the M2 plan, 2026-10-17)
- **Date:** 2026-10-17
- **Approval:** the owner, on 2026-10-17, with the M2 plan ([PROGRESS.md](../PROGRESS.md#m2-plan))
- **Supersedes:** none
- **Superseded by:** none

## Context

M2 is the first milestone that opens real PDFs, and its acceptance tests need them: every corpus file
opens or fails as designed, extracted text equals a known text, ten renders of a page are
byte-identical, and the performance budgets are measured on a 500-page file and on the 2,400-page imar
plan ([ROADMAP.md §6](../ROADMAP.md#6-m2-open-and-view)). M3's pixel-diff acceptance test for edits
reads the same files ([brief §4](../BRIEF.md)).

The constraints:

- **No confidential documents** and only redistributable files
  ([tests/corpus/README.md](../../tests/corpus/README.md)). The documents the design draws (the Turkish
  rental contract, the bank statement, the payslip, the imar plan) are realistic, so ours must be
  generated with invented data.
- **Known answers.** Text extraction can only be checked against a text we know. A generated file can
  carry its expected text as a sidecar; a downloaded one cannot.
- **Licences.** qpdf (Apache-2.0) and pyHanko (MIT) are permissive but add a C++ and a Python toolchain
  to CI. Ghostscript and MuPDF are ruled out ([ADR 0016](0016-dependency-licence-policy.md)).
- **Determinism.** A generator that writes timestamps, random ids or random AES IVs gives a new file
  each run, and the committed SHA-256 no longer proves anything.
- **An independent check.** A generator written with lopdf and read back by lopdf could be wrong in a
  way both sides agree on. PDFium is a second, independent reader.

## Decision

We will generate most of the corpus with our own deterministic tools and check it with PDFium.

- **`tools/corpus`** is a Rust workspace of its own, outside the main workspace (the root
  `Cargo.toml` gets `exclude = ["fuzz", "tools/corpus"]`), never shipped. It uses lopdf to write the
  object structure, harfrust and subsetter for shaped and subset fonts (Plex Sans Arabic for the
  right-to-left report), skrifa and unicode-bidi. If lopdf 0.45 cannot write encryption, the workspace
  has its own security handler (RC4 40 and 128, AES-128, AES-256) on the aes, cbc, rc4 and md-5 crates.
  `cargo deny --manifest-path tools/corpus/Cargo.toml check` runs in CI like the main workspace.
- **Each generator writes `tests/corpus/generated/<name>.pdf` and `<name>.expected.txt`**, the expected
  text with one page per form feed, and nothing else. Output is byte for byte reproducible: no
  timestamps, a fixed `/ID`, seeded AES IVs.
- **Size.** Files up to 1 MB are committed. Larger ones (imar-2400, probably long-500) are regenerated
  by the same command and checked against a SHA-256 pinned in `tests/corpus/README.md`; they are listed
  there like the others.
- **The PDFium oracle test** (`#[ignore]`, needs PDFium) opens every corpus file with its password,
  checks the page count, and compares PDFium's own text extraction with the sidecar, loosely (PDFium
  inserts its own spaces and line breaks). It runs in CI on all three systems.
- **The first wave** (M2): long-500 and imar-2400 (performance); kira-tr with a subset font that lacks
  "ğ" and three attachments, kira-tr-damaged and kira-tr-restricted (owner password only); truncated
  and disagree-pages (crafted damage); payslip-aes256 with ı, ş and ü in the password, plus RC4 40,
  RC4 128 and AES-128 variants; xfa-visa, form-aks1-tr and form-aks1-flat (forms); mietvertrag-de,
  report-ar (`/Direction /R2L`) and letter-ja-vertical (Identity-V); tez-tr (nested outline, page
  labels), ocg-plan (layers), nda-en (a signature dictionary, structure only) and js-openaction
  (scripts); scan-tr and quote-ja-scan (image only).
- **Real-world files** come next to the generated ones, each with its row and licence: PDFium's own
  `testing/resources` (BSD-3-Clause), exports the owner makes from Word and Google Docs of an
  Apache-2.0 source text, and public-domain scans.
- No qpdf or pyHanko in M2. pyHanko is reconsidered in P3, when real signatures need real signing.

## Consequences

### Positive

- Text extraction, search and (in M3) editing are tested against texts we know exactly.
- The sample documents of the design exist as files with invented data, in every script M2 covers.
- A broken generator shows up as a PDFium disagreement, not as a passing test.
- No new toolchain in CI: the generators are Rust, like the engine.

### Negative

- We maintain the generators and, if needed, a small security handler. A generator bug that PDFium
  tolerates too would go unnoticed; the real-world files reduce that risk.
- Generated files are cleaner than what users have. The real-world set and the fuzz targets cover the
  messy files.
- If googlesource is not reachable from the container, the owner fetches PDFium's test files.

### Follow-up

- M2 step 1: the workspace, the first wave, the README rows and the oracle test.
- M3: edit fixtures for the pixel-diff acceptance test (Turkish, Arabic, CJK).
- P3: real signatures, possibly with pyHanko.

## Implementation (M2 step 1)

Recorded when the first wave was built (2026-10-19); none of these points changes the decision.

- **Security handler.** lopdf 0.45 can encrypt, but it draws its initialisation vectors and salts
  from the system's random number generator. So `tools/corpus` has its own handler (`src/crypt.rs`)
  on the aes, md-5 and rc4 crates, with stringprep for revision 6 passwords. CBC is written out over
  aes blocks, so cbc is not a direct dependency.
- **Fonts Ferman does not bundle.** They are fetched by `tools/corpus/fetch-fonts.sh` into
  `build/corpus-fonts/` and checked against `tools/corpus/fonts.lock`; they are never committed.
  EB Garamond sets kira-tr's Madde 6 ([G113](../DESIGN_GAPS.md#g113)). The Japanese files use Noto
  Serif JP, the font `a3-15` names, from the Noto CJK family the M2 plan approved as test data. It is
  a variable font, instanced at `wght` 400 and 600 by subsetter's `variable-fonts` feature. The
  Arabic report uses the bundled IBM Plex Sans Arabic.
- **Two commits.** The first wave arrives in two commits:
  - the tooling, the Latin and Turkish files, the encrypted and damaged files, and the oracle;
  - report-ar, letter-ja-vertical, scan-tr and quote-ja-scan.
- **Names.** The payslip's twins are `payslip-rc4-40`, `payslip-rc4-128` and `payslip-aes128`.
- **Large files.** A generator whose PDF is over 1 MB commits neither file: long-500's expected text
  alone is 1.7 MB. Both are listed in `tests/corpus/generated/.gitignore`, which `check` requires.
- **The oracle.** It lives in `tools/corpus/tests/oracle.rs`, with pdfium-render as a
  dev-dependency, because the generators know each file's password and outcome. It also checks that
  an encrypted file does not open without its password. PDFium orders right-to-left and vertical text
  by heuristics of its own, so report-ar and letter-ja-vertical are compared page by page by their
  characters. Their expected text stays in logical order, which Ferman's own extraction must give.
- **Right-to-left, vertical and scanned files.** The text code lays out right-to-left paragraphs
  with unicode-bidi and draws each line in visual order, as producers do. Vertical text is drawn
  column by column in `Identity-V` fonts with `/W2`, with tate-chu-yoko and kinsoku. The scans come
  from a small rasteriser of glyph outlines. Their pages are image only, so their expected text is
  empty.
- **Determinism across systems.** The generators never read a clock, never draw random numbers, and
  avoid transcendental floating-point functions, whose last bits can differ between C libraries.
  `.gitattributes` keeps the generated files, the text sidecars included, from line-ending
  conversion.

## Alternatives considered

- **qpdf and pyHanko.** Mature and permissive, but a C++ and a Python toolchain in CI for files we can
  write ourselves; pyHanko stays an option for P3's signatures.
- **Only real-world files.** No known texts to check extraction against, and few redistributable files
  in Turkish, Arabic or Japanese with the structures M2 needs.
- **Generating with the app's own writer.** There is none until M3, and testing the reader with files
  from the same code would hide shared mistakes.

## References

- [Brief](../BRIEF.md) §4, §7
- [tests/corpus/README.md](../../tests/corpus/README.md), [ARCHITECTURE.md §13.3](../ARCHITECTURE.md#133-corpus)
- [ADR 0016](0016-dependency-licence-policy.md), [ADR 0017](0017-testing-and-ci.md)
