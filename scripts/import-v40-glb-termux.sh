#!/usr/bin/env bash
# V40: execute from the root of THEDEMIANFF-LAST-ZONE checkout in Termux.
set -euo pipefail
ARCHIVE="${1:-$HOME/storage/downloads/THEDEMIANFF_V40_recursos_3D.zip}"
test -f "$ARCHIVE" || { echo "ZIP not found: $ARCHIVE"; exit 1; }
test -d .git || { echo "Run this inside the Git repository"; exit 1; }
test -f app/src/main/assets/index.html || { echo "Wrong repository root"; exit 1; }
git fetch origin v40-architecture-reconstruction
git switch v40-architecture-reconstruction
git pull --ff-only origin v40-architecture-reconstruction
unzip -o "$ARCHIVE" 'app/src/main/assets/models/*'
for file in lila-operator.glb alternative-female-reference.glb weapons-pack.glb ak74-tactical.glb; do
  test -s "app/src/main/assets/models/$file" || { echo "Missing: $file"; exit 1; }
done
git add app/src/main/assets/models/lila-operator.glb app/src/main/assets/models/alternative-female-reference.glb app/src/main/assets/models/weapons-pack.glb app/src/main/assets/models/ak74-tactical.glb
git commit -m "V40 bundle four user-supplied GLB character and weapon assets" || echo "No new changes to commit"
git push origin v40-architecture-reconstruction
echo "V40 3D assets uploaded. Check GitHub Actions and test the APK on device."
