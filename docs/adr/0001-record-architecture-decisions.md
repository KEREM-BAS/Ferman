# ADR 0001: Record architecture decisions

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §3 and §8
- **Supersedes:** none
- **Superseded by:** none

## Context

Ferman is built over many sessions and milestones, by a lead engineer working from written context and
by contributors who join later. Decisions made in one session must still be clear in the next one,
including the reasons behind them.

The brief sets the rules for this:

- The architecture is fixed and changes "only through an ADR that I approve" ([brief §3](../BRIEF.md)).
- Milestone 0 asks for "ADRs in docs/adr/ for the main decisions" ([brief §8](../BRIEF.md), item 3).
- In every later session: ask the owner before changing an architectural decision, put open questions
  in QUESTIONS.md and continue with the safest option ([brief §9](../BRIEF.md)).

Some decisions come straight from the brief. Others are new, because the brief could not foresee them:
the brief names rustybuzz, which has since been archived upstream (ADR 0007), and the design draws
features and states the brief does not mention ([DESIGN_GAPS.md](../DESIGN_GAPS.md)). We need one way
to tell the two kinds apart and one way to get new decisions approved.

## Decision

We will keep architecture decision records in `docs/adr/`, in a short MADR-style format
([template.md](template.md)).

- **Numbering.** Four digits, never reused: `0001-record-architecture-decisions.md`.
- **Scope.** One decision per ADR. An ADR is written for any choice that is costly to reverse: crate
  boundaries, the document model, threading, file formats, dependencies with licence or security
  weight, privacy rules, and any exception to a brief rule.
- **Statuses.** "Accepted (brief)" for decisions the brief fixes. "Proposed" for anything new and for any
  change to a brief decision. A Proposed ADR has no effect until the owner approves it; until then the
  brief stands. Approved ADRs become "Accepted" with the approval date. The full list is in the
  [ADR index](README.md).
- **Questions.** Every Proposed ADR has a matching entry in [QUESTIONS.md](../QUESTIONS.md), or is
  listed for the milestone review.
- **Immutability.** Accepted ADRs are not rewritten. A change is a new ADR that supersedes the old one;
  the old one keeps its text and gets a "Superseded by" line.
- **Links.** [ARCHITECTURE.md](../ARCHITECTURE.md), [ROADMAP.md](../ROADMAP.md) and the rules files link
  to ADRs instead of repeating their reasoning. Pull requests that implement or touch a decision cite
  its ADR.
- **Index.** [README.md](README.md) lists every ADR with its status and is updated in the same commit.

## Consequences

### Positive

- The owner can approve or reject a change by reading one short file.
- New sessions and new contributors learn why, not only what.
- Proposed decisions are visibly separate from fixed ones, so nobody builds on an unapproved change by
  accident.

### Negative

- Writing ADRs takes time. We keep them short and only for decisions that are costly to reverse.
- ADRs and ARCHITECTURE.md can drift apart. The milestone review checks links and statuses.

### Follow-up

- M0: ADRs 0001 to 0018 written. 0007, 0009, 0018 and part of 0013 are Proposed and wait for the owner,
  as do the proposed details marked inside 0003, 0004, 0006, 0008 and 0016 (listed in the
  [index](README.md)).
- Every milestone: the review in [PROGRESS.md](../PROGRESS.md) lists ADRs that changed status.

## Alternatives considered

- **ARCHITECTURE.md only.** It describes the current design well, but loses the history and the
  rejected options, and gives no clean unit for approval.
- **Issues or discussions on GitHub.** Good for debate, but scattered, and not versioned with the code.
- **A heavier RFC process.** More ceremony than a project of this size needs. ADRs give the same record
  with less overhead.

## References

- [Brief](../BRIEF.md) §3, §8, §9
- [ADR index and process](README.md)
- [Template](template.md)
- Michael Nygard, "Documenting architecture decisions" (2011), and the MADR template
