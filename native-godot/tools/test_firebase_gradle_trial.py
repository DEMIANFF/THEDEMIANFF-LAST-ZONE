#!/usr/bin/env python3
"""Self-contained public-fixture regression for the real Godot 4.7.2 Gradle
Android resource layout. No production Firebase JSON or secrets are read.
"""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from xml.etree import ElementTree

MODULE_PATH = Path(__file__).resolve().parent / "prepare_firebase_gradle_trial.py"
spec = importlib.util.spec_from_file_location("aurora_gradle_prep", MODULE_PATH)
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)


def example_config(package):
    return {
        "project_info": {
            "project_id": "aurora-fixture-no-real-project",
            "project_number": "100000000000",
            "storage_bucket": "aurora-fixture.invalid",
        },
        "client": [{
            "client_info": {
                "mobilesdk_app_id": "1:100000000000:android:fixture",
                "android_client_info": {"package_name": package},
            },
            "api_key": [{"current_key": "FIXTURE-NOT-A-REAL-API-KEY"}],
            "oauth_client": [{
                "client_type": 3,
                "client_id": "fixture-web-client.apps.googleusercontent.com",
            }],
        }],
    }


class AuroraFirebaseGradleLayoutTest(unittest.TestCase):
    def setUp(self):
        self.ctx = tempfile.TemporaryDirectory()
        self.addCleanup(self.ctx.cleanup)
        self.root = Path(self.ctx.name) / "native-godot"
        self.original_root = prep.ROOT
        self.addCleanup(setattr, prep, "ROOT", self.original_root)
        prep.ROOT = self.root
        self.gradle = self.root / "android" / "build" / "build.gradle"
        self.gradle.parent.mkdir(parents=True)
        self.gradle.write_text("plugins { id 'com.android.application' }\n")

    def test_creates_missing_main_resource_tree(self):
        config = self.root / "fixture.json"
        config.write_text(json.dumps(example_config(prep.PACKAGE)))
        self.assertFalse((self.root / "android" / "build" / "src").exists())
        prep.write_firebase_resources(config)
        strings = self.root / "android" / "build" / "src" / "main" / "res" / "values" / "aurora_firebase.xml"
        self.assertTrue(strings.is_file())
        values = {
            node.get("name"): node.text
            for node in ElementTree.parse(strings).getroot().findall("string")
        }
        self.assertEqual(values["google_app_id"], "1:100000000000:android:fixture")
        self.assertEqual(
            values["default_web_client_id"],
            "fixture-web-client.apps.googleusercontent.com",
        )
        self.assertEqual(values["gcm_defaultSenderId"], "100000000000")
        self.assertEqual(values["project_id"], "aurora-fixture-no-real-project")

    def test_wrong_android_package_rejected_without_creating_resources(self):
        config = self.root / "wrong.json"
        config.write_text(json.dumps(example_config("com.thedemianff.lastzone")))
        with self.assertRaisesRegex(ValueError, "nativepreview"):
            prep.write_firebase_resources(config)
        self.assertFalse((self.root / "android" / "build" / "src").exists())

    def test_missing_app_gradle_module_rejected(self):
        config = self.root / "fixture.json"
        config.write_text(json.dumps(example_config(prep.PACKAGE)))
        self.gradle.unlink()
        with self.assertRaisesRegex(FileNotFoundError, "application Gradle module"):
            prep.write_firebase_resources(config)
        self.assertFalse((self.root / "android" / "build" / "src").exists())


if __name__ == "__main__":
    unittest.main()
