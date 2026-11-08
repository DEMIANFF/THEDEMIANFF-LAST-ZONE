#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${1:-/tmp/aurora-operator}"
BLENDER="${BLENDER:-blender}"
bash "$ROOT/tools/fetch_operator.sh" "$SOURCE"
"$BLENDER" --background --python "$ROOT/tools/convert_operator.py" -- "$SOURCE/attractor_mechanic_tpose.fbx" "$SOURCE/attractor_mechanic_tpose.png" "$ROOT/assets/characters/aurora_operator.glb"
"$BLENDER" --background --python "$ROOT/tools/build_awm.py" -- "$ROOT/assets/weapons/aurora_awm.glb"
