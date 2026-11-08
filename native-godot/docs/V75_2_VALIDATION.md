# V75.2 — Motorola layout and recovery

Base: `codex/v75-1-real-match-progression`, commit `130e1fe9e2b9ab1dad9fac5510b2871a06d9eb48` (PR #12). Changes belong only to `codex/v75-2-motorola-recovery`; PR #12 is not merged.

## Reproducible validation

Requires Godot 4.7.2, Blender 4.0 (Ubuntu 24.04), Python 3 with NumPy and network access to the pinned CC0 source.

```bash
bash native-godot/tools/prepare_assets.sh
bash native-godot/tools/run_qa.sh
```

The runner isolates local profiles, requires both generated GLBs, checks import errors and fails on nonzero exit, timeout, `ERROR:` or `SCRIPT ERROR:` in each of 14 test logs. Outputs: `native-godot/out/qa`. The Android workflow repeats the tests, renders the eight reported Motorola screen states plus crouch at 2712×1220 and rejects blank side columns. It exports ARM64 only, checks the debug flag, verifies the APK signature and 16 KiB ZIP alignment, and publishes the SHA-256 and exact build commit. No source screenshots or output artifacts are included in the APK resource export.

## Corrections and evidence

| Area | Change | Regression evidence |
|---|---|---|
| Display / HUD | Expanded logical viewport, immersive edge-to-edge Android, safe insets for controls, landscape in either direction; repositioned gameplay controls and wrapping lobby rows | `responsive_layout_qa`, `capture_responsive_preview` (1280×720, 2712×1220, 2400×1080, 1024×768 geometry) |
| Movement / input | Preserve joystick magnitude; rescale deadzone; clear canceled touches, focus loss and round transitions | `v752_regression_qa`, existing multitouch/control suites |
| Camera | Preserve total swipe across event batching; speed limit applied per physics second; sweep shoulder camera sphere and shorten immediately at cover; recalculate independent airborne yaw after turning the body | `v752_regression_qa`, `camera_fire_qa` |
| Aircraft / drop | Fixed heading and world altitude, inherited ejection velocity, deployment clearance uses buildings as well as terrain | `launch_airdrop_qa`, `v752_regression_qa` |
| AI / roofs | Fresh line-of-sight before every shot; obstacle probes and retreat toward safe zone; closed convex roof collision and corrected surface winding | `sector_battle_qa`, `v752_regression_qa` |
| Animation | Pelvis descent, two-bone leg poses and foot compensation for crouch; crouch remains active during ADS/actions, locomotion loops; reset stance for deployment | `crouch_collision_qa`, head-height assertion in `v752_regression_qa` |
| Round lifecycle | Block actions after results; reset held inputs and combat timers; restart through aircraft without stale control state | `sector_battle_qa`, `v752_regression_qa` |
| Persistence | Hashed staged snapshot, validated primary/backup/temp selection, recovery and retry without counting a match twice; legacy JSON still readable; refuse silent overwrite when both existing saves are invalid | `persistent_match_qa`, `persistence_recovery_qa` |
| Lobby / assets | Aim preview camera after entering scene tree; deterministic model preparation before all visual tests | `launch_airdrop_qa`, `weapon_visual_qa`, rendered lobby |

## Installation and limits

`com.thedemianff.lastzone.nativepreview752` is a separate test application to avoid a signature conflict with V75.1 and preserve the installed profile. Its local ledger starts separately; no V75.1/V70 profile or Firebase data is migrated. Existing certificates and signing settings are unchanged. The pipeline performs its existing disposable debug signing flow; this is not a release-signing change.

This remains the offline nine-participant sector prototype. AI uses local obstacle avoidance, not complete navigation planning. Crouch has authored skeletal poses, not a full production animation/weapon-layer system. Automated geometry and desktop rendering do not certify Motorola touch feel, system insets, GPU performance or installation. On the device verify both landscape orientations, all eight reported screens, three-finger movement/fire/look, parachute steering independent of view, rooftop landing, crouch/stand clearance, completed-match save and reopen, and resume after backgrounding. Record FPS and any Android log errors during a full match.
