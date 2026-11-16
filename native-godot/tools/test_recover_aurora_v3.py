import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

from recover_aurora_v3 import PART_NAMES, extract_archives, recover, verify_originals


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.parts = self.root / "parts"
        self.parts.mkdir()
        self.payload = b"original bytes with two fragments"
        self.manifest = {"received_files": 2, "total_original_bytes": len(self.payload) * 2,
                         "files": [{"name": name, "size_bytes": len(self.payload),
                                    "sha256": hashlib.sha256(self.payload).hexdigest()}
                                   for name in ("original.glb", "duplicate.glb")]}
        self.manifest_path = self.root / "manifest.json"
        self.manifest_path.write_text(json.dumps(self.manifest))
        for name in PART_NAMES:
            with zipfile.ZipFile(self.parts / name, "w"):
                pass
        with zipfile.ZipFile(self.parts / PART_NAMES[0], "a") as archive:
            archive.writestr("fragmentos/original.glb.parte001", self.payload[:8])
            archive.writestr("originales/duplicate.glb", self.payload)
        with zipfile.ZipFile(self.parts / PART_NAMES[1], "a") as archive:
            archive.writestr("fragmentos/original.glb.parte002", self.payload[8:])

    def tearDown(self):
        self.temp.cleanup()

    def test_delivered_script_reconstructs_and_keeps_duplicate_originals(self):
        output = self.root / "recovered"
        report = recover(self.parts, output, self.manifest_path)
        self.assertEqual(report["original_count"], 2)
        self.assertFalse(report["integral_integration_complete"])
        for entry in self.manifest["files"]:
            self.assertEqual((output / "originales" / entry["name"]).read_bytes(), self.payload)
        self.assertEqual(len(verify_originals(output / "originales", self.manifest)), 2)
        self.assertTrue((output / "fragmentos/original.glb.parte001").exists())

    def test_missing_part_fails_without_creating_output(self):
        (self.parts / PART_NAMES[-1]).unlink()
        output = self.root / "missing"
        with self.assertRaisesRegex(ValueError, "Missing archive parts"):
            recover(self.parts, output, self.manifest_path)
        self.assertFalse(output.exists())

    def test_bad_hash_does_not_publish_partial_recovery(self):
        self.manifest["files"][0]["sha256"] = "0" * 64
        self.manifest_path.write_text(json.dumps(self.manifest))
        output = self.root / "corrupt"
        with self.assertRaises(subprocess.CalledProcessError):
            recover(self.parts, output, self.manifest_path)
        self.assertFalse(output.exists())
        self.assertEqual(len(list(self.parts.glob("*.zip"))), 24)

    def test_existing_originals_are_never_overwritten(self):
        output = self.root / "existing"
        output.mkdir()
        marker = output / "keep.txt"
        marker.write_text("unchanged")
        with self.assertRaises(FileExistsError):
            recover(self.parts, output, self.manifest_path)
        self.assertEqual(marker.read_text(), "unchanged")

    def test_zip_traversal_and_conflicting_members_are_rejected(self):
        unsafe = self.root / "unsafe.zip"
        with zipfile.ZipFile(unsafe, "w") as archive:
            archive.writestr("../escaped.txt", b"bad")
        dest = self.root / "safe"
        dest.mkdir()
        with self.assertRaisesRegex(ValueError, "Unsafe ZIP member"):
            extract_archives([unsafe], dest, 1000)
        self.assertFalse((self.root / "escaped.txt").exists())
        first, second = self.root / "first.zip", self.root / "second.zip"
        for target, data in ((first, b"one"), (second, b"two")):
            with zipfile.ZipFile(target, "w") as archive:
                archive.writestr("originales/same.glb", data)
        with self.assertRaisesRegex(ValueError, "Conflicting ZIP member"):
            extract_archives([first, second], dest, 1000)
        self.assertEqual((dest / "originales/same.glb").read_bytes(), b"one")


if __name__ == "__main__":
    unittest.main()
