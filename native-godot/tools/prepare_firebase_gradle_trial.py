#!/usr/bin/env python3
"""CI-only opt-in Gradle Firebase integration: never alter the checked-in APK preset.

Workflow: stage-addon -> install Godot Android build template -> configure-host
-> Godot Gradle export. All mutations are in a disposable Actions checkout.
No Firebase config = diagnostics-only, no possible Auth/App Check session.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, ElementTree

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
PLUGIN = REPO / "firebase-godot-bridge"
ADDON = ROOT / "addons" / "AuroraFirebase"
PRESET = ROOT / "export_presets.cfg"
PROJECT = ROOT / "project.godot"
PACKAGE = "com.thedemianff.lastzone.nativepreview"
TEST_APK = "out/THEDEMIAN-V75.104-MOTOROLA-FIREBASE-GRADLE.apk"


def one_edit(path: Path, original: str, replacement: str) -> None:
    content = path.read_text(encoding="utf-8")
    if content.count(original) != 1:
        raise ValueError(f"Expected exactly one {original[:36]!r} in {path}")
    path.write_text(content.replace(original, replacement), encoding="utf-8")


def stage_addon() -> None:
    if ADDON.exists():
        raise RuntimeError("Addon already present; refusing to overwrite another plugin")
    source = PLUGIN / "addon" / "AuroraFirebase"
    shutil.copytree(source, ADDON)
    for variant in ("debug", "release"):
        src = PLUGIN / "plugin" / "build" / "outputs" / "aar" / ("plugin-" + variant + ".aar")
        if not src.is_file() or src.stat().st_size < 1000:
            raise FileNotFoundError(f"Compiled native {variant} AAR is required")
        target = ADDON / "bin" / variant / ("AuroraFirebase-" + variant + ".aar")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, target)
    project = PROJECT.read_text(encoding="utf-8")
    if "[editor_plugins]" in project or "AuroraFirebase" in project:
        raise ValueError("An editor plugin is already configured; do not override it")
    PROJECT.write_text(project + "\n[editor_plugins]\nenabled=PackedStringArray(" +
                       '"res://addons/AuroraFirebase/plugin.cfg")\n', encoding="utf-8")
    one_edit(PRESET, "gradle_build/use_gradle_build=false",
             "gradle_build/use_gradle_build=true")
    one_edit(PRESET, 'export_path="out/THEDEMIAN-V75.104-MOTOROLA-VULKAN.apk"',
             f'export_path="{TEST_APK}"')
    print("AURORA_FIREBASE_GRADLE_ADDON_STAGE_PASS sdk=compiled package=" + PACKAGE)


def verified_client(config: dict) -> dict:
    apps = []
    for client in config.get("client", []):
        info = client.get("client_info", {})
        if info.get("android_client_info", {}).get("package_name") == PACKAGE:
            apps.append(client)
    if len(apps) != 1:
        raise ValueError(
            "Firebase JSON does not contain exactly one Android app for "
            + PACKAGE + ". Download google-services.json from THIS "
            "Firebase Android app, not the legacy app. Chrome may have "
            "saved it as google-services (1).json; update the GitHub secret "
            "with that exact file. No credentials were printed."
        )
    client = apps[0]
    project = config.get("project_info", {})
    if not project.get("project_id") or not project.get("project_number"):
        raise ValueError("Invalid Firebase project info")
    if not client.get("client_info", {}).get("mobilesdk_app_id"):
        raise ValueError("Missing Firebase Android app id")
    api_keys = client.get("api_key", [])
    if len(api_keys) < 1 or not api_keys[0].get("current_key"):
        raise ValueError("Missing Android Firebase API key")
    oauth_web = [entry.get("client_id") for entry in client.get("oauth_client", [])
                 if entry.get("client_type") == 3 and entry.get("client_id")]
    if len(set(oauth_web)) != 1:
        raise ValueError("Exactly one Google OAuth web client is required for Google sign-in")
    return {
        "google_app_id": client["client_info"]["mobilesdk_app_id"],
        "google_api_key": api_keys[0]["current_key"],
        "gcm_defaultSenderId": str(project["project_number"]),
        "project_id": project["project_id"],
        "google_storage_bucket": project.get("storage_bucket", ""),
        "default_web_client_id": oauth_web[0],
    }


def write_firebase_resources(path: Path) -> None:
    obj = json.loads(path.read_text(encoding="utf-8"))
    strings = verified_client(obj)
    # Generated at build time, never checked in. Android resources normally
    # produced by Google's google-services Gradle plugin; equivalent values.
    # Godot's official Android source template has the Gradle app module at
    # android/build, but may omit src/main until custom resources are added.
    # Android Gradle's conventional main source set discovers this directory
    # when created; do not require an initially existing src/main folder.
    host = ROOT / "android" / "build"
    build_file = host / "build.gradle"
    if not build_file.is_file() or "com.android.application" not in build_file.read_text(
            encoding="utf-8"):
        raise FileNotFoundError("Godot Android application Gradle module is missing")
    target = host / "src" / "main" / "res" / "values"
    target.mkdir(parents=True, exist_ok=True)
    root = Element("resources")
    for name, value in strings.items():
        node = SubElement(root, "string", {"name": name, "translatable": "false"})
        node.text = str(value)
    ElementTree(root).write(target / "aurora_firebase.xml", encoding="utf-8", xml_declaration=True)
    # Never emit the values or the JSON in CI output.
    print("AURORA_FIREBASE_CONFIG_MATCH_PASS package=" + PACKAGE +
          " project_fields=verified oauth_web=present")


def configure_host(firebase_json: Path | None) -> None:
    host = ROOT / "android" / "build"
    build_gradle = host / "build.gradle"
    if not build_gradle.is_file():
        raise FileNotFoundError("Godot 4.7.2 Gradle app template was not installed")
    content = build_gradle.read_text(encoding="utf-8")
    if "AURORA_FIREBASE_HOST_RUNTIME_DEPENDENCIES" in content:
        raise RuntimeError("Gradle runtime dependencies were already inserted")
    # Android plugin AARs do not package Maven dependencies in themselves.
    # Align the same dependency versions as firebase-godot-bridge/plugin.
    deps = """
// AURORA_FIREBASE_HOST_RUNTIME_DEPENDENCIES
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:35.2.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-functions")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
    implementation("androidx.credentials:credentials:1.5.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.5.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
}
"""
    build_gradle.write_text(content + "\n" + deps, encoding="utf-8")
    if firebase_json is not None:
        write_firebase_resources(firebase_json)
    else:
        print("AURORA_FIREBASE_DIAGNOSTIC_ONLY no_matching_config=1 login=blocked")
    print("AURORA_FIREBASE_GRADLE_HOST_PASS sdk_deps=7 addon=1")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("step", choices=["stage", "configure", "validate"])
    parser.add_argument("--firebase-json", type=Path)
    args = parser.parse_args()
    if args.step == "stage":
        stage_addon()
    elif args.step == "validate":
        if args.firebase_json is None:
            raise ValueError("A Firebase JSON path is required for validation")
        verified_client(json.loads(args.firebase_json.read_text(encoding="utf-8")))
        print("AURORA_FIREBASE_JSON_PREFLIGHT_PASS package=" + PACKAGE)
    else:
        configure_host(args.firebase_json)


if __name__ == "__main__":
    main()
