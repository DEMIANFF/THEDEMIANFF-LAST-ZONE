# THEDEMIANFF LAST ZONE V70 unified quality pass

**Base:** V65 quality-fixes commit `505dbf34ea4ddb1053e00c98b4a5c9fd745009ff`.
**Work branch:** `codex/v70-unified-quality-release`.
**Android package:** `com.thedemianff.lastzone`; **versionCode:** 175; **versionName:** 70.0.0-aurora-unified.

## Integrated changes
- V65.1: AWM automatically operates the bolt for 0.50 seconds immediately following each shot; next shot requires a new press; manual action retired.
- V66: preserved existing hybrid TPS camera, x2/x4 plus AWM-exclusive x8, improved fast-swipe damping; relocated weapon HUD to prevent overlap with FUEGO.
- V67: deterministic low-poly snow crystals and illuminated survey markers instanced in two GPU batches; reset disposes resources. Original buildings and collision map kept intact.
- V68: nearby allied bots receive a bounded last-known-location alert and search for the player. Visibility checking interval adjusts to distance. AI remains offline.
- V69: selectable weapon slots and medkits in the match backpack; equipped weapon highlighted. Previously implemented visual store, missions, battle pass and saved progression preserved.
- V70: rolling real device FPS samples, average/min FPS, draw calls, triangles, render quality and scenic object count reported for testing. Battery saver prevents false low-FPS auto-scaling.

## Motorola Edge 60 Fusion physical QA checklist
1. **Install over V65, do not uninstall.** Check guest/Google sign-in, credits, XP, Firebase recovery and player ID.
2. Start training and royale: lobby, aircraft, map, jump, gold glider and landing.
3. Fire the AWM, observe 500 ms automatic cycling. Hold FUEGO longer: no repeat; lift and press again: one shot. Validate x8 scope.
4. Move, fire, ADS and rotate camera together. Verify x2/x4 on non-AWM weapons.
5. Ensure weapon HUD does not obscure FUEGO. Inspect compact landscape and custom HUD.
6. Open bag, tap a different weapon, then use a medkit when injured; check close/resume and ammunition.
7. Check Aurora props against terrain/architecture and AI squad reactions without seeing through walls.
8. Enable FPS overlay: record gameplay, scope, damage and landing FPS, visual glitches and device heat.

A passing CI pipeline does not certify physical touch/thermal/FPS behavior or network/Google recovery. This release **does not** implement real multiplayer with 100 human players or replace the engine with Unreal or Unity.
