#!/usr/bin/env python3
"""Blender 4.x: import four verified Mixamo FBXs and export ONE rigged male GLB.

Usage: blender -b --python build_male_glb.py -- --project /path/native-godot
Requires stage_mixamo_sources.py --install first. Unmodified originals stay
under out/private_mixamo_sources; only one 3D character is exported.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys

try:
    import bpy
except ImportError as exc:
    raise SystemExit('Run with Blender 4.x, not ordinary Python') from exc


def _cli():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True, type=Path)
    parser.add_argument('--texture-limit', type=int, default=1024)
    parser.add_argument('--triangle-limit', type=int, default=95000)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if not 256 <= args.texture_limit <= 2048:
        parser.error('Texture limit must be 256..2048 px')
    return args


def _import_file(path: Path):
    previous = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=False,
                             ignore_leaf_bones=False, use_anim=True)
    added = set(bpy.context.scene.objects) - previous
    armatures = [ob for ob in added if ob.type == 'ARMATURE']
    if len(armatures) != 1:
        raise RuntimeError(f'{path.name}: expected one armature, got {len(armatures)}')
    skeleton = armatures[0]
    names = sorted(b.name for b in skeleton.data.bones)
    if len(names) != 65 or not any(name.endswith('Hips') for name in names):
        raise RuntimeError(f'{path.name}: Mixamo skeleton not as audited')
    return skeleton, added, names


def _pick_action(armature):
    actions = []
    if armature.animation_data:
        if armature.animation_data.action:
            actions.append(armature.animation_data.action)
        for track in armature.animation_data.nla_tracks:
            for strip in track.strips:
                if strip.action:
                    actions.append(strip.action)
    actions = list({id(a): a for a in actions}.values())
    if not actions:
        raise RuntimeError('FBX imported without an armature action')
    # Prefer motion with enough keyed pose bones, not a baked camera clip.
    def amount(act):
        try:
            return sum(len(fc.keyframe_points) for fc in act.fcurves)
        except AttributeError:
            return 0
    return max(actions, key=amount)


def main() -> None:
    args = _cli()
    root = args.project.resolve()
    if root.name != 'native-godot' or not (root / 'project.godot').exists():
        raise RuntimeError('Project root must contain native-godot/project.godot')
    sources = root / 'out' / 'private_mixamo_sources'
    for name in ['Ch02_nonPBR.fbx','Jump.fbx','Start Walking.fbx','Jogging.fbx']:
        if not (sources/name).is_file():
            raise RuntimeError('Missing preverified source: ' + name)
    output = root / 'assets' / 'characters' / 'aurora_male_mixamo' / 'AuroraMaleMixamo.glb'
    if output.exists():
        raise FileExistsError('Refuse to overwrite an already converted model: ' + str(output))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base,base_objects,bones = _import_file(sources/'Ch02_nonPBR.fbx')
    base.name = 'AuroraMaleMixamoRig'
    meshes = [ob for ob in base_objects if ob.type == 'MESH']
    if len(meshes)!=6:
        raise RuntimeError(f'Original male FBX contains unexpected mesh count: {len(meshes)}')
    base_action = _pick_action(base).copy()
    # Reuse source reference pose, but NEVER claim an authored Idle was supplied.
    base_action.name = 'AuroraArmedIdle'
    clips = [('Start Walking.fbx','AuroraArmedWalk'),
             ('Jogging.fbx','AuroraArmedRun'),('Jump.fbx','AuroraJump')]
    actions = [base_action]
    provenance = [{'source':'Ch02_nonPBR.fbx','clip':'AuroraArmedIdle',
                   'note':'reference/rest source, not a separately supplied Idle motion'}]
    for filename,label in clips:
        imported,objs,names = _import_file(sources/filename)
        if names != bones:
            raise RuntimeError(f'{filename}: bone name mismatch')
        movement = _pick_action(imported).copy()
        movement.name = label
        actions.append(movement)
        provenance.append({'source':filename,'clip':label,
                           'frames':[float(v) for v in movement.frame_range]})
        for ob in sorted(objs, key=lambda o:o.type!='MESH'):
            bpy.data.objects.remove(ob, do_unlink=True)
    # The original four FBXs each duplicated the same six meshes. Export ONLY
    # the base's six meshes and 65-bone armature, preserving motion Actions.
    base.animation_data_create()
    base.animation_data.action = None
    for action in actions:
        nla = base.animation_data.nla_tracks.new()
        nla.name = action.name
        strip = nla.strips.new(action.name, int(action.frame_range[0]),action)
        strip.blend_type = 'REPLACE'
    # Reduce texture memory instead of deleting bones, original motion or weights.
    reduced = []
    for img in bpy.data.images:
        if img.size[0] <= 0 or img.size[1] <= 0:
            continue
        longer = max(img.size)
        if longer > args.texture_limit:
            factor = args.texture_limit / float(longer)
            dims = (max(1,round(img.size[0]*factor)),
                    max(1,round(img.size[1]*factor)))
            img.scale(*dims)
            reduced.append({'image':img.name,'scaled_to':dims})
    total_faces = sum(len(ob.data.polygons) for ob in meshes)
    if total_faces>args.triangle_limit:
        # Never silently decimate a weighted animated mesh. Require LOD review.
        raise RuntimeError(f'Male rig has {total_faces} polygons; manual LOD approval required')
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    for ob in [base,*meshes]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = base
    export_args = dict(filepath=str(output),export_format='GLB',use_selection=True,
                       export_animations=True,export_skins=True,
                       export_yup=True,export_materials='EXPORT',
                       export_image_format='AUTO')
    allowed = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    if 'export_animation_mode' in allowed:
        export_args['export_animation_mode']='NLA_TRACKS'
    elif 'export_nla_strips' in allowed:
        export_args['export_nla_strips']=True
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(**export_args)
    if not output.exists() or output.stat().st_size<10000:
        raise RuntimeError('Blender failed to export the single skinned GLB')
    report = {'asset':'AuroraMaleMixamo.glb','fbx_sources':4,
              'original_shared_bones':65,'original_base_meshes':6,
              'source_clips':provenance,'textures_reduced':reduced,
              'source_triangles_estimate':total_faces,'glb_bytes':output.stat().st_size,
              'source_animations_preserved':True,
              'godot_import_verified':False,'motorola_test_verified':False,
              'combat_action_clips_supplied':False,
              'distribution_license_clearance':False}
    (root/'out'/'private_mixamo_build_report.json').write_text(
        json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
    print('AURORA_MALE_MIXAMO_EXPORT',json.dumps(report,ensure_ascii=False))


if __name__=='__main__':
    main()