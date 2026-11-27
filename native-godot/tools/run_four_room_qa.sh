#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
engine="${GODOT_BIN:-godot}"
work="$(mktemp -d)"
logdir="$project/out/online/four"
client_script="online_four_room_qa.gd"
if [ "${AURORA_TERRAIN_QA:-0}" = 1 ]; then
  logdir="$project/out/online/terrain"
  client_script="online_terrain_room_qa.gd"
  export AURORA_ONLINE_TERRAIN_COMBAT=1
fi
mkdir -p "$logdir" "$work/server"
pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done
  rm -rf "$work"
}
trap cleanup EXIT
AURORA_ONLINE_FOUR_COMBAT=1 XDG_DATA_HOME="$work/server" "$engine" --headless --path "$project" --script res://scripts/network/dedicated_server.gd >"$logdir/server.log" 2>&1 &
server=$!; pids+=("$server")
for i in $(seq 1 120); do
  kill -0 "$server" 2>/dev/null || { cat "$logdir/server.log"; exit 1; }
  if grep -q 'AURORA_ONLINE READY' "$logdir/server.log"; then break; fi
  sleep .5
done
grep -F 'AURORA_ONLINE READY' "$logdir/server.log"
clients=()
for i in 0 1 2 3; do
  mkdir -p "$work/client$i"
  XDG_DATA_HOME="$work/client$i" timeout 90 "$engine" --headless --path "$project" --script "res://scripts/network/$client_script" >"$logdir/client$i.log" 2>&1 &
  clients+=("$!"); pids+=("$!")
done
status=0
for pid in "${clients[@]}"; do wait "$pid" || status=1; done
cat "$logdir/"*.log
test "$status" -eq 0
if [ "${AURORA_TERRAIN_QA:-0}" = 1 ]; then
  for i in 0 1 2 3; do grep -F 'V75243_TERRAIN PASS' "$logdir/client$i.log"; done
  grep -F 'V75243_TERRAIN_READY humans=4' "$logdir/server.log"
  grep -F 'V75243_ZONE_HIT slot=0' "$logdir/server.log"
else
  for i in 0 1 2 3; do grep -F 'V75242_FOUR PASS' "$logdir/client$i.log"; done
  grep -F 'V75242_ELIMINATION' "$logdir/server.log"
  grep -F 'V75242_DEATH_CLAIM' "$logdir/server.log"
fi
grep -F 'live_humans=4' "$logdir/server.log"
if grep -E 'SCRIPT ERROR|ERROR: Failed to load script' "$logdir/"*.log; then exit 1; fi
