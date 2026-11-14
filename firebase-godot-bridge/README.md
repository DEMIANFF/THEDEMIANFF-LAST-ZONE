# AuroraFirebase — Android plugin v2 (V75.75, isolated build)

This source module builds a **real Android AAR** implementing the Godot Android v2 singleton `AuroraFirebase`. It is **not included in the currently signed Vulkan preview game APK**. There is no `google-services.json` in this module, no production Firebase deployment and no account login test on a phone yet.

## Implemented

- The plugin extends `GodotPlugin`, registers manifest metadata `org.godotengine.plugin.v2.AuroraFirebase` and exposes `@UsedByGodot` methods.
- `getBridgeStatus()`: exact Android package guard, Firebase setup, **Play Integrity App Check** SDK startup, token availability without printing tokens. The method returns `app_check: token_ready` only after an SDK token request succeeds. **Only Cloud Functions validate the token server-side.**
- `beginGuestSignIn()`: real Firebase Auth anonymous session; does not replace an existing Google account.
- `beginGoogleSignIn()`: Credential Manager with Google ID credential. If the active user is anonymous, it uses `linkWithCredential`, preserving that Firebase UID. It refuses collisions instead of silently switching accounts. Other sessions use Firebase sign-in.
- After authentication, `ensurePlayerIdentity` callable assigns/reads a real sequential number by UID; then `getPlayerProfile` retrieves the server-held nickname. No player can choose a numeric ID by passing data to these functions.
- `getSessionState()` exposes **only status/ID/name metadata**, never Firebase ID tokens, access tokens, refresh tokens or App Check strings.
- All async tasks report safe error categories; no user secrets are put in logcat.

## Build in CI

`gradle -p firebase-godot-bridge :plugin:assembleDebug` using JDK 17 / Android SDK 36 / Gradle 8.13. Output (when CI succeeds): `plugin/build/outputs/aar/plugin-debug.aar`.

`/.github/workflows/aurora-firebase-android-plugin.yml` checks the AAR and uploads it **as a plugin build artifact, NOT an installable game APK**. This compile does not connect to Firebase or prove a working App Check attestation.

## Future activation — do not skip steps

1. In the Firebase Console, **add a second Android app** matching `com.thedemianff.lastzone.nativepreview`. Keep the old Android WebView application `com.thedemianff.lastzone` unchanged. Register the signing certificate's SHA-1 and SHA-256.
2. Enable Anonymous and Google in Firebase Authentication. Confirm the generated `default_web_client_id` belongs to the same Firebase project, but is the **web client ID** used by Google Credential Manager. Never use an Android OAuth client ID in that field.
3. Set up App Check with Play Integrity for the Godot package SHA-256 and appropriate sideload/outside-Google-Play recognition settings. Do not globally enforce it until real-device traffic is confirmed.
4. Install the **Godot Android Gradle Build Template** into a *separate test export*; apply the matching `google-services.json` only in the Gradle host's Android app module and enable the Google Services Gradle plugin there. The AAR itself is not the final host application and does not auto-create Firebase resources.
5. Install the AAR using a verified Godot v2 EditorExportPlugin and ensure the host Gradle app also includes all runtime Maven dependencies from `plugin/build.gradle.kts`. **An AAR alone does not bundle Firebase/Credential Manager transitive libraries.** Do not enable the editor plugin on the original signed preview until its export is proven stable.
6. Make a separate staged Godot APK. On the Motorola: verify `getBridgeStatus`, App Check attestation, anonymous UID, guest-to-Google **linking without changing UID**, `ensurePlayerIdentity`, `getPlayerProfile`, and restore after reinstall with the account.
7. Deploy V75.72/V75.73 Cloud Functions to a **test Firebase project** first. The older `ensurePlayerIdentity` callable and counter are still production-sensitive; no deployment in this V75.75 source branch.

## Security / honesty

A local App Check token is not automatically a verified session. Only server-side verification of the callable request is authoritative. The existing Godot local coins ledger is not migrated to an online wallet and diamonds/ranked remain offline-ineligible. The plugin does not edit existing Firebase Auth users, Firestore permissions, production settings or the stable V44 branch.

References: [Godot Android plugin v2](https://docs.godotengine.org/en/4.7/tutorials/platform/android/android_plugin.html), [Firebase Anonymous Auth](https://firebase.google.com/docs/auth/android/anonymous-auth), [Google Credential Manager with Firebase](https://firebase.google.com/docs/auth/android/google-signin), [App Check Play Integrity](https://firebase.google.com/docs/app-check/android/play-integrity-provider).
