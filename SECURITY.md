# Security policy

Ferman will open PDFs that come from strangers, and people will trust it with contracts, statements
and other private documents. We take security reports seriously and are grateful for them.

## Supported versions

Ferman has no released versions yet. Milestone 1 (foundations) is complete and Milestone 2 (open and
view) is planned, so there is nothing to install and nothing to patch.

Once releases exist, the latest release gets security fixes. Older releases do not, so please update
to the latest release before you report.

| Version | Security fixes |
|---|---|
| None released yet | Not applicable |
| Latest release, once releases exist | Yes |
| Older releases | No |

## How to report a vulnerability

Report privately through GitHub's private vulnerability reporting:

1. Open this repository on GitHub.
2. Select the **Security** tab.
3. Select **Report a vulnerability**.
4. Fill in the form and submit it. Only you, the maintainers and anyone a maintainer adds to the
   advisory can see the report.

**Please do not open a public issue, discussion or pull request for a security problem**, and do not
share details anywhere else until a fix is released. GitHub is the only reporting channel; the
project publishes no email address. If the **Report a vulnerability** button is missing, open a public
issue titled "Security contact request" with no details, and a maintainer will arrange a private
channel.

The same form also takes private code of conduct reports; see
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## What to include

- What is affected: an engine crate, the app, the command line tool, the build or release process, a
  dependency, or the bundled PDFium.
- The version or commit, and your operating system with its version.
- What an attacker can do, and what they need first (for example, the victim opens a crafted PDF).
- Steps to reproduce. If a PDF triggers the problem, attach a minimal crafted file, not a real
  document that contains personal data.
- Any crash output, logs or stack traces.
- Whether the problem is already public, and how you would like to be credited.

## Scope

In scope:

- **Malicious or malformed PDFs** that make Ferman crash, hang or use memory without limit.
- **Memory safety issues**, for example in `unsafe` Rust, at the boundary between the engine and the
  app, or in the PDFium build that Ferman ships.
- **Code execution** of any kind. Ferman never runs document JavaScript (confirmed by the maintainer
  in [Q13](docs/QUESTIONS.md#q13)) and never runs launch actions, so any way to make it do so is in
  scope.
- **File corruption on save**: anything that makes Ferman damage or lose a user's file, change bytes
  it should have kept in an incremental save, or leave a partly written file in place of the original.
- **Privacy leaks**, such as unexpected network access: any connection that Settings → Privacy does
  not list, or one made while its switch is off; document content leaving the device, beyond what
  the optional AI assistant sends to the provider you chose, as its setup says; passwords written to
  logs or to disk.
- **Signature validation flaws**: a changed document shown as validly signed, changes after signing
  that go undetected, or a missing warning before an edit invalidates a signature.
- **Redaction and hidden-information removal**, once they exist: content that can still be recovered
  after Ferman says it is gone.
- **The update mechanism and release packages**, once they exist: tampered, downgraded or unsigned
  updates being accepted.

Out of scope:

- Problems that exist only in a build someone has modified, or in unofficial packages built from
  modified source.
- Social engineering of users or maintainers, including phishing.
- Attacks that need control of the device or the user's account already.
- Features drawn in the design but not built yet.

If you find a vulnerability in a dependency, please report it to that project as well. Tell us too
if Ferman ships an affected version.

The design behind these rules is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#9-security):
resource limits for untrusted PDFs, fuzzing of every parser, pinned and hash-checked PDFium binaries,
and one network gateway ([section 10](docs/ARCHITECTURE.md#10-privacy-and-network-gateway)).

## Response targets

These are targets, not guarantees. Ferman is a small open-source project.

| Step | Target |
|---|---|
| Acknowledge your report | within 5 working days |
| First assessment: whether we can reproduce it, how severe it is, and the plan | within 14 days |
| Progress updates | at least at every change of plan, until the issue is closed |

## Coordinated disclosure

- We confirm the problem, prepare a fix in a private security advisory and agree a disclosure date
  with you.
- By default we publish the advisory when a fixed release is available. We aim for that within 90
  days of your report. If we need longer, we tell you why and agree a new date.
- We credit you in the advisory unless you prefer not to be named.
- We request a CVE identifier through GitHub when the issue warrants one.

## No telemetry

Ferman has no telemetry, no analytics and no crash reporting service. We never see crashes or failures
on anyone's machine. Reports like yours are our only signal.

## Safe harbour

If you research Ferman in good faith and follow this policy, testing only your own installation with
your own files, respecting other people's data and privacy, and giving us a reasonable chance to fix
the problem before you disclose it, we will not pursue or support legal action against you.
