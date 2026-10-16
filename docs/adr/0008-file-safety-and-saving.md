# ADR 0008: File safety and saving

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §3. The private snapshot below, Proposed in M0, was approved by the owner on
  2026-10-16.
- **Supersedes:** none
- **Superseded by:** none

## Context

People open contracts, statements and theses in Ferman and work on them for hours
([brief §1](../BRIEF.md)). Losing their edits is bad; damaging their file is worse. The brief's rule is
"never corrupt a user's file. Save via temp file + atomic rename; incremental update by default;
optional 'optimize and clean' full rewrite; autosave/recovery files in the app data directory"
([brief §3](../BRIEF.md)).

The design adds the honest save states and the failure screens:

- **f4, f4a, f4b**: Unsaved → Saving… → Saved ("Saved on this device · 14:32") → Couldn't save, with a
  persistent toast offering "Save as…". The status bar never claims "saved" while changes are pending.
- **a1-10b**: close with unsaved changes. **a1-11**: Save as with format and options ("Save as a copy",
  "Include comments and markup", "Remove edit history from the file"). **a1-12**: crash recovery
  ("Nothing was sent anywhere").
- **a11-7**: out of disk space, with "Your edits are kept in Ferman's recovery copy". **a11-7b**: the file
  changed on disk while there are unsaved edits. **a11-7c**: an unsupported XFA form, shown read-only.
- **a11-1c** (Settings › Editing): "Save a recovery copy every minute" (a switch, on by default) and
  "Keep versions" ("30 days, next to the file", "7 days", "Don't keep versions").
- **a9-8** (Version history, M4): "Every save, signature and import becomes a version, kept for 30 days in
  a hidden folder next to the file (not inside it)." The onboarding says the same.
- **a8-3** and **a8-2c**: the design already explains that earlier saves remain inside the file and that
  redaction rewrites the file without them.

Gaps recorded in DESIGN_GAPS.md: save-failure states that are not drawn ([G40](../DESIGN_GAPS.md#g40)),
the Save button disabled in the error state by the kit's logic ([G41](../DESIGN_GAPS.md#g41)), no
incremental-versus-full choice in Settings ([G43](../DESIGN_GAPS.md#g43)), and image crop described as
removing content although saves are incremental ([G57](../DESIGN_GAPS.md#g57)).

## Decision

### Rules

1. Never write in place. Every save writes a complete new file and replaces the old one atomically.
2. Never keep the user's file open or memory-mapped after open. The engine reads it into memory.
   Another app truncating the file must not crash Ferman, and on Windows an open mapping would block the
   replace. **Approved by the owner on 2026-10-16:** files above 256 MB are copied to a private
   snapshot in the cache directory and mapped from there ([ARCHITECTURE.md](../ARCHITECTURE.md)
   section 5.1).
3. A failed save leaves the original untouched and deletes the temp file.
4. Edits are never lost because a save failed. They stay in memory and in the recovery journal.

### The save sequence

| Step | Linux | macOS | Windows |
|---|---|---|---|
| Temp file in the **same directory** (same volume), exclusive create | `.<name>.ferman-<random>.tmp` | same | same, hidden attribute |
| Write all bytes, then flush | `fsync` | `F_FULLFSYNC` | `FlushFileBuffers` |
| Verify | re-read the trailer and cross-reference data; for incremental saves check that the original bytes are an exact prefix | same | same |
| Keep metadata | mode bits, owner and group where allowed | ACLs, extended attributes, tags, flags | kept by `ReplaceFileW` |
| Replace atomically | `rename(2)` | `rename(2)` | `ReplaceFileW`, falling back to `MoveFileExW` with `MOVEFILE_REPLACE_EXISTING` and `MOVEFILE_WRITE_THROUGH` |
| Flush the directory | `fsync` on the directory | `fsync` on the directory | not needed |

Symbolic links are resolved and the target is replaced. Files with several hard links, or owned by
someone else, are not replaced silently: Ferman offers Save as. Sharing violations on Windows are
retried briefly, then reported as "locked by another app". A sandboxed macOS build, if there is ever one,
would use the system's item-replacement directory and `replaceItemAtURL` instead of a sibling temp file.

### Incremental by default, full rewrite on request

- **Incremental update (default).** All changes since the last save become one update appended to the
  original bytes, with a cross-reference section of the same form as the original and `/Prev` pointing
  back. New objects in an encrypted file are encrypted with the document's key. The original bytes stay
  an exact prefix, so signatures keep covering what they signed.
- **"Optimize and clean" (opt-in).** A full rewrite: earlier revisions, unreferenced objects and
  duplicate resources are dropped and streams recompressed. It invalidates signatures, so the UI warns
  first. Redaction (P2), "Remove hidden information" (P2) and "Remove edit history from the file" in
  Save as (a1-11) always use it.
- **Repair is always a full rewrite to a new file.** A damaged document (a1-9) is never appended to.
  "Save repaired copy…" writes a new file; replacing the original needs explicit confirmation.
- Hidden is not removed. Content hidden by a crop stays in the file until a full rewrite or "Remove
  hidden information", and the copy says so ([G57](../DESIGN_GAPS.md#g57)).

### Save states

The UI follows f4 exactly. In the "Couldn't save" state, Save stays enabled so the user can retry
([G41](../DESIGN_GAPS.md#g41)). Every failure names what happened and the way out: disk full (a11-7),
read-only or permission denied, locked by another app, rename failed, volume gone. All of them keep the
edits and offer Save as ([G40](../DESIGN_GAPS.md#g40)).

### External changes

At open and after each save the engine records size, modification time and SHA-256. Before saving it
compares size and time; if either differs it hashes again, and if the hash differs the save stops and
the UI shows a11-7b ("Compare", "Keep mine", "Reload"). Ferman never picks a winner. A file-system watcher
that shows the banner earlier is proposed in [ARCHITECTURE.md](../ARCHITECTURE.md) section 7.5.

### Autosave journal and recovery

- Recovery data lives in the **app data directory**, never next to the user's file
  ([brief §3](../BRIEF.md)): `~/Library/Application Support/io.github.kerembas.ferman/Recovery/` on
  macOS, `%LOCALAPPDATA%\Ferman\Recovery\` on Windows, `$XDG_STATE_HOME/ferman/recovery/` on Linux.
  The bundle identifier is `io.github.kerembas.ferman` ([Q01](../QUESTIONS.md#q01)); while the macOS
  App Sandbox is on ([Q18](../QUESTIONS.md#q18)), the macOS path lies inside
  `~/Library/Containers/io.github.kerembas.ferman/Data/`.
- Every commit appends a checksummed record of the changed objects to a journal. While there are unsaved
  changes, a full snapshot of the pending incremental section is written every minute with the same
  atomic sequence (the a11-1c switch turns this off). Replay is pure data and does not depend on fonts or
  engine behaviour.
- Recovery does not rely on the original staying unchanged: the engine keeps a cheap clone or copy of the
  original where the file system allows, otherwise it relies on the recorded hash and reports a conflict
  if the original changed ([G40](../DESIGN_GAPS.md#g40)).
- Recovery data of an encrypted document is written encrypted with the document's own key. Plaintext
  never reaches disk. The folder is owner-only. Nothing in it is ever sent anywhere.
- After a crash, the next launch shows a1-12. Recovery files are deleted after a successful save, "Don't
  save", or "Discard".

### Version history: the design's choice

The design keeps versions **in a hidden folder next to the file** for 30 days (a9-8, a11-1c, and the
onboarding copy). We record that as the starting point for M4: version files are written with the same
atomic sequence, and Ferman never writes versions inside the PDF itself.

A folder next to the file can fail: the directory may be read-only, on a network share, inside a sync
folder (which would upload the versions), or out of reach in a sandboxed build. The final rule for those
cases (for example falling back to the app data directory and saying so in a9-8) is settled with a
follow-up ADR when M4 is planned. Until then Ferman writes nothing next to the user's file other than
the temp file of a save and files the user asks for.

## Consequences

### Positive

- A crash or power cut at any moment leaves either the old file or the new one, never a mix.
- Signatures survive ordinary saves, and saves are fast because only changes are written.
- Edits survive crashes and failed saves.
- Users see the truth about save state at all times.

### Negative

- Incremental saves keep old content inside the file. This is a privacy trade-off that the design already
  explains (a8-3); full rewrites and "Remove hidden information" address it.
- Directory-level operations need write access to the file's folder. Read-only folders get Save as.
- The recovery clone or copy costs disk space for large files without copy-on-write file systems.
- Platform-specific code for three operating systems, each with its own edge cases (network shares, FAT
  volumes, sync folders).

### Follow-up

- M2: open path (read into memory, record hash), read-only and repaired states.
- M3: save, save as, the incremental writer, the save sequence, external-change detection, the recovery
  journal and a1-12, all a11-7 errors. atomic-write-file is evaluated against the table above; if it
  falls short, ferman-core implements the sequence directly.
- M4: version history, with the follow-up ADR on its location.

## Alternatives considered

- **Write in place.** Fastest, but a crash mid-write corrupts the file. Forbidden by the brief.
- **Full rewrite on every save.** Simpler writer, but slow for large files and it breaks signatures every
  time.
- **Recovery files next to the document.** Easy to find, but they leak into shared and synced folders.
  The brief puts them in the app data directory.
- **Rely on the OS** (document versioning on macOS, shadow copies on Windows). Not portable, and not under
  Ferman's control.

## References

- [Brief](../BRIEF.md) §1, §3
- [ARCHITECTURE.md](../ARCHITECTURE.md), sections 5.5 to 5.7 and 7
- [ADR 0004](0004-lopdf-model-pdfium-renderer.md), [ADR 0005](0005-block-scoped-text-editing.md),
  [ADR 0009](0009-threading-and-jobs.md), [ADR 0010](0010-error-handling-no-panics.md),
  [ADR 0018](0018-native-file-pickers.md)
- Artboards f4, f4a, f4b, a1-9, a1-10b, a1-11, a1-12, a8-2c, a8-3, a9-8, a11-1c, a11-7, a11-7b, a11-7c
- [G40](../DESIGN_GAPS.md#g40), [G41](../DESIGN_GAPS.md#g41), [G43](../DESIGN_GAPS.md#g43),
  [G57](../DESIGN_GAPS.md#g57), [Q01](../QUESTIONS.md#q01), [Q18](../QUESTIONS.md#q18)
