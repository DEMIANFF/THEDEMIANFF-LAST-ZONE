#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
engine="${GODOT_BIN:-godot}"
work="$(mktemp -d)"
logdir="$project/out/online/dual"
mkdir -p "$logdir" "$work/server" "$work/first" "$work/second"
pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done
  rm -rf "$work"
}
trap cleanup EXIT
AURORA_ONLINE_DUAL_WAITING=1 XDG_DATA_HOME="$work/server" "$engine" --headless --path "$project" --script res://scripts/network/dedicated_server.gd >"$logdir/server.log" 2>&1 &
server=$!; pids+=("$server")
for i in $(seq 1 120); do
  kill -0 "$server" 2>/dev/null || { cat "$logdir/server.log"; exit 1; }
  if grep -q 'AURORA_ONLINE READY' "$logdir/server.log"; then break; fi
  sleep .5
done
grep -F 'AURORA_ONLINE READY' "$logdir/server.log"
AURORA_DUAL_QA_ROLE=first XDG_DATA_HOME="$work/first" timeout 45 "$engine" --headless --path "$project" --script res://scripts/network/online_dual_waiting_qa.gd >"$logdir/first.log" 2>&1 &
first=$!; pids+=("$first")
AURORA_DUAL_QA_ROLE=second XDG_DATA_HOME="$work/second" timeout 45 "$engine" --headless --path "$project" --script res://scripts/network/online_dual_waiting_qa.gd >"$logdir/second.log" 2>&1 &
second=$!; pids+=("$second")
status=0
wait "$first" || status=1
wait "$second" || status=1
cat "$logdir/server.log" "$logdir/first.log" "$logdir/second.log"
test "$status" -eq 0
grep -F 'V75237_DUAL PASS' "$logdir/first.log"
grep -F 'V75237_DUAL PASS' "$logdir/second.log"
grep -F 'V75237_DISCONNECT removed=true' "$logdir/second.log"
grep -F 'live_humans=2' "$logdir/server.log"
if grep -E 'SCRIPT ERROR|ERROR: Failed to load script' "$logdir/"*.log; then exit 1; fi
