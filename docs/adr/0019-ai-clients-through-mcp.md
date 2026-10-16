# ADR 0019: AI clients through a local MCP server

- **Status:** Accepted (owner, 2026-10-16): the direction. The details marked **Proposed** below are
  settled with the owner when the work starts.
- **Date:** 2026-10-16
- **Approval:** the owner, in the M1 session on 2026-10-16 ([Q20](../QUESTIONS.md#q20)): "after M3,
  with the Ferman app open, local; Settings gives a connection link for Claude, ChatGPT and whatever
  else we can support, or opens it already set up; ask while building it if something comes up."
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

**Proposed** (settled with the owner when the step starts):

- **Transport and pairing.** Clients such as Claude Desktop start a local server as a process and talk
  to it over standard input and output, and install packaged extensions in one click. Ferman ships
  that process as a command of the CLI (`ferman mcp`), which connects to the running app over a local
  socket (a Unix domain socket on macOS and Linux, a named pipe on Windows) and proves itself with a
  per-install token that only the user's account can read. Clients that reach MCP servers only over
  HTTPS from the vendor's cloud (ChatGPT's connectors, as far as known on 2026-10-16) cannot reach a
  local server without a public endpoint or a tunnel; whether and how to support them is decided then,
  never by opening a port silently.
- **Tools.** The first set: list open documents and pages, read text blocks and page images, search,
  and the edit transaction (begin, apply, commit, rollback); then each M3 and M4 operation as a tool
  (organize, comments, forms, signatures, compress). Saving: proposed that a client may save only
  after the user confirms in Ferman, and never with "optimize and clean".
- **Code.** The server logic lives in a new crate `ferman-mcp` on top of `ferman-api`; the app hosts
  the socket and the CLI hosts the stdio side. The MCP SDK is the official Rust SDK (`rmcp`) if its
  licence passes [ADR 0016](0016-dependency-licence-policy.md), otherwise a small JSON-RPC layer of
  our own.
- **What the user sees.** A notice in the window while a client is connected, the client's name on
  each of its edits in the review list, and a way to stop it from the window as well as from
  Settings.

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

- [Q20](../QUESTIONS.md#q20): the Proposed details above, with the owner, when M4 step 11 starts.
- [G94](../DESIGN_GAPS.md#g94): the Settings section and the connected notice need a board, or are
  built from the existing components and recorded.
- [DEPENDENCIES.md](../DEPENDENCIES.md): the MCP SDK, licence-checked, in the same change that adds it.
- [ADR 0015](0015-privacy-and-network.md) and Settings → Privacy: list connected AI clients with the
  other network uses.

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
