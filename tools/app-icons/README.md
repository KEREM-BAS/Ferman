# tools/app-icons

Writes Ferman's app icons for macOS, Windows, Linux and the web from the owner's logo export in
`design/assets/logo/` (the board `design/Ferman Logo.dc.html`, direction 1a "Mühür",
[G112](../../docs/DESIGN_GAPS.md#g112)). It reads `design/` and never writes to it. It has no npm
dependencies. A headless Chrome or Chromium renders each icon at its exact pixel size.

```sh
node tools/app-icons                      # render every icon and write the files that changed
node tools/app-icons --check              # no browser: exit 1 if the logo changed or an icon is stale
node tools/app-icons --chromium <path>    # pick the browser
(cd tools/app-icons && npm test)          # unit tests, no browser needed
```

`--chromium` is the browser to launch. Without it the tool uses `FERMAN_CHROMIUM`, then Google Chrome
or Chromium where each system installs them. An explicit path that does not exist is an error.
`--root <dir>` points at another checkout. Exit codes:

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Stale (`--check`) |
| 2 | The icons cannot be made: the logo export is missing or changed shape, there is no browser, or a render failed |
| 64 | Bad usage |

## Inputs

The seven SVGs of `design/assets/logo/`:

| Group | Files |
|---|---|
| Marks | `ferman-mark.svg`, `-dark`, `-small`, `-mono` |
| App icons | `ferman-app-icon-1024.svg` and its dark twin |
| Favicon | `favicon.svg` |

Each file carries a C2PA `<metadata>` block, which the tool removes before reading. `icons.mjs`
(`readLogo`) takes the shapes and colours from them:

- **Seal:** the teardrop.
- **Ring:** the inner ring, a 1.6-wide stroke.
- **Large F:** the F of the full mark.
- **Small F:** the heavier F of the small mark.
- **Colours:** the five design tokens the export uses: `seal-500` #B5372A, `seal-300` #E0675A,
  `paper-50` #F7F6F3, `soot-100` #1D1C1B and `soot-50` #161615.

It also checks that the files agree:

- the dark mark and both app icons reuse the mark's shapes;
- the mono mark and the favicon are the small mark as one even-odd path;
- the app icons place the mark at `translate(212 212) scale(6)`.

A re-export that changes any of this stops the tool. The new logo is then reviewed here instead of
being drawn wrongly.

## Outputs

Each icon is drawn from one of four artworks:

- **The mark:** the seal alone on a transparent ground, in `seal-500`. The ring and the F are cut
  out, so the surface behind shows through. The board's Windows, Linux and tab-strip tiles draw the
  F and ring in the tile's colour.
- **The macOS tile:** Apple's 1024 grid. An 824-point `paper-50` rounded square, radius 185.4,
  100 points in from each edge, with a hairline and a soft shadow. The export's 600-point mark sits
  inside it, the board's 96 px mark in a 132 px tile.
- **Edge to edge:** `ferman-app-icon-1024.svg` as exported, for surfaces that mask the icon
  themselves.
- **The favicon:** the small mark as one even-odd path, `seal-500`, and `seal-300` when the browser
  is dark.

Sizes up to 32 px use the small mark (no ring, heavier F), as the board's size test does.

| File | Artwork | Sizes |
|---|---|---|
| `app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_<n>.png` | the macOS tile | 16, 32, 64, 128, 256, 512, 1024 (the existing `Contents.json` maps them) |
| `app/windows/runner/resources/app_icon.ico` | the mark, as PNG entries | 16, 20, 24, 32, 40, 48, 64, 96, 128, 256 |
| `app/linux/runner/resources/app_icon.png` | the mark | 256; installed as `data/app_icon.png`, set as the window icon by the runner |
| `app/web/favicon.svg` | the favicon | text |
| `app/web/favicon.png` | the mark | 32 |
| `app/web/icons/Icon-192.png`, `Icon-512.png` | the mark | 192, 512 (`purpose: any`) |
| `app/web/icons/Icon-maskable-192.png`, `-512.png` | edge to edge | 192, 512 (the mark sits inside the maskable safe zone) |
| `app/web/icons/apple-touch-icon.png` | edge to edge | 180 |

`app/web/index.html` and `app/web/manifest.json` link these files and are edited by hand. The
manifest's colours are `paper-50`.

`tools/app-icons/manifest.json` records:

- the SHA-256 of each logo file, taken over the text with LF line ends;
- the browser that rendered the icons;
- the SHA-256 and sizes of every output.

`--check` compares the logo files and the outputs with it and needs no browser. Renders from
another browser version may differ in a few edge pixels, so `--check` never re-renders. After a
deliberate re-render, the new manifest is committed with the icons.

Every render goes through a few safeguards:

- The SVG is inlined in the page; a page that only links an image may be captured before the image
  loads.
- The browser runs with `--force-color-profile=srgb` and a transparent default background.
- The result must have the requested size, and an 8-bit alpha channel unless the icon is opaque
  edge to edge.
- It must also draw something: a fully transparent screenshot fails.

## Not made yet

- **iOS and Android:** those projects do not exist until phase P5
  ([B107](../../docs/BACKLOG.md#open)). The board draws them: iOS light and dark, Android adaptive
  and themed.
- **The macOS dark and tinted icons:** these need an Icon Composer `.icon`
  ([B108](../../docs/BACKLOG.md#open), M5).
