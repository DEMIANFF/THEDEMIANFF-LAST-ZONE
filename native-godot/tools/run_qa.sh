#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
LOGS="${AURORA_QA_LOGS:-$ROOT/out/qa}"
mkdir -p "$LOGS"
# Full QA requires the same generated resources as the Android export.
test -s "$ROOT/assets/characters/aurora_operator.glb"
test -s "$ROOT/assets/weapons/aurora_awm.glb"
export AURORA_REQUIRE_OPERATOR=1 GODOT_SILENCE_ROOT_WARNING=1
# Keep test ledgers independent from installed desktop profiles.
qa_data="$(mktemp -d)"
trap 'rm -rf "$qa_data"' EXIT
export XDG_DATA_HOME="$qa_data"
"$GODOT" --headless --path "$ROOT" --editor --quit > "$LOGS/import.log" 2>&1
if grep -E 'SCRIPT ERROR:|ERROR:' "$LOGS/import.log"; then exit 1; fi
for script in smoke_test combat_rules_test motorola_control_audit mobile_touch_routing_test camera_fire_qa multitouch_combat_qa sector_battle_qa launch_airdrop_qa persistent_match_qa crouch_collision_qa weapon_visual_qa v752_regression_qa persistence_recovery_qa responsive_layout_qa; do
  if ! timeout 90 "$GODOT" --headless --path "$ROOT" --script "res://scripts/qa/$script.gd" > "$LOGS/$script.log" 2>&1; then
    cat "$LOGS/$script.log"
    exit 1
  fi
  if grep -E 'SCRIPT ERROR:|ERROR:' "$LOGS/$script.log"; then exit 1; fi
  marker='PASS'
  case "$script" in
    smoke_test) marker='TPS HUD OK';;
    combat_rules_test) marker='AR automatic fire verified';;
    v752_regression_qa) marker='V752_COVER blocked=100 clear=';;
    responsive_layout_qa) marker='RESPONSIVE_LAYOUT (1024, 768)';;
  esac
  if ! grep -Fq "$marker" "$LOGS/$script.log"; then
    echo "Incomplete test: $script"
    cat "$LOGS/$script.log"
    exit 1
  fi
  echo "$script PASS"
done
