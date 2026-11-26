#!/usr/bin/env bash
# Verify explicit private GLB without copying into project or exporting it.
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "Usage: bash $0 /absolute/path/to/private.glb" >&2
  exit 2
fi
root="$(cd "$(dirname "$0")/../.." && pwd)"
candidate="$(realpath "$1")"
godot_bin="${GODOT:-godot}"
test -f "$candidate"
case "$candidate" in
  "$root"/*) echo "Keep private candidate outside the project tree" >&2; exit 2 ;;
esac
command -v "$godot_bin" >/dev/null
test -s "$root/assets/characters/lila_aurora.glb"
test -s "$root/assets/weapons/aurora_awm.glb"
test -s "$root/assets/characters/aurora_operator.glb"
logs="$(mktemp -d -t lila-private-review.XXXXXXXX)"
echo "Private review logs: $logs"
export XDG_DATA_HOME="$(mktemp -d -t lila-private-data.XXXXXXXX)"
trap 'rm -rf "$XDG_DATA_HOME"' EXIT
python3 "$root/tools/aurora_motion/validate_lila_runtime_private.py" "$candidate" | tee "$logs/contract.json"
# Project resources must already be imported. No Android export.
run_review() {
  local name="$1" script="$2"; shift 2
  timeout 180 "$godot_bin" --headless --path "$root" --script "res://tools/aurora_motion/$script" -- "$@" 2>&1 | tee "$logs/$name.log"
  if grep -Eq 'SCRIPT ERROR:|ERROR:' "$logs/$name.log"; then exit 1; fi
}
run_review import private_lila_runtime_review.gd "$candidate"
grep -F 'LILA_PRIVATE_RUNTIME imported_clips=27 sampled_poses=135' "$logs/import.log"
run_review wrist private_lila_armory_review.gd --candidate "$candidate"
grep -F 'LILA_ARMORY_REVIEW PASS poses=24 baseline=false experimental_palm=false' "$logs/wrist.log"
run_review palm private_lila_armory_review.gd --candidate-palm "$candidate"
grep -F 'LILA_ARMORY_REVIEW PASS poses=24 baseline=false experimental_palm=true' "$logs/palm.log"
echo "PRIVATE_REVIEW_PASS (not production approval); logs: $logs"
