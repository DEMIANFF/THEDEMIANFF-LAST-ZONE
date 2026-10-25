# Unity URP Android configuration — V41

This project references URP 17.0.3, but a package dependency **does not** automatically assign a Scriptable Render Pipeline asset.

## When Unity Editor is available

1. Open `V41-Native` in Unity 6000.0.60f1.
2. Create a URP Pipeline Asset (with Universal Renderer) via **Assets > Create > Rendering > URP Asset (with Universal Renderer)**.
3. Assign that asset in **Edit > Project Settings > Graphics > Default Render Pipeline** and in each enabled Quality tier.
4. For the initial Android benchmark use Forward rendering, HDR off, MSAA off or 2x, one directional light, conservative shadow distance, and no expensive post-processing.
5. Confirm Android ARM64, IL2CPP, landscape and both input backends in Player settings.
6. Build a development APK and inspect Android Logcat, frame timings and camera/physics tests on the target device.

## Performance strategy

- 60 FPS initial target, not a guarantee; increase only after stable device measurements.
- Profile GPU and CPU independently before choosing textures, shaders and scene complexity.
- Use LOD groups, occlusion culling, batching/instancing and texture compression only after validating the render path.
- Keep gameplay logic and render quality configurable independently.

## Current limitations

Termux can edit, version and statically inspect the Unity project, but it cannot run Unity Editor or validate the native URP pipeline. A native APK has **not** been produced. The runtime prints a warning if no SRP asset is assigned.
