#!/usr/bin/env bash
# The no-network run (question 9 of the M4 plan, ADR 0015): runs a command, in CI the app's
# integration test that walks every screen, inside a Linux network namespace whose only way out
# is a dummy default route, while tcpdump records every packet in the namespace. It fails when
# any packet is not loopback. Linux only, with sudo that needs no password (a CI runner); never
# run it on a developer machine. The MCP host speaks over a Unix socket and is off by default;
# crates/ferman-api/tests/mcp.rs checks that it never listens on TCP.
#
# Usage: tools/no-network/run.sh <command> [<argument>...]
# Writes capture.pcap and tcpdump.log to $FERMAN_NO_NETWORK_OUT (default build/no-network).
set -euo pipefail

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 64
}
[ $# -gt 0 ] || usage
if [ "$(uname -s)" != Linux ]; then
  echo "error: the no-network run needs Linux network namespaces" >&2
  exit 64
fi

ns=ferman-offline
# A documentation address (RFC 5737) the run sends one probe to, which proves the capture works.
probe=198.51.100.9
out="${FERMAN_NO_NETWORK_OUT:-build/no-network}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
# Ubuntu's AppArmor profile lets tcpdump write files named *.pcap.
pcap="$out/capture.pcap"
log="$out/tcpdump.log"
rm -f "$pcap" "$log"

tcpdump_pid=
# Stops what is left in the namespace, tcpdump among it, with SIGINT so tcpdump flushes the file.
stop_namespace() {
  sudo ip netns pids "$ns" 2>/dev/null | xargs -r sudo kill -INT 2>/dev/null || true
  if [ -n "$tcpdump_pid" ]; then
    wait "$tcpdump_pid" 2>/dev/null || true
    tcpdump_pid=
  fi
}
cleanup() {
  stop_namespace
  sudo ip netns delete "$ns" 2>/dev/null || true
  sudo rm -rf "/etc/netns/$ns"
}
trap cleanup EXIT

sudo ip netns add "$ns"
in_ns() { sudo ip netns exec "$ns" "$@"; }
in_ns ip link set lo up
# shortcut: IPv6 is off outside loopback, so an IPv6 address literal fails without a packet;
# names still resolve through the IPv4 server below, so their lookup is caught. Give dummy0 an
# IPv6 route too if a feature ever dials IPv6 literals (its own neighbour discovery must be
# filtered out then).
in_ns sysctl -q -w net.ipv6.conf.default.disable_ipv6=1
in_ns ip link add dummy0 type dummy
in_ns ip addr add 192.0.2.1/24 dev dummy0
in_ns ip link set dummy0 up
in_ns ip route add default dev dummy0
# ip netns exec mounts /etc/netns/<ns>/resolv.conf over /etc/resolv.conf, so a name lookup leaves
# as a DNS packet instead of reaching the host's resolver on loopback.
sudo mkdir -p "/etc/netns/$ns"
echo "nameserver 198.51.100.53" | sudo tee "/etc/netns/$ns/resolv.conf" >/dev/null

# -Z root: tcpdump keeps writing as root rather than as its own user.
sudo ip netns exec "$ns" tcpdump -i any -n -U -Z root -w "$pcap" 2>"$log" &
tcpdump_pid=$!
for _ in $(seq 50); do
  grep -q 'listening on' "$log" 2>/dev/null && break
  sleep 0.2
done
if ! grep -q 'listening on' "$log"; then
  cat "$log" >&2
  echo "error: tcpdump did not start" >&2
  exit 1
fi
in_ns bash -c "echo probe > /dev/udp/$probe/9" || true

status=0
# The command runs as the calling user with their environment, inside the namespace.
sudo -E ip netns exec "$ns" sudo -E -u "$(id -un)" env "PATH=$PATH" "HOME=$HOME" "$@" || status=$?

sleep 1
stop_namespace
cat "$log"

if [ -z "$(sudo tcpdump -n -r "$pcap" "udp and dst host $probe" 2>/dev/null)" ]; then
  echo "::error::The capture missed the probe to $probe: the run proves nothing"
  exit 1
fi
leaks="$(sudo tcpdump -n -r "$pcap" "not (net 127.0.0.0/8 or ip6 host ::1 or host $probe)" 2>/dev/null)"
loopback="$(sudo tcpdump -n -r "$pcap" "net 127.0.0.0/8 or ip6 host ::1" 2>/dev/null | wc -l)"
echo "Loopback packets: $loopback (not judged: the test tool talks to the app over loopback)"
if [ -n "$leaks" ]; then
  echo "::error::Packets left loopback during the run:"
  printf '%s\n' "$leaks" | head -n 100
  exit 1
fi
echo "No packet left loopback."
if [ "$status" -ne 0 ]; then
  echo "::error::The command failed with status $status"
fi
exit "$status"
