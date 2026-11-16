#!/usr/bin/env python3
"""Validate the current Android Mobile/Vulkan export; never build OpenGL APKs.

The desktop editor keeps Compatibility for reproducible headless regression.
The Motorola preview uses only the native Android Vulkan Mobile renderer.
Signing identity, app package and user data are never changed.
"""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project.godot"
PRESET = ROOT / "export_presets.cfg"


def configure(variant: str) -> None:
    if variant != "mobile":
        raise ValueError("Android export supports only mobile/vulkan")
    project = PROJECT.read_text(encoding="utf-8")
    preset = PRESET.read_text(encoding="utf-8")
    assert 'renderer/rendering_method="gl_compatibility"' in project, (
        "Headless desktop regression must remain compatible")
    assert project.count('renderer/rendering_method.mobile="mobile"') == 1
    assert project.count('rendering_device/driver.android="vulkan"') == 1
    assert 'renderer/rendering_method.mobile="gl_compatibility"' not in project
    # Version advances every approved milestone. The previous hard-coded
    # 75.105/code 95 assertions silently broke manual APK export of V75.117
    # despite the complete native CI being green. Validate consistency of
    # the CURRENT preset instead of asserting a stale milestone.
    version_match = re.search(
        r'(?m)^version/name="(\\d+)\\.(\\d+)\\.(\\d+)-mobile-vulkan"


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", choices=["mobile"], default="mobile")
    args = parser.parse_args()
    configure(args.variant)
,
        preset)
    code_match = re.search(r'(?m)^version/code=(\\d+)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", choices=["mobile"], default="mobile")
    args = parser.parse_args()
    configure(args.variant)
, preset)
    assert version_match is not None and code_match is not None, (
        "Missing ARM64 Mobile/Vulkan version metadata")
    major, minor, patch = map(int, version_match.groups())
    version_code = int(code_match.group(1))
    assert major == 75 and minor >= 105 and patch == 0, (
        "Unexpected preview version: " + version_match.group(0))
    assert version_code == minor - 10, (
        f"Version code {version_code} must match version 75.{minor}")
    assert preset.count('export_path="out/THEDEMIAN-V') == 1
    assert (
        'export_path="out/THEDEMIAN-V75.'
        + str(minor)
        + '-MOTOROLA-VULKAN.apk"'
    ) in preset, "No stale OpenGL/diagnostic APK path allowed"
    assert 'package/unique_name="com.thedemianff.lastzone.nativepreview"' in preset
    assert 'architectures/arm64-v8a=true' in preset
    assert 'architectures/armeabi-v7a=false' in preset
    print(f"AURORA_VULKAN_ONLY Android=mobile/vulkan "
          f"desktop=compatibility versionCode={version_code}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", choices=["mobile"], default="mobile")
    args = parser.parse_args()
    configure(args.variant)
