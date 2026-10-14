# Aurora mobile HUD — Unreal foundation

The C++ class `UAuroraTouchHUD` exposes Blueprint-callable methods for movement joystick, camera drag, jump, aim and fire. Aim/fire currently emit a Blueprint event only: there is **no weapon firing or ADS logic connected**.

## Editor work required
1. Compile the C++ project in Unreal.
2. Create a Widget Blueprint derived from `AuroraTouchHUD`.
3. Add independent touch regions and buttons for movement, camera, jump, aim, and fire.
4. Track touch pointer IDs separately for each control, handle cancel/lost-touch events, and never allow one finger to steal another control.
5. Convert joystick position to normalized X/Y and camera dragging to pixel deltas.
6. Bind press and release to `SetJumpPressed`, `SetAimPressed`, `SetFirePressed`; release joystick on touch end.
7. Bind `OnCombatInputChanged` to future weapon component logic.
8. Instantiate widget from the local player controller and add it to the viewport.
9. Test on an actual multitouch Android device, including four simultaneous fingers.

**Current status:** source scaffolding only. No UMG visual widget, input ownership implementation, 4-finger verification, APK, or compiled UE editor build yet.
