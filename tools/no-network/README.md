# no-network

The no-network run of [ADR 0015](../../docs/adr/0015-privacy-and-network.md), as question 9 of the
[M4 plan](../../docs/PROGRESS.md#m4-plan) decided in place of strace (closed on 2026-11-06). CI's
`no-network` job runs it on Linux; it needs network namespaces and sudo without a password, so it is
not meant for a developer machine.

```sh
tools/no-network/run.sh xvfb-run -a flutter test integration_test -d linux --no-pub \
  --plain-name 'the built app starts with its own title bar'
```

`run.sh` creates the namespace `ferman-offline` with loopback and a `dummy0` interface that holds
the default route, points the namespace's `resolv.conf` at a documentation address so a name lookup
leaves as a DNS packet, starts tcpdump on every interface of the namespace, sends one probe packet
that proves the capture works, and runs the command there as the calling user. It fails when the
probe is missing from the capture or when any other packet is not loopback, and prints those
packets. The capture and tcpdump's log go to `$FERMAN_NO_NETWORK_OUT` (default `build/no-network`);
CI uploads them.

The command is the integration test's first test, which starts the app and walks every screen:
first run or the start screen, each Settings pane, and the editor with kira-tr in every mode and
with every sidebar tab (`_walkEveryScreen` in `app/integration_test/app_test.dart`). The job builds
first, outside the namespace, so cargo, rustup and cargokit's tool have what they need; inside,
`CARGO_NET_OFFLINE` keeps cargo off the network.

Limits:

- Loopback is not judged: `flutter test` talks to the app over it. The MCP host speaks over a Unix
  socket and is off by default; `crates/ferman-api/tests/mcp.rs` checks that nothing listens on
  TCP.
- IPv6 is off outside loopback in the namespace, so an IPv6 address literal would fail without a
  packet; every name lookup goes through the IPv4 server and is caught.
- The walk opens no dialogs or menus and shows only first run's first step.

tcpdump (BSD-3-Clause, a few files with the 4-clause BSD text) and libpcap (BSD-3-Clause) are CI
tools, never shipped; the job checks the licence of every package their install adds
([DEPENDENCIES.md](../../docs/DEPENDENCIES.md)).
