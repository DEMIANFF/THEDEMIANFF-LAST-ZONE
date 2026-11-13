#!/usr/bin/env python3
"""V75.48: verify Android Mobile/Vulkan export; never rebuild OpenGL APKs.

The desktop editor keeps Compatibility for reproducible headless regression.
The Motorola preview uses only the native Android Vulkan Mobile renderer.
Signing identity, app package and user data are never changed.
"""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project.godot"
PRESET = ROOT / "export_presets.cfg"


def configure(variant: str) -> None:
    if variant != "mobile":
        raise ValueError("V75.48 Android export supports only mobile/vulkan")
    project = PROJECT.read_text(encoding="utf-8")
    preset = PRESET.read_text(encoding="utf-8")
    assert 'renderer/rendering_method="gl_compatibility"' in project, (
        "Headless desktop regression must remain compatible")
    assert project.count('renderer/rendering_method.mobile="mobile"') == 1
    assert project.count('rendering_device/driver.android="vulkan"') == 1
    assert 'renderer/rendering_method.mobile="gl_compatibility"' not in project
    assert 'version/code=42' in preset
    assert 'version/name="75.48.0-mobile-vulkan"' in preset
    assert 'package/unique_name="com.thedemianff.lastzone.nativepreview"' in preset
    print("AURORA_VULKAN_ONLY Android=mobile/vulkan desktop=compatibility versionCode=42")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", choices=["mobile"], default="mobile")
    args = parser.parse_args()
    configure(args.variant)
