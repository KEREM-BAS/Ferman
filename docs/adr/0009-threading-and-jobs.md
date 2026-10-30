# ADR 0009: Threading model and jobs

- **Status:** Accepted (owner, 2026-10-16)
- **Date:** 2026-10-14
- **Approval:** the owner, on 2026-10-16, with the other Proposed items of M1; the order of the
  tile-transfer options through [Q19](../QUESTIONS.md#q19). The details marked **Proposed** below
  (the tile format and the render-only appendix) are part of the
  [M2 plan](../PROGRESS.md#m2-plan) and wait for the owner's approval of it.
- **Supersedes:** none
- **Superseded by:** none

## Context

The brief fixes the outcome, not the mechanism: "Rendering and heavy work never run on the UI thread.
Tile-based rendering for deep zoom; thumbnail and glyph caches." Jobs (OCR, convert, compress, batch)
are "async, cancellable and stream progress" ([brief §3](../BRIEF.md)). The budgets are first page in
under 1 s for 500 pages, 60 fps scrolling and zooming, and edit-to-render under 100 ms
([brief §5](../BRIEF.md)).

Constraints:

- **PDFium is not thread-safe.** pdfium-render's `thread_safe` feature serialises every call behind one
  global lock ([ADR 0004](0004-lopdf-model-pdfium-renderer.md)). There is one PDFium per process.
- **lopdf is the source of truth** and is mutated by edits. Renders, searches and jobs must read a
  consistent document while the user keeps typing.
- **The Flutter UI isolate must never block.** FRB runs async Rust functions on its own worker pool; long
  work there would starve other calls.
- The design shows concurrent work: progressive open of a 2,400-page file while the user reads (a1-7),
  several tabs, background tasks with pause and cancel (a11-6b), live search counts (a2-4a), a page cache
  setting (a11-1k), tiles that must load low-resolution first ([G30](../DESIGN_GAPS.md#g30)).

## Decision

The engine uses message-passing actors, immutable revisions, one render thread and a
job pool.

### Threads

| Thread | Count | Owns | Never does |
|---|---|---|---|
| UI isolate (Dart) | 1 | widgets, input, tile images | block; call sync FFI (except the version check); run a task over 4 ms |
| FRB workers | FRB's pool | nothing | work longer than about 1 ms; they validate, send a message and await the reply |
| Document actor | 1 per open document, parked when idle | the working model, revision stack, open transaction | render, touch PDFium |
| Render thread | 1 per process | the PDFium library and one PDFium document per open document | parse with lopdf, write files |
| Job pool | a dedicated rayon pool, cores − 2, at least 1 | nothing shared; jobs hold snapshots | mutate a document directly |

Messages travel over crossbeam channels. No async runtime (such as tokio) is added to the engine unless a
later need is shown; the network gateway in M5 is decided with its own dependency entry.

### One actor per document

- Each open document has an actor with a mailbox: begin, apply, commit, rollback, undo, redo, save,
  apply change set, close. Messages run one at a time, so mutations are totally ordered without locks on
  the model.
- Every commit publishes a new **immutable snapshot** (`Arc<Snapshot>`) by swapping one pointer. A
  snapshot is the base bytes plus an overlay of changed objects with structural sharing, so a revision
  costs memory only for what it changed. Readers never block the writer and the writer never blocks
  readers.
- Saves run on the actor, so a save always sees one consistent revision
  ([ADR 0008](0008-file-safety-and-saving.md)). Large full rewrites run as jobs on a snapshot and are
  applied only if no newer revision exists; otherwise the user is asked.

### PDFium on one render thread

- All PDFium calls run on the render thread. The global lock from `thread_safe` stays on as a second
  guard and is never contended.
- When a revision changes pixels, the render thread loads the revised bytes as a new PDFium document
  (reading the snapshot's base bytes and in-memory update without concatenating a copy), swaps it in, and
  drops the old one after in-flight tiles finish.
- Each page has a **render key**: a hash over the versions of the page object and everything its content,
  resources and annotation appearances reach. Pages whose key did not change keep their tiles.
- **Proposed** with the M2 plan: **layer visibility through a render-only appendix.** PDFium has no
  public call to show or hide an optional-content group, and pdfium-render 0.9.4 exposes none. To
  show or hide a layer (a2-3c), ferman-core builds an in-memory incremental section after the
  snapshot's bytes that changes only the group's state in the default configuration, and the render
  thread loads that document through the same reader, as for a revision. The original bytes stay an
  exact prefix. Only the pages that use the group get new render keys. The appendix is never written
  to disk, never becomes a revision on the undo stack and never reaches a save; it is also the first
  piece of the M3 incremental writer. Built in M2 (W2, commit 10b), with one shortcut: every page
  gets a new render key until M3's interpreter finds the pages that use the group. The appendix
  ends in a cross-reference stream that names every object, not a section with `/Prev`, so it
  reads the same after every kind of table. A repaired document and one opened with its password
  keep their layers for now (BACKLOG B111).

### Prioritised, cancellable tile queue

- Tiles are 512 × 512 device pixels at quarter-octave zoom buckets.
- **Proposed** with the M2 plan: every tile that crosses to Dart is 512 × 512 in PDFium's BGRA byte
  order, which Flutter takes as `PixelFormat.bgra8888` (1 MiB for a full tile). The 256 × 256
  buffers and the per-platform byte order of option 3 below apply only if that fallback is ever
  used. If a platform rejects `bgra8888` in the integration test, tiles switch to RGBA through
  PDFium's `FPDF_REVERSE_BYTE_ORDER` render flag (pdfium-render's `set_reverse_byte_order`).
- Priority classes, highest first: visible tiles (nearest the viewport centre first), prefetch in the
  scroll direction, visible thumbnails, other thumbnails, background renders.
- Each `request_tiles` call replaces the view's wanted set and carries a generation number. Queued
  requests that are no longer wanted are dropped before rendering. Where pdfium-render exposes PDFium's
  progressive rendering with a pause callback, a slow tile is abandoned when it goes stale (to verify in
  M2).
- The UI keeps the newest render key per page and ignores older tiles, so a page never flips back to an
  old revision. While a sharp tile is missing it draws the best cached lower bucket or the thumbnail.

### Job pool with progress streams

- A job runs on the dedicated pool with its own snapshot and a cancel token (running, paused, cancelled)
  checked at page granularity and inside long loops. Pause parks it between steps (a11-6b).
- Progress streams to Dart as events with a value (or none when unknown) and a message key with
  parameters, throttled to 10 per second.
- A job never mutates a document. It produces a file in a temp location or a change set that the actor
  commits. Cancelling never leaves partial output.
- Order: user-started work (search, save) before open indexing before background work.

### Caches

Tiles (Rust memory, capped by the a11-1k page cache setting and a share of RAM), tile images in Dart
(wanted set plus a margin, disposed promptly), thumbnails, loaded PDFium pages (a few per document,
dropped on reload), per-page text models in the snapshot (shared across revisions when the page did not
change), glyph and shaping caches in ferman-fonts, and a system font index. Exact caps are in
[ARCHITECTURE.md](../ARCHITECTURE.md) section 4.7.

### Before approval (M1)

Only the brief's rule applied: nothing heavy on the UI thread. M1 needed little engine concurrency
(the version check and engine info), so the actor model is built from M2.

## Consequences

### Positive

- The UI thread never waits on the engine, by construction.
- No locks on the model and no data races: one writer per document, immutable snapshots for readers.
- PDFium's thread-safety limits are contained in one place.
- Stale work is dropped early, which keeps scrolling smooth on large documents.
- Jobs share one mechanism for progress, pause and cancel, which serves a1-7, a11-6b and later OCR,
  conversion and batch work.

### Negative

- **One render thread limits throughput.** Parallel rendering across pages or documents is not possible
  in one process. Caching, low-resolution placeholders, prefetching and progressive rendering are the
  answer. If M2 measurements miss the budgets, the fallback is a pool of helper processes with one PDFium
  each, which also isolates PDFium crashes. It is not planned before those measurements.
- **Reload per revision.** Every pixel-changing commit reloads the document in PDFium. It must fit the
  100 ms edit-to-render budget; measured in M3.
- **Memory.** Snapshots, two parsed representations (lopdf and PDFium) and tile caches add up. Budgets
  are proposed in ARCHITECTURE.md and measured from M2.
- Message passing means more code than calling functions directly, and actor failures must be handled
  (a panic stops only that document, [ADR 0010](0010-error-handling-no-panics.md)).

### Follow-up

- M1: the FRB tile-transfer benchmark (zero copy) and a skeleton render thread. If the benchmark
  fails, the texture-registry fallback is designed and recorded here before M2.
- M2: actors, snapshots, render keys, the tile queue, thumbnails, indexing jobs, measurements against the
  budgets.
- M3: edit transactions on the actor, reload-per-edit measurement.
- M4: background task drawer with pause and cancel.

### Implementation notes (M2)

Found while building the render thread and its tile queue; none changes the decision above.

- **One render thread holds PDFium at a time.** pdfium-render's `thread_safe` lock covers only part
  of its bindings (in 0.9.4, 192 of 481 functions run without it, `FPDF_GetPageSizeByIndexF` among
  them), so it is a partial second guard. ferman-render therefore refuses a second render thread in
  the same process while the first holds PDFium. The app has one; tests take turns.
- **Tiles are rendered with a 32-pixel margin**, cut away afterwards: PDFium draws a glyph that
  crosses the edge of its bitmap differently, which would show as a seam in text at tile edges.
  With the margin, tiles put together match one render of the page to within two levels of
  antialiasing ([ARCHITECTURE.md §4.4](../ARCHITECTURE.md#44-pdfium-confinement)).
- **No progressive rendering.** pdfium-render 0.9.4 exposes PDFium's pause callback only through
  its raw, unsafe bindings, so a tile always finishes once started. The queue takes every waiting
  message before each tile and again after it, so a replaced wanted set loses at most the tile in
  progress.

<a id="tile-transfer-m1-measurements-and-options-proposed"></a>

### Tile transfer: M1 measurements and options

The M1 benchmark (`debug_bytes`, the integration test "a 1 MiB byte vector crosses the bridge")
does not meet the target of 1 MB in under 0.2 ms. No number below comes from R1 or R2:

| Build | Machine | Result for 1 MiB |
|---|---|---|
| Debug, one cold call per run, four runs | Development container, Linux x64, Xvfb | 52 to 63 ms |
| Debug, one cold call | CI runner `macos-15`, run [38823480726](https://github.com/KEREM-BAS/Ferman/actions/runs/38823480726) | 46 ms |
| Profile (`flutter drive --profile`), 20 warm calls | Development container, Linux x64, Xvfb | minimum 3.3 ms, median 5.9 ms |

The cause is the codec, not the build mode. With codegen 2.13's default `full_dep: false`, the
generated glue uses the SSE codec: the Rust side writes the `Vec<u8>` into a serialization buffer one
byte at a time, and Dart copies it out with `getUint8List`. At the profile rate, one 512 × 512 BGRA
tile (1 MiB, the tile of the queue above) costs 3.3 to 5.9 ms, so a zoom step that delivers a few
tiles would already spend the whole 16 ms frame on copies.

Options, cheapest first:

1. **The Dco codec (`full_dep: true`).** A `Vec<u8>` crosses through `Dart_PostCObject` as external
   typed data, which should be zero copy. It keeps the generated boundary and adds no hand-written
   unsafe code. Costs: codegen then needs ffigen (dev dependency, BSD-3-Clause) and libclang (LLVM,
   Apache-2.0 WITH LLVM-exception) on developer machines and in the CI codegen job. Tried in M1 in a
   scratch copy: the bindings generated, but the Dart did not compile, because ffigen emits a C
   struct named `ApiVersion` that clashes with the Dart mirror of the same name. It needs a rename
   or an FRB setting. Zero copy is not verified yet.
2. **An opaque pixel buffer read through a pointer view.** The engine keeps each tile's pixels in a
   Rust buffer and hands Dart a pointer and length. Dart wraps it with `Pointer<Uint8>.asTypedList`
   and a native finalizer that frees the buffer in Rust. This is zero copy, but it needs a small
   hand-written `extern "C"` surface in ferman-api outside the generated module. That is an
   exception to the unsafe-code rule ([ADR 0010](0010-error-handling-no-panics.md)), which the owner
   must approve.
3. **A platform texture registry** (the fallback named in M0). The engine renders into pixel buffers
   registered with Flutter's texture registry: a pixel-buffer texture on Linux and Windows, a
   `CVPixelBuffer` on macOS. Nothing crosses into Dart, but it needs native code on three systems,
   one `Texture` widget per tile, and goldens of the canvas then need a test path.
4. **Keep the copying codec.** It is not recommended, because of the frame cost above.

**Approved by the owner on 2026-10-16** ([Q19](../QUESTIONS.md#q19)): try option 1 at the start of
M2 step 3, before tiles are built, and measure it on R1 and R2 with `flutter drive --profile` (the
command is in CONTRIBUTING.md). If it misses the budget, use option 2, with the owner's approval of
its unsafe surface. Use option 3 only if both fail. M1 changed nothing in the codec.

**The trial, 2026-10-19 (M2 wave W1): option 1 works and is in use.** The codegen runs with
`full_dep: true` and ffigen 20.1.1, the version flutter_rust_bridge 2.13.0 itself is built with,
which finds libclang in Xcode on macOS and in `libclang-dev` (`/usr/lib/llvm-18`) on the CI runner.
The M1 clash had a simpler cause than a missing setting: the codegen's cbindgen pass reads the
whole crate, the facade's public constant `API_VERSION` made it declare the facade's `ApiVersion`
as an opaque C struct, and ffigen turned that into a Dart class with the mirror's name. The facade
module now carries `cbindgen:ignore` beside `frb(ignore)`, so no type is renamed. The generated
Dart had compiled only in appearance: `flutter analyze` leaves `lib/bridge/` out, so the trial
analyzed it on its own and built the app. flutter_rust_bridge turns on allo-isolate's `zero-copy`
feature, so a `Vec<u8>` crosses as external typed data: Dart reads the Rust buffer in place and a
finalizer frees it, with no copy on either side.

| Build | Machine | Codec | Result for 1 MiB, 20 warm calls |
|---|---|---|---|
| Profile (`flutter drive --profile`) | The owner's MacBook Pro, Apple M5 Pro, 48 GB, macOS 26.5 (not R1 or R2) | SSE (before) | minimum 665 µs, median 1,053 µs |
| Profile | The same Mac | Dco | minimum 26 µs, median 73 µs: **meets the 0.2 ms target** |
| Debug (`flutter test integration_test -d macos`) | The same Mac | Dco | minimum 5,932 µs, median 6,148 µs (debug builds do not count) |

The numbers time the whole asynchronous call, scheduling included, so the transfer itself is
smaller still. The budget is set for R1 and R2, which are slower than this Mac, so the profile run
on R1 and R2 stays an owner check before the tile API depends on the result
([PROGRESS.md](../PROGRESS.md#pending-owner-checks-m2)); option 2 is needed only if it misses there.

<a id="option-3-in-detail-the-texture-registry-fallback-proposed"></a>

#### Option 3 in detail: the texture-registry fallback

ROADMAP §5 step 3 asks for the texture-registry fallback to be designed before M2 starts if the
benchmark misses its budget, which it does. This is that design. It is used only if options 1 and 2
fail on R1 and R2.

- **What crosses the bridge.** Only small messages: a tile request (document, page, zoom, tile
  index, texture slot) and a result (slot, version, or a typed error). The pixels never enter Dart.
- **Pixel buffers.** ferman-render keeps a pool of tile buffers, 256 × 256 device pixels at 4 bytes
  each (256 KiB), two per texture slot (front and back). The render thread draws a tile into the
  back buffer with PDFium, then swaps front and back under a short lock and tells the platform side
  that a new frame is ready. Byte order is the platform's: BGRA on macOS (PDFium's native order) and
  RGBA on Linux and Windows (PDFium's `FPDF_REVERSE_BYTE_ORDER` render flag, through pdfium-render's
  render configuration), so no conversion pass runs.
- **Platform textures.** One texture per slot, registered once and reused for whichever tile the
  slot shows:
  - Linux: a subclass of `FlPixelBufferTexture` whose `copy_pixels` returns the front buffer,
    registered with `fl_texture_registrar_register_texture` and refreshed with
    `fl_texture_registrar_mark_texture_frame_available`.
  - Windows: a `flutter::PixelBufferTexture` whose callback returns a `FlutterDesktopPixelBuffer`
    pointing at the front buffer, with a release callback that unlocks it, registered through the
    plugin registrar's `TextureRegistrar` and refreshed with `MarkTextureFrameAvailable`.
  - macOS: an object conforming to `FlutterTexture` whose `copyPixelBuffer` returns a
    `CVPixelBuffer` (`kCVPixelFormatType_32BGRA`) made from the front buffer with a release callback,
    registered with `FlutterTextureRegistry` and refreshed with `textureFrameAvailable:`.
  The three live in the `rust_lib_ferman` plugin (`app/rust_builder/`), beside the code that loads
  the engine, and the app creates and disposes slots through the plugin's method channel.
- **Locking and lifetime.** Flutter reads a texture on its raster thread while the render thread
  draws the next tile. The front buffer is held from `copy_pixels` or `copyPixelBuffer` until the
  release callback (macOS, Windows) or the next call (Linux); the swap waits for that hold, never
  the other way round, so the raster thread never blocks on rendering. Disposing a slot unregisters
  the texture first and frees its buffers only after Flutter's unregister callback.
- **The engine side.** The platform code reads buffers through a small C surface of ferman-api
  (acquire the front buffer of a slot, release it), next to the generated bridge. Like option 2, it
  is hand-written `extern "C"` code outside the generated module, an exception to the unsafe-code
  rule ([ADR 0010](0010-error-handling-no-panics.md)) that the owner must approve.
- **The canvas.** The canvas lays out one `Texture(textureId: …)` widget per visible tile, sized in
  logical pixels for the tile's device pixels. Slots are recycled as tiles leave the viewport; a
  prefetch margin keeps neighbouring tiles ready. About 60 slots cover a 1440 × 900 window at 2× with
  a one-tile margin: 60 × 2 × 256 KiB, about 30 MiB, counted in the tile cache's cap (ARCHITECTURE §4.7).
  Priorities and cancellation stay as in the tile queue above.
- **Tests.** `flutter test` has no texture registry, and a `Texture` widget paints nothing there, so
  the canvas has a test path: the fake engine of the widget tests hands the canvas decoded images
  (`decodeImageFromPixels`) for the same slots, and the canvas goldens use it. The integration test
  on each system renders one page through the real textures and compares a read-back of the front
  buffer with a PDFium render of the same tile, pixel for pixel.
- **Web.** The web target (phase 5) has no platform texture registry; it is decided with the web
  engine.
- **Cost.** Native code on three systems, a method channel, the C surface and the test path: about
  the size of the title bar work of M1 phase H1, against a few lines of codegen settings for option 1.

## Alternatives considered

- **A mutex around each document model.** Simple, but renders and jobs would contend with typing, and
  long reads would cause visible jank.
- **One engine thread for everything.** No concurrency bugs, but rendering would block edits and jobs
  would block both.
- **Helper processes for PDFium from the start.** True parallel rendering and crash isolation, but IPC
  copies of every tile, process management on three platforms and more memory. Kept as the measured
  fallback.
- **Work in Dart isolates.** The UI must never touch PDF internals ([brief §3](../BRIEF.md)); the engine
  is Rust.
- **An async runtime with futures throughout the engine.** Adds a large dependency and colours every
  function. Most engine work is CPU-bound, which threads and channels handle directly.

## References

- [Brief](../BRIEF.md) §3, §5
- [ARCHITECTURE.md](../ARCHITECTURE.md), sections 3.4, 3.7 and 4
- [ADR 0003](0003-crate-layout-and-api-boundary.md), [ADR 0004](0004-lopdf-model-pdfium-renderer.md),
  [ADR 0008](0008-file-safety-and-saving.md), [ADR 0010](0010-error-handling-no-panics.md)
- Artboards a1-7, a2-3c, a2-4a, a11-1k, a11-6b
- [G30](../DESIGN_GAPS.md#g30), [G49](../DESIGN_GAPS.md#g49)
