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
status line (for example ADR 0013, whose new part the owner has since accepted) and mark each part.
A smaller new detail inside an Accepted (brief) ADR is marked **Proposed:** where it appears, as in
[ARCHITECTURE.md](../ARCHITECTURE.md) (for example the crash-log placeholders in ADR 0010). Like a
Proposed ADR, it has no effect until the owner approves it, at the milestone review or in the
question it cites.

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
| [0003](0003-crate-layout-and-api-boundary.md) | Crate layout and the ferman-api boundary | Accepted (brief); its Proposed detail approved (owner, 2026-10-16) |
| [0004](0004-lopdf-model-pdfium-renderer.md) | lopdf as the document model, PDFium as a read-only rasteriser | Accepted (brief); its Proposed detail approved (owner, 2026-10-16) |
| [0005](0005-block-scoped-text-editing.md) | Block-scoped text editing | Accepted (brief) |
| [0006](0006-font-pipeline-and-missing-glyphs.md) | Font pipeline and the missing-glyph policy | Accepted (brief); its Proposed detail approved (owner, 2026-10-16) |
| [0007](0007-harfrust-instead-of-rustybuzz.md) | harfrust instead of rustybuzz for shaping | Accepted (owner, [Q04](../QUESTIONS.md#q04), 2026-10-15) |
| [0008](0008-file-safety-and-saving.md) | File safety and saving | Accepted (brief); its Proposed detail approved (owner, 2026-10-16) |
| [0009](0009-threading-and-jobs.md) | Threading model and jobs | Accepted (owner, 2026-10-16) |
| [0010](0010-error-handling-no-panics.md) | Error handling without panics | Accepted (brief) |
| [0011](0011-flutter-state-navigation-components.md) | Flutter state, navigation and components | Accepted (brief) |
| [0012](0012-design-token-pipeline.md) | Design token pipeline | Accepted (brief) |
| [0013](0013-fonts-and-icons.md) | Fonts and icons | Accepted: brief parts, plus Plex Sans Hebrew and Devanagari (owner, [Q08](../QUESTIONS.md#q08), 2026-10-15) |
| [0014](0014-localization-and-rtl.md) | Localization and right-to-left support | Accepted (brief) |
| [0015](0015-privacy-and-network.md) | Privacy and network use | Accepted (brief); a fifth network use, revocation lookups, added (owner, [Q06](../QUESTIONS.md#q06), 2026-10-16) |
| [0016](0016-dependency-licence-policy.md) | Dependency licence policy | Accepted (brief); three licence exceptions approved (owner, [Q17](../QUESTIONS.md#q17), 2026-10-15); the reading of "GPL-compatible" confirmed (2026-10-16) |
| [0017](0017-testing-and-ci.md) | Testing and continuous integration | Accepted (brief) |
| [0018](0018-native-file-pickers.md) | OS-native file pickers | Accepted (owner, [Q07](../QUESTIONS.md#q07), 2026-10-16) |
| [0019](0019-ai-clients-through-mcp.md) | AI clients through a local MCP server | Accepted (owner, [Q20](../QUESTIONS.md#q20), 2026-10-16): the direction, then the details |
| [0020](0020-test-corpus.md) | Test corpus and its generators | Accepted (owner, with the M2 plan, 2026-10-17) |
| [0021](0021-open-from-the-os.md) | Opening files from the operating system | Accepted (owner, with the M2 plan, 2026-10-17) |

## Waiting for the owner

Approved on 2026-10-15, with the M0 go-ahead: ADR 0007 ([Q04](../QUESTIONS.md#q04)), the new part of
ADR 0013 ([Q08](../QUESTIONS.md#q08)) and the three licence exceptions in ADR 0016
([Q17](../QUESTIONS.md#q17), parts 1 to 3). Approved on 2026-10-16, when M1 was merged: ADR 0009
(with the order of the tile-transfer options, [Q19](../QUESTIONS.md#q19)), ADR 0018
([Q07](../QUESTIONS.md#q07)), the details of ADR 0019 ([Q20](../QUESTIONS.md#q20)), the Proposed
details of ADRs 0003, 0004, 0006 ([Q09](../QUESTIONS.md#q09)) and 0008, and the reading of
"GPL-compatible" in ADR 0016 ([Q17](../QUESTIONS.md#q17), part 4). Approved on 2026-10-17: the
detail of [ADR 0010](0010-error-handling-no-panics.md) where the copied crash log replaces the home
folder, folder names and file names with placeholders ([ARCHITECTURE.md](../ARCHITECTURE.md) section
8.4).

Approved with the M2 plan on 2026-10-17: ADR 0020 (the test corpus), ADR 0021 (opening files from
the operating system), and the details the plan adds to ADRs 0008, 0009 and 0010. Still waiting:
memory-mapping files over 256 MB ([Q21](../QUESTIONS.md#q21)), which ADR 0008 leaves to that
question.
