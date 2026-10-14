# ADR 0007: harfrust instead of rustybuzz for shaping

- **Status:** Proposed
- **Date:** 2026-10-14
- **Approval:** none yet; asked in [Q04](../QUESTIONS.md#q04)
- **Supersedes:** none (it would change the shaper named in brief §3)
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

**Proposed:** ferman-fonts uses **harfrust 0.14** instead of rustybuzz.

- harfrust is pinned to an exact version and upgraded together with skrifa, read-fonts and subsetter,
  as one font stack.
- The shaper sits behind ferman-fonts' internal `Shaper` trait. Nothing outside ferman-fonts names the
  shaping crate.
- rustybuzz is not a direct dependency anywhere. It is tolerated only as a transitive dependency of
  krilla until a krilla release moves to harfrust; P4 work prefers that release.
- Once this ADR is approved, cargo-deny bans rustybuzz except when krilla pulls it in
  (`wrappers = ["krilla"]`, [ADR 0016](0016-dependency-licence-policy.md)), and
  [DEPENDENCIES.md](../DEPENDENCIES.md) marks rustybuzz as rejected.

**Until the owner approves, the brief stands:** rustybuzz is the shaper, and the cargo-deny ban on
rustybuzz is not active. Shaping is first needed in M3, so the choice must be settled before M3 starts.
Because of the `Shaper` trait, switching later touches one module.

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
- This changes a library the brief names, so it needs the owner's approval before it takes effect
  ([brief §3](../BRIEF.md), [§9](../BRIEF.md)).

### Follow-up

- M0: [Q04](../QUESTIONS.md#q04) asks the owner.
- M3, if approved: add harfrust, activate the cargo-deny ban, add Arabic, Persian, Devanagari and CJK
  shaping tests against HarfBuzz reference output.
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
