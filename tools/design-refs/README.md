# tools/design-refs

Renders every board of the read-only design export in `design/` to one PNG per board id, offline,
as the visual reference the app's goldens are compared against
([ROADMAP §5 step 6](../../docs/ROADMAP.md), [G07](../../docs/DESIGN_GAPS.md#g07)). It reads
`design/` and never writes to it. The output goes to `build/design-refs/`, which is gitignored.
`node tools/design-refs compare` then lines the app's goldens up with those references and writes
a report with a perceptual difference score per pair
([ROADMAP §5 step 11](../../docs/ROADMAP.md); [Comparing goldens with the references](#comparing-goldens-with-the-references)).
Nothing here is part of the app.

## Usage

Node 24.22.0 (`.nvmrc`) and the Chromium headless shell revision 1194 (Chromium 141.0.7390.37),
the browser of playwright-core 1.56.1.

```sh
(cd tools/design-refs && npm ci)                  # exact versions from package-lock.json
(cd tools/design-refs && npm test)                # unit tests, no browser needed

# The browser. Linux x64: download, check and unpack it once (prints the executable's path).
export FERMAN_CHROMIUM="$(tools/design-refs/fetch-chromium.sh)"
# The development container already has it in /opt/pw-browsers, which is found on its own.

node tools/design-refs                            # all 223 boards + the DS additions sheet
node tools/design-refs --only @m1                 # the 17 M1 boards
node tools/design-refs --only a1-1,a11-1 --twice  # render twice, fail unless identical
node tools/design-refs --list                     # ids, capture mode, file; the sets
node tools/design-refs compare                    # goldens against references: build/design-compare/
```

| Option | Meaning |
|---|---|
| `--only <ids>` | Render only these ids: comma-separated, repeatable. `@m1` expands the M1 set from `boards.json`; `ds-additions` is the DS additions sheet. |
| `--out <dir>` | Output directory. Default: `build/design-refs` in the repository, whatever the working directory. Refused inside `design/`, also through a symlink, and regardless of case on a case-insensitive filesystem (macOS, Windows): the check compares real paths (of the nearest existing folder when `<dir>` does not exist yet). |
| `--twice` | Render the same boards again in a freshly launched browser and fail unless every PNG has the same SHA-256. For a board that differs, both renders and a pixel diff go to `<out>/_diffs/<id>.first.png`, `.second.png` and `.diff.png`. |
| `--jobs <n>` | Boards rendered in parallel. Default: the number of CPUs, at most 4. The output does not depend on it. |
| `--chromium <path>` | The Chromium executable to launch. See [The browser](#the-browser). |
| `--write-boards` | Regenerate `boards.json` from the design files (after a re-export), keeping its sets. |

Output: `<out>/<id>.png` for each board and `<out>/manifest.json` with every PNG's size and
SHA-256, the playwright-core and Chromium versions, and the viewport. A `--only` run updates the
manifest entries of the boards it rendered and keeps the others.

A board fails, and leaves no PNG, when:

- its element is missing, not unique, or still shows a runtime placeholder or error (below);
- its page throws an uncaught error (Playwright's `pageerror`), unless an entry in
  `ALLOWED_PAGE_ERRORS` in `browser.mjs` covers it; each entry names the boards, a pattern and
  the reason the board is still complete, and the list is empty today;
- one of its requests is blocked, or asks for a file that is missing from `design/`;
- with `--twice`, its second render fails or differs from the first.

A failing board's PNG from an earlier run is deleted and its manifest entry dropped, so nothing
stale looks current.

The exit code is 0 only if every requested board has its PNG. It is 1 if a board failed, a PNG is
missing (the count check), a request tried to leave the machine, a file the design references is
missing from `design/`, `--twice` found a difference, or the browser cannot be found or launched;
2 for a usage error.

Measured in the development container (4 CPUs, 4 jobs): all 224 PNGs in about 3 minutes, the 15
M1 boards in about 15 seconds; `--twice` doubles that.

## Comparing goldens with the references

`compare` lines up each window golden of the app (phase K1) with the render of the board it was
built from, scores how far apart they are, and writes the images a person needs to judge it. It
is informative: in M1 a person reviews the report, and no score fails a run
([ROADMAP §5 step 11](../../docs/ROADMAP.md), [ARCHITECTURE §13.5](../../docs/ARCHITECTURE.md#135-flutter-tests)).
It needs no browser and no network: it reads PNGs and writes PNGs and Markdown.

```sh
node tools/design-refs --only @m1                 # the references first (or a full render)
node tools/design-refs compare                    # → build/design-compare/report.md
node tools/design-refs compare --goldens <dir> --out <dir> --threshold 0.05
```

| Option | Meaning |
|---|---|
| `--refs <dir>` | The board renders, `<dir>/<board>.png`. Default: `build/design-refs`. |
| `--goldens <dir>` | The goldens. Default: `app/test/goldens/goldens/linux`. |
| `--out <dir>` | Output directory. Default: `build/design-compare`. Refused inside `design/` and inside the goldens folder. |
| `--map <file>` | The pairs. Default: `tools/design-refs/compare-map.json`. |
| `--threshold <t>` | pixelmatch's colour threshold, from 0 to 1: how far apart, in its YIQ colour distance, two pixels may be and still count as the same. Default: 0.1, pixelmatch's own default. |

Output, in `--out`:

- `report.md`: a summary line (pairs compared, missing, with errors, not compared; the median and
  highest share of differing pixels), how to read the scores, and one table row per pair with its
  result, both scores, its images and its notes (the map's note, the crops and the masks).
- `<pair>.side.png`: reference | golden | diff side by side, with a grey gap and every masked area
  outlined in magenta on the reference and the golden.
- `<pair>.diff.png`: pixelmatch's diff: the reference faded, red where pixels differ beyond the
  threshold, yellow where the difference is anti-aliasing (not counted), grey stripes where a mask
  applies.

Each pair's two images are deleted before it is compared, so a pair that is missing this time
leaves no image from an earlier run. The report holds no time stamp; in GitHub Actions it links
the run whose `design-compare` artifact holds the images.

A pair's result is one of:

| Result | When |
|---|---|
| `compared` | Both images exist and have the same size after cropping. |
| `missing` | The golden, the reference or both do not exist (the row says which). A missing goldens folder makes every pair missing; it is not an error, because the goldens may come later than the map. |
| `error` | An image cannot be decoded, a crop lies outside its image, a golden without a `goldenCrop` is not 1440 × 900, or the two sides differ in size. |
| `not compared` | The map gives the reason instead of a golden. |

Exit codes: 0 when the report is written, whatever the scores and results; 64 for a usage error;
66 when the map cannot be read or is invalid, or the reference folder does not exist; 1 for
anything unexpected.

### The scores

- **Differing pixels**: the share of the compared pixels (those no mask covers) whose colour
  differs by more than the threshold, with anti-aliased pixels left out (pixelmatch detects a pixel
  as anti-aliasing from its neighbours in both images). It answers "how much of the window is a
  different colour". Identical images score 0 %; one changed pixel of 1440 × 900 is 0.00008 %.
- **1 − SSIM**: one minus the mean structural similarity (SSIM, Wang et al. 2004) of the luma
  (Rec. 601) over 8 × 8 windows in steps of 4, with masked pixels left out of every window. It
  answers "how different is the structure": edges, text and texture. 0 is identical.

What they do not mean:

- They are not a pass mark, and no threshold says "matches the design". Flutter and Chromium
  rasterise text differently, so a faithful golden still differs at the edges of its glyphs
  (pixelmatch leaves out what it recognises as anti-aliasing; SSIM does not), and the expected
  differences (the licence text of `a1-2c`, the network rows of `a1-2b`, a disabled control)
  count like real ones. Read the side-by-side image.
- They are not comparable across pairs: a window that is mostly flat background dilutes its share
  of differing pixels. For scale, measured on the references themselves: the whole window shifted
  right by 1 px gives 0.66 % to 0.86 % and 1 − SSIM 0.031 to 0.039 (`a1-2c`, `a1-5`, `a11-1`); two
  different screens (the `a1-5` render standing in for the `a1-2c` golden) give 2.21 % and 0.1523.
- 1 − SSIM does not see a change of colour at the same luma; the differing-pixel score does,
  through pixelmatch's YIQ distance. Neither looks under a mask.

### The map

`compare-map.json` lists every pair. `goldenSize` is the contract with the goldens: a whole
window at 1440 × 900 and a device pixel ratio of 1, named
`<screen>_<mac|win>_<light|dark>_<en|tr|ar>.png` with the screens of the golden matrix. Each pair:

| Field | Meaning |
|---|---|
| `board` | A board id of `boards.json`; its reference is `<refs>/<board>.png`. |
| `id` | The pair's name in the report and its image names. Default: the board id; required when a board has two pairs (`f6-mac`, `f6-win`). |
| `golden` | The golden's file name, or none with `notCompared`. |
| `notCompared` | Why the board has no golden. |
| `crop` | `{x, y, width, height}`: the part of the board render to compare. Needs `cropSource`. |
| `cropSource` | How the crop rectangle was found. |
| `goldenCrop` | The part of the golden to compare (default: all of it). Both sides must have the same size. |
| `masks` | `[{label, x, y, width, height}]` in the compared frame (after cropping): areas neither score counts. |
| `note` | What a reviewer should know: what the board shows and which differences are expected. |

Every run checks the map (unknown keys, unknown boards, golden names, rectangle sizes, masks inside
the frame) and stops with exit code 66 on a problem. The tests check that it names every board of
the `@m1` set, and only boards of that set, which CI renders.

| Pair | Golden | Crop and masks | Why |
|---|---|---|---|
| `f6-mac` | `shell_edit_mac_light_en` | board 0, 182, 1440 × 79; golden top 79 rows | Fix 6's macOS title bar and mode bar strip (Edit mode). |
| `f6-win` | `shell_edit_win_light_en` | board 0, 318, 1440 × 79; golden top 79 rows | Fix 6's Windows strip. |
| `f6a` | `shell_edit_win_light_en` | board 0, 45, 1440 × 900; canvas masked | The Windows editor window, Edit mode. |
| `a1-1` | `language_picker_mac_light_en` | | Language picker, macOS, light, English. |
| `a1-2b` | `welcome_privacy_mac_light_en` | | Welcome step 2 (G24 changes the rows). |
| `a1-2c` | `welcome_free_mac_light_en` | | Welcome step 3 (G12, G13 change the texts). |
| `a1-5` | `start_mac_light_en` | | The empty start screen. |
| `a11-1` | `settings_general_mac_light_en` | | Settings General, macOS. |
| `a11-1w` | `settings_general_win_light_en` | | Settings General, Windows chrome. |
| `a11-1b` | `settings_language_mac_light_en` | | Settings Language and region (region Türkiye). |
| `a12-2a` | `start_mac_light_ar` | rows 232 to 899 masked | Start in Arabic; the board's recent files are M2. |
| `a12-2b` | none | | German board: no German golden in M1. |
| `a12-2c` | `settings_language_mac_light_ar` | | Settings Language and region in Arabic. |
| `a12-2d` | none | | German board: no German golden in M1. |
| `a2-1b` | `shell_view_mac_light_en` | canvas masked | The macOS chrome, light (ROADMAP step 8). |
| `a3-1d` | `shell_edit_mac_dark_en` | canvas masked | The macOS chrome, dark (ROADMAP step 8). |
| `a12-1tr` | `shell_edit_mac_light_tr` | canvas masked | The macOS chrome in Turkish, Edit mode. |
| `a12-1ar` | `shell_edit_mac_light_ar` | canvas masked (mirrored, 264, 123) | The macOS chrome in Arabic, right to left, Edit mode. |

The canvas mask is 960 × 751 at 216, 123: FmWindow's canvas between the sidebar (216 px) and the
right panel (264 px), below the title bar, mode bar and tool row (38 + 40 + 45 px) and above the
status bar (26 px), as measured in the `a2-1b`, `a3-1d` and `f6a` renders. It hides the document
those boards draw; M1 opens none.

How the fix-board crops were found. The renders of `f6` (3468 × 1433) and `f6a` (3468 × 1008)
are wider than a window, because the fix sections stretch to the widest section of their page,
and they hold headings and captions. The windows inside them are `.fm-root` elements: in
`section#f6`, two strips of 1440 × 79 (FmWindow `platform=mac` and `platform=win`, `mode=edit`,
no status bar) and one 1440 × 900 window; in `div#f6a`, the same 1440 × 900 window. Their boxes
were measured in the renderer's page relative to the board's clip (182.41, 317.5 and 469.69 px
down in `f6`, 44.69 px in `f6a`, all at x 0) and checked in the PNGs, where each box's 1 px
box-shadow ring is the row above it, the row below it and column 1440. The window inside `f6`
(rows 470 to 1369) is pixel-identical to the `f6a` crop, so `f6` is compared through its two
strips, and the window once, as `f6a`. Both strip crops were confirmed to the pixel: the top 79
rows of the `f6a` window (Windows) and of the `a3-1c` render (a light macOS Edit window) equal
them, with 0 differing pixels and 1 − SSIM 0. After a design re-export, measure again: the boards'
box positions can move.

In CI, the design-references workflow runs `compare` after rendering the M1 boards, appends
`report.md` to the job's step summary and uploads `build/design-compare/` as the
`design-compare` artifact.

## The browser

The renderer launches the first of these that applies:

1. `--chromium <path>`;
2. the environment variable `FERMAN_CHROMIUM`;
3. `$PLAYWRIGHT_BROWSERS_PATH/chromium_headless_shell-1194/` (`chrome-linux/headless_shell`,
   `chrome-mac/headless_shell` or `chrome-win/headless_shell.exe`), if it exists;
4. the same under `/opt/pw-browsers`, where the development container keeps it;
5. otherwise Playwright's own default browser folder.

A path given with 1 or 2 that does not exist stops the run. The run logs which executable it
launched and warns when its version is not 141.0.7390.37, the one playwright-core 1.56.1 expects
(`node_modules/playwright-core/browsers.json`).

`fetch-chromium.sh` (bash and curl, Linux x64) gets the browser without the Playwright installer,
which would also download Playwright's ffmpeg build (LGPL-2.1):

- it downloads `chromium-headless-shell-linux.zip` of revision 1194 from the Playwright CDN
  (`cdn.playwright.dev`, then `playwright.download.prss.microsoft.com` if that fails), over
  HTTPS only;
- it checks the zip's SHA-256 against `CHROMIUM_SHA256` in the script;
- it unpacks it into `<cache-dir>/chromium_headless_shell-1194/` (default
  `~/.cache/ferman/design-refs`; the folder layout Playwright uses, so
  `PLAYWRIGHT_BROWSERS_PATH=<cache-dir>` works too) and prints the executable's path on stdout;
- a later run reuses the unpacked copy; `--zip <file>` checks and unpacks a zip downloaded before.

**The hash is pinned.** `CHROMIUM_SHA256` holds the SHA-256 of `chromium-headless-shell-linux.zip`
for revision 1194 (`d745c721…c91f`), taken from the first CI download on 2026-10-15 (the CDN is
blocked in the development container). A different zip fails the step. When the revision
changes, set `CHROMIUM_SHA256=UNPINNED`: the script then prints the computed SHA-256 with a loud
warning (also as a GitHub Actions `::warning::` and in the step summary) and carries on, so the
new hash can be copied from the CI log.

On macOS and Windows, download the matching zip of the same revision by hand
(`chromium-headless-shell-mac-arm64.zip`, `-mac.zip` or `-win64.zip` under the same CDN path),
unpack it and pass its `headless_shell` executable with `--chromium`.

In CI (Linux) the design-refs job runs, in `tools/design-refs`:

```sh
npm ci && npm test
npx playwright-core install-deps chromium-headless-shell   # system libraries and fonts (apt)
exe=$(./fetch-chromium.sh "$RUNNER_TEMP/chromium")   # an assignment, so a failure fails the step
echo "FERMAN_CHROMIUM=$exe" >> "$GITHUB_ENV"
node index.mjs --only @m1 --twice                   # in a later step, with FERMAN_CHROMIUM set
node index.mjs compare                              # then the report, appended to the step summary
```

## What is captured

`boards.json` lists the 223 boards in file and document order, each with its design file and
capture mode, plus the DS additions sheet as one extra page and the named sets. Every run checks it
against a fresh scan of the design files (`id="f…"`/`id="a…"` on a board element, or `bid="a…"`
passed to FmBoard) and stops if they disagree; a re-export needs `--write-boards`.

| Mode | Boards | What is screenshotted |
|---|---|---|
| `element` | the 9 fix boards `f1` to `f6a` in `00 Fixes` | the element with the id: the whole `section#fN` for `f1` to `f6`; the `div` with the id for `f4a`, `f4b` and `f6a`, which sit inside the sections `f4` and `f6` |
| `fm-root` | the 214 product boards | the first `.fm-root` inside the element with the id, which is the board frame; for the seven sidebar boards `a2-3p` to `a2-3x` the element with the id is itself the `.fm-root` |
| `page` | the DS additions sheet (`ds-additions.png`) | the page's outer `.fm-root` |

The fix sections stretch to the width of the widest section on their page, so `f1` to `f6a` are
3468 px wide with empty space on the right. A board whose element is missing, is not unique, or
still holds a runtime placeholder or error (`.sc-placeholder`, `.sc-logic-error`, an unresolved
`{{ … }}` value) fails instead of producing a PNG.

## Offline by construction

- `server.mjs` serves `design/` read-only on an ephemeral port of 127.0.0.1: GET and HEAD for
  regular files only, no directory listings, nothing outside `design/` (also not through symlinks).
- `routes.mjs` routes every request of the browser (Playwright `context.route`):
  - the local server passes through;
  - `https://unpkg.com/…`: the three scripts `design/support.js` names (React and ReactDOM
    18.3.1, Babel standalone 7.29.0) come from `node_modules`. Before any page loads, the
    installed versions must equal the versions in the URLs and the files must match the SRI
    hashes in `support.js` (the browser checks them again);
  - `https://fonts.googleapis.com/css2?…`: the stylesheet is generated from the @fontsource
    packages: for each requested family, weight and style, the package's own
    `<weight>[-italic].css` (all subsets with their unicode ranges), with its font URLs pointed
    at `https://fonts.gstatic.com/fontsource/<package>/<file>`, which is answered from that
    package's `files/` folder. A family without a pinned package fails;
  - everything else is aborted and recorded; the board whose page asked for it fails, and so does
    the run.
- Chromium also gets a proxy on a closed local port, so a request that escaped the routing could
  still not leave the machine.
- `test/router.test.mjs` checks these decisions without a browser: the pinned unpkg script and the
  css2 stylesheet with its font files are served from `node_modules`, and every other URL
  (another host, another unpkg file, an unpinned family, a gstatic path, a POST) is aborted and
  recorded.

## Deterministic output

Two runs on the same machine give byte-identical PNGs, whichever boards are selected and however
many jobs run. Measured: four full renders (4, 3, 3 and 4 jobs) gave identical SHA-256 for all
224 PNGs, and a `--only` render of 10 boards matched the full render. To get there:

- Every board is rendered on a freshly loaded page and its screenshot is the first one taken
  there. Repeated full-page screenshots on one page did not always give the same pixels (`a3-15`
  flipped between two antialiasing results), and screenshots after scrolling depended on what had
  been drawn before (a handful of boards each run).
- The page is ready when every component has resolved (no `.sc-placeholder`), the network is idle,
  `document.fonts` reports everything loaded and the DOM stays the same over consecutive frames.
  Then the whole page is laid out once more, because Chromium does not always redo layout that
  depends on a late web font (the `text-combine-upright` digits in `a3-15`).
- CSS animations and transitions are switched off for good with an injected stylesheet, so each
  element shows its resting style: carets visible, spinners and progress bars at their start
  (the states of Playwright's `animations: 'disabled'`). Reduced motion is on as well.
- Fixed browser settings: viewport 1920 × 1200, device scale factor 1, light colour scheme,
  locale en-US, time zone UTC. The clip is the element's box rounded to whole pixels, so a
  1440 × 900 frame gives a 1440 × 900 PNG.
- Fixed text rasterisation: every launch passes `--font-render-hinting=none` and
  `--disable-lcd-text` (Playwright adds `--force-color-profile=srgb`). The development
  container's launcher script passes the same two switches, so the plain headless shell that
  `fetch-chromium.sh` unpacks renders the same pixels: launching the container's binary directly
  gave PNGs identical to the launcher's for the 15 M1 boards, and without the two switches `f6`
  differed.

Across machines the PNGs can differ: glyphs that no web font covers fall back to the system's
fonts, and a different Chromium build rasterises differently. Compare against references rendered
on the same machine type, which is why CI renders its own.

## Dependencies and licences

Pinned exactly in `package.json` and `package-lock.json` (npm registry, with integrity hashes).
The packages are installed into `node_modules/`, which is gitignored: nothing is committed or
vendored into the repository, and none of it ships with Ferman. The browser is downloaded by
`fetch-chromium.sh` onto developer machines and CI runners, outside the repository.

| Package | Version | Licence | Used for |
|---|---|---|---|
| playwright-core | 1.56.1 | Apache-2.0 | Drives Chromium (revision 1194, Chromium 141.0.7390.37) |
| react | 18.3.1 | MIT | `umd/react.production.min.js`, served for unpkg.com |
| react-dom | 18.3.1 | MIT | `umd/react-dom.production.min.js`, served for unpkg.com |
| @babel/standalone | 7.29.0 | MIT | `babel.min.js`, served for unpkg.com (the export loads it only for JSX imports) |
| scheduler 0.23.2, loose-envify 1.4.0, js-tokens 4.0.0 | | MIT | dependencies of react and react-dom |
| pixelmatch | 7.2.0 | ISC | diff images for `--twice`; the differing-pixel score and diff images of `compare` |
| pngjs | 7.0.0 | MIT | PNG decoding and encoding for both |
| @fontsource/ibm-plex-sans-jp | 5.3.0 | OFL-1.1 | IBM Plex Sans JP 400, 500, 600 |
| @fontsource/ibm-plex-sans-kr | 5.3.0 | OFL-1.1 | IBM Plex Sans KR 400, 500, 600 |
| @fontsource/ibm-plex-sans-hebrew | 5.3.0 | OFL-1.1 | IBM Plex Sans Hebrew 400, 500, 600 |
| @fontsource/ibm-plex-sans-devanagari | 5.3.0 | OFL-1.1 | IBM Plex Sans Devanagari 400, 500, 600 |
| @fontsource/noto-sans-sc | 5.3.0 | OFL-1.1 | Noto Sans SC 400, 500, 600 |
| @fontsource/noto-serif-jp | 5.3.0 | OFL-1.1 | Noto Serif JP 400, 600 |
| @fontsource/noto-naskh-arabic | 5.3.0 | OFL-1.1 | Noto Naskh Arabic 400, 600 |
| @fontsource/eb-garamond | 5.3.0 | OFL-1.1 | EB Garamond 400, 600, 400 italic |
| @fontsource/cormorant-garamond | 5.3.0 | OFL-1.1 | Cormorant Garamond 400, 600 |
| @fontsource/crimson-pro | 5.3.0 | OFL-1.1 | Crimson Pro 400, 600 |
| @fontsource/caveat | 5.3.0 | OFL-1.1 | Caveat 500 |
| @fontsource/dancing-script | 5.3.0 | OFL-1.1 | Dancing Script 500 |
| @fontsource/homemade-apple | 5.3.0 | Apache-2.0 | Homemade Apple 400 |

The 13 font families and their weights are exactly those of the `@import` on line 1 of
`design/ds-additions/fm-additions.css`. Each @fontsource package carries its font licence in
`LICENSE` (the SIL Open Font License 1.1 with the font's copyright line; Apache License 2.0 for
Homemade Apple). The fonts are used unmodified, only to render the reference images. The React,
ReactDOM and Babel files are byte-identical to the unpkg.com files the export names: their SHA-384
matches the SRI hashes in `design/support.js`.

The Chromium headless shell is BSD-3-Clause with the licences of its components; it is only run
to render the references and never distributed. `fetch-chromium.sh` downloads nothing else. The
Playwright installer is not used because it adds Playwright's ffmpeg build (LGPL-2.1) to every
Chromium install. `npx playwright-core install-deps` in CI installs Ubuntu packages with apt and
downloads no browser.

## Updating

- A re-export of `design/`: run `node tools/design-refs --write-boards`, review the diff of
  `boards.json`, then render.
- If `design/support.js` moves to other React, ReactDOM or Babel versions, the run stops and names
  the version to pin in `package.json`.
- If `fm-additions.css` imports another family, the run stops with "no @fontsource/<name>
  dependency"; add that package with an exact version and record its licence here and in
  [DEPENDENCIES.md](../../docs/DEPENDENCIES.md).
- Moving to a newer playwright-core changes the Chromium revision: update `REVISION`, the
  version in the header and `CHROMIUM_SHA256` (back to `UNPINNED` until CI prints the new hash)
  in `fetch-chromium.sh` (a unit test checks the revision against playwright-core), and the
  development container's browser has to move with it
  ([DEPENDENCIES.md §3.12](../../docs/DEPENDENCIES.md#312-tooling)).
