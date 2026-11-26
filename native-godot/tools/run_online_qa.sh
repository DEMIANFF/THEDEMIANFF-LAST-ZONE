#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
engine="${GODOT_BIN:-godot}"
work="$(mktemp -d)"
pid=""
cleanup() {
  if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/server" "$work/client"
logdir="${AURORA_ONLINE_LOG_DIR:-$project/out/online}"
mkdir -p "$logdir"
AURORA_ONLINE_QA_FIXTURE=1 XDG_DATA_HOME="$work/server" "$engine" --headless --path "$project" --script res://scripts/network/dedicated_server.gd >"$logdir/server.log" 2>&1 &
pid=$!
for i in $(seq 1 120); do
  kill -0 "$pid" 2>/dev/null || { cat "$logdir/server.log"; exit 1; }
  if grep -q 'AURORA_ONLINE READY' "$logdir/server.log"; then break; fi
  sleep .5
done
grep -F 'AURORA_ONLINE READY' "$logdir/server.log"
if ! XDG_DATA_HOME="$work/client" timeout 60 "$engine" --headless --path "$project" --script res://scripts/network/online_client_qa.gd >"$logdir/client.log" 2>&1; then
  cat "$logdir/server.log" "$logdir/client.log"; exit 1
fi
cat "$logdir/client.log"
grep -F 'V75221_ONLINE PASS' "$logdir/client.log"
grep -F 'AURORA_ONLINE MATCH' "$logdir/server.log"
if grep -E 'SCRIPT ERROR|ERROR: Failed to load script' "$logdir/server.log" "$logdir/client.log"; then exit 1; fi
