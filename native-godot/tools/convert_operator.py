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
from mathutils import Vector, Quaternion

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
print('ARM_DIRECTION', [(b.name, (b.tail_local-b.head_local)[:]) for b in arm.data.bones if b.name.endswith(('LeftArm','RightArm'))])
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
    if any(k in n for k in ['leftforearm', 'lforearm', 'forearml']):
        return 'forearm_l'
    if any(k in n for k in ['rightforearm', 'rforearm', 'forearmr']):
        return 'forearm_r'
    if any(k in n for k in ['leftarm', 'lupperarm', 'upperarml', 'shoulderl']):
        return 'arm_l'
    if any(k in n for k in ['rightarm', 'rupperarm', 'upperarmr', 'shoulderr']):
        return 'arm_r'
    if any(k in n for k in ['spine', 'chest']):
        return 'spine'
    return ''

# Skeletal pose quality gate: optimize each actual upper-arm joint against
# an anatomical hand target. Unlike fixed Euler guesses, this samples the FBX
# rest matrices, and measures the resulting world-space wrist/shoulder points.
def _relaxed_arm_poses():
    result = {}
    bpy.context.view_layer.update()
    for side in ("Right", "Left"):
        arm_name = next((b.name for b in arm.pose.bones if b.name.endswith(side + "Arm")), None)
        hand_name = next((b.name for b in arm.pose.bones if b.name.endswith(side + "Hand")), None)
        if not arm_name or not hand_name:
            raise RuntimeError("Rig is missing " + side + "Arm/Hand")
        upper = arm.pose.bones[arm_name]
        hand = arm.pose.bones[hand_name]
        upper.rotation_mode = 'QUATERNION'
        upper.rotation_quaternion = Quaternion((1.0, 0.0, 0.0, 0.0))
        bpy.context.view_layer.update()
        shoulder = arm.matrix_world @ upper.matrix.translation
        original_hand = arm.matrix_world @ hand.matrix.translation
        delta = original_hand - shoulder
        assert delta.length > 0.1, "Armature wrist is coincident with shoulder"
        # Reduce sideways extension to 35%, and place the wrist near hip height.
        # In the FBX scene the actual shoulder Y coordinate is ~159 cm;
        # down is -Y, not -Z. Earlier code pushed wrists behind the back.
        target = shoulder + Vector((delta.x * .32, -delta.length * .69, delta.length * .05))
        axes = [
            Vector((1,0,0)), Vector((0,1,0)), Vector((0,0,1)),
            Vector((1,1,0)), Vector((1,-1,0)),
            Vector((1,0,1)), Vector((1,0,-1)),
            Vector((0,1,1)), Vector((0,1,-1)),
            Vector((1,1,1)), Vector((1,-1,1))]
        angles = [-2.25,-1.90,-1.55,-1.20,-.86,-.52,0,.52,.86,1.20,1.55,1.90,2.25]
        best = Quaternion((1.0,0.0,0.0,0.0))
        base_cost = (original_hand-target).length_squared
        cost = base_cost
        for axis in axes:
            for angle in angles:
                candidate = Quaternion(axis.normalized(), angle)
                upper.rotation_quaternion = candidate
                bpy.context.view_layer.update()
                wrist = arm.matrix_world @ hand.matrix.translation
                error = (wrist - target).length_squared
                if error < cost:
                    best, cost = candidate.copy(), error
        upper.rotation_quaternion = best
        bpy.context.view_layer.update()
        corrected_hand = arm.matrix_world @ hand.matrix.translation
        result["arm_" + side.lower()[0]] = best.copy()
        print("ANATOMICAL_ARM", side,
              "shoulder", tuple(round(v,2) for v in shoulder),
              "original_hand", tuple(round(v,2) for v in original_hand),
              "new_hand", tuple(round(v,2) for v in corrected_hand),
              "target", tuple(round(v,2) for v in target),
              "cost_reduction", round(1.0-cost/max(base_cost,.001),3))
    return result

base_arm_pose = _relaxed_arm_poses()

def _aim_arm_poses():
    """Fit both arms to separate grip and foregrip targets using BOTH elbow
    joints. Produces a simple authored combat pose, not full IK/mocap."""
    output={}
    for side in ("Right","Left"):
        shoulder_bone=arm.pose.bones["rig:"+side+"Arm"]
        forearm_bone=arm.pose.bones["rig:"+side+"ForeArm"]
        hand_bone=arm.pose.bones["rig:"+side+"Hand"]
        shoulder_bone.rotation_mode='QUATERNION'
        forearm_bone.rotation_mode='QUATERNION'
        shoulder_bone.rotation_quaternion=base_arm_pose["arm_"+side.lower()[0]].copy()
        forearm_bone.rotation_quaternion=Quaternion((1.0,0.0,0.0,0.0))
        bpy.context.view_layer.update()
        shoulder_world=arm.matrix_world @ shoulder_bone.matrix.translation
        wrist_start=arm.matrix_world @ hand_bone.matrix.translation
        total_arm_length=(wrist_start-shoulder_world).length
        # Right hand near trigger, left beneath forward handguard.
        target=shoulder_world+Vector((
            -math.copysign(total_arm_length*.30,shoulder_world.x),
            -total_arm_length*(.34 if side=="Right" else .38),
            total_arm_length*(.38 if side=="Right" else .62)))
        axes=[Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)),
              Vector((1,1,0)),Vector((1,-1,0)),Vector((0,1,1))]
        angles=[-.85,-.52,-.30,0,.30,.52,.85]
        initial_error=(wrist_start-target).length_squared
        for _ in range(3):
            for joint in (shoulder_bone,forearm_bone):
                initial_quat=joint.rotation_quaternion.copy()
                best_quat=initial_quat
                bpy.context.view_layer.update()
                current=(arm.matrix_world @ hand_bone.matrix.translation-target).length_squared
                for axis in axes:
                    for angle in angles:
                        candidate=(initial_quat @ Quaternion(axis.normalized(),angle))
                        joint.rotation_quaternion=candidate
                        bpy.context.view_layer.update()
                        error=(arm.matrix_world @ hand_bone.matrix.translation-target).length_squared
                        if error<current:
                            best_quat=candidate.copy()
                            current=error
                joint.rotation_quaternion=best_quat
                bpy.context.view_layer.update()
        actual=arm.matrix_world @ hand_bone.matrix.translation
        output["arm_"+side.lower()[0]]=shoulder_bone.rotation_quaternion.copy()
        output["forearm_"+side.lower()[0]]=forearm_bone.rotation_quaternion.copy()
        print("AURORA_ARMED_POSE",side,"target",tuple(round(v,2) for v in target),
              "wrist",tuple(round(v,2) for v in actual),
              "error_cm",round((actual-target).length,2),
              "starting_error_cm",round(math.sqrt(initial_error),2))
        assert (actual-target).length<total_arm_length*.7, "Weapon grip pose failed anatomical fit"
    return output

armed_pose=_aim_arm_poses()

def pose_crouch(phase, walking):
    # Source FBX has Y-up coordinates and centimetre-scale bone offsets.
    # Solve each thigh/shin chain to its authored foot target after lowering hips.
    hips = arm.pose.bones["rig:Hips"]
    hips.location = Vector((0.0, -58.0 * (math.sin(phase*.5)*.32 if clip_name == "AuroraLand" else 1.0), 0.0))
    hips.keyframe_insert(data_path="location")
    for side, sign in [("Left", 1.0), ("Right", -1.0)]:
        thigh = arm.pose.bones["rig:" + side + "UpLeg"]
        shin = arm.pose.bones["rig:" + side + "Leg"]
        foot = arm.pose.bones["rig:" + side + "Foot"]
        original_hip = thigh.bone.head_local
        original_knee = shin.bone.head_local
        original_foot = foot.bone.head_local
        hip = original_hip + hips.location
        target = original_foot.copy()
        if walking:
            target.z += math.sin(phase) * sign * 12.0
            target.y += max(0.0, math.cos(phase) * sign) * 3.0
        upper_rest = original_knee - original_hip
        lower_rest = original_foot - original_knee
        direction = (target - hip).normalized()
        distance = (target - hip).length
        along = (upper_rest.length_squared - lower_rest.length_squared + distance**2) / (2.0 * distance)
        bend = (Vector((0,0,1)) - direction * direction.z).normalized()
        knee = hip + direction * along + bend * math.sqrt(max(0.0, upper_rest.length_squared - along**2))
        upper = upper_rest.rotation_difference(knee - hip)
        lower = lower_rest.rotation_difference(target - knee)
        for bone, rotation in [(thigh, upper), (shin, upper.inverted() @ lower), (foot, lower.inverted())]:
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = rotation
            bone.keyframe_insert(data_path="rotation_quaternion")

# Use authored foot positions, a two-bone knee solve and pelvis motion during
# the locomotion clips. This is a provisional procedural gait, not mocap or
# finished two-handed weapon IK.
def pose_ground_gait(phase, running):
    hips=arm.pose.bones["rig:Hips"]
    hips.location=Vector((0.0,(1.8 if running else 1.0)*(1.0-math.cos(2.0*phase)),0.0))
    hips.keyframe_insert(data_path="location")
    stride=23.0 if running else 14.0
    lift=10.0 if running else 6.0
    for side,sign in [("Left",1.0),("Right",-1.0)]:
        thigh=arm.pose.bones["rig:"+side+"UpLeg"]
        shin=arm.pose.bones["rig:"+side+"Leg"]
        foot=arm.pose.bones["rig:"+side+"Foot"]
        hip=thigh.bone.head_local+hips.location
        knee_rest=shin.bone.head_local
        foot_rest=foot.bone.head_local
        upper_rest=knee_rest-thigh.bone.head_local
        lower_rest=foot_rest-knee_rest
        swing=math.sin(phase)*sign
        target=foot_rest+Vector((0.0,max(0.0,swing)*lift,math.cos(phase)*sign*stride))
        diff=target-hip
        reach=max(.001,diff.length)
        d=min(reach,(upper_rest.length+lower_rest.length)*.995)
        direction=diff/reach
        along=(upper_rest.length_squared-lower_rest.length_squared+d*d)/(2.0*d)
        bend=Vector((0,0,1))-direction*direction.z
        if bend.length_squared<.0001:
            bend=Vector((1,0,0))
        bend.normalize()
        knee=hip+direction*along+bend*math.sqrt(max(0.0,upper_rest.length_squared-along*along))
        upper=upper_rest.rotation_difference(knee-hip)
        lower=lower_rest.rotation_difference(target-knee)
        # Keep a visible opposing thigh swing even when the fitted knee chain
        # sits near its straight-leg extension; the old solver locked thighs
        # during armed walking despite a moving ankle/pelvis.
        swing_upper=upper @ Quaternion(Vector((1,0,0)),swing*(.25 if running else .19))
        for bone,rotation in [(thigh,swing_upper),(shin,swing_upper.inverted() @ lower),(foot,lower.inverted())]:
            bone.rotation_mode='QUATERNION'
            bone.rotation_quaternion=rotation
            bone.keyframe_insert(data_path='rotation_quaternion')


clips=[
    ('AuroraIdle',.012,60,False),
    ('AuroraWalk',.23,32,False),
    ('AuroraRun',.40,24,False),
    ('AuroraArmedIdle',.008,60,True),
    ('AuroraArmedWalk',.12,32,True),
    ('AuroraArmedRun',.20,24,True),
    ('AuroraAim',.004,40,True),
    ('AuroraAimAWM',.004,40,True),
    ('AuroraFire',.05,6,True),
    ('AuroraReloadAR',.10,48,True),
    ('AuroraReloadAWM',.10,93,True),
    ('AuroraHit',.035,10,True),
    ('AuroraLand',.035,12,True),
    ('AuroraJump',.12,30,True),
    ('AuroraFreefall',.09,36,False),
    ('AuroraParachute',.045,48,False),
    ('AuroraCrouch',.01,48,True),
    ('AuroraCrouchWalk',.10,28,True),
]
for clip_name, amplitude, frames, armed in clips:
    action = bpy.data.actions.new(clip_name)
    arm.animation_data.action = action
    crouched = clip_name.startswith("AuroraCrouch") or clip_name == "AuroraLand"
    # Additional gait samples smooth alternation of feet and weight transfer.
    key_frames=sorted({1+int(round(frames*step/12)) for step in range(13)}) if clip_name in (
        "AuroraWalk","AuroraRun","AuroraArmedWalk","AuroraArmedRun") else [
        1,1+frames//4,1+frames//2,1+3*frames//4,1+frames]
    for frame in key_frames:
        phase = math.tau * (frame - 1) / frames
        scene.frame_set(frame)
        for bone in arm.pose.bones:
            assigned = role(bone.name)
            if not assigned or (crouched and assigned.startswith("leg_")):
                continue
            bone.rotation_mode = 'QUATERNION'
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
            if assigned.startswith('arm_'):
                # Combat clips preserve weapon grip; locomotion has modest sway.
                swing_amount=offset * (.35 if armed else 1.0)
                swing=Quaternion(Vector((1,0,0)),swing_amount)
                bone.rotation_quaternion=(armed_pose[assigned] if armed else base_arm_pose[assigned]) @ swing
                bone.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=bone.name)
            elif assigned.startswith('forearm_'):
                bone.rotation_quaternion=armed_pose[assigned] if armed else Quaternion((1.0,0.0,0.0,0.0))
                bone.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=bone.name)
            else:
                bone.rotation_quaternion = Quaternion(Vector((1,0,0)), offset)
                bone.keyframe_insert(data_path='rotation_quaternion', frame=frame, group=bone.name)
        # Authored upper-body actions, blended with moving legs by Godot.
        progress = (frame - 1) / frames
        pulse = math.sin(math.pi * progress)
        if clip_name.startswith("AuroraReload"):
            for side, amount in [("Left", 1.0), ("Right", .25)]:
                forearm = arm.pose.bones["rig:" + side + "ForeArm"]
                forearm.rotation_mode = "QUATERNION"
                forearm.rotation_quaternion = armed_pose["forearm_" + side.lower()[0]] @ Quaternion(Vector((1,0,0)), pulse * amount)
                forearm.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        if clip_name in ("AuroraFire", "AuroraHit"):
            spine = arm.pose.bones["rig:Spine"]
            spine.rotation_mode = "QUATERNION"
            spine.rotation_quaternion = Quaternion(Vector((1,0,0)), -.10 * pulse if clip_name == "AuroraFire" else .16 * pulse)
            spine.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        if crouched:
            pose_crouch(phase, clip_name == "AuroraCrouchWalk")
        else:
            hips = arm.pose.bones["rig:Hips"]
            hips.location = Vector((0,0,0))
            hips.keyframe_insert(data_path="location", frame=frame)
            for side in ("Left","Right"):
                for suffix in ("Leg","Foot"):
                    bone = arm.pose.bones["rig:" + side + suffix]
                    bone.rotation_mode = "QUATERNION"
                    bone.rotation_quaternion = Quaternion((1,0,0,0))
                    bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)
            if clip_name in ("AuroraWalk","AuroraRun","AuroraArmedWalk","AuroraArmedRun"):
                pose_ground_gait(phase,clip_name.endswith("Run"))
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
