# tools/fonts

Installs IBM's unmodified IBM Plex TTF files into `app/assets/fonts/` from the IBM/plex
GitHub release zips pinned in `fonts.lock`, and checks the committed copies offline
([ADR 0013](../../docs/adr/0013-fonts-and-icons.md),
[DEPENDENCIES.md §5.2](../../docs/DEPENDENCIES.md#52-fonts)).

The files are never subset, converted, renamed or otherwise modified: the licence reserves the
font name "Plex". Only the file mode is set to 0644 (some zip entries are marked executable).

## What is bundled

| Package (IBM release) | Zip SHA-256 | Font revision | Files in `app/assets/fonts/ibm-<package>/` |
|---|---|---|---|
| `@ibm/plex-sans@1.1.0` | `fb365d91…69200` | 3.005 | `IBMPlexSans-Regular.ttf` (400), `-Italic.ttf` (400 italic), `-Medium.ttf` (500), `-SemiBold.ttf` (600) |
| `@ibm/plex-serif@2.0.0` | `c006b095…51f1e` | 3.006 | `IBMPlexSerif-Regular.ttf` (400), `-Italic.ttf` (400 italic), `-SemiBold.ttf` (600) |
| `@ibm/plex-mono@2.5.0` | `6d23f012…c481c` | 2.005 | `IBMPlexMono-Regular.ttf` (400), `-Medium.ttf` (500) |
| `@ibm/plex-sans-arabic@1.1.0` | `f0391558…14013` | 1.005 | `IBMPlexSansArabic-Regular.ttf` (400), `-Medium.ttf` (500), `-SemiBold.ttf` (600) |
| `@ibm/plex-sans-hebrew@1.1.0` | `d7d490b8…369fd` | 1.003 | `IBMPlexSansHebrew-Regular.ttf` (400), `-Medium.ttf` (500), `-SemiBold.ttf` (600) |
| `@ibm/plex-sans-devanagari@1.1.0` | `effc4a35…8ac94` | 1.002 | `IBMPlexSansDevanagari-Regular.ttf` (400), `-Medium.ttf` (500), `-SemiBold.ttf` (600) |

Each folder also holds the package's `LICENSE.txt` (OFL-1.1, "Copyright © 2017 IBM Corp. with
Reserved Font Name "Plex""; the six files are identical). In total 18 TTFs and 6 licences,
3,919,740 bytes. The full hashes are in `fonts.lock`. Each pinned version was the newest
release tag of its package on 2026-10-15.

### Why these weights and styles

Taken from the design system, not guessed:

- `tokens/fonts.css` declares exactly these faces: Plex Sans 400/500/600, Plex Sans Arabic
  400/500/600, Plex Serif 400, 600 and 400 italic, Plex Mono 400/500. `typography.css` uses
  only `--weight-regular` 400, `--weight-medium` 500 and `--weight-semibold` 600.
- **Plex Sans Italic (400):** the font picker's missing-font state sets the name in italic UI
  text (`components/forms/forms.css`, `.fm-fonttrigger--missing`), the case ADR 0013 names.
  The design's CSS declares no italic Plex Sans face, so the browser renders that state with a
  synthesised oblique; the app uses IBM's real italic.
- **Plex Serif:** 600 for the wordmark (`--type-wordmark`); 400 italic for the typed signature
  (`components/fill-sign/fill-sign.css`); 400 as declared by the design system and used by the
  fill-sign form field text (`--font-doc-sample`).
- **Plex Mono 400/500** only. The boards also use `font: 600 … var(--font-mono)`, but only for
  their own section numbers ("1.1", "1.2a"), which are board annotation, not app UI.
- **Plex Sans Hebrew and Devanagari 400/500/600**, the weights `fm-additions.css` requests
  (approved by the owner in Q08 on 2026-10-15).
- Not bundled: 700 (`font: 700` appears only in a mobile large title, a later phase), the Text
  (450), Light, ExtraLight and Thin weights, and other italics. Adding one is a `fonts.lock`
  line plus a `pubspec.yaml` entry.

## Usage

```sh
tools/fonts/fetch.sh                     # download (cached in build/fonts/cache/), check, install
tools/fonts/fetch.sh --verify-committed  # offline: the committed files equal fonts.lock (CI)
tools/fonts/selftest.sh                  # offline: proves that bad files are rejected
python3 -I tools/fonts/coverage.py       # script coverage and naming report
python3 -I tools/fonts/coverage.py --pubspec   # the pubspec.yaml fonts block
```

- A download goes to a `.part` file, is hashed, and is kept only if the zip's SHA-256 matches.
- Every pinned file is extracted into a staging folder and hashed. Only when every package
  passes are the `ibm-<package>/` folders replaced, so a failure leaves the committed fonts as
  they were.
- `--verify-committed` fails on a changed or missing file and on any file in
  `app/assets/fonts/` that `fonts.lock` does not pin (a subset or converted copy, for example).
  OS metadata files that `.gitignore` also ignores (`.DS_Store`, `Thumbs.db`, `desktop.ini`)
  are not counted, so a folder opened in Finder or Explorer still verifies.
- The install replaces only the `ibm-<package>/` folders named in `fonts.lock`; other files in
  the destination are left alone. The staging folder is a hidden folder inside the destination.
- `LICENSE.txt` is released with CRLF line endings. Its hash is checked on the text with CRLF
  line endings whatever the checkout did to them, so a checkout with LF line endings still
  verifies, while any change of wording fails.
- Exit status: 0 success, 1 a check or download failed, 2 usage error.
- Needs bash (3.2 or later), curl, unzip, awk, sed and `sha256sum` or `shasum`; the offline
  check needs no unzip and no network. curl honours `HTTPS_PROXY`. Works on macOS, Linux and
  Git Bash on Windows. `coverage.py` needs only the Python 3 standard library.

The self-test checks, on temporary copies: the committed fonts verify; a changed byte, a
missing font, an extra file and a reworded licence each fail; OS metadata files and a licence
with LF line endings pass. With python3 and unzip present it also builds a stand-in release zip and checks that a
matching zip installs byte-identical files, and that a zip or a font with the wrong hash is
rejected without touching the installed fonts.

## fonts.lock

One record per line, fields separated by spaces, `#` starts a comment:

```text
url      <release zip URL; {package} and {version} are filled in>
package  <package> <version> <SHA-256 of the release zip>
license  <package> LICENSE.txt <SHA-256 of the file as released, with CRLF line endings>
font     <package> <file name> <SHA-256 of the file as released>
```

The files come from `ibm-<package>/LICENSE.txt` and `ibm-<package>/fonts/complete/ttf/<file>`
inside the zip.

## Coverage (coverage.py)

Result for the committed files (2026-10-16), every check passing. CI runs it in the
repository-checks job, after `--verify-committed`:

- **Plex Sans** (all four files): Basic Latin U+0020 to U+007E, the Latin-1 letters U+00C0 to
  U+00FF, Turkish (İ ı Ğ ğ Ş ş Ç ç Ö ö Ü ü Â â Î î Û û), Vietnamese
  U+1EA0 to U+1EF9 plus Ă Đ Ơ Ư and the combining marks, Cyrillic U+0400 to U+045F plus Ґ ґ,
  Greek with tonos and dialytika, and the UI punctuation including € and ₺.
- **Plex Sans Arabic:** Arabic letters, harakat, Arabic-Indic digits, the Persian letters
  پ چ ژ گ ک ی and the Persian digits. It does not map U+200C (zero width non-joiner); Plex Sans
  does.
- **Plex Sans Hebrew:** letters, points and punctuation. **Plex Sans Devanagari:** letters,
  vowel signs, digits and the dandas.
- The golden sample "İMZALA ğ ş ı · Tiếng Việt · Русский · Ελληνικά · العربية · فارسی · עברית ·
  हिन्दी" resolves through the chain Plex Sans → Arabic → Hebrew → Devanagari with no missing
  character.
- Plex Sans Arabic, Hebrew and Devanagari carry ASCII and the Latin-1 letters themselves, but
  not Latin Extended-A (only 1 of İ ı Ğ ğ Ş ş), so Plex Sans must follow each of them in every
  fallback chain.

## Upgrading

1. Change the `package` record (version and zip SHA-256) and the `font` and `license` hashes in
   `fonts.lock`.
2. Run `tools/fonts/fetch.sh`, then `tools/fonts/selftest.sh` and
   `python3 -I tools/fonts/coverage.py`.
3. Update DEPENDENCIES.md §5.2 in the same change, and compare the UI against the design
   references, since metrics can change between font revisions.
