#!/usr/bin/env python3
"""Static foundation checks. Does NOT compile Unreal Engine code."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
project = json.loads((ROOT / "THEDEMIANFF.uproject").read_text())
assert project["FileVersion"] == 3
assert any(m["Name"] == "THEDEMIANFF" for m in project["Modules"])
assert any(p["Name"] == "EnhancedInput" and p["Enabled"] for p in project["Plugins"])

source = ROOT / "Source" / "THEDEMIANFF"
classes = {
    "AuroraCharacter": ("AAuroraCharacter", "SetupPlayerInputComponent", "PawnClientRestart"),
    "AuroraMobileController": ("AAuroraMobileController", "SetMobileMovement", "AddMobileLook", "SetMobileJump"),
    "AuroraTouchHUD": ("UAuroraTouchHUD", "UpdateMoveJoystick", "UpdateCameraDrag", "SetFirePressed"),
    "AuroraHeliosOutpost": ("AAuroraHeliosOutpost", "UInstancedStaticMeshComponent"),
    "AuroraPerformanceSettings": ("UAuroraPerformanceSettings", "ApplyGraphicsPreset"),
    "AuroraGameMode": ("AAuroraGameMode",),
}
for name, tokens in classes.items():
    header = source / f"{name}.h"
    cpp = source / f"{name}.cpp"
    assert header.is_file() and cpp.is_file(), f"Missing source for {name}"
    h, c = header.read_text(), cpp.read_text()
    assert f'#include "{name}.generated.h"' in h, f"Missing generated header: {name}"
    assert re.search(r"\bUCLASS\s*\(", h), f"Missing UCLASS: {name}"
    assert c.startswith(f'#include "{name}.h"'), f"CPP must include own header first: {name}"
    for token in tokens:
        assert token in h + c, f"Missing {token} in {name}"
    print(f"OK: {name}")

game_mode = (source / "AuroraGameMode.cpp").read_text()
assert "PlayerControllerClass = AAuroraMobileController::StaticClass()" in game_mode
assert "DefaultPawnClass = AAuroraCharacter::StaticClass()" in game_mode
config = (ROOT / "Config" / "DefaultEngine.ini").read_text()
assert "GlobalDefaultGameMode=/Script/THEDEMIANFF.AuroraGameMode" in config
print("PASS: Unreal foundation static checks (not an Unreal compilation)")
