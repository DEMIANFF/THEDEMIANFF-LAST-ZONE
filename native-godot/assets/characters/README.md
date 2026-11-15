# Lila Aurora and skinned rivals

`lila_aurora.glb` is the playable Lila and the lobby preview. It is prepared
from the developer-supplied `rigged-model(1).glb` (56 bones, 57 source clips).
The game asset keeps the original skinned mesh and 2048px albedo, and includes
the clips used by the existing AnimationTree. Fabric colour overrides use a
clothing mask, preserving the baked base texture and the offline cosmetic IDs.

Lila's idle, gait, crouch, jump, land and bandage motions come from the source
rig. The source has no authored rifle/AWM combat, directional impact, freefall
or canopy clips. The prepared asset adds rig-specific poses for these actions,
including independent rifle and AWM recoil and reload. Air transitions are
driven by the existing flight controller. Hand fit, canopy straps and motion
polish must also be reviewed on a physical Motorola with Vulkan Mobile.

To rebuild the playable asset from the original supplied GLB:
```bash
python3 native-godot/tools/build_lila.py 'rigged-model(1).glb' \
  native-godot/assets/characters/lila_aurora.glb
```

The near-range AI rivals use a separate budgeted CC0 rig. The pinned FBX and
texture are validated by Git object hash before conversion. See
[CC0 source](https://github.com/s0ck3t/VideoIntoBlenderModel/blob/c1f1fa8f01524d60197c4d65306349e266d339cb/assets/LICENCES.md).

```bash
bash native-godot/tools/fetch_operator.sh /tmp/aurora-operator
blender --background --python native-godot/tools/convert_operator.py -- \
  /tmp/aurora-operator/attractor_mechanic_tpose.fbx \
  /tmp/aurora-operator/attractor_mechanic_tpose.png \
  native-godot/assets/characters/aurora_operator.glb
```
