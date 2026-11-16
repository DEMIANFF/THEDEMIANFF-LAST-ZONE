#!/usr/bin/env python3
"""Validate the current Android Mobile/Vulkan export without stale version pins.

Desktop headless QA remains Compatibility for software rendering; Android
always uses ARM64 Vulkan Mobile with the existing preview app identity.
No key, secret, manifest package or resource is modified here.
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

    # Validate a consistent preview milestone. Hardcoded V75.105 assertions
    # broke the V75.117 test export while allowing all native QA to succeed.
    match = re.search(
        r'(?m)^version/name="(\d+)\.(\d+)\.(\d+)-mobile-vulkan"$',
        preset)
    code_match = re.search(r'(?m)^version/code=(\d+)$', preset)
    assert match is not None and code_match is not None, (
        "Missing Mobile/Vulkan version metadata")
    major, minor, patch = map(int, match.groups())
    code = int(code_match.group(1))
    assert major == 75 and minor >= 105 and patch == 0, (
        "Unexpected preview version")
    assert code == minor - 10, (
        f"Preview versionCode {code} does not match 75.{minor}")
    expected_path = f'export_path="out/THEDEMIAN-V75.{minor}-MOTOROLA-VULKAN.apk"'
    assert expected_path in preset, "Stale OpenGL or diagnostic export path"
    assert preset.count('export_path="out/THEDEMIAN-V') == 1
    assert 'package/unique_name="com.thedemianff.lastzone.nativepreview"' in preset
    assert 'architectures/arm64-v8a=true' in preset
    assert 'architectures/armeabi-v7a=false' in preset
    assert 'architectures/x86=false' in preset
    assert 'architectures/x86_64=false' in preset
    print(f"AURORA_VULKAN_ONLY Android=mobile/vulkan "
          f"desktop=compatibility versionCode={code}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", choices=["mobile"], default="mobile")
    args = parser.parse_args()
    configure(args.variant)
