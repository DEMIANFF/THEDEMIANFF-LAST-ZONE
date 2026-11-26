"""Regression tests for selective private staging; no proprietary assets."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import stage_optional_armory as stage


class SelectiveArmoryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "native-godot"
        self.root.mkdir()
        (self.root / "project.godot").write_text("; fixture")
        self.archive = Path(self.tmp.name) / "private.zip"
        self.assets = {name: name.encode() * 600 for name in ("HK416", "P90", "VSS")}
        self.staged = {
            name: ("native-godot/assets/" + name + ".glb",
                   hashlib.sha256(data).hexdigest())
            for name, data in self.assets.items()
        }
        self.patcher = patch.object(stage, "STAGED", self.staged)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)
        self.write_archive()
        self.p90 = self.root / "assets/P90.glb"
        self.p90.parent.mkdir()
        self.p90.write_bytes(b"newer public P90")

    def write_archive(self, corrupt=None):
        with zipfile.ZipFile(self.archive, "w") as archive:
            rows = []
            for name, (path, sha) in self.staged.items():
                rows.append({"name": name, "staged_path": path, "sha256": sha})
                archive.writestr(path, self.assets[name] + (b"bad" if name == corrupt else b""))
            archive.writestr("PRIVATE_ARMORY_MANIFEST.json", json.dumps({"models": rows}))

    def test_selective_dry_run_and_install(self):
        result = stage.prepare(self.archive, self.root, models=("HK416", "VSS"))
        self.assertEqual(result["archive_models_verified"], 3)
        self.assertEqual(result["excluded"], ["P90"])
        self.assertFalse((self.root / "assets/HK416.glb").exists())
        stage.prepare(self.archive, self.root, True, ("HK416", "VSS"))
        for name in ("HK416", "VSS"):
            self.assertEqual((self.root / ("assets/" + name + ".glb")).read_bytes(),
                             self.assets[name])
        self.assertEqual(self.p90.read_bytes(), b"newer public P90")

    def test_corrupt_excluded_model_blocks_every_write(self):
        self.write_archive(corrupt="P90")
        with self.assertRaises(ValueError):
            stage.prepare(self.archive, self.root, True, ("HK416", "VSS"))
        self.assertFalse((self.root / "assets/HK416.glb").exists())

    def test_default_refuses_to_replace_newer_p90(self):
        with self.assertRaises(FileExistsError):
            stage.prepare(self.archive, self.root, True)
        self.assertEqual(self.p90.read_bytes(), b"newer public P90")
        self.assertFalse((self.root / "assets/HK416.glb").exists())

    def test_selected_conflict_prevents_other_install(self):
        (self.root / "assets/VSS.glb").write_bytes(b"different")
        with self.assertRaises(FileExistsError):
            stage.prepare(self.archive, self.root, True, ("HK416", "VSS"))
        self.assertFalse((self.root / "assets/HK416.glb").exists())

    def test_unknown_selection_rejected(self):
        with self.assertRaises(ValueError):
            stage.prepare(self.archive, self.root, True, ("not-a-model",))


if __name__ == "__main__":
    unittest.main()
