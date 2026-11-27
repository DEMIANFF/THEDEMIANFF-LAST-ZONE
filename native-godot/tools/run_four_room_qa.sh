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
if [ "${AURORA_MIXED_QA:-0}" = 1 ]; then
  logdir="$project/out/online/mixed"
  client_script="online_mixed_room_qa.gd"
  export AURORA_ONLINE_MIXED_COMBAT=1
fi
if [ "${AURORA_MIXED_LOOT_QA:-0}" = 1 ]; then
  logdir="$project/out/online/mixed_loot"
  client_script="online_mixed_loot_qa.gd"
  export AURORA_ONLINE_MIXED_COMBAT=1
fi
if [ "${AURORA_MIXED_FLIGHT_QA:-0}" = 1 ]; then
  logdir="$project/out/online/mixed_flight"
  client_script="online_mixed_flight_qa.gd"
  export AURORA_ONLINE_MIXED_FLIGHT=1
fi
if [ "${AURORA_ONLINE_CATALOG_QA:-0}" = 1 ]; then
  logdir="$project/out/online/catalog"
  client_script="online_catalog_room_qa.gd"
fi
if [ "${AURORA_ONLINE_TACTICAL_QA:-0}" = 1 ]; then
  logdir="$project/out/online/tactical"
  client_script="online_tactical_room_qa.gd"
fi
if [ "${AURORA_FLEX_QA:-0}" = 1 ]; then
  logdir="$project/out/online/flexible"
  client_script="online_flexible_room_qa.gd"
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
slots="0 1 2 3"
if [ "${AURORA_FLEX_QA:-0}" = 1 ]; then slots="0 1"; fi
for i in $slots; do
  mkdir -p "$work/client$i"
  XDG_DATA_HOME="$work/client$i" timeout 90 "$engine" --headless --path "$project" --script "res://scripts/network/$client_script" >"$logdir/client$i.log" 2>&1 &
  clients+=("$!"); pids+=("$!")
done
if [ "${AURORA_FLEX_QA:-0}" = 1 ]; then
  for i in $(seq 1 100); do
    if grep -q 'V75250_SEALED humans=2 bots=48 total=50' "$logdir/server.log"; then break; fi
    sleep .2
  done
  grep -F 'V75250_SEALED humans=2 bots=48 total=50' "$logdir/server.log"
  mkdir -p "$work/late"
  AURORA_FLEX_LATE=1 XDG_DATA_HOME="$work/late" timeout 25 "$engine" --headless --path "$project" --script "res://scripts/network/$client_script" >"$logdir/late.log" 2>&1 &
  clients+=("$!"); pids+=("$!")
fi
status=0
for pid in "${clients[@]}"; do wait "$pid" || status=1; done
cat "$logdir/"*.log
test "$status" -eq 0
if [ "${AURORA_FLEX_QA:-0}" = 1 ]; then
  for i in 0 1; do grep -F 'V75250_FLEX PASS' "$logdir/client$i.log"; done
  grep -F 'V75250_LATE PASS' "$logdir/late.log"
  grep -F 'V75250_LATE_DENIED' "$logdir/server.log"
  grep -F 'V75244_MIXED_READY humans=2 physical_bots=48 total=50' "$logdir/server.log"
  grep -F 'V75246_GROUND humans=2 bots_landed=48 total=50' "$logdir/server.log"
elif [ "${AURORA_ONLINE_TACTICAL_QA:-0}" = 1 ]; then
  for i in 0 1 2 3; do grep -F 'V75249_TACTICAL PASS' "$logdir/client$i.log"; done
  grep -F 'V75249_THROW slot=0 remaining=0' "$logdir/server.log"
  grep -F 'V75249_WALL slot=0 remaining=0' "$logdir/server.log"
  grep -F 'V75249_BLAST seq=1' "$logdir/server.log"
elif [ "${AURORA_ONLINE_CATALOG_QA:-0}" = 1 ]; then
  for i in 0 1 2 3; do grep -F 'V75248_CATALOG PASS' "$logdir/client$i.log"; done
  for slot in 2 3 6; do grep -F "V75248_SWITCH slot=0 weapon=$slot " "$logdir/server.log"; done
elif [ "${AURORA_MIXED_FLIGHT_QA:-0}" = 1 ]; then
  for i in 0 1 2 3; do grep -F 'V75246_FLIGHT PASS' "$logdir/client$i.log"; done
  grep -F 'V75246_DEPART humans=4 bots=46' "$logdir/server.log"
  grep -F 'V75246_GROUND humans=4 bots_landed=46 total=50' "$logdir/server.log"
  grep -F 'V75247_EARLY_SHOT slot=0' "$logdir/server.log"
  grep -F 'V75247_EARLY_PICKUP slot=0 kind=ammo_ar' "$logdir/server.log"
  grep -F 'V75247_INDIVIDUAL slot=0 early_fire=true early_pickup=true air_safe=true shared_early=true' "$logdir/"client*.log
  for slot in 0 1 2 3; do
    grep -F "V75246_JUMP slot=$slot " "$logdir/server.log"
    grep -F "V75246_CANOPY slot=$slot" "$logdir/server.log"
    grep -F "V75246_LAND slot=$slot " "$logdir/server.log"
  done
elif [ "${AURORA_MIXED_LOOT_QA:-0}" = 1 ]; then
  for i in 0 1 2 3; do grep -F 'V75245_BOT_LOOT PASS' "$logdir/client$i.log"; done
  grep -F 'V75244_MIXED_READY humans=4 physical_bots=46 total=50' "$logdir/server.log"
  grep -E 'V75245_BOT_DROP kind=ammo_ar .*human_kill=true' "$logdir/server.log"
  grep -E 'V75245_BOT_CLAIM .*slot=1 kind=ammo_ar .*rounds_granted=[1-9]' "$logdir/server.log"
elif [ "${AURORA_MIXED_QA:-0}" = 1 ]; then
  for i in 0 1 2 3; do grep -F 'V75244_MIXED PASS' "$logdir/client$i.log"; done
  grep -F 'V75244_MIXED_READY humans=4 physical_bots=46 total=50' "$logdir/server.log"
  grep -F 'V75244_BOT_HUMAN' "$logdir/server.log"
  grep -F 'V75244_HUMAN_BOT' "$logdir/server.log"
  grep -F 'V75245_DISCONNECT_CLEAN slot=1 bots_checked=46 remaining_refs=0' "$logdir/server.log"
  for slot in 0 2 3; do
    grep -F "V75245_LIVE_DISCONNECT slot=$slot removed=true continued=true" "$logdir/"client*.log
  done
elif [ "${AURORA_TERRAIN_QA:-0}" = 1 ]; then
  for i in 0 1 2 3; do grep -F 'V75243_TERRAIN PASS' "$logdir/client$i.log"; done
  grep -F 'V75243_TERRAIN_READY humans=4' "$logdir/server.log"
  grep -F 'V75243_ZONE_HIT slot=0' "$logdir/server.log"
else
  for i in 0 1 2 3; do grep -F 'V75242_FOUR PASS' "$logdir/client$i.log"; done
  grep -F 'V75242_ELIMINATION' "$logdir/server.log"
  grep -F 'V75242_DEATH_CLAIM' "$logdir/server.log"
fi
# Every fixture must prove the expected number of actual admissions.
if [ "${AURORA_FLEX_QA:-0}" = 1 ]; then
  grep -F 'live_humans=2' "$logdir/server.log"
  test "$(grep -c 'V75237_SERVER_ADMIT' "$logdir/server.log")" -eq 2
  grep -F 'V75245_DISCONNECT_CLEAN slot=0 bots_checked=48 remaining_refs=0' "$logdir/server.log"
  grep -F 'V75245_DISCONNECT_CLEAN slot=1 bots_checked=48 remaining_refs=0' "$logdir/server.log"
else
  grep -F 'live_humans=4' "$logdir/server.log"
fi
if grep -E 'SCRIPT ERROR|ERROR: Failed to load script' "$logdir/"*.log; then exit 1; fi
