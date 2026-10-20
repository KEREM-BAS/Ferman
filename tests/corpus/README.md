# Test corpus

The PDFs that Ferman's engine tests, pixel-diff acceptance runs and fuzz regressions read. Every file
here has a row in the table below: where it came from, under which licence, its SHA-256 and what it
covers. A file without a row is not merged. Background: [ARCHITECTURE.md §13.3](../../docs/ARCHITECTURE.md#133-corpus)
and [ADR 0017](../../docs/adr/0017-testing-and-ci.md).

The first wave of generated files arrived in M2 step 1 ([ADR 0020](../../docs/adr/0020-test-corpus.md)).
`tools/corpus check` ([tools/corpus/README.md](../../tools/corpus/README.md)) holds this folder to its
table, and CI runs it on macOS, Windows and Linux. The PDFium oracle test checks that every generated
file opens or fails as its generator says, with its page count and its expected text (by characters
for the right-to-left and vertical files, whose order PDFium guesses).

## Rules

- **No confidential documents.** Never add a real contract, statement, payslip, ID, medical record or
  anything else with personal or client data, even redacted. Sample documents with realistic content
  (the Turkish rental contract, the bank statement, the payslip) are generated with invented data.
- **Licence first.** A real-world file is added only if its licence allows redistribution in this
  repository (public domain, CC0, CC BY, or a permissive licence). The licence column names it as an
  SPDX identifier where one exists, and the source column links to the page that states it.
- **Generated files name their generator.** A file produced by a script in `tools/corpus` lists that
  script and its arguments in the source column, so anyone can regenerate it byte for byte. Generators
  are deterministic: no timestamps, random ids or machine-specific paths in the output. A generated
  PDF's expected text, `generated/<name>.expected.txt`, shares the PDF's row.
- **Hashes are checked.** The SHA-256 is of the file as committed. Changing a file means a new hash, a
  new row note and a reason in the commit message.
- **Size.** Files up to 1 MB are committed here ([ADR 0020](../../docs/adr/0020-test-corpus.md)).
  A generator whose PDF is larger commits neither file. `tools/corpus` regenerates both, checks the PDF
  against the SHA-256 of its row, and requires both in `generated/.gitignore`. Larger real-world files
  are fetched with a pinned SHA-256. All are listed here.
- **Byte for byte.** `.gitattributes` keeps `generated/` from line-ending conversion, so a Windows
  checkout has the same bytes.
- **Fuzz regressions.** A crash found by a fuzz target becomes a file here (source: the target name and
  the date it was found), with the test that replays it.
- **Damaged on purpose.** Truncated, malformed and hostile files are welcome. Say what is wrong with
  them in the "covers" column.

## Columns

| Column | What goes in it |
|---|---|
| File | Path relative to this folder, for example `generated/rental-contract-tr.pdf` |
| Source | A URL for a real-world file, or `tools/corpus/<script>` plus its arguments for a generated one |
| Licence | SPDX identifier (`CC0-1.0`, `CC-BY-4.0`, `Apache-2.0`, …), or `generated` for files made by our scripts (they inherit the repository's Apache-2.0) |
| SHA-256 | Lowercase hex digest of the committed file (`sha256sum`, `shasum -a 256` or `Get-FileHash`) |
| Covers | What the file exercises: producer, fonts and encodings, scripts, structure, damage, features |
| Added | The milestone that added it (`M2`, `M3`, …) |

## Files

| File | Source | Licence | SHA-256 | Covers | Added |
|---|---|---|---|---|---|
| `generated/kira-tr.pdf` | `tools/corpus generate --only kira-tr` | generated | `030fade0019a3de156eeadc6d675099d6869007de66e3373a520b7990ff794bc` | `DocKira`: 3-page Turkish rental contract set as Word sets it: IBM Plex Serif as simple TrueType WinAnsi subsets, with composite `Identity-H` subsets of the same face for ş, ı, ğ, İ; `Tw` justification, `Tc` in the title. Madde 6 in EB Garamond, whose subsets lack "ğ": the "ğ" of "Olağan" is borrowed from Plex Serif (E02, [G113](../../docs/DESIGN_GAPS.md#g113)). The IBAN line framed right below Madde 4 (E06). Six form fields on page 3, two of them unsigned signature fields. Three attachments (xlsx, jpg, pdf). The expected text sidecar shares this row | M2 |
| `generated/kira-tr-damaged.pdf` | `tools/corpus generate --only kira-tr-damaged` | generated | `07e79e12295099b9afb134009d7cc6542c8d1418d9de5bdd752778d9731b8e46` | `a1-9`: the older copy. Every cross-reference offset is two bytes early, so a reader must rebuild the table. Page 3 is in TimesNewRomanPSMT and TimesNewRomanPS-BoldMT, not embedded, WinAnsi with the Windows-1254 `/Differences`. No fields or attachments | M2 |
| `generated/kira-tr-restricted.pdf` | `tools/corpus generate --only kira-tr-restricted` | generated | `c1587e984e46365721a7fbe43ae0d23c2f88ec441681eb4fe4d934e0a417465b` | `a2-10a`: kira-tr with an owner password only (AES-128, R4; owner password `Kaya-Moda-18`). It opens without a password. Printing and accessibility extraction are allowed; changes, copying, comments and form filling are not | M2 |
| `generated/truncated.pdf` | `tools/corpus generate --only truncated` | generated | `d656f9534783dbace5d1020ed1df005d9bb1a435f6ff961dca9779eb3b5b75f4` | `a1-9b`, "Tarama_0042.pdf": a 4-page scan cut at 18,432 bytes inside object 13, the first page image. Objects 1 to 12 are complete. There is no page tree, catalog, cross-reference table or trailer, so it cannot be opened. Its expected text is empty | M2 |
| `generated/disagree-pages.pdf` | `tools/corpus generate --only disagree-pages` | generated | `05ef33dcd77be45519f05b1c20b044a59e76a8138ae16c8078a9b8a8746fd607` | [G102](../../docs/DESIGN_GAPS.md#g102): 3 pages, the second without `/Type /Page`. PDFium finds 3 pages; lopdf 0.45, which requires the type, finds 2 | M2 |
| `generated/payslip-aes256.pdf` | `tools/corpus generate --only payslip-aes256` | generated | `2975d006997d82f33157253c1f304876fa0c2351f15eeed3a50612032c137363` | `a1-8`, `a1-8b`: 1-page payslip, IBM Plex Sans composite fonts, AES-256 (R6). User password `Eylül2026maaşı` (ı, ş and ü; SASLprep, then UTF-8), owner password `bordro-yonetim-2026`. The wrong password `eylul2026` fails. macOS PDFKit does not open it with this password; PDFium does | M2 |
| `generated/payslip-rc4-40.pdf` | `tools/corpus generate --only payslip-rc4-40` | generated | `2c2234395d6d0c67aca45fd698e9451f17b964adfab99bb3c704612868846ee9` | The payslip with RC4 40-bit (R2), password `bordro2026` | M2 |
| `generated/payslip-rc4-128.pdf` | `tools/corpus generate --only payslip-rc4-128` | generated | `08df21f790e866069ae37b03a7da250912a5defabba870e251fa62c53fdab22a` | The payslip with RC4 128-bit (R3), password `bordro2026` | M2 |
| `generated/payslip-aes128.pdf` | `tools/corpus generate --only payslip-aes128` | generated | `ecf5554baac33a44b428af80ef77d103e9d39643d371d29ca0f5005a0435c784` | The payslip with AES-128 (R4), password `bordro2026` | M2 |
| `generated/xfa-visa.pdf` | `tools/corpus generate --only xfa-visa` | generated | `b07dc5d11eb6779e5d3dccf767c0847dc2b8c7dc9a09236c833e3589a3d0e78f` | `a11-7c`: a dynamic XFA-only form. The XDP is in five packets under `/AcroForm /XFA`, with `/NeedsRendering true` and no AcroForm fields. The page says that the form needs an XFA viewer | M2 |
| `generated/form-aks1-tr.pdf` | `tools/corpus generate --only form-aks1-tr` | generated | `7dd136b850124622daf25b207c456751ac9cdc7b1c415f20054669250bc79b0d` | `DocForm`, [G59](../../docs/DESIGN_GAPS.md#g59): e-Devlet Form AKS-1, 1 page. 20 fields, 15 of them required, with the design's names in the design's order: 10 text fields, 3 dates with `AFDate` format and keystroke actions, a radio group, 3 combo boxes, 2 check boxes and a signature field. `AFRange_Validate(1, 20)` on `hane_kisi_sayisi`. Unfilled. Its field scripts are document JavaScript | M2 |
| `generated/form-aks1-flat.pdf` | `tools/corpus generate --only form-aks1-flat` | generated | `d99f97fc65e9e2e452284a94d1c0ffab55e4ccf041e2ca4b245b0c8d2deeff3b` | `a5-4`, `a5-8b`: the same page with no fields; the boxes are only drawn | M2 |
| `generated/mietvertrag-de.pdf` | `tools/corpus generate --only mietvertrag-de` | generated | `d1bf7f9438fde1e0a9704b527ba5f5bd3caf594e3bdc215f02843f7769f7a76c` | 6-page German lease with umlauts, ß, „ “, § and €. IBM Plex Serif simple TrueType WinAnsi subsets only, `TJ` justification. "Müller" for search folding ([G61](../../docs/DESIGN_GAPS.md#g61)). Annex 1 is a table | M2 |
| `generated/nda-en.pdf` | `tools/corpus generate --only nda-en` | generated | `99235cd6c1db4db7f53da4405b1aabd1d3fab7213764c3fb09a0e0f1ab3cf669` | 4-page English mutual NDA in IBM Plex Sans simple TrueType. A signed `/Sig` field on page 4: its `/ByteRange` surrounds an 8,192-byte `/Contents` of zeros. It has a signature's structure, with no cryptographic signature (P3). `/SigFlags 3` | M2 |
| `generated/report-ar.pdf` | `tools/corpus generate --only report-ar` | generated | `1501ba5dcd22d97afea1f3ee1439294ee9a311a469714cb23d5f1d2bd5ef704f` | `a2-15`, "التقرير السنوي 2025.pdf": 12-page Arabic annual report in IBM Plex Sans Arabic composite subsets, `/ViewerPreferences /Direction /R2L` ([G32](../../docs/DESIGN_GAPS.md#g32)). Lines in visual order with Western-digit numbers, an IBAN, "ISO 9001" and an e-mail address left to right inside them; lam-alef and other ligatures, marks on their letters, mirrored parentheses, Arabic-Indic page numbers, three tables. Expected text in logical order | M2 |
| `generated/letter-ja-vertical.pdf` | `tools/corpus generate --only letter-ja-vertical` | generated | `582d3124222889ce1a51bd1ac823dc9071bdc051fb74a4386c0ef13d8f727d5e` | `a3-15`, "賃貸借契約更新のご案内.pdf": 1-page Japanese letter in vertical text, Noto Serif JP at two instances of the variable font (400 and 600) as `Identity-V` subsets with `/W2` and `/DW2` and vertical punctuation forms; "19" upright across its column (tate-chu-yoko) in an `Identity-H` font; kinsoku, with a hanging comma; `TJ` letter spacing | M2 |
| `generated/tez-tr.pdf` | `tools/corpus generate --only tez-tr` | generated | `d7554171f7f78679fac64b49785a2a2608ce24fb1558fd40ddd799802608ae78` | `a2-1d`, `a2-3a`, `a3-14`: 64-page tagged thesis in composite IBM Plex Serif with ligatures and `TJ` justification. Object streams and a cross-reference stream (PDF 1.5). Page labels i to viii, then 1 to 56. A nested outline of chapters, sections and subsections. A structure tree of `H1` to `H3`, `P` and `BlockQuote`, with the page numbers as artifacts, and `/Lang en-US` on the English abstract and block quote (E08) | M2 |
| `generated/ocg-plan.pdf` | `tools/corpus generate --only ocg-plan` | generated | `6580f85eb3e886cf129940363d714de2b92d8abe3de429efe1bda1ba3be4e81a` | `DocPlan`: an A4 landscape floor plan at 1:75 in six layers (OCGs). "Tesisat" is off by default and holds no text. A `/VP` viewport has a `/Measure` dictionary for the 1:75 scale | M2 |
| `generated/js-openaction.pdf` | `tools/corpus generate --only js-openaction` | generated | `2fe58c40a88b99f631d36df462dd7e981133a8ff70ab51e24830fbef5c629736` | [Q13](../../docs/QUESTIONS.md#q13), [G100](../../docs/DESIGN_GAPS.md#g100): a 1-page English notice with JavaScript in `/OpenAction`, the `/JavaScript` name tree and the page's `/AA /O`. Its Helvetica is named, with widths, and not embedded | M2 |
| `generated/scan-tr.pdf` | `tools/corpus generate --only scan-tr` | generated | `ad2690b402b9aea925a352f261788785036d667ec912015bda4a5ac52a8b5be9` | `a3-11`, "Kira artış bildirimi (tarama).pdf": a 3-page Turkish letter with two enclosures, image only: greyscale at 200 dpi, turned 0.6°, Flate with the PNG Up predictor. No text; the text drawn is in the generator, for the OCR test of P3 | M2 |
| `generated/quote-ja-scan.pdf` | `tools/corpus generate --only quote-ja-scan` | generated | `e170e51fced28d32b16e5a61a483fdad8210594e832e5c2d75c5950dbcdf2387` | "見積書_2026-10.pdf": a 2-page Japanese quotation, image only: black and white at 300 dpi, one bit per pixel, turned 0.4°, Flate. No text | M2 |
| `generated/long-500.pdf` | `tools/corpus generate --only long-500` | generated | `682a809c3700f53ca030e433d1afe67f4d00fd04dd3816747c8c4d2742e2cf15` | ARCHITECTURE §14: 500-page English handbook in simple TrueType WinAnsi subsets, with `Tw` justification. Over 1 MB, so it is regenerated, not committed | M2 |
| `generated/imar-2400.pdf` | `tools/corpus generate --only imar-2400` | generated | `6814fe87d253d2988945756e632606894fdd416051d410e53ad3ca180127cd67` | `a1-7`: 2,400-page Turkish zoning report, with a parcel table and a plan note on every page. Over 1 MB, so it is regenerated, not committed | M2 |
