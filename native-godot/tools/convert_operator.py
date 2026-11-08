"""Convert a vetted CC0 female mechanic humanoid FBX into an Android-friendly GLB.

Run with Blender (not standard Python):
    blender --background --python convert_operator.py -- source.fbx source.png output.glb

The source is authored by s0ck3t/VideoIntoBlenderModel contributors, declared CC0-1.0
at assets/LICENCES.md. This is a temporary female Aurora operator visual,
NOT final original Lila art. No Free Fire / Blood Strike assets are copied.
"""
import bpy
import sys
from pathlib import Path
import math

args = sys.argv[sys.argv.index("--") + 1:]
fbx, atlas, out = map(Path, args[:3])
assert fbx.is_file() and atlas.is_file(), "missing vetted source asset"
out.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(fbx), use_anim=False, use_image_search=True)

meshes = [o for o in bpy.data.objects if o.type == 'MESH']
armatures = [o for o in bpy.data.objects if o.type == 'ARMATURE']
assert meshes, 'FBX source contains no mesh; abort'
assert armatures, 'FBX source contains no skeleton; abort'
arm = max(armatures, key=lambda o: len(o.data.bones))
print('OPERATOR_MESHES', len(meshes), 'BONES', len(arm.data.bones))
print('BONE_NAMES', ','.join(b.name for b in arm.data.bones)[:2000])
# Mobile optimization: discard unneeded ARKit facial morph targets, keep the full rig.
for obj in meshes:
    if obj.data.shape_keys:
        keys = obj.data.shape_keys.key_blocks
        for idx in range(len(keys)-1,0,-1):
            obj.shape_key_remove(keys[idx])
        print('REMOVED_UNUSED_FACIAL_MORPHS',obj.name)

image = bpy.data.images.load(str(atlas), check_existing=True)
image.scale(1024, 1024)
image.pack()

# Preserve original image maps when import succeeded; assign the CC0 atlas to
# materials missing texture nodes rather than shipping untextured geometry.
for obj in meshes:
    if not obj.data.materials:
        obj.data.materials.append(bpy.data.materials.new('AuroraOperatorPBR'))
    for mat in obj.data.materials:
        if mat is None:
            continue
        mat.use_nodes = True
        bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf is None:
            bsdf = mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
            output = next((n for n in mat.node_tree.nodes if n.type == 'OUTPUT_MATERIAL'), None)
            if output:
                mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
        bsdf.inputs['Roughness'].default_value = 0.73
        bsdf.inputs['Metallic'].default_value = 0.04
        textures = [n for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE']
        if not textures:
            tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
            tex.image = image
            mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
        else:
            for tex in textures:
                if tex.image and (not tex.image.has_data or
                                  not Path(bpy.path.abspath(tex.image.filepath)).is_file()):
                    tex.image = image
                if tex.image and tex.image.size[0] > 1024:
                    tex.image.scale(1024, 1024)
                if tex.image:
                    tex.image.pack()
        mat.blend_method = 'OPAQUE' if hasattr(mat, 'blend_method') else 'OPAQUE'

# Add a small, genuine articulated locomotion set using named pose-bone channels.
# These are deliberately modest authoring clips, not fictitious mocap/AAA animation.
arm.animation_data_create()
scene = bpy.context.scene
scene.render.fps = 30

def norm(name):
    return ''.join(ch for ch in name.lower() if ch.isalnum())

def role(bone_name):
    n = norm(bone_name)
    if any(k in n for k in ['leftupleg', 'lthigh', 'thighl', 'upperlegl']):
        return 'leg_l'
    if any(k in n for k in ['rightupleg', 'rthigh', 'thighr', 'upperlegr']):
        return 'leg_r'
    if any(k in n for k in ['leftarm', 'lupperarm', 'upperarml', 'shoulderl']):
        return 'arm_l'
    if any(k in n for k in ['rightarm', 'rupperarm', 'upperarmr', 'shoulderr']):
        return 'arm_r'
    if any(k in n for k in ['spine', 'chest']):
        return 'spine'
    return ''

for clip_name, amplitude, frames in [('AuroraIdle', 0.012, 60),
                                     ('AuroraWalk', 0.23, 32),
                                     ('AuroraRun', 0.40, 24)]:
    action = bpy.data.actions.new(clip_name)
    arm.animation_data.action = action
    for frame in [1, 1 + frames // 4, 1 + frames // 2,
                  1 + 3 * frames // 4, 1 + frames]:
        phase = math.tau * (frame - 1) / frames
        scene.frame_set(frame)
        for bone in arm.pose.bones:
            assigned = role(bone.name)
            if not assigned:
                continue
            bone.rotation_mode = 'XYZ'
            if assigned == 'leg_l':
                offset = amplitude * math.sin(phase)
            elif assigned == 'leg_r':
                offset = -amplitude * math.sin(phase)
            elif assigned == 'arm_l':
                offset = -amplitude * .6 * math.sin(phase)
            elif assigned == 'arm_r':
                offset = amplitude * .6 * math.sin(phase)
            else:
                offset = min(.035, amplitude * .14) * math.sin(phase)
            bone.rotation_euler[0] = offset
            bone.keyframe_insert(data_path='rotation_euler', frame=frame, group=bone.name)
    track = arm.animation_data.nla_tracks.new()
    track.name = clip_name
    strip = track.strips.new(clip_name, 1, action)
    strip.action_frame_start = 1
    strip.action_frame_end = 1 + frames
    arm.animation_data.action = None

# Preserve the FBX native scale; Godot normalizes placement in scene.
bpy.ops.export_scene.gltf(
    filepath=str(out),
    export_format='GLB',
    use_selection=False,
    export_animations=True,
    export_nla_strips=True,
    export_apply=False,
    export_image_format='JPEG',
)
print('OPERATOR_GLTF_EXPORTED', out, out.stat().st_size)
assert out.stat().st_size < 35_000_000, 'Character mesh exceeds the V72 preview budget'
assert out.stat().st_size > 100_000, 'Export unexpectedly empty'
