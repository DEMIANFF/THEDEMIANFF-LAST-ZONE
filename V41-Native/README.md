# THEDEMIANFF LAST ZONE — V41 Native Unity Rebuild

This is a **separate Unity 6 / C# native Android project**. It does not load the V40 HTML/WebView runtime. V40 is preserved on its original branch.

## First playable milestone
- 3D test arena with a few buildings, doors, roofs, obstacle rocks, snowy surfaces and safe spawning.
- Third-person CharacterController with gravity, jump, roof landing, collision and camera obstruction handling.
- Touch joystick + drag-to-look + fire/aim/jump controls, plus keyboard/mouse for Editor testing.
- Hitscan test rifle, reload, simple target dummies, health/ammunition HUD.
- Android-oriented quality profile, frame target selectable up to 120 (actual performance depends on hardware and refresh rate).
- Primitive **test assets only**. Lila's realistic rig/animation and polished Puerto Aurora assets are **not yet implemented**.

## Open
1. Install Unity Editor 6000.0.x with Android Build Support (SDK/NDK/OpenJDK).
2. Open the `V41-Native` folder in Unity Hub.
3. Wait for packages to resolve. Open menu **THEDEMIANFF > V41 > Create Native Test Scene**.
4. Press Play in the Editor; save scene as `Assets/Scenes/V41_Test.unity` when prompted.
5. For Android, choose Android as active Build Profile and use **THEDEMIANFF > V41 > Configure Android**. Build through Unity's Android build pipeline.

## Project architecture
`Assets/Scripts/V41Bootstrap.cs` builds test level and actors.
`Assets/Scripts/V41Player.cs` controls movement, aiming, third-person camera, combat and HUD.
`Assets/Scripts/V41Touch.cs` owns finger identities for independent joystick/look/button input.
`Assets/Editor/V41ProjectTools.cs` creates a saved Editor scene and Android configuration.

## Important constraints
A Unity Android build requires an editor/build machine or properly provisioned CI runner **and Unity license activation**. Termux alone cannot run Unity Editor. No claim is made that this code has already been compiled or benchmarked. The objective is first to obtain a valid native APK, then measure stutter, collisions and responsiveness on the Motorola Edge 60 Fusion.

The legacy `app/` and V40 GitHub Actions APK are unrelated to this native project's build output.

## GitHub Actions native build (separate from V40)

Workflow: `.github/workflows/v41-unity-android.yml` on branch `v41-native-unity-rebuild`.
It uses Unity 6000.0.60f1 and game-ci. A valid Unity activation is required.
Set the GitHub Actions repository secret `UNITY_LICENSE`, or the supported Unity account secrets `UNITY_EMAIL` and `UNITY_PASSWORD`. Never paste credentials in chat.
Use Actions > **V41 Unity Native Android APK** > Run workflow. The job may fail until licensing, Unity packages and C# compilation are validated. Successful completion should upload `THEDEMIANFF-V41-UNITY-NATIVE-APK`.
The legacy V40 workflow is not a native build.

**First benchmark:** 60 FPS requested (not guaranteed). Test actual FPS, frame-time spikes, camera collisions, rooftop landings and Android touch controls. The native test package ID differs from V40 so both versions can coexist.
