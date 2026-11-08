# Godot V75.3 — current development preview

Base: `codex/v75-2-motorola-recovery` at `3a61df64b59de94bf1fb8ffad4b8bbf3a538e851`.
Development branch: `codex/v75-3-battle-royale-improvements`.

This is an offline sector Battle Royale (one player and eight AI opponents), with training and local results. The original Lila artwork, network multiplayer and cloud account integration remain unfinished.

V75.3 adds collision-checked shared A* routes, wounded-enemy cover selection, physically traversable entrances, muzzle obstruction checks, layered reload/fire animations, saved camera sensitivity and bounded tracer reuse. Terrain placement now interpolates the actual collision triangles. See [the V75.3 validation plan](../docs/V75_3_VALIDATION.md).

Use Godot **4.7.2**, Blender **4.0.2**, Java **17** and Android build tools **35.0.1**:

```bash
bash native-godot/tools/prepare_assets.sh
bash native-godot/tools/run_qa.sh
godot --headless --path native-godot --export-debug "Android Preview" out/THEDEMIANFF-V75.3-MOTOROLA.apk
python3 native-godot/tools/verify_android_apk.py native-godot/out/THEDEMIANFF-V75.3-MOTOROLA.apk --build-tools "$ANDROID_HOME/build-tools/35.0.1" --logs native-godot/out
AURORA_QA_LOGS="$PWD/native-godot/out/qa-exported" bash native-godot/tools/run_exported_qa.sh native-godot/out/THEDEMIANFF-V75.3-MOTOROLA.apk
```

The debug package `com.thedemianff.lastzone.nativepreview753` installs separately from V75.2. Its local results/settings are independent; no automatic migration or Firebase synchronization is provided. Existing signing certificates are not changed. `BUILD.txt`, `apk-verification.json`, `signature.txt`, `alignment.txt` and `SHA256SUMS.txt` identify the exact build. Physical Motorola testing is still required.

## Historical development notes

# THEDEMIANFF LAST ZONE — native 3D rebuild (V71 foundation)

This is a **separate Godot 4.7.2 project** designed for a native Android battle royale. It lives next to — and does not replace — the signed Three.js/WebView V70 APK.

### Included at this milestone
- Native `CharacterBody3D` player collision controller, camera orbit and separate touch movement/look ownership.
- Continuous, non-square Aurora archipelago mesh and collision mesh; water surface and simple lighting.
- Ability to attach a reviewed `PackedScene` containing a rigged GLB operator.
- Headless scene boot/syntax smoke test in GitHub Actions.
- Architecture and asset acceptance contract in `docs/V71_REAL_BATTLE_ROYALE_MASTER_PLAN.md`.

### Intentionally *not* claimed
No finished realistic operator, weapon reload animations, networked 100-player battle royale, finished AAA buildings or Android native APK yet. The scene intentionally **does not substitute cube humanoids** if the production model is missing.

### Open on PC or Android
Open `native-godot/project.godot` with Godot 4.7.2. The Compatibility renderer provides the baseline for lower-memory devices; switch to Mobile only after device profiling. To validate with the Godot CLI:

```bash
godot --headless --path native-godot --editor --quit
godot --headless --path native-godot --script res://scripts/qa/smoke_test.gd
```

For production visuals, first acquire/create and license-audit operator rig, clips, PBR materials and building meshes, then assign them to the operator and scene instances. Use original assets or properly licensed sources.

## V73 tactical quality pass (preview, not release)
- Original V72 signed APK is unchanged. This branch uses `com.thedemianff.lastzone.nativepreview73`, a separately installed debug package.
- Real AK-74 GLB already present in the user's repository is reused as the assault-rifle visual, replacing a cylinder proxy. Its origin/licence must be audited before any public/commercial distribution.
- The same skinned female temporary operator GLB is instanced for four offline training bots (not real multiplayer). Bots patrol, scan line-of-sight, investigate and apply bounded damage, with respawn.
- Player health, touch sprint, jump and camera/control response added.
- The animation-generation pipeline now aims upper arms downward using each bone's rest orientation; screenshots and device playtesting remain required.

## V74: Aurora offline sector royale (limited vertical slice)
The new **INICIAR BR** button starts a physically simulated **9-fighter** mini-battle (player + 8 AI), including AI-vs-AI line-of-sight combat, permanent enemy eliminations, a hazard circle that shrinks and causes health loss, 16 world-loot auto-collect pickups, ammo/medkits, alive counter, victory/defeat, and restart. The original training sandbox remains available before the match starts. The sector is a small portion of Puerto Aurora, NOT an 8x8 km /100-server-player BR.

Automated tests: `scripts/qa/sector_battle_qa.gd` plus movement/camera/weapon checks. No Android phone performance claim until the user tests it. Debug package ID V74 `com.thedemianff.lastzone.nativepreview74` isolates it from V70 and saved Firebase data.
