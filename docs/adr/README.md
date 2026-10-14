# Architecture decision records

This folder holds Ferman's architecture decision records (ADRs). Each ADR records one decision: the
context, the decision, its consequences and the alternatives we turned down. Together they explain
why the code looks the way it does. [ARCHITECTURE.md](../ARCHITECTURE.md) describes the system as a
whole and links here for the reasons.

## Why ADRs

The brief fixes the main architecture and says it changes "only through an ADR that I approve"
([brief §3](../BRIEF.md)). It also says to ask the owner before changing an architectural decision
([brief §9](../BRIEF.md)). ADRs are how we do both: every fixed decision is written down once, and every
change is proposed in writing and approved before it takes effect.

## Statuses

| Status | Meaning |
|---|---|
| **Accepted (brief)** | The decision comes from [BRIEF.md](../BRIEF.md). The ADR records it and fills in the details needed to follow it. It is not re-decided. Engineering details inside an Accepted (brief) ADR (versions, file layouts, lint names) follow the brief's rule and do not change it. |
| **Proposed** | A new decision, or a change to a brief decision. It has **no effect** until the owner approves it. Until then, the brief and the Accepted ADRs stand. |
| **Accepted** | A Proposed ADR the owner approved. The ADR's "Approval" line records the date and where the approval was given. |
| **Rejected** | The owner said no. The file stays, with the reason, so the question is not reopened by accident. |
| **Superseded by ADR NNNN** | A later ADR replaced it. Only the status lines change. |
| **Deprecated** | No longer relevant, and nothing replaces it. |

Some ADRs are split: one part comes from the brief and another part is new. Those say so in their
status line (for example ADR 0013) and mark each part. A smaller new detail inside an Accepted (brief)
ADR is marked **Proposed:** where it appears, as in [ARCHITECTURE.md](../ARCHITECTURE.md) (for example
the crate-edge check in ADR 0003). Like a Proposed ADR, it has no effect until the owner approves it, at
the milestone review or in the question it cites.

## Process

1. **Write it.** Copy [template.md](template.md) to `NNNN-short-title.md` with the next free number.
   One decision per ADR. Cite the brief by section, artboards by id (a3-3a, f2), design gaps as
   `../DESIGN_GAPS.md#g07` and open questions as `../QUESTIONS.md#q04`.
2. **Mark it.** A decision taken from the brief is **Accepted (brief)**. Anything new, and any change
   to a brief decision, is **Proposed**.
3. **Ask.** Add a question to [QUESTIONS.md](../QUESTIONS.md) that links the ADR, and list it in the
   milestone summary. Work continues with the safest option, which is usually the brief as written.
4. **Record the answer.** When the owner approves, set the status to **Accepted** and fill in the
   approval line (date and where, for example "M0 review"). When the owner declines, set **Rejected**
   and add one sentence on why.
5. **Never rewrite history.** An Accepted ADR is not edited except for its status lines and links. A
   change of mind is a new ADR that supersedes the old one.
6. **Keep the index current.** Update the table below in the same commit as the ADR.

Contributors outside the core team follow the same steps in a pull request. See
[CONTRIBUTING.md](../../CONTRIBUTING.md).

Milestones are written M0 to M5 and phases P2 to P5, as in the [roadmap](../ROADMAP.md).

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted (brief) |
| [0002](0002-rust-engine-flutter-ui-frb.md) | Rust engine and one Flutter UI, connected by flutter_rust_bridge v2 | Accepted (brief) |
| [0003](0003-crate-layout-and-api-boundary.md) | Crate layout and the ferman-api boundary | Accepted (brief) |
| [0004](0004-lopdf-model-pdfium-renderer.md) | lopdf as the document model, PDFium as a read-only rasteriser | Accepted (brief) |
| [0005](0005-block-scoped-text-editing.md) | Block-scoped text editing | Accepted (brief) |
| [0006](0006-font-pipeline-and-missing-glyphs.md) | Font pipeline and the missing-glyph policy | Accepted (brief) |
| [0007](0007-harfrust-instead-of-rustybuzz.md) | harfrust instead of rustybuzz for shaping | **Proposed** |
| [0008](0008-file-safety-and-saving.md) | File safety and saving | Accepted (brief) |
| [0009](0009-threading-and-jobs.md) | Threading model and jobs | **Proposed** |
| [0010](0010-error-handling-no-panics.md) | Error handling without panics | Accepted (brief) |
| [0011](0011-flutter-state-navigation-components.md) | Flutter state, navigation and components | Accepted (brief) |
| [0012](0012-design-token-pipeline.md) | Design token pipeline | Accepted (brief) |
| [0013](0013-fonts-and-icons.md) | Fonts and icons | Accepted (brief) in part; **Proposed** in part |
| [0014](0014-localization-and-rtl.md) | Localization and right-to-left support | Accepted (brief) |
| [0015](0015-privacy-and-network.md) | Privacy and network use | Accepted (brief) |
| [0016](0016-dependency-licence-policy.md) | Dependency licence policy | Accepted (brief) |
| [0017](0017-testing-and-ci.md) | Testing and continuous integration | Accepted (brief) |
| [0018](0018-native-file-pickers.md) | OS-native file pickers | **Proposed** |

## Waiting for the owner

| ADR | What needs approval | Question | Until approved |
|---|---|---|---|
| [0003](0003-crate-layout-and-api-boundary.md), [0004](0004-lopdf-model-pdfium-renderer.md), [0008](0008-file-safety-and-saving.md) | Proposed details: the CI crate-edge check (0003); read-only open when lopdf and PDFium disagree (0004); a private snapshot for files above 256 MB (0008) | M0 review | Not built until approved. |
| [0006](0006-font-pipeline-and-missing-glyphs.md) | Proposed detail: text set in an embedded font whose `fsType` allows at most preview and print does not reuse its glyphs | [Q09](../QUESTIONS.md#q09) | Settled before M3, when text editing starts. |
| [0007](0007-harfrust-instead-of-rustybuzz.md) | Use harfrust 0.14 instead of the archived rustybuzz | [Q04](../QUESTIONS.md#q04) | The brief's rustybuzz stands. |
| [0009](0009-threading-and-jobs.md) | Document actors, immutable revisions, one PDFium render thread, tile queue, job pool | M0 review | Only the brief's rule applies: no rendering or heavy work on the UI thread. |
| [0013](0013-fonts-and-icons.md) | Bundle Plex Sans Hebrew and Plex Sans Devanagari | [Q08](../QUESTIONS.md#q08) | Hebrew and Hindi use system fonts, like CJK. |
| [0016](0016-dependency-licence-policy.md) | Three licence exceptions: MPL-2.0 `dbus` (through desktop_drop), NCSA `libfuzzer-sys` (`fuzz/` only), LGPL-3.0 Swatinem/rust-cache (CI only); and the project's reading of "GPL-compatible" (no GPL code of any version, no LGPL-only code) | [Q17](../QUESTIONS.md#q17) | CI caches with actions/cache (MIT) or not at all; desktop_drop and `fuzz/` are not added. Needed by M2. |
| [0018](0018-native-file-pickers.md) | OS-native open, save and folder pickers as the only exception to the custom-dialog rule | [Q07](../QUESTIONS.md#q07) | M1 builds no file picker. If M2 starts before an answer, the OS picker is used as the safest option (brief §9) and flagged again in each milestone summary. |
