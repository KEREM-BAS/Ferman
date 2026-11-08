# ADR 0019: AI clients through a local MCP server

- **Status:** Accepted (owner, 2026-10-16): the direction, then the details below as written.
- **Date:** 2026-10-16
- **Approval:** the owner, in the M1 session on 2026-10-16 ([Q20](../QUESTIONS.md#q20)): "after M3,
  with the Ferman app open, local; Settings gives a connection link for Claude, ChatGPT and whatever
  else we can support, or opens it already set up; ask while building it if something comes up."
  The details below were approved as written on 2026-10-16, with the other Proposed items of M1.
  On 2026-11-06 the owner changed them with question 1 of the [M4 plan](../PROGRESS.md#m4-plan), as
  this ADR asks when the step's plan needs it.
- **Supersedes:** none
- **Superseded by:** none

## Context

The owner wants AI assistants such as Claude and ChatGPT to work on the documents open in Ferman,
using everything the app supports, through the Model Context Protocol (MCP). MCP lets an AI client
call tools that an application offers.

What the brief fixes and what this must respect:

- The UI never touches PDF internals; it calls only `ferman-api`: open and close, page info, tile
  rendering, text blocks, edit transactions (begin, apply, commit, rollback, which give engine-level
  undo and redo) and jobs (brief §3, [ADR 0003](0003-crate-layout-and-api-boundary.md)). `ferman-cli`
  already calls the same facade.
- Never corrupt a user's file: save through a temporary file and an atomic rename, incremental update
  by default ([ADR 0008](0008-file-safety-and-saving.md)).
- No telemetry, and the network is used for four things only, one of them optional AI (a local model
  or the user's own key), all listed in Settings → Privacy (brief §3,
  [ADR 0015](0015-privacy-and-network.md)). Documents never leave the device unless the user sends
  them.
- Document JavaScript is never executed ([Q13](../QUESTIONS.md#q13)).
- Editing existing text arrives in M3 and the page, comment, form and signature operations in M4
  ([ROADMAP.md](../ROADMAP.md)). Before M3 there is little for an AI client to do.

No board draws this ([G94](../DESIGN_GAPS.md#g94)). The design draws Ferman's own AI assistant
(a10-1 to a10-2b, a11-1g, P4), which is a different thing: there Ferman calls a model itself.

## Decision

1. **Ferman offers a local MCP server for AI clients, built after M3** (M4 step 11 in
   [ROADMAP.md](../ROADMAP.md#8-m4-rest-of-phase-1)).
2. **It works with the running app.** The client's actions go through the same `ferman-api` facade
   and the same document sessions as the UI, on the documents open in Ferman. Every change is an
   edit transaction: it shows on the page at once, appears in the edit review list and can be undone
   like any other edit. The rules of the UI apply unchanged: block-scoped text edits, the missing-glyph
   policy (never substitute silently, [ADR 0006](0006-font-pipeline-and-missing-glyphs.md)), the
   warning before editing a signed document, atomic saves. Document JavaScript is never run.
3. **Off by default, set up from Settings.** Settings lists the AI clients Ferman supports (Claude,
   ChatGPT and any other client that speaks MCP and can reach a local server), each with a connection
   link or a one-click setup that writes the client's configuration so it opens already connected,
   and a switch that stops the server. Settings → Privacy lists the connected clients: what a client
   reads, it sends to its own provider under the user's account, which is the brief's optional AI.
4. **Nothing listens on the network.** The server is reachable only from the same computer, only
   while Ferman runs and the switch is on.
5. **Out of scope:** Ferman calling AI providers itself (the P4 assistant), access from another
   computer, and AI actions on files that are not open in Ferman.

**Approved by the owner on 2026-10-16**, with the other Proposed items of M1, and **amended on
2026-11-06** (question 1 of the M4 plan, a to f); anything else that changes when the step starts
goes back to the owner:

- **Transport and pairing.** Clients such as Claude Desktop start a local server as a process and talk
  to it over standard input and output, and install packaged extensions in one click. Every desktop
  bundle ships that process as a tiny byte pump named `ferman-mcp`, with no PDF code, signed in M5,
  because the CLI is not bundled and its name clashes with the app's binary (b). It connects to the
  running app over a local socket (a Unix domain socket on macOS and Linux, a named pipe on Windows)
  and proves itself with a per-install token that only the user's account can read.
- **ChatGPT (e).** Local clients only in M4. Clients that reach MCP servers only over HTTPS from the
  vendor's cloud (ChatGPT's connectors, as far as known on 2026-10-16) cannot reach a local server,
  and Settings says so. No tunnel and no port.
- **The macOS sandbox (f).** The socket is tried under the sandbox first. If a client cannot reach it,
  Settings shows a copyable configuration instead of one-click setup, and the sandbox stays.
- **Permissions (c).** Read and edit are granted per client, read only by default, on the whole
  document. Enforced in `ferman-api`, never left to the client.
- **Signed documents (d).** A client's first commit on a signed document always asks the user, even if
  the user already confirmed for their own edits.
- **Tools.** The first set: list open documents and pages, read text blocks and page images, search,
  and the edit transaction (begin, apply, commit, rollback); then each M3 and M4 operation as a tool
  (organize, comments, forms, signatures, compress). Saving: a client may save only
  after the user confirms in Ferman, and never with "optimize and clean".
- **Code (a).** A crate `ferman-mcp` on top of `ferman-api` cannot be hosted by the app: `frb` lives
  inside ferman-api, so the crates would form a cycle. The server logic is a module `facade::mcp`
  behind a feature that is off for the CLI and the web, the app hosts the socket and `ferman-mcp`
  pumps the bytes. This brings tokio into the engine for this feature alone, the shown need
  [ADR 0009](0009-threading-and-jobs.md) asks for. The MCP SDK is the official Rust SDK (`rmcp`) if its
  licence passes [ADR 0016](0016-dependency-licence-policy.md), otherwise a small JSON-RPC layer of our
  own. A trial resolve passed the licences with 82 packages and no HTTP client (M4 plan, decision 37);
  the newest release was a day old, so an older one is pinned and `cargo deny` runs when W7 starts.
  **Built in W7:** rmcp 3.8.0 and tokio passed `cargo deny`, so rmcp it is, behind the feature `mcp`
  of ferman-api. The engine's side needs no runtime and is always built (`facade::clients`): a
  client connects by the name its `initialize` handshake gives, read only until granted edit; its
  edit transactions are owned by it, one open per document as for the user, so it waits while
  another is open and has its own rolled back when it disconnects; each step it commits names it
  in the history (`HistoryStep::client`) and in the engine's own log, and reaches the app through a
  change stream. The recovery journal holds objects only and restores unsaved changes as one step
  without names, so it does not record the client.
  The host (`facade::mcp`, started and stopped by the app, off by default) listens in the `mcp`
  folder of the app data directory: a Unix domain socket in a 0700 folder, itself 0600, on macOS
  and Linux, and on Windows a named pipe with a random part in its name that refuses remote
  callers, its name in the folder's `pipe` file. The token is a 0600 file in the same folder,
  new each time the host starts; a connection whose first line is not the token is closed.
  `ferman-mcp <folder>` (crate `ferman-mcp`, tokio only) sends the token, then pumps bytes until
  the app closes, and says that Ferman is not running (status 1) when it cannot connect; the
  Linux and Windows CMake builds and a Runner build phase on macOS (universal, signed ad hoc until
  M5) put it beside the executable. The tools read the open documents (pages, bookmarks,
  attachments, information, text blocks, search, comments, form fields, links, history,
  versions) under read permission, and with edit permission run the M3 text edit and each M4
  operation through the facade's own calls, run for the client so its step names it and a signed
  document asks for its own confirmation (organize pages, comments and replies, flatten, links,
  form fill and clear, bookmarks, metadata, attachments, compress, extract, split, combine, a
  simple signature). What the UI would confirm becomes a request the app answers: the client's
  first change to a signed document, writing or reading a file at a path the client names,
  placing a signature, and saving or restoring a version, which the app then does in its own
  flow. The macOS sandbox is kept and the socket lives in the container; whether a client outside
  the sandbox reaches it is an owner check on a real Mac.
- **What the user sees.** A notice in the window while a client is connected, the client's name on
  each of its edits in the review list, and a way to stop it from the window as well as from
  Settings.
  **Built in W7 ([G94](../DESIGN_GAPS.md#g94)):** Settings › AI clients ("Let AI clients connect",
  off by default and stored; an imported settings file never turns it on) starts and stops the
  host; each connected client is listed read only until "Can change documents" is turned on for
  that connection; Claude Desktop is set up in one click outside the macOS sandbox and on Windows,
  otherwise the configuration is copied. Settings › Privacy has the row "AI clients on this
  computer" with the same switch. The window notice names the connected clients with Stop. The app
  reads `mcp_clients` every 2 s while the host runs (the engine sends no connect or disconnect
  event, [B230](../BACKLOG.md#open)), routes `client_changes` through
  `DocumentEditor.clientChanged` so a client's step reaches the pages, the tab, the history and the
  review list and undoes as the person's own, and answers a client's Save or RestoreVersion request
  only after its own save or restore flow has finished.

## Consequences

### Positive

- AI clients can use every feature Ferman has, through the facade the UI already uses, with the same
  undo, review and file safety.
- Users choose their own assistant and account; Ferman sends nothing itself and stays free of
  provider code and keys.

### Negative

- Document content leaves the device through the connected client. The switch is off by default,
  Privacy lists every connected client, and the window shows when one is connected.
- A local socket is an attack surface: any program running as the user could try to connect. The
  per-install token and the switch limit it; the server takes no request while the switch is off.
- MCP and its clients change quickly, and support differs between clients (local process, packaged
  extension, remote connector). The supported list in Settings follows what works when the step is
  built.

### Follow-up

- [Q20](../QUESTIONS.md#q20): the details above were approved on 2026-10-16 and amended on 2026-11-06;
  further changes go back to the owner when M4 W7 starts.
- [G94](../DESIGN_GAPS.md#g94): the Settings section and the connected notice need a board, or are
  built from the existing components and recorded.
- [DEPENDENCIES.md](../DEPENDENCIES.md): the MCP SDK, licence-checked, in the same change that adds it.
- **The permission model** (the owner's suggestion of 2026-11-01,
  [ROADMAP §14](../ROADMAP.md#ideas-to-weigh-later)) was decided on 2026-11-06 as (c) above. Still
  ideas for later: comment as a grant of its own; grants per document; page ranges; parts the client
  may not change (form fields named by the user, areas the user locks). Two limits to keep in mind:
  - Permissions narrow what injected instructions in a document's text can make a client do, but do
    not stop prompt injection: a client allowed to read can still be misled, and what it reads goes
    to its provider. The edit review, undo and the visible connection stay needed with them.
  - A signed document is not protected by locking the visible signature area. The engine applies
    the document's own rules: what each signature covers (its byte range and any later incremental
    updates), a certification signature's allowed changes (DocMDP `/P`) and field locks (`/Lock`,
    FieldMDP), and the same warning before editing a signed document as the UI.
- [ADR 0015](0015-privacy-and-network.md) and Settings → Privacy: list connected AI clients with the
  other network uses. Done in W7 (the Privacy row); the network activity log lists the server's
  local connections when it ships ([B084](../BACKLOG.md#open), M5).

## Alternatives considered

- **A server that works on files without the app** (like the CLI). Simpler, but the owner wants the
  edits in the open app, visible and undoable as the user watches. A file-only mode can still come
  later from the same crate.
- **Ferman calling AI providers itself.** That is the P4 assistant (a10-1 to a10-2b) with a local
  model or the user's own key; it does not let the user bring the assistant they already use.
- **No AI integration in phase 1.** The owner asked for it after M3.

## References

- [Brief](../BRIEF.md) §3 (architecture, privacy, network uses), §4 (text editing), §7 (roadmap)
- [ADR 0003](0003-crate-layout-and-api-boundary.md), [ADR 0006](0006-font-pipeline-and-missing-glyphs.md),
  [ADR 0008](0008-file-safety-and-saving.md), [ADR 0015](0015-privacy-and-network.md),
  [ADR 0016](0016-dependency-licence-policy.md)
- [Q13](../QUESTIONS.md#q13), [Q20](../QUESTIONS.md#q20), [G94](../DESIGN_GAPS.md#g94)
- Model Context Protocol specification: modelcontextprotocol.io
