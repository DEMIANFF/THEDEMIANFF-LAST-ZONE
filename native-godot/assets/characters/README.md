# Temporary female operator visual asset

This project **does not claim** that the developer's finalized Lila 3D model has been created.

For Android/Godot test builds we use a female CC0 rig published by the
contributors to [VideoIntoBlenderModel](https://github.com/s0ck3t/VideoIntoBlenderModel)
(`assets/rigs/attractor_mechanic_tpose.fbx`). Their
[`assets/LICENCES.md`](https://github.com/s0ck3t/VideoIntoBlenderModel/blob/c1f1fa8f01524d60197c4d65306349e266d339cb/assets/LICENCES.md)
registers this asset as `rig_attractor_mechanic`, CC0-1.0.

The pinned FBX and texture are downloaded and **validated using Git object hashes**
before Blender converts them into a texture-downscaled GLB. The result is bundled in
the preview APK at `res://assets/characters/aurora_operator.glb`.

This is a provisional character to measure actual shape/rig/animation in Godot.
No copyrighted models are extracted from Free Fire or Blood Strike.
Its short animation clips are authored by our Blender conversion script.

To generate locally with Blender installed:
```bash
bash native-godot/tools/fetch_operator.sh /tmp/aurora-operator
blender --background --python native-godot/tools/convert_operator.py -- \
  /tmp/aurora-operator/attractor_mechanic_tpose.fbx \
  /tmp/aurora-operator/attractor_mechanic_tpose.png \
  native-godot/assets/characters/aurora_operator.glb
```
The generated GLB is not checked into Git to prevent large binary diffs.
