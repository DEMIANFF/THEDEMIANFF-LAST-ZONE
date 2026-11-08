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
