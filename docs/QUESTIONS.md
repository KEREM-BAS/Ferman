# Questions for the owner

These are the open questions that need the owner's decision. Brief §9 says to put open questions
here and continue with the safest option. Every entry therefore names the option in force until the
owner answers, so work does not stop and nothing is built on an unapproved change by accident.

Brief §8 asks Milestone 0 to end with at least three questions: the bundle identifier
([Q01](#q01)), the publisher name for code signing ([Q02](#q02)) and the minimum macOS and Windows
versions ([Q03](#q03)). The others came up during discovery and planning.

Related: [design gaps](DESIGN_GAPS.md) · [roadmap](ROADMAP.md) · [architecture](ARCHITECTURE.md) ·
[dependencies](DEPENDENCIES.md) · [ADRs](adr/README.md) · [progress](PROGRESS.md)

## Contents

1. [How to answer](#how-to-answer)
2. [Entry format](#entry-format)
3. [Summary](#summary)
4. [Questions](#questions)

## How to answer

- Answer in any form: a reply to the M0 summary, a GitHub issue or comment, or an edit to this file.
  A short answer such as "Q04: yes" is enough.
- The answer is written into the entry with its date, and the status becomes **Answered**.
- The documents that depend on it follow in the same change: the ADR status, the linked
  [DESIGN_GAPS.md](DESIGN_GAPS.md) entries (from Needs owner to Decided or Resolved), and
  [ROADMAP.md](ROADMAP.md), [DEPENDENCIES.md](DEPENDENCIES.md) or [ARCHITECTURE.md](ARCHITECTURE.md)
  where they mention the question.
- New questions get the next free id, Q17 onwards. Ids are never reused, so links stay valid.

### Status values

| Status | Meaning |
|---|---|
| Open | Waiting for the owner. The default in the entry is in force. |
| Answered | The owner has decided. The answer and its date are in the entry. |
| Withdrawn | No longer needed. The entry says why. |

## Entry format

Each entry starts with an HTML anchor, so other documents can link to it as `QUESTIONS.md#q07`:

```markdown
<a id="qNN"></a>

### QNN · Short title

- **Question:** what the owner is asked to decide
- **Why it matters:** what depends on the answer
- **Options:** the realistic choices, with their costs
- **Proposal:** the option recommended
- **Meanwhile:** what is in force until the owner answers
- **Needed by:** the milestone, or the step, that the answer blocks
- **Status:** Open, Answered (with date) or Withdrawn
- **Related:** ADRs, design gaps and other questions
- **Answer:** none yet
```

## Summary

| ID | Question | Needed by | Status |
|---|---|---|---|
| [Q01](#q01) | Bundle identifier | M1 step 2 (placeholder allowed); final before M5 | Open |
| [Q02](#q02) | Code-signing publisher name | M5 | Open |
| [Q03](#q03) | Minimum OS versions and architectures | M1 step 2 (proposal used); final before M5 | Open |
| [Q04](#q04) | Approve ADR 0007: harfrust instead of rustybuzz | M1 step 1; M3 at the latest | Open |
| [Q05](#q05) | Confirm eight mode tabs, including Tools | M1 step 8 | Open |
| [Q06](#q06) | Network uses the design adds: OCSP and CRL, local network | M4 (Privacy rows); P3 | Open |
| [Q07](#q07) | Approve ADR 0018: OS-native file pickers | M2 | Open |
| [Q08](#q08) | Fonts to bundle: Hebrew, Devanagari, CJK, handwriting, similar fonts | M1 step 5; M3; M4 | Open |
| [Q09](#q09) | Missing-glyph default as designed | M3 | Open |
| [Q10](#q10) | Milestones for drawn features the roadmap does not name | M2 | Open |
| [Q11](#q11) | Design re-export and fixes, or DESIGN_GAPS decisions as final | none blocked; M1 gains most | Open |
| [Q12](#q12) | Linux packaging formats and window chrome | M1 step 8; M5 | Open |
| [Q13](#q13) | Document JavaScript is never executed | M2 | Open |
| [Q14](#q14) | Copyright holder "The Ferman Authors" | M1; final before M5 | Open |
| [Q15](#q15) | Update check: endpoint and payload | M5 | Open |
| [Q16](#q16) | OCR engine | P3 | Open |

## Questions

<a id="q01"></a>

### Q01 · Bundle identifier

- **Question:** Which reverse-DNS identifier should Ferman use as its bundle and application id?
- **Why it matters:** The id is how each operating system knows the app. On macOS it is the
  `CFBundleIdentifier`: Gatekeeper, notarization and keychain entries use it, and so does the
  folder `~/Library/Application Support/<bundle id>/` that holds recovery files
  ([ADR 0008](adr/0008-file-safety-and-saving.md)). On Windows it feeds the installer, the file
  associations and the winget package. On Linux it names the desktop file, and Flatpak requires a
  reverse-DNS application id. The iOS and Android apps (phase 5) need one too. It must be based on a
  domain or account you control, so nobody else can claim it. It cannot change after the first
  release without breaking settings, recovery paths, file associations and updates.
- **Options:**
  1. A domain you own, for example `org.<your-domain>.ferman`. The most durable choice, but the
     domain must stay registered.
  2. Your GitHub account: `io.github.kerem-bas.ferman`. No domain needed, and Flathub accepts
     `io.github.<user>.<project>` ids that it can verify through the repository. It is tied to the
     account name.
  3. The domain of a future organisation, if Ferman moves to one. It must exist before the first
     release.
- **Proposal:** option 2, unless you own or plan to own a domain for Ferman. Some platforms restrict
  the characters in an id (some Linux and D-Bus ids do not allow hyphens, so Linux may need
  `io.github.kerem_bas.Ferman`); M1 checks the exact form for each platform.
- **Meanwhile:** M0 has no code, so the placeholder `io.github.kerem-bas.ferman` appears only in
  these documents. If M1 step 2 starts before an answer, the platform projects carry a clearly
  marked placeholder with a [BACKLOG.md](BACKLOG.md) entry, and nothing is released with it.
- **Needed by:** M1 step 2, where a marked placeholder is allowed. Final before M5 signing and
  release.
- **Status:** Open
- **Related:** [ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md),
  [ADR 0008](adr/0008-file-safety-and-saving.md), [Q02](#q02), [Q12](#q12)
- **Answer:** none yet

<a id="q02"></a>

### Q02 · Code-signing publisher name

- **Question:** Under which name should releases be signed: the Apple Developer ID team name on
  macOS, and the subject of the Authenticode certificate on Windows?
- **Why it matters:** The name is what people see when they install Ferman: in Gatekeeper on macOS,
  and as the "Verified publisher" in the Windows permission prompt and SmartScreen. Apple and the
  certificate authority verify it. An individual account shows your legal name. An organisation
  account shows the organisation's legal name and needs a registered legal entity (Apple asks for a
  D-U-N-S number). SmartScreen builds reputation per certificate and publisher, so changing the name
  later loses that reputation. Unsigned builds are blocked or flagged on both systems, and the
  bundled PDFium library is signed together with the app.
- **Options:**
  - macOS: (a) an individual Apple Developer Program membership, signed with your legal name;
    (b) an organisation membership, signed with the organisation's name.
  - Windows: (a) an organisation-validated code-signing certificate from a commercial certificate
    authority, in your name or the organisation's (the key must live on a hardware token or in a
    cloud key store); (b) SignPath Foundation's free signing for open-source projects, where the
    publisher shown is the foundation, not Ferman; (c) Azure Trusted Signing, Microsoft's managed
    signing service, where eligibility depends on identity validation and country.
  - Linux packages and release checksums are signed with a project key, whatever the answer here.
- **Proposal:** one name on both platforms. Use an individual Apple membership unless an
  organisation exists. On Windows, use Azure Trusted Signing or an organisation-validated
  certificate in the same name if available to you, and SignPath Foundation otherwise.
- **Meanwhile:** development and CI builds stay unsigned. M4 runs a signing dry run with a test
  certificate (see [ROADMAP.md](ROADMAP.md)). Nothing is published as a release before an answer.
- **Needed by:** M5. Enrolment and certificate validation can take weeks, so an early answer helps.
- **Status:** Open
- **Related:** [ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md),
  [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md), [Q01](#q01), [Q14](#q14)
- **Answer:** none yet

<a id="q03"></a>

### Q03 · Minimum OS versions and architectures

- **Question:** Which operating-system versions and processor architectures must Ferman support?
- **Why it matters:** The answer sets the deployment targets in the Flutter platform projects, the
  CI matrix, which PDFium binaries ship, and which OS features Ferman can use without fallbacks
  (file pickers and sandbox bookmarks, atomic file replacement, portals on Linux). Ferman's users
  are office and public-sector staff, who often work on older managed machines. Lower minimums
  reach more people but cost testing and workarounds.
- **Options:** the proposal below, or higher or lower minimums for each platform.
- **Proposal:**
  - macOS 12 Monterey or later, as one universal build (arm64 and x86_64).
  - Windows 10 22H2 and Windows 11, on x64 and arm64. Windows 10 reached its end of support in
    October 2025, but many managed office machines still run it, some with extended security
    updates.
  - Linux, best effort: x64 and arm64 on glibc-based distributions, for example Ubuntu 22.04 or
    later.
  - M1 checks these against the minimums of Flutter 3.47.7 and of the PDFium binaries. Where
    Flutter needs more, its minimum wins and this entry is updated.
- **Meanwhile:** the proposal. If M1 step 2 starts before an answer, the platform projects use it
  with a [BACKLOG.md](BACKLOG.md) entry until this question is final.
- **Needed by:** M1 step 2 (deployment targets; the proposal is used if there is no answer). Final
  before M5.
- **Status:** Open
- **Related:** [ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md),
  [ADR 0018](adr/0018-native-file-pickers.md), [G15](DESIGN_GAPS.md#g15), [Q12](#q12)
- **Answer:** none yet

<a id="q04"></a>

### Q04 · Approve ADR 0007: harfrust instead of rustybuzz

- **Question:** May ferman-fonts shape text with harfrust instead of rustybuzz, which brief §3
  names?
- **Why it matters:** Shaping turns text into positioned glyphs for every edit Ferman writes into a
  PDF: Arabic and Persian joining forms, Devanagari clusters, ligatures and kerning in Latin
  scripts, and CJK. rustybuzz is archived upstream and points its users to harfrust, so it gets no
  more fixes, including security fixes on a path that reads untrusted fonts. harfrust (0.14.0, MIT)
  is the maintained successor in the HarfBuzz organisation and uses read-fonts, the same font
  parser as skrifa, so Ferman parses fonts with one library instead of two. The brief fixes this
  library, so changing it needs your approval (brief §3 and §9).
- **Options:** (a) harfrust, pinned to an exact version; (b) rustybuzz, as the brief says;
  (c) HarfBuzz itself through C bindings, the most mature option, at the cost of a C dependency and
  build work on three systems.
- **Proposal:** (a), as [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md) describes.
- **Meanwhile:** the brief's rustybuzz stands. The shaper sits behind one internal interface, so a
  switch touches one module. cargo-deny does not ban rustybuzz unless you approve.
- **Needed by:** M1 step 1, which sets the ferman-fonts dependencies and the cargo-deny bans. M3 at
  the latest, when shaping is first used.
- **Status:** Open
- **Related:** [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md),
  [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md), [DEPENDENCIES.md](DEPENDENCIES.md)
- **Answer:** none yet

<a id="q05"></a>

### Q05 · Confirm eight mode tabs, including Tools

- **Question:** Should the mode bar have the eight tabs that every artboard draws: View, Edit,
  Comment, Fill & Sign, Organize, Convert, Protect and Tools?
- **Why it matters:** The design disagrees with itself. FmWindow and every board with a mode bar
  show eight tabs, while the design system's `FERMAN_MODES` constant and its readme list seven,
  without Tools. Tools holds Compress and Version history (M4), basic Print (proposed for M4,
  [Q10](#q10)) and later tools: Compare, Accessibility, PDF/A & preflight, Batch actions, Measure and
  AI assistant. The brief does not list the modes. The mode bar is built in M1.
- **Options:** (a) eight tabs as drawn; (b) seven tabs as the design system constant says, with the
  Tools items moved somewhere no board draws, such as a menu or other modes.
- **Proposal:** (a).
- **Meanwhile:** eight tabs. Later-phase Tools items are visible but disabled with "Available in a
  future version".
- **Needed by:** M1 step 8 (app shell).
- **Status:** Open
- **Related:** [G09](DESIGN_GAPS.md#g09),
  [ADR 0011](adr/0011-flutter-state-navigation-components.md)
- **Answer:** none yet

<a id="q06"></a>

### Q06 · Network uses the design adds

- **Question:** May Ferman use the network for OCSP and CRL certificate revocation checks, and for
  scanner discovery and phone pairing on the local network?
- **Why it matters:** Brief §3 allows exactly four network uses: the update check, optional
  language-pack downloads, optional AI, and signature timestamp servers. The design adds more:
  - revocation lookups when signing or opening a signed file (a11-1h "Signature checks", on by
    default; a11-1e; long-term validation, PAdES-B-LT, by default in a5-5b and a5-6);
  - Wi-Fi scanner discovery and phone-as-camera pairing over the local network (a7-4);
  - "Send to my computer…" from the mobile app (a13-8f).

  Revocation data makes signature validation trustworthy and lets signatures stay verifiable for
  years, which matters for Turkish e-imza. Without it, validation can only use data already in the
  file and must say that revocation was not checked.
- **Options:**
  - Revocation: (a) allowed, off until first use, with its own switch in Settings › Privacy and an
    entry in the network activity log; (b) allowed and on by default, as drawn; (c) not allowed:
    validation uses embedded data and says when revocation was not checked, and signing defaults
    to PAdES-B-T.
  - Local network: (a) discovery and pairing allowed, off until first use, with their own switch;
    (b) only the scanners the operating system provides, and no pairing; (c) left out.
- **Proposal:** revocation (a). Local network (b) for phase 3, and pairing reconsidered with the
  mobile apps in phase 5.
- **Meanwhile:** none of these is enabled. The drawn rows and switches stay visible but disabled.
  Nothing is built before phase 3.
- **Needed by:** M4 decides which rows Settings › Privacy shows; P3 builds the features.
- **Status:** Open
- **Related:** [G24](DESIGN_GAPS.md#g24), [G51](DESIGN_GAPS.md#g51), [G52](DESIGN_GAPS.md#g52),
  [G56](DESIGN_GAPS.md#g56), [ADR 0015](adr/0015-privacy-and-network.md)
- **Answer:** none yet

<a id="q07"></a>

### Q07 · Approve ADR 0018: OS-native file pickers

- **Question:** May Ferman use the operating system's own pickers to open a file, choose a save
  location and choose a folder, as the only exception to the brief's custom-dialog rule?
- **Why it matters:** Brief §6 says dialogs are custom design-system widgets. File pickers are
  different. In sandboxed builds (the Mac App Store, Flatpak, Snap, the web, iOS and Android) only
  the system picker can give Ferman access to a file the user chose. People also rely on the
  picker's favourites, cloud drives, network locations and accessibility. The design draws a custom
  Save as sheet (a1-11) with "Other location…", "Choose a folder…" in a6-2 and a7-2, and no open
  dialog at all.
- **Options:** (a) native pickers for opening, save location and folder only, while Ferman's a1-11
  sheet stays and hands off for "Other location…"; (b) a custom Ferman file browser, which cannot
  work in sandboxed builds; (c) native pickers everywhere, including Save as, which drops the drawn
  a1-11 sheet.
- **Proposal:** (a), as [ADR 0018](adr/0018-native-file-pickers.md) describes.
- **Meanwhile:** M1 builds no picker; entry points that would open one stay visible and disabled
  with "Available in a future version". If M2 starts before an answer, the OS-native open picker is
  used as the safest option (brief §9), and in M3 the native save-location handoff from a1-11; each
  milestone summary flags it again for approval, as ADR 0018 says.
- **Needed by:** M2 (open dialog); M3 (Save as).
- **Status:** Open
- **Related:** [ADR 0018](adr/0018-native-file-pickers.md), [G25](DESIGN_GAPS.md#g25),
  [G26](DESIGN_GAPS.md#g26), [G28](DESIGN_GAPS.md#g28), [Q12](#q12)
- **Answer:** none yet

<a id="q08"></a>

### Q08 · Fonts to bundle

- **Question:** Beyond IBM Plex Sans, Serif, Mono and Sans Arabic, which fonts should ship with the
  app?
- **Why it matters:** Brief §2 says fonts come from the design, and scripts the bundled fonts do not
  cover fall back to system fonts. The design names more faces than that core set and loads them
  from Google Fonts at run time, which Ferman never does ([G07](DESIGN_GAPS.md#g07)). Every font
  adds size to the app and a licence to ship. Four groups need a decision:
  1. **IBM Plex Sans Hebrew and IBM Plex Sans Devanagari** (OFL-1.1, small) for the Hebrew and Hindi
     UI, as the design's UI font stack names them. Without them, Hebrew and Hindi use system fonts.
  2. **CJK.** IBM's Plex Sans JP, KR, SC and TC releases are tens to hundreds of megabytes, so
     Japanese, Korean and Chinese use system fonts ([ADR 0013](adr/0013-fonts-and-icons.md)).
     Downloadable font packs would be a new network use.
  3. **Handwriting faces for typed signatures** (M4): Caveat and Dancing Script (OFL-1.1) and
     Homemade Apple (Apache-2.0), the design's `--font-hand-1..3`.
  4. **Similar document fonts for missing glyphs** (M3): the a3-3b group "Similar fonts included
     with Ferman" shows Cormorant Garamond and Crimson Pro (both OFL-1.1). Any font shipped for this
     must allow embedding.
- **Options:** bundle each group or not; for group 2, system fonts only or optional font packs.
- **Proposal:** bundle groups 1, 3 and 4 as unmodified upstream files with their licences; CJK from
  system fonts, with no font packs.
- **Meanwhile:** Hebrew, Hindi and CJK use system fonts. No handwriting fonts ship, so typed
  signatures wait while drawn and image signatures work. Missing-glyph step 3 offers embedded fonts,
  installed fonts and the bundled Plex families.
- **Needed by:** M1 step 5 (groups 1 and 2), M3 (group 4), M4 (group 3).
- **Status:** Open
- **Related:** [ADR 0013](adr/0013-fonts-and-icons.md) (proposed in part),
  [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md), [G06](DESIGN_GAPS.md#g06),
  [G07](DESIGN_GAPS.md#g07), [G08](DESIGN_GAPS.md#g08)
- **Answer:** none yet

<a id="q09"></a>

### Q09 · Missing-glyph default as designed

- **Question:** Is the design's default for a character the font cannot draw the right one?
- **Why it matters:** Brief §4: when an edit needs a glyph the embedded font lacks (for example ğ,
  ş or İ in a subset font), Ferman (1) uses the embedded glyph if present, (2) takes it from the
  same font if that font is installed, re-subsets and embeds it, and (3) otherwise offers similar
  fonts exactly as the design shows, never substituting silently. The design's Settings › Editing
  (a11-1c) defaults to "Use a similar font and say so": the closest font draws the character at
  once, the panel says so once and marks the character, and "Choose a font…" and "Keep as is" stay
  available. The other settings are "Ask each time" and "Keep the original font and mark the
  character". Ferman reads the default as compliant, because it is never silent, but "offer" could
  also mean "ask first".
- **Options:** (a) the design's default, "Use a similar font and say so"; (b) "Ask each time" as the
  default; (c) "Keep the original font and mark the character" as the default.
- **Proposal:** (a).
- **Meanwhile:** (a), with step 2 always tried first
  ([ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md)).
- **Needed by:** M3.
- **Status:** Open
- **Related:** [G36](DESIGN_GAPS.md#g36), [G37](DESIGN_GAPS.md#g37),
  [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md)
- **Answer:** none yet

<a id="q10"></a>

### Q10 · Milestones for drawn features the roadmap does not name

- **Question:** Do you accept the proposed milestones for drawn features that brief §7 does not
  schedule?
- **Why it matters:** The design draws these features with no milestone tags, and the brief's
  roadmap does not name them. Until they are scheduled, their entry points are visible but disabled.
- **Options:** accept the proposal, move individual features, or mark some as out of scope (they
  would then stay disabled, with a BACKLOG entry saying so).
- **Proposal:**

  | Feature | Boards | Proposed |
  |---|---|---|
  | Layers (optional content) tab | a2-3c | M2 |
  | Basic system print | a9-6 | M4 |
  | Presentation mode, reading mode, split view, inverted dark reading | a2-5a, a2-5b, a2-8a, a2-8b, a2-9 | P2 |
  | Read aloud, measure and calibrate | a2-6, a4-1c, a9-7 | P4 |
  | Booklet, poster, separations | a9-6b, a9-6c, a9-6d | P5 |
  | Mobile night mode and read aloud, iPad split view | a13-4d, a14-1c | P5, with the mobile and tablet apps |

  Drawn features placed with the nearest roadmap item (crash recovery with saving, bookmarks and
  metadata editing, links, and others) are listed in [ROADMAP.md](ROADMAP.md) under "Not scheduled
  yet".
- **Meanwhile:** the proposal. Entry points stay disabled with "Available in a future version"
  until each feature ships.
- **Needed by:** M2 (layers), then M4 and each later phase.
- **Status:** Open
- **Related:** [G33](DESIGN_GAPS.md#g33), [ROADMAP.md](ROADMAP.md)
- **Answer:** none yet

<a id="q11"></a>

### Q11 · Design re-export and fixes

- **Question:** Will the designer provide a re-export and corrected boards, or should the decisions
  in [DESIGN_GAPS.md](DESIGN_GAPS.md) be treated as final?
- **Why it matters:** The export is incomplete. The desktop UI kit that the brief cites
  (`design/ui_kits/desktop/index.html`) does not exist, and the component sources, foundation
  guidelines, icon SVGs and licence files are missing ([G01](DESIGN_GAPS.md#g01) to
  [G04](DESIGN_GAPS.md#g04), [G08](DESIGN_GAPS.md#g08)). Many states and variants are not drawn:
  Linux chrome, Windows dialogs, dark, right-to-left and Turkish variants, empty and error states.
  Several boards need copy changes: GPL-3.0 to Apache-2.0, "Included" on later features, the list of
  network uses. Ferman never edits `design/`, so each fix either comes from the designer or stays a
  decision in DESIGN_GAPS.md.
- **Options:**
  - (a) A re-export with `ui_kits/`, component sources (`.jsx`, `.d.ts`), guidelines, icon SVGs,
    licence files and the additions merged, plus new or corrected boards for the gaps, delivered per
    milestone.
  - (b) No re-export: the DESIGN_GAPS decisions are final, and goldens built from them become the
    reference.
  - (c) A mix: the missing files now, and boards only for the riskiest gaps (M1 shell variants and
    the M3 editing states).
- **Proposal:** (c).
- **Meanwhile:** the DESIGN_GAPS decisions stand. The `Fm*` building blocks, `_ds_bundle.js` and
  `_adherence.oxlintrc.json` are the source for components. Ferman builds undrawn states from
  existing components and records them in goldens. A re-export replaces `design/` only through a
  change you make or approve (brief §9).
- **Needed by:** no milestone is blocked. M1 (component library and shell) gains most from an early
  answer.
- **Status:** Open
- **Related:** [G01](DESIGN_GAPS.md#g01), [G02](DESIGN_GAPS.md#g02), [G03](DESIGN_GAPS.md#g03),
  [G04](DESIGN_GAPS.md#g04), [G05](DESIGN_GAPS.md#g05), [G08](DESIGN_GAPS.md#g08),
  [G60](DESIGN_GAPS.md#g60), and every DESIGN_GAPS entry that asks for boards;
  [ADR 0012](adr/0012-design-token-pipeline.md), [ADR 0013](adr/0013-fonts-and-icons.md)
- **Answer:** none yet

<a id="q12"></a>

### Q12 · Linux packaging formats and window chrome

- **Question:** Which Linux package formats should releases include, and should the Linux window use
  Ferman's own title bar or the system's?
- **Why it matters:** Linux is best effort (brief §1), and the design draws no Linux chrome
  ([G15](DESIGN_GAPS.md#g15)). The package format decides sandboxing (Flatpak and Snap reach files
  through portals, which ties into [Q07](#q07)), how updates arrive (through the package manager,
  not the in-app updater, [G53](DESIGN_GAPS.md#g53)), the application id ([Q01](#q01)) and what CI
  builds. The chrome decides the Linux title bar in M1.
- **Options:**
  - Formats: Flatpak on Flathub (sandboxed, wide reach, updates through Flathub); AppImage (one
    file, no sandbox, updates need extra work); `.deb` and `.rpm` (native packages, work per
    distribution); Snap; a plain archive.
  - Chrome: (a) client-side decorations drawn by Ferman, with the caption buttons at the end in the
    GNOME (libadwaita) style, matching the custom title bars on macOS and Windows; (b) the system's
    own decorations, with Ferman's tab, mode and tool rows below them.
- **Proposal:** Flatpak on Flathub plus an AppImage for M5; chrome (a).
- **Meanwhile:** chrome (b) with a [BACKLOG.md](BACKLOG.md) entry. No packaging before M5.
- **Needed by:** M1 step 8 (chrome); M5 (packaging).
- **Status:** Open
- **Related:** [G15](DESIGN_GAPS.md#g15), [G53](DESIGN_GAPS.md#g53),
  [ADR 0018](adr/0018-native-file-pickers.md), [Q01](#q01), [Q03](#q03), [Q07](#q07)
- **Answer:** none yet

<a id="q13"></a>

### Q13 · Document JavaScript is never executed

- **Question:** Do you confirm that Ferman never runs JavaScript embedded in PDF files?
- **Why it matters:** PDFs can carry JavaScript for form calculations, validation and formatting,
  and for actions when a document opens. Scripts are a common attack path, and a script engine is a
  large dependency. Some forms rely on scripts to compute totals or format dates; without them,
  those fields show their stored values and need typing by hand.
- **Options:** (a) never run document JavaScript, and tell the user when a document contains scripts
  that Ferman does not run; (b) (a), plus built-in support for the most common form helpers (number,
  date and percentage formats, simple sums) without a script engine; (c) run scripts in a sandboxed
  engine.
- **Proposal:** (a) now; consider (b) with form filling (M4) or form authoring (P4).
- **Meanwhile:** (a). The PDFium build Ferman ships has no JavaScript engine, and the engine never
  executes document scripts ([ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md),
  [ADR 0015](adr/0015-privacy-and-network.md)).
- **Needed by:** M2 (opening documents that contain scripts); M4 (form filling).
- **Status:** Open
- **Related:** [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md),
  [ADR 0015](adr/0015-privacy-and-network.md), [ARCHITECTURE.md](ARCHITECTURE.md)
- **Answer:** none yet

<a id="q14"></a>

### Q14 · Copyright holder

- **Question:** Should the copyright line read "Copyright The Ferman Authors"?
- **Why it matters:** The line appears in the About screen (a11-5), in the app's metadata (the
  macOS bundle and the Windows file properties), in installers and in notice files. With "The
  Ferman Authors", every contributor keeps the copyright in their own contribution and licenses it
  under Apache-2.0 (inbound equals outbound, no contributor licence agreement), and the git history
  records who the authors are.
- **Options:** (a) "The Ferman Authors"; (b) your legal name, with contributors credited; (c) a
  future organisation.
- **Proposal:** (a).
- **Meanwhile:** "The Ferman Authors" in the documents. The LICENSE file is the unmodified
  Apache-2.0 text and needs no name.
- **Needed by:** M1 (app metadata and About); final before M5.
- **Status:** Open
- **Related:** [ADR 0016](adr/0016-dependency-licence-policy.md),
  [CONTRIBUTING.md](../CONTRIBUTING.md), [LICENSE](../LICENSE)
- **Answer:** none yet

<a id="q15"></a>

### Q15 · Update check: endpoint and payload

- **Question:** Where should the update check connect, and what may it send?
- **Why it matters:** The update check is the only network use that is on by default (brief §3), so
  it must be small and easy to verify. a11-1h promises that it sends "the version number and
  platform"; a1-2b says "only the version number" ([G24](DESIGN_GAPS.md#g24)). The endpoint decides
  who sees the request, and any request shows the user's IP address to that server.
- **Options:**
  - Endpoint: (a) a static release manifest served from GitHub (Releases or Pages), with no server
    of our own; (b) the GitHub Releases API; (c) a Ferman server.
  - Payload: (a) nothing beyond the request itself, with versions compared on the device; (b) the
    version and platform, as a11-1h says, so the server can pick the right file.
  - Either way, update packages are verified with a signature before they are installed.
- **Proposal:** endpoint (a), with one manifest per channel (Stable, Beta) and a signature. One
  HTTPS request with no cookies and no identifiers; the user agent carries only the version and
  platform, matching a11-1h; the comparison happens on the device.
- **Meanwhile:** no network code exists before M5.
- **Needed by:** M5.
- **Status:** Open
- **Related:** [G24](DESIGN_GAPS.md#g24), [G53](DESIGN_GAPS.md#g53),
  [ADR 0015](adr/0015-privacy-and-network.md)
- **Answer:** none yet

<a id="q16"></a>

### Q16 · OCR engine

- **Question:** Which OCR engine should Ferman use in phase 3?
- **Why it matters:** OCR makes scanned pages searchable and editable (a3-11, a7-5). It should cover
  as many of the 21 UI languages' scripts as possible, Turkish first. ocrs, the engine brief §3 asks
  to verify, recognises only Latin script in its current preview, and the licence of its trained
  models is unclear. Model and language-data licences must pass Ferman's policy
  ([ADR 0016](adr/0016-dependency-licence-policy.md)), and OCR language packs are one of the four
  allowed network uses.
- **Options:** (a) ocrs with rten, if models for more scripts with a clear licence appear before
  phase 3; (b) Tesseract (Apache-2.0) with Leptonica (BSD-2-Clause): wide language coverage and
  trained data under Apache-2.0, at the cost of a C++ dependency on three systems; (c) another
  engine with ONNX models, after a licence review.
- **Proposal:** decide at the start of phase 3 after a fresh check. Tesseract is the fallback.
- **Meanwhile:** no OCR before phase 3. OCR entry points are disabled with "Available in a future
  version".
- **Needed by:** P3.
- **Status:** Open
- **Related:** [ADR 0016](adr/0016-dependency-licence-policy.md), [DEPENDENCIES.md](DEPENDENCIES.md),
  [ROADMAP.md](ROADMAP.md), [G29](DESIGN_GAPS.md#g29), [G39](DESIGN_GAPS.md#g39)
- **Answer:** none yet
