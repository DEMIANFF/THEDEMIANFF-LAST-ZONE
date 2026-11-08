#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="${1:?Usage: run_exported_qa.sh path/to.apk}"
exported="$(mktemp -d)"
trap 'rm -rf "$exported"' EXIT
python3 - "$APK" "$exported" <<'PY'
import sys, zipfile
from pathlib import Path
target=Path(sys.argv[2])
with zipfile.ZipFile(sys.argv[1]) as archive:
    for name in archive.namelist():
        if not name.startswith('assets/') or name.endswith('/'):
            continue
        relative=Path(name.removeprefix('assets/'))
        assert '..' not in relative.parts and not relative.is_absolute()
        out=target/relative
        out.parent.mkdir(parents=True,exist_ok=True)
        out.write_bytes(archive.read(name))
PY
AURORA_QA_ROOT="$exported" AURORA_QA_EXPORTED=1 bash "$ROOT/tools/run_qa.sh"
