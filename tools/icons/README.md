# tools/icons

Writes the design's icons for the app and renders the component reference
([ADR 0013](../../docs/adr/0013-fonts-and-icons.md), [G04](../../docs/DESIGN_GAPS.md#g04),
[G60](../../docs/DESIGN_GAPS.md#g60), [G02](../../docs/DESIGN_GAPS.md#g02)). Pure Dart; no Flutter
needed to run it.

```sh
cd tools/icons
dart pub get
dart run                                  # write the icon files (only those that changed)
dart run icons --check                    # write nothing; exit 1 if a file is missing or stale
dart run icons --lucide ../../build/lucide         # recompute provenance from the npm tarballs
dart run icons --check --lucide ../../build/lucide # also verify provenance and licence texts
dart run icons:component_spec             # render the reference part of docs/COMPONENTS.md
dart run icons:component_spec --check     # exit 1 if docs/COMPONENTS.md is stale
dart test
```

`--root <dir>` points at another checkout; by default the repository root is the nearest parent
directory that holds `design/` and `tools/icons/`. Exit codes: 0 success, 1 stale (`--check`), 2 the
sources cannot be generated, 64 bad usage. `design/` is only read.

## Icons

Inputs: `ICON_PATHS` in `design/_ds/…/_ds_bundle.js` (145 glyphs) and the `ADD` map of
`design/ds-additions/fm-icons.js` (84 glyphs, merged into `ICON_PATHS` at run time). A small reader
parses the two JavaScript object literals (quoted keys, quoted strings with escapes, comments) and
fails on anything else. The counts are part of the contract: a re-export with a different count
stops the tool until ADR 0013 is reviewed.

Outputs:

| File | Content |
|---|---|
| `app/assets/icons/<name>.svg` (229) | `<svg … viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">` + the design's child markup byte for byte + `</svg>` and a newline. The exported, provenance-tracked set; the app does not load these files. |
| `app/lib/design/icons/icon_name.g.dart` | `enum IconName` with one value per icon in name order (`chevron-right` → `chevronRight`), `id`, `directional` and `IconName.fromId`. Plain Dart, formatted with `dart format`. |
| `app/lib/design/icons/icon_data.g.dart` | `extension IconNameElements on IconName` with `elements`: an exhaustive switch giving each icon's SVG elements as const instances of the sealed classes in the hand-written `icon_element.dart` (`IconPath`, `IconCircle`, `IconEllipse`, `IconRect`, `IconLine`, `IconPolyline`, `IconPolygon`). Numbers keep the design's text (`r: .5`), path data and points stay strings, and `fill="currentColor"` becomes `filled: true`. The Icon widget paints this data; no SVG package is used because they depend on `http`. |
| `app/assets/icons/PROVENANCE.md` | Per icon: design source, matching Lucide releases, the source used and whether it mirrors in RTL; the licence files and the counts. |
| `app/assets/icons/LICENSE-lucide-0.460.0.txt` | `package/LICENSE` of lucide-static 0.460.0, verbatim (byte-identical in 0.300.0 and 0.500.0). |
| `app/assets/icons/LICENSE-lucide-1.56.0.txt` | `package/LICENSE` of lucide-static 1.56.0, verbatim; it lists the Feather-derived icons and carries the MIT text. |
| `tools/icons/lucide_matches.json` | For each icon, the pinned releases whose icon of the same name has the same geometry. |

Directional icons are the eight the design flips in right-to-left (`lib/src/directional.dart`, with
the evidence for each); a test re-reads the design files and fails if a flipped glyph is missing.

The element data understands exactly the elements and attributes the design uses
(`lib/src/icon_data.dart`). An unknown element, an unknown attribute (other than `class`, `id` and
`key`, which are dropped), a missing attribute, a number with units or any `fill` but
`currentColor` stops the tool, so the painter is extended on purpose rather than drawing a re-export
wrongly. `test/icon_data_test.dart` compiles the generated data with the enum and the element
classes as plain Dart and checks that it prints back the design's markup for all 229 icons.

Every text file is read with its line endings normalized to LF, so a Windows checkout with
`core.autocrlf` (CRLF design sources or licence texts) gives the same output and passes `--check`;
the licence hashes are taken over the LF text.

### Provenance

`lib/src/lucide.dart` pins four lucide-static releases in preference order: 0.460.0, 1.56.0, 0.500.0
and 0.300.0 (G60). Each pin holds the npm integrity hash of the tarball and the SHA-256 of its
`LICENSE`. With `--lucide <dir>` the tool downloads missing tarballs with curl from
`registry.npmjs.org` into `<dir>` (use `build/lucide`, which git ignores), checks both hashes, reads
`package/LICENSE` and `package/icons/<name>.svg` straight from the tar.gz, compares the geometry
(same elements in the same order with the same attributes; attribute order and whitespace ignored)
and rewrites `lucide_matches.json` and the licence texts. `lucide_matches.json` records, per icon, the
SHA-256 of its markup with the matching releases. Without `--lucide` the tool works offline from the
committed matches, stops when an icon's markup no longer has the recorded hash (its provenance must be
recomputed), and only checks the licence files against the pinned hashes; a failed licence check
stops the run before anything is written.

Result: 222 glyphs match 0.460.0; bell, funnel and grid-2x2 match 1.56.0; expand and paperclip match
0.500.0; file-signature matches 0.300.0; ellipse matches no release and is listed as Ferman design,
pending Q11.

## Component reference

`dart run icons:component_spec` replaces the region between the `GENERATED COMPONENT REFERENCE`
markers in `docs/COMPONENTS.md` with tables rendered from `app/test/design/component_spec.json`. The
JSON is written by hand from the design export (the schema is documented in COMPONENTS.md);
`test/component_spec_test.dart` checks it against the manifest, the lint config
(`_adherence.oxlintrc.json`), the bundle sections and every CSS or board line it cites.

## Dependencies

args, crypto and path (BSD-3-Clause, Dart team); test (BSD-3-Clause) and very_good_analysis (MIT)
for development. The lucide-static tarballs (ISC) are read at development time only and never ship;
only the two licence texts are copied.
