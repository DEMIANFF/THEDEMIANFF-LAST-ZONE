#!/usr/bin/env python3
"""Fail closed on wrong package/ABI, bad signature, CRC or 16 KiB alignment."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import struct
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("apk", type=Path)
parser.add_argument("--build-tools", type=Path, required=True)
parser.add_argument("--logs", type=Path, required=True)
args = parser.parse_args()
args.logs.mkdir(parents=True, exist_ok=True)

# Read version metadata from the active Godot export preset.
preset = (Path(__file__).resolve().parents[1] / 'export_presets.cfg').read_text()
def preset_value(key):
    match = re.search(r'^' + re.escape(key) + r'=(.+)$', preset, re.MULTILINE)
    if not match:
        raise RuntimeError(f'Missing export preset value: {key}')
    raw = match.group(1).strip()
    return json.loads(raw) if raw.startswith('"') else raw

package_name = str(preset_value('package/unique_name'))
version_code = int(preset_value('version/code'))
version_name = str(preset_value('version/name'))
if not package_name.startswith('com.thedemianff.lastzone.nativepreview'):
    raise RuntimeError('Refusing production APK with preview signing')


def run(tool, arguments, log):
    process = subprocess.run([str(args.build_tools / tool), *arguments, str(args.apk)],
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (args.logs / log).write_text(process.stdout)
    if process.returncode:
        raise RuntimeError(f"{tool} failed: see {log}")
    return process.stdout


badging = run("aapt", ["dump", "badging"], "badging.txt")
assert f"package: name='{package_name}'" in badging, 'Unexpected Android package'
assert f"versionCode='{version_code}'" in badging and f"versionName='{version_name}'" in badging, 'Unexpected Android build version'
assert "native-code: 'arm64-v8a'" in badging.splitlines()
assert "application-debuggable" in badging.splitlines()
signature = run("apksigner", ["verify", "--verbose", "--print-certs"], "signature.txt")
assert "Verified using v2 scheme (APK Signature Scheme v2): true" in signature
assert "Verified using v3 scheme (APK Signature Scheme v3): true" in signature
run("zipalign", ["-c", "-P", "16", "-v", "4"], "alignment.txt")
libraries = []
with zipfile.ZipFile(args.apk) as archive:
    assert archive.testzip() is None, "CRC failure"
    native = [name for name in archive.namelist() if name.startswith("lib/") and name.endswith(".so")]
    assert native, "Missing engine library"
    for name in native:
        assert name.startswith("lib/arm64-v8a/"), f"Unexpected ABI: {name}"
        elf = archive.read(name)
        assert elf[:6] == b"\x7fELF\x02\x01", "Not little-endian ELF64"
        assert struct.unpack_from("<H", elf, 18)[0] == 183, "Not AArch64"
        offset = struct.unpack_from("<Q", elf, 32)[0]
        entry_size, count = struct.unpack_from("<HH", elf, 54)
        alignments = []
        for i in range(count):
            fields = struct.unpack_from("<IIQQQQQQ", elf, offset + i * entry_size)
            if fields[0] == 1:  # PT_LOAD
                assert fields[7] >= 16384, f"ELF segment alignment below 16 KiB: {name}"
                assert fields[2] % 16384 == fields[3] % 16384, f"ELF offset/VA mismatch: {name}"
                alignments.append(fields[7])
        assert alignments
        libraries.append({"name": name, "load_segment_alignments": alignments})
    assert "assets/project.binary" in archive.namelist(), "Missing exported Godot project"

digest = hashlib.sha256(args.apk.read_bytes()).hexdigest()
result = {"apk": args.apk.name, "bytes": args.apk.stat().st_size, "sha256": digest,
          "package": package_name, "version_code": version_code,
          "version_name": version_name, "debug": True,
          "signature_v2_v3": True, "zip_alignment_16k": True, "crc": "PASS", "libraries": libraries}
(args.logs / "apk-verification.json").write_text(json.dumps(result, indent=2) + "\n")
(args.logs / "SHA256SUMS.txt").write_text(f"{digest}  {args.apk.name}\n")
print(json.dumps(result, indent=2))
