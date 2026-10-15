# Backlog

This file lists every feature that is visible in the app but not working yet, and everything that
was deferred or skipped. Two rules from the [brief](BRIEF.md) put it here:

- Brief §6: features that are not implemented yet stay visible exactly as designed but disabled,
  with the tooltip "Available in a future version", and get an entry in this file.
- Brief §9: nothing is silently skipped. Anything left out of a milestone is logged here.

[ROADMAP.md](ROADMAP.md) checks both in every milestone: gate S9 (honest UI) and exit check E5
(backlog complete).

Related: [roadmap](ROADMAP.md) · [design inventory](DESIGN_INVENTORY.md) ·
[design gaps](DESIGN_GAPS.md) · [questions](QUESTIONS.md) · [progress](PROGRESS.md)

## What goes here

- Every entry point that is visible but disabled: tools, menu items, quick tools, palette commands,
  settings options and panes.
- Every drawn screen or state that is deferred to a later milestone.
- Every placeholder that stands in for a missing answer or asset, such as a default kept while an
  owner question in [QUESTIONS.md](QUESTIONS.md) is open.
- Every check the development container and CI cannot run (hardware, arm64 builds, screen readers,
  native-speaker review), with its pending owner check in [PROGRESS.md](PROGRESS.md#pending-owner-checks).
- Every string in a goldened screen that falls back to English because its translation is missing.
- Every test case or check that was skipped, with the reason.

Not here: open questions for the owner ([QUESTIONS.md](QUESTIONS.md)), conflicts and gaps in the
design ([DESIGN_GAPS.md](DESIGN_GAPS.md)), and bugs (GitHub issues).

## Rules

- Add the entry in the same commit that disables, defers or skips the item.
- Ids run B001, B002 and so on. They are never reused.
- When the item ships, remove its disabled state, move its row to [Done](#done) with the milestone
  it shipped in, and commit both together.
- **Proposed** in [ROADMAP.md](ROADMAP.md): one feature registry in Dart drives every disabled state,
  and a CI check fails if a disabled feature has no entry here.

## Entry format

| Field | Content |
|---|---|
| ID | B001, B002, … |
| Feature | what is disabled, deferred or skipped |
| Artboards | the board ids that draw it, from [DESIGN_INVENTORY.md](DESIGN_INVENTORY.md) |
| Where it appears disabled | the exact place in the app, for example "Start › quick tools › Compare"; "not visible" for deferred states and skipped checks |
| Target milestone | the milestone that will make it work (M1 to M5, P2 to P5), with a link to the question if it depends on one |
| Notes | the reason, related design gaps or questions, and anything the next person needs |

Example of a row, for illustration only:

```markdown
| B001 | Compare documents | a9-2, a9-2b | Start › quick tools › Compare; Tools row › Compare | P3 | Compare is phase 3 (brief §7) |
```

## Open

No entries yet. M1 (in progress) adds the first entries when it builds the shell, the start screen
and the settings skeleton, in the same commits that disable each item.

| ID | Feature | Artboards | Where it appears disabled | Target milestone | Notes |
|---|---|---|---|---|---|

## Done

| ID | Feature | Shipped in | Notes |
|---|---|---|---|
