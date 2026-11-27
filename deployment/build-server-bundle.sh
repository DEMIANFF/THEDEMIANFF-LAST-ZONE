#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
engine="${GODOT_BIN:?Set GODOT_BIN to the validated Godot engine}"
out="$root/native-godot/out/server-release"
mkdir -p "$out"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/bin" "$stage/functions" "$stage/native-godot" "$stage/deployment"
install -m 0755 "$engine" "$stage/bin/godot"
# Preserve the actual imported assets and scripts used by the tested server.
# Do not copy Android credentials, application Gradle files or QA artifacts.
tar -C "$root/native-godot" --exclude='./out' --exclude='./android' --exclude='./.godot/editor' --exclude='./.godot/shader_cache' --exclude='google-services.json' --exclude='*.keystore' --exclude='*.pem' --exclude='*.key' --exclude='.env' -cf - . | tar -C "$stage/native-godot" -xf -
cp -a "$root/functions/src" "$root/functions/scripts" "$root/functions/package.json" "$stage/functions/"
cp "$root/deployment/aurora-room@.service" "$root/deployment/INTERNET_FIREBASE_RUNBOOK.md" "$stage/deployment/"
test -s "$stage/native-godot/project.godot"
test -d "$stage/native-godot/.godot/imported"
test -s "$stage/native-godot/assets/characters/aurora_operator.glb"
test -s "$stage/native-godot/assets/weapons/aurora_awm.glb"
# Verify the standalone copy can run real TLS admission and movement.
GODOT_BIN="$stage/bin/godot" bash "$stage/native-godot/tools/run_internet_qa.sh"
mkdir -p "$root/native-godot/out/online/bundle"
cp "$stage/native-godot/out/online/internet/"*.log "$root/native-godot/out/online/bundle/"
rm -rf "$stage/native-godot/out"
{ git -C "$root" rev-parse HEAD; "$stage/bin/godot" --headless --version; echo 'Protocol 31; Linux x86_64; public TLS credentials and Node dependencies not included'; } > "$stage/BUILD.txt"
tar -C "$stage" -czf "$out/THEDEMIAN-V75.252-LINUX-SERVER.tar.gz" .
(cd "$out" && sha256sum THEDEMIAN-V75.252-LINUX-SERVER.tar.gz > SHA256SUMS.txt)
echo AURORA_STANDALONE_TLS_SERVER_BUNDLE_PASS
