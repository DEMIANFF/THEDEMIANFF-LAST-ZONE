"""Convert a vetted CC0 female mechanic humanoid FBX into an Android-friendly GLB.

Run with Blender (not standard Python):
    blender --background --python convert_operator.py -- source.fbx source.png output.glb

The source is authored by s0ck3t/VideoIntoBlenderModel contributors, declared CC0-1.0
at assets/LICENCES.md. The skinned CC0 body has original Aurora signature armor and
a sculpted, bone-weighted Aurora hairstyle. The imported face and body remain
provisional. No third-party game assets are copied.
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

# Add a coherent ORIGINAL Aurora tactical kit to the vetted skinned CC0 body.
# This is a Lila identity milestone, not yet an original face/hair/base sculpt.
# All pieces are single-bone weighted, in ONE mesh/drawable using three
# shared simple PBR materials; they move with authored skeletal animations.
def build_lila_aurora_signature():
    from mathutils import Matrix

    needed = [
        "rig:Hips", "rig:Spine", "rig:Head",
        "rig:LeftArm", "rig:RightArm",
        "rig:LeftForeArm", "rig:RightForeArm",
        "rig:LeftUpLeg", "rig:RightUpLeg",
    ]
    missing = [name for name in needed if arm.data.bones.get(name) is None]
    assert not missing, "Lila requires an articulated body: " + ", ".join(missing)

    def center(name):
        bone = arm.data.bones[name]
        return (bone.head_local + bone.tail_local) * 0.5

    hips = center("rig:Hips")
    spine = center("rig:Spine")
    head = center("rig:Head")
    shoulder_l = center("rig:LeftArm")
    shoulder_r = center("rig:RightArm")
    forearm_l = center("rig:LeftForeArm")
    forearm_r = center("rig:RightForeArm")
    knee_l = center("rig:LeftUpLeg")
    knee_r = center("rig:RightUpLeg")
    height = max(b.head_local.y for b in arm.data.bones) - min(
        b.tail_local.y for b in arm.data.bones)
    assert 135.0 < height < 260.0, "Lila FBX is not in expected centimetres"
    # Scale uniform authored additions to rig proportions, not a second
    # hardcoded one-size-fits-all body controller.
    k = height / 180.0
    chest_y = hips.y * .37 + head.y * .63
    front = spine.z + 12.0*k
    back = spine.z - 11.5*k

    colors = [
        ("LilaAuroraMidnightFabric", (.045, .105, .145, 1.0), .84, .08),
        ("LilaAuroraCopperArmor", (.58, .30, .14, 1.0), .51, .43),
        ("LilaAuroraSignalCyan", (.035, .68, .79, 1.0), .38, .12),
    ]
    materials = []
    for label, rgba, roughness, metallic in colors:
        mat = bpy.data.materials.new(label)
        mat.diffuse_color = rgba
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        if shader is None:
            shader = next(n for n in mat.node_tree.nodes
                          if n.type == "BSDF_PRINCIPLED")
        shader.inputs["Base Color"].default_value = rgba
        shader.inputs["Roughness"].default_value = roughness
        shader.inputs["Metallic"].default_value = metallic
        materials.append(mat)

    vertices, faces, face_materials = [], [], []
    bone_vertices = {}

    def plate(label, xyz, dims, material_index, bone_name):
        assert all(0.3*k <= d <= 45.0*k for d in dims), (
            "Out-of-bounds Lila kit piece: " + label)
        x, y, z = xyz
        dx, dy, dz = [a*.5 for a in dims]
        start = len(vertices)
        vertices.extend([
            (x-dx,y-dy,z-dz), (x+dx,y-dy,z-dz),
            (x+dx,y+dy,z-dz), (x-dx,y+dy,z-dz),
            (x-dx,y-dy,z+dz), (x+dx,y-dy,z+dz),
            (x+dx,y+dy,z+dz), (x-dx,y+dy,z+dz),
        ])
        for idx in (0, 1, 2, 3, 4, 5):
            quads = [
                (0,3,2,1), (4,5,6,7), (0,1,5,4),
                (3,7,6,2), (0,4,7,3), (1,2,6,5)]
            faces.append(tuple(start+i for i in quads[idx]))
            face_materials.append(material_index)
        bone_vertices.setdefault(bone_name, []).extend(range(start,start+8))
        print("LILA_GEAR_PART",label, "BONE",bone_name)

    # Original silhouette: restrained asymmetry rather than a copied
    # third-party battle-royale skin. Positive Z is the source model front.
    plate("inner_chest_harness",(spine.x,chest_y,front),
          (26*k,19*k,3*k),0,"rig:Spine")
    plate("aurora_chest_plaque",(spine.x,chest_y+3*k,front+2*k),
          (12*k,8*k,1.5*k),1,"rig:Spine")
    plate("signal_chest_stripe",(spine.x,chest_y+3*k,front+3.1*k),
          (9*k,1.5*k,.7*k),2,"rig:Spine")
    plate("left_chest_webbing",(spine.x-10*k,chest_y-2*k,front+2*k),
          (3*k,18*k,2*k),1,"rig:Spine")
    plate("right_chest_webbing",(spine.x+10*k,chest_y-2*k,front+2*k),
          (3*k,18*k,2*k),0,"rig:Spine")
    plate("left_pauldron",(shoulder_l.x,shoulder_l.y+1*k,
          shoulder_l.z+3*k),(12*k,6*k,11*k),0,"rig:LeftArm")
    plate("right_pauldron",(shoulder_r.x,shoulder_r.y+1*k,
          shoulder_r.z+3*k),(12*k,6*k,11*k),1,"rig:RightArm")
    plate("left_wrist_console",(forearm_l.x,forearm_l.y,
          forearm_l.z+3*k),(7*k,5*k,7*k),2,"rig:LeftForeArm")
    plate("right_wrist_guard",(forearm_r.x,forearm_r.y,
          forearm_r.z+3*k),(7*k,5*k,7*k),0,"rig:RightForeArm")
    plate("back_radio",(spine.x,chest_y-1*k,back),
          (15*k,19*k,6*k),0,"rig:Spine")
    plate("radio_antenna",(spine.x+4*k,chest_y+13*k,back-2*k),
          (1*k,13*k,1*k),2,"rig:Spine")
    plate("utility_belt",(hips.x,hips.y+3*k,hips.z+5*k),
          (32*k,7*k,5*k),0,"rig:Hips")
    plate("belt_emblem",(hips.x,hips.y+3*k,hips.z+8*k),
          (7*k,5*k,1*k),1,"rig:Hips")
    plate("left_utility_case",(hips.x-12*k,hips.y-5*k,hips.z+7*k),
          (8*k,12*k,6*k),1,"rig:Hips")
    plate("right_utility_case",(hips.x+12*k,hips.y-5*k,hips.z+7*k),
          (8*k,12*k,6*k),0,"rig:Hips")
    plate("left_knee_protector",(knee_l.x,knee_l.y-7*k,
          knee_l.z+7*k),(10*k,9*k,3*k),0,"rig:LeftUpLeg")
    plate("right_knee_protector",(knee_r.x,knee_r.y-7*k,
          knee_r.z+7*k),(10*k,9*k,3*k),1,"rig:RightUpLeg")
    plate("head_signal_band",(head.x,head.y+8*k,head.z+9*k),
          (17*k,3*k,2*k),2,"rig:Head")
    plate("headband_center",(head.x,head.y+8*k,head.z+10.6*k),
          (4*k,3*k,1*k),1,"rig:Head")

    mesh = bpy.data.meshes.new("LilaAuroraSignatureSkin")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    for mat in materials:
        mesh.materials.append(mat)
    for face, material in zip(mesh.polygons, face_materials):
        face.material_index = material
    obj = bpy.data.objects.new("LilaAuroraSignatureKit", mesh)
    bpy.context.collection.objects.link(obj)
    # Parent-local coordinates match armature rest-space; the armature
    # modifier deforms all accessories with the original CC0 skeletal clips.
    obj.parent = arm
    obj.matrix_parent_inverse = Matrix.Identity(4)
    for name, ids in bone_vertices.items():
        group = obj.vertex_groups.new(name=name)
        group.add(ids,1.0,'REPLACE')
    deform = obj.modifiers.new("LilaSkinToOriginalArmature","ARMATURE")
    deform.object = arm
    deform.use_deform_preserve_volume = True
    assert len(mesh.vertices)==19*8, "Every Lila kit piece must remain skinned"
    assert len(mesh.polygons)==19*6, "Only static low-poly armor is permitted"
    assert len(mesh.materials)==3
    print("LILA_SIGNATURE_KIT_PASS",len(mesh.vertices),"vertices",
          len(mesh.polygons),"faces",len(bone_vertices),"weighted_bones")
    return obj

lila_signature=build_lila_aurora_signature()

# A separate sculpted hairstyle authored for Lila. The imported face/body
# is still CC0; these strands and materials are original Aurora assets.
# Approx. 2k vertices in ONE additional skinned mesh, with no per-frame script.
def build_lila_aurora_hair():
    from mathutils import Matrix

    head_bone = arm.data.bones["rig:Head"]
    head = (head_bone.head_local + head_bone.tail_local) * 0.5
    spine = arm.data.bones["rig:Spine"]
    height = max(b.head_local.y for b in arm.data.bones) - min(
        b.tail_local.y for b in arm.data.bones)
    k = height / 180.0
    assert 135.0 < height < 260.0

    palette = [
        ("LilaAuroraHairMidnight", (.018, .034, .051, 1.0), .68, .0),
        ("LilaAuroraHairPetrol", (.048, .182, .214, 1.0), .56, .0),
        ("LilaAuroraHairCopperTie", (.58, .285, .116, 1.0), .34, .32),
    ]
    materials = []
    for name, color, rough, metal in palette:
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        material.diffuse_color = color
        shader = next(n for n in material.node_tree.nodes
                      if n.type == "BSDF_PRINCIPLED")
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = rough
        shader.inputs["Metallic"].default_value = metal
        materials.append(material)

    verts, polygons, mat_index = [], [], []
    # Blender vertex groups are bound to the EXISTING Mixamo-compatible bones.
    weights = {"rig:Head": [], "rig:Spine": []}

    def vertex(position, head_weight=1.0):
        index = len(verts)
        verts.append(tuple(position))
        weights["rig:Head"].append((index, head_weight))
        if head_weight < 0.9999:
            weights["rig:Spine"].append((index, 1.0 - head_weight))
        return index

    def quad(a,b,c,d,mat):
        polygons.append((a,b,c,d))
        mat_index.append(mat)

    # Layered asymmetrical scalp, not a textured primitive sphere or cubes.
    # The Y/Z orientation follows the vetted FBX; Z+ faces the viewer.
    scalp_levels = [
        (13.8, .35), (13.3, 2.5), (11.7, 5.5), (9.1, 7.8),
        (6.7, 8.9), (4.6, 9.35), (3.0, 9.1),
    ]
    columns = 24
    rings = []
    for layer, (y, radial) in enumerate(scalp_levels):
        ring = []
        for i in range(columns):
            angle = 2.0*math.pi*i/columns
            # Subtle off-centre parting, longer back of the crown.
            asymmetry = .3*math.sin(angle*2.0)
            x = head.x + (radial*math.cos(angle)+asymmetry)*k
            z = head.z + radial*math.sin(angle)*k
            ring.append(vertex(Vector((x,head.y+y*k,z))))
        rings.append(ring)
        if layer:
            for i in range(columns):
                j = (i+1)%columns
                quad(rings[layer-1][i], rings[layer-1][j],
                     ring[j],ring[i],0 if i%7 else 1)

    def strand(name, controls, start_radius, mat, spine_influence=0.0):
        assert len(controls)>=3
        circumference = 6
        paths=[]
        # Catmull interpolation produces curved, tapered locks without
        # unsupported Blender geometry-node or hair-particle dependencies.
        points=[Vector(v) for v in controls]
        samples=[]
        for segment in range(len(points)-1):
            p0=points[max(0,segment-1)]
            p1=points[segment]
            p2=points[segment+1]
            p3=points[min(len(points)-1,segment+2)]
            for step in range(3):
                u=step/3.0
                sample=.5*((2*p1)+(-p0+p2)*u+
                    (2*p0-5*p1+4*p2-p3)*(u*u)+
                    (-p0+3*p1-3*p2+p3)*(u*u*u))
                samples.append(sample)
        samples.append(points[-1])
        for step, point in enumerate(samples):
            phase=step/max(1,len(samples)-1)
            earlier=samples[max(0,step-1)]
            later=samples[min(len(samples)-1,step+1)]
            tangent=(later-earlier).normalized()
            ref=Vector((0,0,1))
            if abs(tangent.dot(ref))>.94:
                ref=Vector((1,0,0))
            normal=tangent.cross(ref).normalized()
            binormal=tangent.cross(normal).normalized()
            radius=start_radius*(.90*(1.0-phase)+.075)
            # Roots follow head; long rear locks ease into torso pose.
            hweight=1.0-spine_influence*phase*phase
            path=[]
            for side in range(circumference):
                angle=2*math.pi*side/circumference
                path.append(vertex(point+(normal*math.cos(angle)+
                    binormal*math.sin(angle))*radius,hweight))
            paths.append(path)
            if step:
                for side in range(circumference):
                    nxt=(side+1)%circumference
                    quad(paths[step-1][side],
                         paths[step-1][nxt],path[nxt],path[side],mat)
        # Close the tip to avoid a light-leaking open cylinder.
        tip=vertex(samples[-1],1.0-spine_influence)
        for side in range(circumference):
            polygons.append((paths[-1][side],
                             paths[-1][(side+1)%circumference],tip))
            mat_index.append(mat)
        print("LILA_HAIR_LOCK",name,"samples",len(samples))

    # Rear-layer flowing hair, graded into upper-back movement for soft turns.
    rear_count=18
    for i in range(rear_count):
        theta=math.pi+.055+(math.pi-.11)*i/(rear_count-1)
        x0=head.x+7.5*k*math.cos(theta)
        z0=head.z+7.8*k*math.sin(theta)
        length=(23.0+6.0*(i%4)/3.0)*k
        sway=(i-rear_count*.5)*.12*k
        strand("back_%02d"%i,[
            (x0,head.y+7.0*k,z0),
            (x0+sway*.4,head.y-1*k,z0-1*k),
            (x0+sway,head.y-length*.53,z0-2.9*k),
            (x0+sway*1.5,head.y-length,z0-4*k)
        ],(.72+.18*(i%3))*k,1 if i%5==0 else 0,.48)

    # Short side-swept fringe frames face instead of covering eyes.
    fringe_count=11
    for i in range(fringe_count):
        x0=head.x+(i-5)*1.38*k
        endx=x0+(3.0+2*(i/10))*k
        strand("fringe_%02d"%i,[
            (x0,head.y+11.3*k,head.z+5.3*k),
            (x0+.5*k,head.y+9*k,head.z+7.6*k),
            (endx,head.y+6.7*k,head.z+9.4*k),
            (endx+1.4*k,head.y+4.5*k,head.z+9.1*k)
        ],(.68+.15*(i%4))*k,1 if i%4==0 else 0)

    # One distinct tied side ponytail: no expensive real-time cloth solver.
    for i in range(5):
        x0=head.x-6.5*k+float(i-2)*1.2*k
        strand("left_tied_%02d"%i,[
            (x0,head.y+7.5*k,head.z-2.7*k),
            (x0-3.5*k,head.y+2.5*k,head.z-5*k),
            (x0-5*k,head.y-12*k,head.z-7.5*k),
            (x0-4*k+float(i-2)*.5*k,head.y-29*k,head.z-8*k)
        ],(1.05-.05*i)*k,1 if i==2 else 0,.42)

    # Copper tie near the ponytail root, still head-bone weighted.
    strand("signature_hair_tie",[
        (head.x-9.6*k,head.y+3*k,head.z-5.2*k),
        (head.x-10.2*k,head.y+2*k,head.z-5.8*k),
        (head.x-10.6*k,head.y+1*k,head.z-6.3*k)
    ],1.8*k,2)

    mesh=bpy.data.meshes.new("LilaAuroraHairSculpt")
    mesh.from_pydata(verts,[],polygons)
    mesh.update(calc_edges=True)
    for material in materials:
        mesh.materials.append(material)
    for poly, mi in zip(mesh.polygons,mat_index):
        poly.material_index=mi
        poly.use_smooth=True
    obj=bpy.data.objects.new("LilaAuroraOriginalHair",mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent=arm
    obj.matrix_parent_inverse=Matrix.Identity(4)
    for bone_name, assignments in weights.items():
        group=obj.vertex_groups.new(name=bone_name)
        for idx, amount in assignments:
            if amount>0.0:
                group.add([idx],amount,"REPLACE")
    deform=obj.modifiers.new("LilaHairHeadSpineSkin","ARMATURE")
    deform.object=arm
    deform.use_deform_preserve_volume=True
    assert len(verts)<3500, "Lila hair exceeds mobile-geometry budget"
    assert len(mesh.materials)==3
    assert len(mesh.polygons)>1000, "Lila procedural hair geometry missing"
    print("LILA_HAIR_SCULPT_PASS",len(mesh.vertices),
          "vertices",len(mesh.polygons),"faces",
          "3 shared materials, head+spine weighted")
    return obj

lila_hair=build_lila_aurora_hair()

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
            -math.copysign(total_arm_length*(.27 if side=="Right" else .41),shoulder_world.x),
            -total_arm_length*(.33 if side=="Right" else .37),
            total_arm_length*(.48 if side=="Right" else .80)))
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
            if clip_name=="AuroraFire":
                # A visible coordinated recoil impulse moves the animated
                # shoulders/elbows around the genuine two-handed grip.
                for side in ("Right","Left"):
                    upper=arm.pose.bones["rig:"+side+"Arm"]
                    forearm=arm.pose.bones["rig:"+side+"ForeArm"]
                    upper.rotation_quaternion=(
                        armed_pose["arm_"+side.lower()[0]]
                        @ Quaternion(Vector((1,0,0)),pulse*(-.075 if side=="Right" else -.038)))
                    upper.keyframe_insert(data_path="rotation_quaternion",frame=frame)
                    forearm.rotation_quaternion=(
                        armed_pose["forearm_"+side.lower()[0]]
                        @ Quaternion(Vector((1,0,0)),pulse*.045))
                    forearm.keyframe_insert(data_path="rotation_quaternion",frame=frame)
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
