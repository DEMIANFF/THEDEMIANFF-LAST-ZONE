# Unreal Android migration — development checklist

## What is available now
- UE C++ source project, Enhanced Input bindings, third-person pawn and Helios blockout actor.
- Source only: no compiled Android APK, no production art assets, no validated Unreal editor build.

## Required editor steps
1. Open `unreal/THEDEMIANFF.uproject` on a compatible desktop/cloud host with the matching Unreal version and C++ toolchain.
2. Compile the project. Resolve any version-specific compiler/API errors.
3. Create an empty level and save it as `Content/Maps/Aurora_Helios.umap`.
4. Set the level's GameMode to `AuroraGameMode`, and place a PlayerStart.
5. Place `AuroraHeliosOutpost` in the level; it is **a geometry blockout**, not finished architecture.
6. Create `IA_Move` (Axis2D), `IA_Look` (Axis2D), `IA_Jump` (Boolean), and `IMC_Aurora` (Input Mapping Context).
7. Create Blueprint subclass `BP_AuroraCharacter` and assign the input actions/context. Create `BP_AuroraGameMode` and set its Default Pawn to `BP_AuroraCharacter`. Assign this GameMode to the level.
8. Configure Android SDK/NDK/JDK through the official Epic Android setup and package a test APK.

## Mobile design
Input bindings can be connected to Android virtual joystick/touch UI later; no claim of working 4-finger touch yet.
Target graphics presets and frame rates will be validated on actual devices; 120Hz display does not imply 120 FPS.
Keep art asset licenses documented and do not check in temporary engine build products.

## Budget
GitHub + Termux source editing: free. A working Unreal editor and Android packaging host still require access to a compatible desktop/cloud GPU; no guaranteed permanent free service is assumed.
