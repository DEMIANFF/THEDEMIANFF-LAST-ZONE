# THEDEMIANFF LAST ZONE V75.27 — Lobby and real customizable HUD

Base: `codex/v75-26-camera-controls-motion-polish`, physically confirmed on Motorola Edge 60 Fusion.

## Implemented
- Existing real animated/rigged GLB Lila lobby preview now rotates automatically and responds to touch/mouse dragging through the **existing 440 × 600 preview viewport**, with no extra 3D duplication.
- New original Aurora coast sidebar/backplates separate character preview, game mode selectors, local profile, and options, without showing fabricated online friends, battle pass purchases, credits or Google IDs.
- **AJUSTES → EDITAR CONTROLES / HUD** creates the actual Training scene, then enters a paused live HUD editor with all combat input suspended.
- Press/drag joystick, fire pad, sprint, aim, reload, swap weapon, jump, crouch, heal or deployable cover, and use touch toolbar **TAMAÑO −/+, OPACIDAD −/+, GUARDAR, RESTAURAR, CERRAR**. A selected button is highlighted; in-editor actions cannot trigger combat.
- Each control is stored with normalized safe-screen coordinates, scale (0.72–1.32), and opacity (0.35–1.0); restores the underlying action signal paths and uses original Godot controls, not replicas. Aircraft/freefall/parachute controls keep their original safe layouts to avoid obscuring flight controls.
- Layout saved to `user://aurora_hud_layout.cfg`, with strict validation and `.tmp` / `.bak` fallback. A failed write does not masquerade as a valid save. Closing without saving discards temporary changes. 'Restaurar' commits an empty layout and reverts to existing well-tested screen geometry.
- No changes to audio WAV crash fix, player locomotion, Firebase, online backend, anti-cheat, source assets, production keystore or legacy stable V44.

## What was NOT implemented
- Player online accounts / Firebase cloud backup, battle pass payment or a 50-human network match; these still need server-side implementation and testing.
- A permanent original Lila mesh. The current glTF rig is still provisional CC0 source, clearly labeled in lobby.
- Physics at 120 ticks (stays at 60). This feature adds no new render target while playing.

## Validation
- Run the full QA matrix in native Godot and from APK exported resources, including `v7527_lobby_hud_editor_qa.gd` for actual 3D lobby, paused scene, drag, scale, alpha, atomic save/backups, corrupted-file recovery, reset and return to lobby.
- Export Android ARM64 preview as **versionCode 29**, signed with the same GitHub encrypted preview keystore as V75.25/V75.26; package name `com.thedemianff.lastzone.nativepreview`. The workflow requires the pinned cert to match and refuses transient keys.
- Real device acceptance: update over V75.26, enter Ajustes and touch EDITAR HUD, drag/scale/alpha at 120 Hz, save, exit, relaunch both modes to confirm saved buttons and restored shooting, check original flight HUD, measure FPS and ensure WAV loop never crashes.
