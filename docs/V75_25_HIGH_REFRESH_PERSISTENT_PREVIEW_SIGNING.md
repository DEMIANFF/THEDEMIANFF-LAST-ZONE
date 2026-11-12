# V75.25 — 120Hz rendering and persistent Android preview signing

## Verified root causes

- V75.24 exposed only the frame caps **30 / 45 / 60** in its Aurora settings. The front end applied `Engine.max_fps` based on the saved preset, with a 45 FPS default.
- Prior CI generated an ephemeral Android debug keystore for each GitHub Actions runner, but did **not** set `keystore/debug` in the Godot export preset. Actual V75.22/23/24 APK certificates were different (Godot CN), and package IDs also changed on every version.
- **Android will not upgrade an APK unless the application ID and signing certificate match** and the new `versionCode` is higher.
- **It is cryptographically impossible to extract the old signing private key from V75.24's APK.** Do not claim it can upgrade to V75.25.

## New high-refresh behaviour

- `baja` 30 FPS, `media` 45, `alta` 60, `ultra` 90, `extrema` 120.
- New high-refresh preview defaults to `extrema`, and the FPS cap is saved across launches. Old valid settings, if any, still load.
- `application/run/max_fps=120` eliminates the pre-front-end 60 FPS ceiling.
- Android Swappy is enabled and configured with `swappy_mode=0` so it attempts to honor `Engine.max_fps` instead of automatically decreasing the configured limit.
- **Physics and AI remain at 60 ticks per second**, not 120, to avoid doubling navigation/collision costs and causing timing regressions to the recovered freefall or WAV audio.
- FPS counter displays measured frames, not configured target. Android 15/16 can still cap game refresh rate at 60Hz based on system policy, battery, thermal headroom and supported modes. 120 FPS is not guaranteed.

## Persistent non-production signing

New **preview-only package**: `com.thedemianff.lastzone.nativepreview`.

- VersionCode V75.25: `27`; increment for every future APK.
- **Pinned public certificate SHA-256**: `60390683c689ea7376dba5392450929e30044589189c9a200d4db54806f4a653`.
- GitHub Actions **requires** an encrypted repository secret `AURORA_PREVIEW_KEYSTORE_B64`. A missing or different certificate **fails** the workflow; a key is NEVER regenerated.
- `keystore/debug`, `keystore/debug_user` and `keystore/debug_password` are explicitly configured on the runner. `apksigner verify --print-certs` checks the resulting package fingerprint after export.
- The corresponding **preview-only key is intentionally not present in the repository**. The repository owner must retain an encrypted backup and upload base64 keystore bytes to the GitHub Actions repository secret; private key material must not appear in public commits or workflow logs.

**Owner setup (one time, from Termux):**

1. Save the independently provided private preview signing keystore `AURORA-V75.25-PREVIEW-KEYSTORE.p12` in a safe private location. Alias `androiddebugkey`, store password `android` (preview only).
2. `pkg install gh -y`; authenticate with `gh auth login` through the official GitHub browser flow.
3. If the file is in Android Downloads, run:
   ```bash
   base64 -w0 ~/storage/downloads/AURORA-V75.25-PREVIEW-KEYSTORE.p12 | gh secret set AURORA_PREVIEW_KEYSTORE_B64 -R DEMIANFF/THEDEMIANFF-LAST-ZONE
   ```
4. Rerun the branch workflow in GitHub Actions. It will reject missing or mismatched keystores rather than produce un-upgradable APKs.

**Migration:** V75.25 is a one-time separate preview installation. V75.24 cannot be upgraded due to an unrelated application ID and different private key. Keep V75.24 installed while validating V75.25 if its local progress matters. Later V75.26+ previews with the fixed package ID, this cert and increased versionCodes can update **V75.25 directly**, retaining that application's data.

**Production signing and player cloud account**: NEVER use this QA key for `com.thedemianff.lastzone` or Google/Firebase identity. To update a production app, the real release certificate/private key is required. This change does not touch V44 stable, Firebase configuration or Unity.

## Acceptance

- Source and exported QA pass with 30/45/60/90/120 FPS presets, persistent 120 selection and unchanged 60 physics ticks.
- Exported APK is signed with the pinned SHA-256 fingerprint and stable package ID; no transient Godot debug cert.
- Motorola real device: select `Extrema / 120 FPS`, enable 120Hz in system settings, watch measured FPS and temperature while playing Training and Battle Royale.
- Install a subsequent higher versionCode signed with the same key and confirm Android offers **Update**, not a second app or a certificate conflict.
