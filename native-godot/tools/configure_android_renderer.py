#!/usr/bin/env python3
"""Select a reproducible Android renderer at export time, without mixing
driver settings into the tested source code or changing the package identity.

The editor/source remains Godot GL Compatibility for its existing QA.
The Mobile APK overrides only Android using the supported .mobile setting.
Never touches signing, Firebase, game scenes, physics cadence or player data.
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project.godot"
PRESET = ROOT / "export_presets.cfg"

def replace_exact(data: str, old: str, new: str) -> str:
    count = data.count(old)
    if count != 1:
        raise ValueError(f"Expected exactly one setting {old!r}; found {count}")
    return data.replace(old, new, 1)

def configure(variant: str) -> None:
    if variant not in {"compat", "mobile"}:
        raise ValueError("Only compat/mobile are accepted")
    project = PROJECT.read_text(encoding="utf-8")
    config = PRESET.read_text(encoding="utf-8")
    assert 'renderer/rendering_method="gl_compatibility"' in project, (
        "Desktop QA must continue to use the proven Compatibility renderer")
    # The Android .mobile override determines rendering method on-device.
    project = re.sub(
        r'renderer/rendering_method\.mobile="(?:mobile|gl_compatibility)"',
        'renderer/rendering_method.mobile="' +
        ("mobile" if variant == "mobile" else "gl_compatibility") + '"',
        project,
    )
    # Keep an explicit mobile driver, not a desktop renderer exported by
    # accident. The driver entry belongs to the existing [rendering] section.
    key = 'rendering_device/driver.android="vulkan"\n'
    project = project.replace(key, "")
    if variant == "mobile":
        project = replace_exact(
            project,
            'renderer/rendering_method.mobile="mobile"\n',
            'renderer/rendering_method.mobile="mobile"\n' + key,
        )
    assert project.count("renderer/rendering_method.mobile=") == 1
    assert project.count(key) == (1 if variant == "mobile" else 0)
    # A/B builds must stay cross-installable and must have the SAME game
    # content and signing identity. Build paths differ; version code does not.
    assert 'version/code=41' in config
    assert 'package/unique_name="com.thedemianff.lastzone.nativepreview"' in config
    config = re.sub(
        r'version/name="75\.47\.0-(?:mobile-vulkan|compat-opengl)"',
        'version/name="75.47.0-' +
        ("mobile-vulkan" if variant == "mobile" else "compat-opengl") + '"',
        config,
    )
    assert config.count('version/name="75.47.0-') == 1
    PROJECT.write_text(project, encoding="utf-8")
    PRESET.write_text(config, encoding="utf-8")
    print("AURORA_RENDER_CONFIG",
          "variant=" + variant,
          "android=" + ("mobile/vulkan" if variant == "mobile" else "compatibility/opengl"),
          "desktop=compatibility", "versionCode=41",
          "package=com.thedemianff.lastzone.nativepreview")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", required=True,
                        choices=("compat", "mobile"))
    configure(parser.parse_args().variant)
