# THEDEMIANFF LAST ZONE — Unreal Engine migration

**Status: source scaffold only.** This is NOT an Unreal-built Android APK, a finished UE level, or a verified UE project. The existing Three.js Android game remains the playable version.

## Open on an Unreal-capable computer
1. Install Unreal Engine **5.6** via the official Epic Games Launcher. This scaffold targets 5.6 for reproducibility; engine version can be upgraded after testing.
2. Download this repository and open `Unreal/THEDEMIANFF_LAST_ZONE.uproject`.
3. Create a new level in the editor, save as `Content/Maps/Aurora_Helios_Preview.umap`.
4. Add a PlayerStart, floor, lighting, and a temporary character. Set the map as startup map after it exists.
5. Install the Android toolchain through Epic's Android setup instructions before attempting packaging.

## Scope of first vertical slice
- One traversable, detailed research facility (Complejo Helios)
- Third-person character and camera using Enhanced Input
- Touch HUD, movement, shooting and collision
- One bot, pickups and performance instrumentation
- Android shipping configurations: 30/60/90/120 FPS targets **subject to actual device support and profiling**

## Project structure
- `Config/`: portable project settings
- `Content/Maps/`: Helios vertical slice, later Aurora regions
- `Content/Characters/Lila/`: skeletal mesh, animation blueprint, outfits
- `Content/Weapons/`: meshes, firing and recoil
- `Content/AI/`: behavior trees and navigation
- `Content/Environment/Aurora/`: modular building kits and landscape
- `Docs/`: requirements and migration mapping

UE `.umap`, `.uasset`, cooked data and binary meshes must be authored/imported using an Unreal editor or compatible asset pipeline; they cannot be synthesized into valid editor assets merely by renaming files.

## Android-only workflow
Termux can edit Git-managed text, docs, shaders and configuration. It cannot run the desktop UE editor or cook an Android UE build natively. Use an authorized remote GPU workstation for visual editing and packaging. No guaranteed permanent free GPU desktop service is assumed.
