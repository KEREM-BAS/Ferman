# ADR 0010: Error handling without panics

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §5. The crash-log placeholders below, Proposed until then, were approved by the
  owner on 2026-10-17. The out-of-memory note marked **Proposed** is part of the
  [M2 plan](../PROGRESS.md#m2-plan) and waits for the owner's approval of it.
- **Supersedes:** none
- **Superseded by:** none

## Context

Every PDF Ferman opens comes from someone else, and many are malformed. A panic in the engine would at
best stop a document and at worst take the app down with every open document. The brief's quality bar:
"no unwrap/expect/panic in library code; thiserror errors; documented public APIs; cargo fmt; clippy -D
warnings; unit and integration tests; cargo-fuzz targets for every parser" ([brief §5](../BRIEF.md)).

Errors also reach users. The design wants errors that say what happened, then the way out (a11-7: "What
happened, then the way out"), with technical details kept secondary and copyable (a1-9b), and a crash
log that the user copies by hand (a1-12, "Copy crash log"). All UI text must be localizable
([ADR 0014](0014-localization-and-rtl.md)), so the engine cannot produce sentences.

## Decision

### Errors per crate

- Each library crate has its own error enum built with **thiserror**: `CoreError`, `FontError`,
  `TextError`, `RenderError`, `OpsError` (and one per crate split from ferman-ops). Public error enums are
  `#[non_exhaustive]`.
- Variants carry context (object id, page, operator offset, file path), **never document text**, typed
  characters or passwords.
- Library crates never return `Box<dyn Error>` or `anyhow::Error`. anyhow is allowed only in binaries
  (ferman-cli, tools).
- Every public item is documented (`missing_docs` warns, and CI turns warnings into errors).

### No panics in library code

Enforced in `[workspace.lints]` from M1:

| Lint | Level | Where |
|---|---|---|
| `clippy::unwrap_used` | deny | all library crates |
| `clippy::expect_used` | deny | all library crates |
| `clippy::panic` | deny | all library crates |
| `clippy::todo`, `clippy::unimplemented` | deny | all library crates |
| `clippy::indexing_slicing` | deny | parser and decoder modules (lexer, xref, filters, CMaps, font parsing, interpreter); warn elsewhere where it is practical |
| `clippy::arithmetic_side_effects` | deny | parser and decoder modules; sizes and offsets from files use checked arithmetic |
| `unsafe_code` | forbid; deny in ferman-api | every crate root except ferman-api. ferman-api allows unsafe code only on the FRB-generated module behind the `frb` feature, because that glue needs `extern "C"` exports and `unsafe` blocks and an inner `allow` cannot override `forbid` ([ARCHITECTURE.md](../ARCHITECTURE.md) section 8.1). A CI check fails on any other `allow(unsafe_code)`. Any further exception, for example in ferman-render, is documented and reviewed |

- Tests may unwrap: `clippy.toml` sets `allow-unwrap-in-tests` and `allow-expect-in-tests`.
- Invariants that "cannot fail" are still expressed as errors (`Internal` with context), not panics.
- Untrusted input is bounded by explicit limits (nesting depth, recursion, decoded stream size, filter
  chain length, operators per page). Hitting a limit is an error, never a hang or a crash
  ([ARCHITECTURE.md](../ARCHITECTURE.md) section 9).

### ApiError at the boundary

ferman-api converts every internal error into one type the UI understands:

```rust
// Sketch; the final shape settles in M1.
pub struct ApiError {
    pub kind: ApiErrorKind,     // NotFound, PermissionDenied, FileLocked, DiskFull, FileChangedOnDisk,
                                // PasswordRequired, WrongPassword, Restricted, Damaged, Unsupported,
                                // NotEditable, ConfirmationRequired, ResourceLimit, Cancelled, Internal
    pub message_key: String,    // an ARB key, for example "errorSaveDiskFull"
    pub details: ErrorDetails,  // message parameters, a technical string, a retryable flag
}
```

- `message_key` values come from one closed `MessageKey` type in the engine (a newtype with constants
  and `MessageKey::ALL`; keys are lowerCamelCase ARB keys, as gen-l10n requires). A CI test checks that
  every key exists in `app_en.arb` and `app_tr.arb`; it arrives with the first error strings in the ARB
  files (M1 step 10).
- In M1, `details` is an `Option<String>` of structural facts. The message parameters and the
  retryable flag are added with the first call that needs them. A caught panic gets the fixed details
  "panic at the API boundary": its payload is free text from any crate and can hold document text, so
  it never reaches `details` or the release log.
- The UI formats the sentence from the key and its parameters in the user's language. Error codes never
  appear in the sentence. The technical string is shown only behind "Details" or "Copy technical details"
  (a1-9b).
- Each kind maps to a design state (for example `DiskFull` to a11-7, `FileChangedOnDisk` to a11-7b,
  `WrongPassword` to a1-8b). The full table is in [ARCHITECTURE.md](../ARCHITECTURE.md) section 8.2.

### Panics at the FFI boundary, as a last resort

- FRB v2 turns a panic in a Rust call into a Dart exception. In addition, ferman-api wraps each actor
  and job entry point in `std::panic::catch_unwind`. This is the only place `catch_unwind` is used:
  library crates never use it to hide errors.
- A caught panic becomes `ApiError` with kind `Internal`, is logged with its location, and **stops that
  document's actor**: no further edits are accepted. The UI offers to reopen the document from the
  recovery journal ([ADR 0008](0008-file-safety-and-saving.md)). Other documents are unaffected.
- The release profile keeps `panic = "unwind"`. With `abort`, every bug would become a crash that loses
  all open documents.
- Crashes inside PDFium (C++) cannot be caught. The defences are the pinned binary, fuzzing, the recovery
  journal and the helper-process fallback ([ADR 0009](0009-threading-and-jobs.md)).
- **Proposed** with the M2 plan: **out of memory.** Rust aborts the whole process when an allocation
  fails, and `catch_unwind` cannot stop that. a1-9f promises that only the failing document's tab
  closes, so the engine checks before it allocates: large buffers (the file, decoded streams, tiles)
  are reserved with `try_reserve`, and the limits of [ARCHITECTURE.md](../ARCHITECTURE.md) section 9.1
  refuse oversized work up front. A shortage found this way becomes `ApiError` with kind
  `ResourceLimit` and the message key `errorOutOfMemory`; the document closes and the others keep
  working. Memory running out inside PDFium, or in a small allocation that no check covers, cannot be
  caught and still ends the app; the recovery journal is the defence there.

### Logs stay local

- The engine logs with `tracing`, the app with a thin Dart logger, both to local rotating files in the
  app's log directory.
- Logs never contain document text, typed characters, passwords or rendered content. File paths may
  appear in the local log files, because they help explain open and save failures. Ferman never sends a
  log anywhere.
- Nothing is uploaded. "Copy crash log" (a1-12) and "Show log files" (a11-1k) are the only ways a log
  leaves Ferman, and both are the user's own action ([ADR 0015](0015-privacy-and-network.md)).
  **Approved by the owner on 2026-10-17** (Proposed until then): the copied crash log replaces the
  home folder, folder names and file names with placeholders ([ARCHITECTURE.md](../ARCHITECTURE.md)
  section 8.4).

### Dart side

- Engine errors arrive as typed exceptions mapped from `ApiError`. Feature code handles them with
  exhaustive `switch` over the kind; nothing is caught and ignored silently.
- very_good_analysis lints apply ([ADR 0011](0011-flutter-state-navigation-components.md)).

## Consequences

### Positive

- Malformed files produce messages, not crashes.
- Users see plain, localized sentences that match the design's error states.
- One panicking document cannot take others down.
- Lints make the rules mechanical, so reviews can focus on logic.

### Negative

- Code is more verbose: checked indexing and arithmetic in parsers, explicit error variants for
  impossible cases.
- Two error vocabularies (crate errors and `ApiError`) need mapping code and tests.
- `catch_unwind` cannot catch aborts or C++ crashes, so it is a safety net, not a guarantee.

### Follow-up

- M1: workspace lints, `clippy.toml`, `ApiError` and `MessageKey` with the ARB check, logging setup.
- M2: limits and fuzz targets for the first parsers ([ADR 0017](0017-testing-and-ci.md)).

## Alternatives considered

- **anyhow everywhere.** Quick to write, but loses typed kinds at the boundary, so the UI could not map
  errors to design states.
- **Localized strings from Rust.** Would duplicate the l10n system and bypass Weblate.
- **`panic = "abort"`.** Smaller binaries, but turns every bug into a full crash.
- **Allowing `expect` with justification comments.** Easy to abuse; a typed `Internal` error carries the
  same information without crashing.

## References

- [Brief](../BRIEF.md) §5
- [ARCHITECTURE.md](../ARCHITECTURE.md), sections 8 and 9
- [ADR 0003](0003-crate-layout-and-api-boundary.md), [ADR 0008](0008-file-safety-and-saving.md),
  [ADR 0009](0009-threading-and-jobs.md), [ADR 0014](0014-localization-and-rtl.md),
  [ADR 0015](0015-privacy-and-network.md), [ADR 0017](0017-testing-and-ci.md)
- Artboards a1-8b, a1-9b, a1-9f, a1-12, a11-1k, a11-7, a11-7b
