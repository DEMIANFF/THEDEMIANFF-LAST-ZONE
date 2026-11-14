#!/usr/bin/env python3
"""Read-only V75.74 prerequisite audit for the Godot Android Firebase bridge.

Never reads Firebase credentials, exports tokens, changes the Firebase project,
switches Android signing or installs a plugin. The legacy Android application
uses another package; its google-services.json must not be used in Godot.
"""
import argparse
import json
import re
from pathlib import Path

NATIVE = Path(__file__).resolve().parent.parent
REPO = NATIVE.parent
PRESET = NATIVE / "export_presets.cfg"
EXPECTED_PACKAGE = "com.thedemianff.lastzone.nativepreview"
LEGACY_PACKAGE = "com.thedemianff.lastzone"


def setting(data: str, name: str) -> str:
    matches = re.findall(r"^" + re.escape(name) + r"=(.*)$", data, re.M)
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one {name} setting")
    return matches[0].strip().strip('"')


def firebase_packages(config: Path) -> set[str]:
    if not config.is_file():
        return set()
    doc = json.loads(config.read_text(encoding="utf-8"))
    result = set()
    for entry in doc.get("client", []):
        info = entry.get("client_info", {}).get("android_client_info", {})
        package = info.get("package_name")
        if isinstance(package, str):
            result.add(package)
    return result


def audit() -> dict:
    cfg = PRESET.read_text(encoding="utf-8")
    package = setting(cfg, "package/unique_name")
    gradle = setting(cfg, "gradle_build/use_gradle_build") == "true"
    if package != EXPECTED_PACKAGE:
        raise ValueError("The preview package was unexpectedly modified")
    legacy = firebase_packages(REPO / "app" / "google-services.json")
    # A future Gradle build template needs a NEW matching config from the
    # correct Firebase Android app registration. Legacy package is different.
    native_config = firebase_packages(NATIVE / "android" / "build" / "google-services.json")
    aar = list((NATIVE / "addons").rglob("*AuroraFirebase*.aar")) if (
        NATIVE / "addons").is_dir() else []
    return {
        "package": package,
        "legacy_package": LEGACY_PACKAGE if LEGACY_PACKAGE in legacy else "not_confirmed",
        "gradle_build_enabled": gradle,
        "matching_native_firebase_config": package in native_config,
        "native_plugin_aar_present": bool(aar),
        # No local source file proves a valid Android Play Integrity token.
        "app_check_verified": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--assert-blocked", action="store_true")
    args = parser.parse_args()
    state = audit()
    # No API keys, service-account JSON, signing passwords, UID or tokens are
    # printed. This is safe to show in CI logs.
    ready = all((
        state["gradle_build_enabled"],
        state["matching_native_firebase_config"],
        state["native_plugin_aar_present"],
        state["app_check_verified"],
    ))
    print("AURORA_FIREBASE_PREFLIGHT", "READY" if ready else "BLOCKED")
    print("native_package=" + state["package"])
    print("legacy_package=" + state["legacy_package"])
    print("gradle_build=" + str(state["gradle_build_enabled"]).lower())
    print("matching_native_config=" + str(state["matching_native_firebase_config"]).lower())
    print("compiled_plugin=" + str(state["native_plugin_aar_present"]).lower())
    print("app_check_attestation=requires_motorola_verification")
    if args.assert_blocked and ready:
        raise AssertionError("This CI release unexpectedly enables unverified Firebase")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
