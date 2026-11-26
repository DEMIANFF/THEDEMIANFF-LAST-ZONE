#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
engine="${GODOT_BIN:-godot}"
work="$(mktemp -d)"
logdir="$project/out/online/dual"
client_script="online_dual_waiting_qa.gd"
if [ "${AURORA_ONLINE_DUAL_COMBAT:-0}" = 1 ]; then
  logdir="$project/out/online/duel"
  client_script="online_duel_qa.gd"
fi
if [ "${AURORA_ONLINE_DUAL_LOOT:-0}" = 1 ]; then
  logdir="$project/out/online/dual_loot"
  client_script="online_dual_loot_qa.gd"
fi
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
AURORA_DUAL_QA_ROLE=first XDG_DATA_HOME="$work/first" timeout 45 "$engine" --headless --path "$project" --script "res://scripts/network/$client_script" >"$logdir/first.log" 2>&1 &
first=$!; pids+=("$first")
AURORA_DUAL_QA_ROLE=second XDG_DATA_HOME="$work/second" timeout 45 "$engine" --headless --path "$project" --script "res://scripts/network/$client_script" >"$logdir/second.log" 2>&1 &
second=$!; pids+=("$second")
status=0
wait "$first" || status=1
wait "$second" || status=1
cat "$logdir/server.log" "$logdir/first.log" "$logdir/second.log"
test "$status" -eq 0
if [ "${AURORA_ONLINE_DUAL_LOOT:-0}" = 1 ]; then
  grep -F 'V75240_LOOT PASS' "$logdir/first.log"
  grep -F 'V75240_LOOT PASS' "$logdir/second.log"
  test "$(grep -c 'V75240_SERVER_CLAIM kind=ammo_ar' "$logdir/server.log")" -eq 1
  test "$(grep -c 'V75240_SERVER_CLAIM kind=medkit' "$logdir/server.log")" -eq 2
  grep -F 'total=3' "$logdir/server.log"
elif [ "${AURORA_ONLINE_DUAL_COMBAT:-0}" = 1 ]; then
  grep -F 'V75238_DUEL PASS' "$logdir/first.log"
  grep -F 'V75238_DUEL PASS' "$logdir/second.log"
  grep -F 'V75238_SERVER_ELIMINATION' "$logdir/server.log"
else
  grep -F 'V75237_DUAL PASS' "$logdir/first.log"
  grep -F 'V75237_DUAL PASS' "$logdir/second.log"
  grep -F 'V75237_DISCONNECT removed=true' "$logdir/second.log"
fi
grep -F 'live_humans=2' "$logdir/server.log"
if grep -E 'SCRIPT ERROR|ERROR: Failed to load script' "$logdir/"*.log; then exit 1; fi
