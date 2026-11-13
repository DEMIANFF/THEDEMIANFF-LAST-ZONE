# THEDEMIAN: LAST ZONE V75.55 — One consolidated Vulkan APK (V75.51–V75.55)

## Decision and audited base
The user explicitly requested the scope planned as V75.51–V75.55 **in a single professional version**. This branch starts from actual V75.50 SHA `fb8d5438cc6f164eecb7a3f41744f35d6d708a80` and does not create intermediate binaries or discard any previous features.

- Godot 4.7.2; Android **Vulkan Mobile only**; ARM64; Android versionCode **45**.
- Same `com.thedemianff.lastzone.nativepreview` application identity and pinned preview signing certificate. No Firebase, Google or stored game-profile migration.
- Historic `v44-3-2-autosave-guest` is unchanged; V75.46–V75.50 form a strict code ancestry. The CI Linux renderer is compatible purely for headless Godot QA, not an extra Android APK.
- Requires CI on the new branch AND an actual Motorola Edge 60 Fusion check. "No errors" cannot be guaranteed from a desktop CI runner alone.

## Real integrated work, not five duplicate releases

### 1. Skinned character movement and camera (planned V75.51)
- Existing authored Lila rig/AnimationTree keeps upper-body weapon actions independent of locomotion.
- Add a bounded AnimationNodeTimeScale on **real CharacterBody3D horizontal velocity** for gait playback; no placeholder character or root motion; avoid apparent foot sliding when movement slows at house doors or covers.
- Retain the existing Walk/Run hysteresis, accurate footsteps, collision capsule, spring-style third-person follow and camera-obstruction probing.
- Running increases camera field of view slightly to reveal more surroundings; the established 4.6m third-person camera distance is unchanged and all x2/x4/AWM x8 zoom modes remain exclusive.

### 2. Combat visibility (planned V75.52)
- Opponents send actual world positions only when the player's physical damage call succeeds, allowing a camera-relative FRONT/REAR/LEFT/RIGHT danger indicator.
- Radiation and other environmental damage **never invent a shooter**; unconfirmed gunshot sounds do not reveal an attacker.
- Retains V75.50 AI finite ammunition, flanking, cover, real LOS, bullets, recoil and V75.49 three-second medkit interruption.

### 3. Physical level interactions (planned V75.53)
- Three phase-restricted supply objects appear at fixed positions when the existing zone moves into phases one, two and three, never during initial deployment. Each is the original, functioning Area3D loot pickup using the same terrain, actual interaction radius, collision checks and inventory limits.
- Each phase can add **at most one** supply: no infinite loot duplication or separate fake events.
- Existing 25 world loot sites, discoverable AWM, house floors, roofs, coastal lanes and navigational entrances stay intact.

### 4. Interactive inventory (planned V75.54)
- The inventory actually equips AR-7 or AWM via the same authoritative combat routine as the main HUD weapon button, with proper ownership enforcement. An AWM is unavailable until its real world weapon is collected.
- Shows the existing equipped ammo, bag, armor, medkits, barriers alongside genuine loot pickup count and recorded health damage inflicted on enemies.
- Buttons are genuine touch targets, and the panel retains mobile safe-screen layout and state resets after combat.

### 5. Real end-of-round results (planned V75.55)
- Shows rank among actual offline participants, eliminations, confirmed enemy HP damage, successful physical loot pickups and time survived.
- Rank uses live CharacterBody3D survivors; no fictional online human players.
- Atomic local match history, pending save recovery, retry results and player profile data remain unchanged (no new schema needed). Statistics reset on replay.

## Scope and acceptance
The new `v7555_unified_battle_royale_qa.gd` runs on actual `Main.tscn` and verifies real character AnimationTree, aim camera, damage bearing, inventory ownership, real AWM acquisition, collection of three phase supplies, accurate end screen, atomic save and reset. It joins **all previous 60 tests** and must also pass on exported Android resources.

The work consolidates those **five areas**, but does not pretend to complete every feature of a commercial online 50-human Battle Royale, production art, map editor, backend or the total goal of 1000 improvements.

## Motorola device checks
Install over V75.50 signed preview, **do not uninstall/clear data**. Verify Vulkan renderer in Settings, flights/parachute, camera free vs x2/x4/x8 ADS, character gait/turning, real shot origin arrows, indoor stairs and doors, physical phase supplies, inventory weapon switches, battle finish/ranking and persistent match history, at 9 then 20 then 30 offline participants. Record real FPS, temperature and crashes; a CI pass does not prove device stability.
