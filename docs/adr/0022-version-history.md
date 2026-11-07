# ADR 0022: Version history in the app data directory

- **Status:** Proposed (the direction approved by the owner with the M4 plan's question 2 on 2026-11-06; the details below are Proposed)
- **Date:** 2026-11-07
- **Approval:** question 2 of the [M4 plan](../PROGRESS.md#m4-plan), 2026-11-06, for where versions live and how they are found
- **Supersedes:** none
- **Superseded by:** none

## Context

a9-8 draws a timeline of versions: "Every save, signature and import becomes a version, kept for 30
days in a hidden folder next to the file (not inside it)". a11-1c has "Keep versions" and a1-11
repeats "next to the file". ROADMAP §8 step 6 asks for version history with restore, and
[ARCHITECTURE §7.4](../ARCHITECTURE.md#74-version-history-m4) left the place to this ADR. A folder
beside the file does not work: the macOS App Sandbox grants the file alone (ADR 0018, ADR 0021), sync
clients upload a hidden folder next to a synced file, and a read-only folder has nowhere to put one.
The owner chose the app data directory in question 2 of the M4 plan, found by path and then by the
hash of the last saved bytes. Decisions 27 (restore) and 28 (encrypted documents) of the same plan
bind the rest. File safety (ADR 0008) and privacy (ADR 0015) apply: no network, owner-only files,
atomic writes.

## Decision

1. **Place.** Versions live in `Versions` beside the recovery folder in the app data directory
   (ARCHITECTURE §7.6): `~/Library/Application Support/io.github.kerembas.ferman/Versions` on macOS
   (inside the container under the sandbox), `%LOCALAPPDATA%\Ferman\Versions` on Windows,
   `$XDG_STATE_HOME/ferman/versions` on Linux. The app names it once at launch
   (`Engine::start_versions`). Folders are created owner-only (0700 on Unix).
2. **Layout.** One folder per document, named with 32 random hex digits. `manifest.json` holds the
   file's path and the SHA-256 of the bytes it last saved; each version is `<id>.pdf` (the file's
   bytes exactly) and `<id>.json` (kind, time, size, edit count, edit names, SHA-256). The id is the
   version's time in milliseconds, made unique in its folder. JSON is the flat format of the
   recovery manifest. Every file is written through `safe_write` (ADR 0008).
3. **Finding a document's versions.** By the file's path first; after a rename or a move, by the
   SHA-256 of the bytes it last saved, which is the file's own hash until something else writes it.
   The next version then records the new path. A Save as to another path starts that path's own
   folder and never takes over the old file's.
4. **What becomes a version** (ferman-core `versions`, called by the document actor in ferman-api):
   - the file as it was opened (kind `opened`), before the first save of a session that keeps a
     version, unless the newest version already holds those bytes (also an imported file's first
     state: Create PDF and Combine write a file that is then opened);
   - every save of the document's own file (`saved`), Optimize and clean and Save as included; a
     save after a simple signature is `signed` (M4's signature is the simple one; P3 and P4 add the
     certificate and e-imza kinds);
   - unsaved work kept before a restore (`unsaved`) and the restore itself (`restored`).
   A copy to another file (Save a copy, Compress, Extract) is not a version of the document. Bytes
   equal to the newest version's add no row. A staged save (sandbox) keeps its version when it is
   staged and deletes it if the swap fails.
5. **Encrypted documents (decision 28).** A version's bytes are the file's, so they stay encrypted
   with the document's key; the row keeps the edit count only, never the edits' names, which are
   document text.
6. **Preview.** `Engine::open_version` opens a version from its bytes as a separate read-only
   document; nothing is written. An encrypted version needs its password again.
7. **Restore (decision 27).** `Engine::restore_version`: unsaved work becomes a version first, the
   external-change check of §7.5 runs, the version's bytes replace the file whole through the save
   sequence, the recovery journal is cleaned, and the restore becomes a version. The app then opens
   the file again, as Reload does; the document's revisions in memory are not changed in place.
8. **Retention.** 30 days (`versions::KEEP`, Still Proposed at the M4 review). Purged at each open
   (on a thread of its own) and after each save; a folder left empty is deleted.
9. **Off.** "Keep versions" off (`Engine::set_versions_enabled(false)`) keeps nothing new; what was
   kept stays listed until purged.
10. **Copy.** The boards' "next to the file" becomes "Kept for 30 days" in a9-8, a11-1c,
    `settingsKeepVersions30` and onboarding (W5 and the a9-8 screen; ADR 0008 repeats it).

## Consequences

### Positive

- Works under the sandbox and on read-only and synced folders; nothing is uploaded by sync clients.
- Every write is atomic and owner-only; no document text of an encrypted file reaches disk.
- Restore never loses work: unsaved work and the replaced file are both versions.

### Negative

- Versions do not travel with the file to another computer or user.
- Each version is a whole copy of the file. A large document saved often uses space for 30 days.
  shortcut in `versions.rs`: store an incremental version as its update section over the one before
  when large files make the folder too big.
- The path is stored in the manifest on the device, as the recovery manifest already does.

### Follow-up

- The a9-8 screen, its restore confirmation, empty and storage-failure states (G48), and the copy
  change (W4's app area).
- Settings › Editing's Keep versions switch calls `setVersionsEnabled` (W5).
- Compare with current (a9-2) is P3 (B027).

## Alternatives considered

- **A hidden folder next to the file, as drawn.** Refused by the sandbox, uploaded by sync clients,
  impossible in read-only folders (question 2).
- **Versions inside the PDF as incremental revisions.** The file already keeps earlier revisions
  until Optimize and clean; that is not a timeline, and Remove edit history would erase it.
- **One store of objects shared by all versions.** Smaller, but a new format to parse and fuzz;
  left for when whole copies prove too large.

## References

- [Brief](../BRIEF.md) §7 (file safety), [ARCHITECTURE](../ARCHITECTURE.md) §7.2, §7.4, §7.5, §7.6
- ADR 0008, ADR 0015, ADR 0018
- M4 plan question 2, decisions 27 and 28; [G48](../DESIGN_GAPS.md#g48); BACKLOG B060
