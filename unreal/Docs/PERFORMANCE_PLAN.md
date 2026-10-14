# THEDEMIANFF Unreal — graphics and performance plan

Source-side presets: Competitive (70% resolution scale), Balanced (80%), Quality (90%), Ultra (100%). Presets set scalability variables where available. Target FPS values: 30, 60, 90, 120.

These are **requested caps**, not measured FPS or guarantees of display refresh. Android platform frame pacing and device profile overrides must be configured and validated after the Unreal project compiles. `r.ScreenPercentage` may not affect all mobile rendering paths as expected.

Validation criteria: actual frame pacing, GPU/CPU times, thermal throttling, sustained FPS over 20 minutes, memory use, and input latency. A 120 FPS target requires a total frame budget near 8.33 ms.

This C++ foundation has not been compiled in Unreal or tested on Android. Next: expose presets via a UMG menu, add platform profiles, measure on actual device.
