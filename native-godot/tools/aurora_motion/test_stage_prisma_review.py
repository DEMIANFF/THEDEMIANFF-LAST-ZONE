"""Tests use generated data, never the user's unlicensed motion recording."""
import copy
import unittest
from unittest.mock import patch
import stage_prisma_review as stage


class PrivateReviewTest(unittest.TestCase):
    def setUp(self):
        self.clip = "ReviewPrisma_fixture"
        names = sorted(stage.BODY_NAMES | {"Root"})
        names += ["fixture_" + str(i) for i in range(56-len(names))]
        self.document = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": 4}],
            "nodes": [{"name": n} for n in names], "skins": [{"joints": list(range(56))}],
            "meshes": [{"name": "original_mesh"}], "bufferViews": [], "accessors": [],
            "animations": [{"name": "AuroraArmedIdle", "samplers": [], "channels": []}]}
        self.bank = {"schema": "aurora-lila-private-review-v1", "review_only": True,
            "source_sha256": stage.SOURCE_SHA, "lila_source_sha256": stage.LILA_SHA,
            "clips": [{"name": self.clip, "times": [0, .1], "tracks": [
                {"bone": "Hips", "path": "translation", "values": [[0, -.1, 0], [0, -.2, 0]]},
                {"bone": "LeftLeg", "path": "rotation", "values": [[0,0,0,1], [0,0,0,1]]}]}]}
        self.patcher = patch.object(stage, "EXPECTED", {self.clip: (2, {"LeftLeg"})})
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def test_append_keeps_original_mesh_bones_animation_and_binary(self):
        before = copy.deepcopy(self.document)
        raw = stage.merge_private_bank(self.document, b"ABCD", self.bank)
        after, binary = stage.parse_glb(raw)
        for key in ("meshes", "nodes", "skins"):
            self.assertEqual(before[key], after[key])
        self.assertEqual(before["animations"][0], after["animations"][0])
        self.assertEqual(after["animations"][1]["name"], self.clip)
        self.assertEqual(binary[:4], b"ABCD")
        self.assertFalse(after["asset"]["extras"]["private_prisma_review"]["production_approved"])

    def test_horizontal_pelvis_rejected(self):
        self.bank["clips"][0]["tracks"][0]["values"][0][2] = 54
        with self.assertRaises(ValueError):
            stage.merge_private_bank(self.document, b"ABCD", self.bank)
        self.assertEqual(len(self.document["animations"]), 1)

    def test_root_motion_rejected(self):
        self.bank["clips"][0]["tracks"][1]["bone"] = "Root"
        with self.assertRaises(ValueError):
            stage.merge_private_bank(self.document, b"ABCD", self.bank)

    def test_invalid_quaternion_rejected(self):
        self.bank["clips"][0]["tracks"][1]["values"][0] = [0,0,0,0]
        with self.assertRaises(ValueError):
            stage.merge_private_bank(self.document, b"ABCD", self.bank)

    def test_nonmonotonic_time_rejected(self):
        self.bank["clips"][0]["times"] = [0,0]
        with self.assertRaises(ValueError):
            stage.merge_private_bank(self.document, b"ABCD", self.bank)


if __name__ == "__main__":
    unittest.main()
