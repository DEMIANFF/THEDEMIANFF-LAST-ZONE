# Production asset gate — no placeholder humanoids

Current V70 GLB audit (measured by reading the JSON chunk from the actual APK):
| Original asset | Bytes | Position accessors | Skins | Clips | Materials | Images |
|---|---:|---:|---:|---:|---:|---:|
| lila-operator.glb | 92,144 | 5,516 | 0 | 0 | 0 | 0 |
| alternative-female-reference.glb | 24,823,060 | 497,400 | 0 | 0 | 1 | 1 |
| ak74-tactical.glb | 3,518,588 | 2,619 | 0 | 0 | 1 | 4 |
| weapons-pack.glb | 745,776 | 10,483 | 0 | 0 | 8 | 3 |

**Requirement**: All production operators must be licensed, rigged/skinned 3D GLB with authored animation clips and PBR materials. LOD and texture profiles for mobile are mandatory. A 3D model without skins/animations cannot honestly be marked as an animated production character.

**Copyright**: Existing `alternative-female-reference.glb` is not shipped into the native project until its licensing, optimization and rig are verified.

**Build**: Native preview starts without a visible primitive-humanoid if the audited character scene is missing. An intentionally unassigned production slot is more accurate than a cube-shaped stand-in.

**Auth**: Firebase/google assets and native Android release signing must be reviewed separately; neither this folder nor these smoke tests implement cloud account migration.
