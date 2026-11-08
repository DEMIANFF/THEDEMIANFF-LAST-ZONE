#!/usr/bin/env bash
set -euo pipefail
# Pinned repository revision and Git blob IDs. The provider declares the
# source female model CC0. Do not download any Renderpeople-Free restricted rig.
REV=c1f1fa8f01524d60197c4d65306349e266d339cb
SOURCE=https://raw.githubusercontent.com/s0ck3t/VideoIntoBlenderModel/$REV/assets/rigs
DEST="${1:-/tmp/aurora-operator-source}"
mkdir -p "$DEST"
curl -fLsS --retry 3 --retry-delay 3 "$SOURCE/attractor_mechanic_tpose.fbx" -o "$DEST/attractor_mechanic_tpose.fbx"
curl -fLsS --retry 3 --retry-delay 3 "$SOURCE/attractor_mechanic_tpose.png" -o "$DEST/attractor_mechanic_tpose.png"
test "$(git hash-object "$DEST/attractor_mechanic_tpose.fbx")" = 611c60c0fca0fcc0b4dae0b7a12cc6fdce85602e
test "$(git hash-object "$DEST/attractor_mechanic_tpose.png")" = 76fd605c8f0b157b70389f1ba53b3837b195a231
printf 'CC0 source verified: %s\n' "$REV"
