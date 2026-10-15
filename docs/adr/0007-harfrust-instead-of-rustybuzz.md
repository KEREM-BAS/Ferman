# ADR 0007: harfrust instead of rustybuzz for shaping

- **Status:** Accepted (owner, Q04, 2026-10-15)
- **Date:** 2026-10-14
- **Approval:** the owner, on 2026-10-15, answering [Q04](../QUESTIONS.md#q04) with the M0 go-ahead
- **Supersedes:** none (it changes the shaper named in brief §3)
- **Superseded by:** none

## Context

The brief names the shaper: ferman-fonts does "shaping (rustybuzz)" ([brief §3](../BRIEF.md)). Shaping
is needed whenever Ferman lays out text it will write into a PDF: Arabic and Persian joining forms and
marks, ligatures, kerning, Devanagari clusters, CJK vertical alternates
([ADR 0005](0005-block-scoped-text-editing.md), [ADR 0006](0006-font-pipeline-and-missing-glyphs.md)).
The pixel-diff acceptance cases for Arabic depend on it ([brief §4](../BRIEF.md)).

The dependency check on 2026-10-13 found:

- **rustybuzz 0.20.1**, last released on 2024-11-12. Its upstream README says it is unmaintained and
  archived and tells users to switch to HarfRust. It parses fonts with ttf-parser, which has had no
  release since November 2024.
- **harfrust 0.14.0** (MIT), released on 2026-10-04, in the harfbuzz organisation. It is the official
  successor: a Rust port of HarfBuzz that continues where rustybuzz stopped. Releases are regular
  (0.13.0 to 0.14.0 between August and October 2026). Minimum Rust 1.85.
- harfrust 0.14 is built on **read-fonts 0.45**, the same version **skrifa 0.48** uses. skrifa and
  read-fonts are already the brief's font parsers. With harfrust, parsing and shaping share one font
  stack. With rustybuzz, a second parser (ttf-parser) would sit next to it.
- **krilla 0.8.2** (planned for PDF/A and tagging in P4) still pulls in rustybuzz through its default
  `simple-text` feature. krilla's main branch already uses harfrust, but that is not released yet.

An archived shaper gets no fixes for shaping bugs, new Unicode versions or security issues in its font
parsing, and Ferman shapes text from untrusted fonts.

## Decision

ferman-fonts uses **harfrust 0.14** instead of rustybuzz.

- harfrust is pinned to an exact version and upgraded together with skrifa, read-fonts and subsetter,
  as one font stack.
- The shaper sits behind ferman-fonts' internal `Shaper` trait. Nothing outside ferman-fonts names the
  shaping crate.
- rustybuzz is not a direct dependency anywhere. It is tolerated only as a transitive dependency of
  krilla until a krilla release moves to harfrust; P4 work prefers that release.
- cargo-deny bans rustybuzz except when krilla pulls it in
  (`{ crate = "rustybuzz", wrappers = ["krilla"] }`, [ADR 0016](0016-dependency-licence-policy.md)),
  from the first `deny.toml` in M1 step 1. [DEPENDENCIES.md](../DEPENDENCIES.md) lists rustybuzz as
  rejected as a direct dependency.

The owner approved this on 2026-10-15 ([Q04](../QUESTIONS.md#q04)). Shaping is first needed in M3,
when harfrust is added.

## Consequences

### Positive

- A maintained shaper with HarfBuzz behaviour, in the harfbuzz organisation.
- One font parsing stack (read-fonts) for metrics, outlines and shaping, instead of two. Fewer
  dependencies, smaller binaries, no duplicate parsing of untrusted fonts.
- The API is close to rustybuzz's, so the brief's design does not change; only the crate does.

### Negative

- harfrust is pre-1.0 and changes often. Exact pins and joint upgrades are required, and every upgrade
  reruns the shaping and pixel-diff suites.
- Until krilla moves to harfrust, a P4 build would contain both shapers. That costs binary size, not
  correctness, because krilla's copy is only used inside krilla.
- This changes a library the brief names, so it needed the owner's approval before it took effect
  ([brief §3](../BRIEF.md), [§9](../BRIEF.md)). The owner gave it on 2026-10-15.

### Follow-up

- M0: [Q04](../QUESTIONS.md#q04) asked the owner; approved on 2026-10-15.
- M1 step 1: the cargo-deny ban on rustybuzz (krilla wrapper only) is active in the first `deny.toml`.
- M3: add harfrust and Arabic, Persian, Devanagari and CJK shaping tests against HarfBuzz reference
  output.
- P4: check whether krilla has released its harfrust move before adding it.

## Alternatives considered

- **Keep rustybuzz** (the brief as written). No owner decision needed, but an archived dependency on a
  security-relevant path, and a second font parser next to read-fonts.
- **HarfBuzz itself through C bindings.** The reference implementation, but it adds a C++ build to
  every platform, complicates the WebAssembly build in P5, and brings memory-unsafe parsing of untrusted
  fonts into Ferman's own editing path.
- **swash** (MIT OR Apache-2.0). A capable Rust shaper and scaler, but it does not aim for HarfBuzz
  parity on complex scripts, and it would add a third font stack.
- **allsorts** (Apache-2.0). Shaping and subsetting in one crate, but its own parser again, and smaller
  coverage of complex scripts than HarfBuzz.

## References

- [Brief](../BRIEF.md) §3, §4, §9
- [ADR 0005](0005-block-scoped-text-editing.md), [ADR 0006](0006-font-pipeline-and-missing-glyphs.md),
  [ADR 0016](0016-dependency-licence-policy.md)
- [DEPENDENCIES.md](../DEPENDENCIES.md): harfrust, rustybuzz, skrifa, read-fonts, subsetter, krilla
- [Q04](../QUESTIONS.md#q04)
- rustybuzz README (archived; points to HarfRust); harfrust 0.14.0 on crates.io
