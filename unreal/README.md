# THEDEMIANFF LAST ZONE — Unreal migration

**Status:** source scaffold only; NOT compiled, tested in Unreal, or an Android APK.

## Android-only workflow

1. In Termux: `pkg install git`; `git clone -b unreal5-migration https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE.git`.
2. Files for Unreal are under `unreal/`. Keep the existing HTML/WebView game as a playable backup.
3. On a Windows machine with Unreal Engine 5.8 and Android SDK/NDK/JDK configured, open `unreal/THEDEMIANFF.uproject`, generate/build C++ project, then package for Android.
4. The editor must generate assets/maps. Source-only GitHub Actions runners are not a substitute for the UE5 installation and licensed engine/toolchain.

## Aurora visual vertical slice

Build one playable **Complejo Helios** environment first: a navigable laboratory, exterior architecture, doorways, lighting, ice/snow PBR materials, third-person character, mobile Enhanced Input, one enemy, one weapon, and a measurable performance profile. Only then expand to eight POIs.

## Quality targets

Provide configurable mobile scalability tiers; measure frame pacing at 30/60/90/120 FPS on compatible hardware. 120 FPS is a target, not a guarantee. Nanite/Lumen availability on mobile is constrained and must be validated per renderer/device.

## No-cost limitation

GitHub and Termux can host and edit source code without a GPU workstation. A free, persistent GPU Windows desktop with UE5 is **not guaranteed**. Avoid publishing secrets, paid cloud credentials or binary engine distributions in this repository.
