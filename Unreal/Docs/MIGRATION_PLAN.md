# Aurora Glacial: migration specification

## Current source of truth
- Existing playable project: Three.js + Android WebView, in existing branches.
- UE5 branch: independent experimental scaffold, **not a port yet**.
- Never overwrite stable `main`, `v21-hud-recovery`, or `v22-complete-upgrade`.

## First playable milestone
1. Real Unreal project opens without missing plugins.
2. Helios preview level loads with modular, non-cubic architecture.
3. Lila placeholder has third-person locomotion and touch camera.
4. Shooting, one AI bot, loot and two traversable entrances.
5. Android arm64 package installs and launches on a real phone.
6. Capture FPS/frame-time and memory; compare 60 and 120 FPS targets.

## Aurora world plan
Eight POIs: Cráter Aurora (center), Glaciar Espejo (north), Santuario de Hielo (northwest), Bosque Lumínico (northeast), Valle de los Ecos (west), Puerto Vórtex (east), Complejo Helios (southwest), Bahía de Cristal (southeast). Full 8 km × 8 km is a long-term World Partition design goal, not part of the first prototype.

## Visual quality tiers
Competitive: stable frame-time and responsive 4-finger HUD.
High: improved assets, textures and atmospheric effects.
Ultra: optional expensive effects only on supported GPUs.
120 FPS = 8.33 ms total frame budget, not a universal guarantee.
Mobile renderer capabilities differ from desktop UE5: avoid assuming desktop Nanite/Lumen feature parity.

## Asset pipeline
Create licensed/original modular meshes in Blender or DCC; export FBX/glTF as appropriate; import in UE editor. Use LODs, texture budgets, instancing, occlusion and mobile device profiles. Never commit third-party assets without appropriate rights.
