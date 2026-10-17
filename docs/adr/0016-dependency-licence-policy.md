# ADR 0016: Dependency licence policy

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §1, §3 and §9. The three licence exceptions below were approved by the owner
  on 2026-10-15 ([Q17](../QUESTIONS.md#q17), parts 1 to 3); the reading of "GPL-compatible" (part 4)
  was confirmed on 2026-10-16.
- **Supersedes:** none
- **Superseded by:** none

## Context

Ferman is licensed under **Apache-2.0** ([brief §1](../BRIEF.md)). The brief's dependency rule:
"permissive or GPL-compatible licences only. Never AGPL or non-commercial (no MuPDF, no Ghostscript).
Enforce with cargo-deny and list every dependency with its licence in docs/DEPENDENCIES.md"
([brief §3](../BRIEF.md)). And: ask the owner before "adding a dependency with an unusual licence"
([brief §9](../BRIEF.md)).

"GPL-compatible" needs a precise reading for an Apache-2.0 product:

- **GPL-2.0-only** code cannot be combined with Apache-2.0 code in one distributed binary. The FSF
  considers Apache-2.0's patent-termination and indemnity terms incompatible with GPLv2.
- **GPL-3.0** accepts Apache-2.0 code, but only one way: a binary that includes GPL-3.0 code must be
  distributed under GPL-3.0 as a whole. That would relicense Ferman.
- **LGPL** libraries can in principle be linked dynamically, but Rust and Flutter link statically by
  default, and the relinking obligations are hard to meet in signed app bundles and mobile stores.
- **MPL-2.0** is weak copyleft at file level: unmodified MPL files can ship inside an Apache-2.0
  product, with a notice and an offer of their source.

So in practice the rule is: **permissive licences, plus MPL-2.0 for unmodified dependencies after the
owner's review**. This reading of "GPL-compatible" is the project's, not the brief's wording; the
owner confirmed it on 2026-10-16 ([Q17](../QUESTIONS.md#q17), part 4).
The dependency check of 2026-10-13 found that the planned Rust graph (about 356 runtime crates) uses
only MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, Zlib and Unicode-3.0, or offers one of them
inside an OR expression. Two anomalies: `allo-isolate` (from flutter_rust_bridge) declares its
licence as a file holding the Apache-2.0 text, and `libfuzzer-sys` adds NCSA for the vendored libFuzzer.
On the Dart side, desktop_drop depends on `dbus` (MPL-2.0) on every platform: the import is
unconditional, and it is used only on Linux at run time. Some crates are traps by name or by what they
link: the `pdfium` crate (GPL-3.0, easily confused with pdfium-render), mupdf bindings, `jbig2dec`
(wraps an AGPL library), poppler bindings, magick_rust (ImageMagick renders PDF through Ghostscript),
libheif and FFmpeg bindings.

Assets outside the package managers also carry licences: PDFium and its third-party code
([ADR 0004](0004-lopdf-model-pdfium-renderer.md)), IBM Plex (OFL-1.1), Lucide (ISC with the Feather MIT
section) ([ADR 0013](0013-fonts-and-icons.md)), and possibly Homemade Apple (Apache-2.0). The design
export ships none of their licence texts ([G08](../DESIGN_GAPS.md#g08)); the repository carries them for
the copies inside `design/` in [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).

## Decision

### Allowed

- **Code dependencies (Rust and Dart):** Apache-2.0, Apache-2.0 WITH LLVM-exception, MIT, MIT-0,
  BSD-2-Clause, BSD-3-Clause, ISC, Zlib, 0BSD, BSL-1.0, CC0-1.0, Unicode-3.0, Unicode-DFS-2016. An OR
  expression is fine when one side is on this list (for example `MIT OR Apache-2.0 OR LGPL-2.1-or-later`).
- **MPL-2.0:** only per package, after the owner's review, for an unmodified dependency, with a notice.
  Known cases: `dbus` through desktop_drop (every platform), approved on 2026-10-15
  ([Q17](../QUESTIONS.md#q17)); `option-ext` if `dirs` appears, which would be asked the same way.
- **NCSA:** only for `libfuzzer-sys`, only in the separate `fuzz/` workspace, which never ships.
  Approved on 2026-10-15 ([Q17](../QUESTIONS.md#q17)).
- **Fonts:** OFL-1.1 (and Apache-2.0 for Homemade Apple if it ships), for font files only, never as a
  code licence.
- **Tools that run only in CI** (for example the LGPL-3.0 Swatinem/rust-cache action) are not
  distributed, so their licence does not reach users. Their code is never vendored or copied. rust-cache
  was approved on 2026-10-15 ([Q17](../QUESTIONS.md#q17)).

These three exceptions (MPL-2.0 `dbus`, NCSA `libfuzzer-sys`, the LGPL-3.0 CI action) are outside the
allow-list, so they waited for the owner ([brief §9](../BRIEF.md)). The owner approved all three on
2026-10-15 ([Q17](../QUESTIONS.md#q17), parts 1 to 3): CI may cache with Swatinem/rust-cache from M1,
desktop_drop is added in M2 (unmodified, with the `dbus` notice), and the `fuzz/` workspace is created
with the first parser in M2, as the brief requires ([brief §5](../BRIEF.md)). Each stays a named
exception; none widens the allow-list.

### Never

- AGPL (any version), GPL-2.0-only, GPL-2.0-or-later, GPL-3.0 (any), LGPL (any) as a sole licence, EUPL,
  SSPL, BUSL, Elastic, Commons Clause, and any non-commercial licence (CC-BY-NC, PolyForm Noncommercial).
- MuPDF, Ghostscript, poppler or xpdf, in any form, including tools that shell out to them.
- Anything with no licence, or a licence we cannot identify.

### Enforcement: Rust

`deny.toml` (cargo-deny 0.20) was added in M1 step 1, based on the discovery's proposal, and passes
`cargo deny check`; [DEPENDENCIES.md §7](../DEPENDENCIES.md#7-denytoml) summarises it. An excerpt:

```toml
# Excerpt of deny.toml at the repository root.
[licenses]
confidence-threshold = 0.93
allow = [
  "Apache-2.0", "Apache-2.0 WITH LLVM-exception", "MIT", "MIT-0", "BSD-2-Clause", "BSD-3-Clause",
  "ISC", "Zlib", "0BSD", "BSL-1.0", "CC0-1.0", "Unicode-3.0", "Unicode-DFS-2016",
]
exceptions = [
  { crate = "libfuzzer-sys", allow = ["NCSA"] },   # fuzz/ workspace only; approved in Q17
]

[[licenses.clarify]]
crate = "allo-isolate"                              # licence file is the Apache-2.0 text
expression = "Apache-2.0"
license-files = [{ path = "LICENSE", hash = 0x0a6d4ed6 }]   # XXH32 of the normalised LICENSE text

[bans]
multiple-versions = "warn"
wildcards = "deny"
deny = [
  { crate = "mupdf", reason = "AGPL-3.0, MuPDF" },
  { crate = "mupdf-sys", reason = "AGPL-3.0, MuPDF" },
  { crate = "pdfium", reason = "GPL-3.0 wrapper; use pdfium-render" },
  { crate = "jbig2dec", reason = "wraps Artifex jbig2dec (AGPL)" },
  { crate = "poppler-rs", reason = "links GPL poppler" },
  { crate = "poppler-sys-rs", reason = "links GPL poppler" },
  { crate = "magick_rust", reason = "ImageMagick renders PDF through Ghostscript (AGPL)" },
  { crate = "libheif-sys", reason = "links LGPL-3.0 libheif" },
  { crate = "ffmpeg-sys-next", reason = "FFmpeg LGPL/GPL" },
  { crate = "rustybuzz", wrappers = ["krilla"], reason = "archived; use harfrust (ADR 0007)" },
  # Added with the network gateway in M5 (ADR 0015), for the HTTP client chosen then:
  # { crate = "<http client>", wrappers = ["ferman-api"], reason = "network only through the gateway" },
]

[advisories]
yanked = "deny"
unmaintained = "workspace"

[sources]
unknown-registry = "deny"
unknown-git = "deny"
```

- CI runs `cargo deny check` (licences, bans, advisories, sources) on every pull request, with a second
  job that includes dev-dependencies ([ADR 0017](0017-testing-and-ci.md)).
- No licence is added to the global allow-list without an ADR. One-off cases go into `exceptions` with a
  comment and a DEPENDENCIES.md entry.

### Enforcement: Dart

cargo-deny does not see pub packages. CI runs very_good_cli's licence check with the same allow-list
(`very_good packages check licenses --allowed=…`). MPL-2.0 is not on that list. `dbus`, approved in Q17,
is skipped by name from the commit that adds desktop_drop (M2) and listed in DEPENDENCIES.md, so any
other MPL package still fails the check.

### Enforcement: assets

PDFium (the archive's `licenses/` folder, including `licenses/pdfium.txt`, and the packager's MIT
`LICENSE`), the IBM Plex families, the Lucide icons and any other bundled font are listed by hand in
DEPENDENCIES.md and registered with Flutter's `LicenseRegistry`. From M4, cargo-about generates the
Rust notices for the licences screen, and every release from M5 bundles its output; together they feed
the third-party notices screen ([G14](../DESIGN_GAPS.md#g14)).

### Process

- **[DEPENDENCIES.md](../DEPENDENCIES.md) is updated in the same commit** as any dependency change:
  name, ecosystem, exact version, SPDX licence, purpose, milestone and status. A pull request that adds a
  dependency without that update is not merged.
- **Unusual licences go to the owner first** ([brief §9](../BRIEF.md)): anything outside the allow-list,
  any MPL-2.0 case, model weights or data files (for example OCR models, [Q16](../QUESTIONS.md#q16)), and
  anything whose licence cannot be verified. The question goes into [QUESTIONS.md](../QUESTIONS.md);
  work continues without that dependency.
- Fast-moving crates are pinned exactly (lopdf `=0.45`, the fontations stack, flutter_rust_bridge
  `=2.13.0`), and `image` is used with default features off to avoid unmaintained transitive crates.
- Inbound contributions are accepted under Apache-2.0 (inbound equals outbound), as described in
  [CONTRIBUTING.md](../../CONTRIBUTING.md). The copyright line is "Copyright The Ferman Authors"
  ([Q14](../QUESTIONS.md#q14), answered on 2026-10-15).

## Consequences

### Positive

- Ferman stays distributable under Apache-2.0, including in signed app bundles and app stores.
- Banned crates cannot slip in by accident or by a similar name.
- One list (DEPENDENCIES.md) shows every dependency and its licence, as the brief requires.

### Negative

- Some useful libraries are out of reach (MuPDF, poppler, Ghostscript, LGPL codecs). Ferman relies on
  PDFium and Rust crates instead.
- The policy is stricter than a literal reading of "GPL-compatible". That is deliberate: it keeps the
  brief's Apache-2.0 licence intact. The owner confirmed it on 2026-10-16 (Q17, part 4) and can
  relax it through an ADR.
- Licence checks need maintenance: clarify hashes, exceptions and the Dart skip list change with
  upgrades.

### Follow-up

- M0: [Q17](../QUESTIONS.md#q17) asked the owner about the three exceptions; approved on 2026-10-15.
- M1: `deny.toml` with the rustybuzz ban (ADR 0007 accepted), the CI jobs for cargo-deny and the pub
  licence check, the first DEPENDENCIES.md entries for real dependencies. Done so far: `deny.toml`, the
  cargo-deny CI job and the DEPENDENCIES.md entries; the dev-dependency licence run and the pub licence
  check in CI follow.
- M2: desktop_drop with the named `dbus` skip and notice; the `fuzz/` workspace with its
  `libfuzzer-sys` exception.
- M4: cargo-about notices for the licences screen.
- M5: bundle the notices in every release; the gateway ban entry.

## Alternatives considered

- **Literal "GPL-compatible", allowing GPL-3.0.** Would force Ferman's binaries to GPL-3.0, contradicting
  the Apache-2.0 licence in the brief.
- **Allow LGPL with dynamic linking.** Workable on desktop with care, but fragile with static Rust
  linking, signed bundles and mobile stores. Per-case review through the owner remains possible.
- **No automated checks, review by hand.** Misses transitive dependencies; the brief asks for cargo-deny.
- **cargo-deny's old copyleft settings.** Removed from current cargo-deny versions; only the allow-list
  model remains.

## References

- [Brief](../BRIEF.md) §1, §3, §9
- [DEPENDENCIES.md](../DEPENDENCIES.md)
- [ADR 0004](0004-lopdf-model-pdfium-renderer.md), [ADR 0007](0007-harfrust-instead-of-rustybuzz.md),
  [ADR 0013](0013-fonts-and-icons.md), [ADR 0015](0015-privacy-and-network.md),
  [ADR 0017](0017-testing-and-ci.md)
- [G08](../DESIGN_GAPS.md#g08), [G14](../DESIGN_GAPS.md#g14), [Q14](../QUESTIONS.md#q14),
  [Q16](../QUESTIONS.md#q16), [Q17](../QUESTIONS.md#q17)
- FSF licence list (Apache-2.0 and GPL compatibility); cargo-deny documentation (licences, bans)
