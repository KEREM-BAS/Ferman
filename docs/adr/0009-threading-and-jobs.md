# ADR 0009: Threading model and jobs

- **Status:** Proposed
- **Date:** 2026-10-14
- **Approval:** none yet; requested in the M0 review
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

**Proposed:** the engine uses message-passing actors, immutable revisions, one render thread and a
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

### Prioritised, cancellable tile queue

- Tiles are 512 × 512 device pixels at quarter-octave zoom buckets.
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

### Until approved

Only the brief's rule applies: nothing heavy on the UI thread. M1 needs little engine concurrency (the
version check and engine info), so the actor model is built from M2, once approved.

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
- Artboards a1-7, a2-4a, a11-1k, a11-6b
- [G30](../DESIGN_GAPS.md#g30), [G49](../DESIGN_GAPS.md#g49)
