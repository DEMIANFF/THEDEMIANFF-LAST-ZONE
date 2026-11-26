extends SceneTree
## Private candidate only; no replacement or export of production models.
const SHA: String="19c93a00c114246aba2dca99c3a53698990dea2b9c519fc50a61a159331c4d45"
const POSES: Array[String]=["AuroraArmedIdle","AuroraCrouch"]
const DISTANCES: Array[float]=[4.0,15.0,30.0,60.0,100.0,150.0]
var failed: bool=false
func _initialize() -> void:
    call_deferred("_review")
func check(ok: bool, why: String) -> void:
    if not ok:
        failed=true
        push_error("LILA_LOD "+why)
func own_children(parent: Node, scene_root: Node) -> void:
    for child in parent.get_children():
        child.owner=scene_root
        own_children(child,scene_root)
func _review() -> void:
    var args: PackedStringArray=OS.get_cmdline_user_args()
    if args.size()!=2 or not args[0].is_absolute_path() or FileAccess.get_sha256(args[0])!=SHA:
        push_error("Use -- /absolute/Rev9.glb /absolute/output")
        quit(2)
        return
    var folder: String=args[1]
    if not folder.is_absolute_path() or DirAccess.make_dir_recursive_absolute(folder)!=OK:
        quit(2)
        return
    var doc:=GLTFDocument.new()
    var state:=GLTFState.new()
    if doc.append_from_file(args[0],state)!=OK or state.get_meshes().size()!=1:
        quit(1)
        return
    var im: ImporterMesh=state.get_meshes()[0].mesh
    if im.get_surface_count()!=1:
        quit(1)
        return
    var source: Array=im.get_surface_arrays(0)
    var full: PackedInt32Array=source[Mesh.ARRAY_INDEX]
    im.generate_lods(25.0,60.0,[])
    var generated: Array=im.get_surface_arrays(0)
    check(source==generated,"base attributes changed during simplification")
    var lods: Array[PackedInt32Array]=[full]
    var thresholds: Array[float]=[0.0]
    for i in range(im.get_surface_lod_count(0)):
        var ix: PackedInt32Array=im.get_surface_lod_indices(0,i)
        check(ix.size()%3==0 and ix.size()<lods[-1].size(),"invalid LOD index count")
        for v in ix:
            if v<0 or v>=source[Mesh.ARRAY_VERTEX].size():
                check(false,"index out of range")
                break
        lods.append(ix)
        thresholds.append(im.get_surface_lod_size(0,i))
    check(lods.size()>=2,"no lower detail levels")
    if failed:
        quit(1)
        return
    # Keep only the tested first reduction; retain the source index buffer.
    var level:=ArrayMesh.new()
    level.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source,[],{0.04:lods[1]})
    level.surface_set_material(0,im.get_surface_material(0))
    var control:=ArrayMesh.new()
    control.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source)
    control.surface_set_material(0,im.get_surface_material(0))
    # Compare equivalently packed meshes, not the pre-pack float arrays.
    var packed_equal: bool=level.surface_get_arrays(0)==control.surface_get_arrays(0)
    check(packed_equal,"adding LOD changed the packed base arrays")
    var counts: Array[int]=[full.size()/3,lods[1].size()/3]
    var samples: Array[Dictionary]=[]
    var visual: Node3D=doc.generate_scene(state) as Node3D
    if visual==null:
        quit(1)
        return
    root.size=Vector2i(800,800)
    var stage:=Node3D.new()
    root.add_child(stage)
    stage.add_child(visual)
    var meshes: Array[Node]=visual.find_children("*","MeshInstance3D",true,false)
    var anims: Array[Node]=visual.find_children("*","AnimationPlayer",true,false)
    var rigs: Array[Node]=visual.find_children("*","Skeleton3D",true,false)
    if meshes.size()!=1 or anims.size()!=1 or rigs.size()!=1:
        quit(1)
        return
    var mesh: MeshInstance3D=meshes[0] as MeshInstance3D
    mesh.mesh=level
    var anim: AnimationPlayer=anims[0] as AnimationPlayer
    var rig: Skeleton3D=rigs[0] as Skeleton3D
    check(rig.get_bone_count()==56,"rig count")
    own_children(visual,visual)
    var packed:=PackedScene.new()
    check(packed.pack(visual)==OK,"private scene pack failed")
    var private_scene_path: String=folder+"/Lila_Rev9_LOD_privada.scn"
    check(ResourceSaver.save(packed,private_scene_path,ResourceSaver.FLAG_BUNDLE_RESOURCES)==OK,"private scene save failed")
    var restored: PackedScene=ResourceLoader.load(private_scene_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
    if restored==null:
        quit(1)
        return
    var reloaded: Node=restored.instantiate()
    var reloaded_mesh: MeshInstance3D=reloaded.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
    var reloaded_rig: Skeleton3D=reloaded.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
    var reloaded_anim: AnimationPlayer=reloaded.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
    var saved_equal: bool=reloaded_mesh.mesh.surface_get_arrays(0)==control.surface_get_arrays(0)
    check(saved_equal and reloaded_rig.get_bone_count()==56 and reloaded_anim.get_animation_list().size()==27,"saved scene round trip changed rig/animation/base mesh")
    # Render the deserialized mesh itself, including its stored LOD indices.
    mesh.mesh=reloaded_mesh.mesh
    reloaded.free()
    var height: float=mesh.get_aabb().size.y*mesh.global_basis.y.length()
    if height<=0:
        quit(1)
        return
    visual.scale*=1.76/height
    var center: Vector3=mesh.to_global(mesh.get_aabb().get_center())
    var env:=WorldEnvironment.new()
    env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_COLOR
    env.environment.background_color=Color(0.16,0.18,0.22)
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color=Color(0.88,0.91,1.0)
    env.environment.ambient_light_energy=0.85
    stage.add_child(env)
    var light:=DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-35,-25,0)
    light.light_energy=1.2
    stage.add_child(light)
    var fill:=DirectionalLight3D.new()
    fill.rotation_degrees=Vector3(-25,155,0)
    fill.light_energy=0.65
    stage.add_child(fill)
    var camera:=Camera3D.new()
    camera.fov=40.0
    stage.add_child(camera)
    camera.current=true
    anim.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var captures: int=0
    for pose in POSES:
        if not anim.has_animation(pose):
            check(false,"clip missing "+pose)
            continue
        anim.play(pose)
        anim.seek(anim.get_animation(pose).length*.35,true)
        anim.advance(0.0)
        rig.force_update_all_bone_transforms()
        for distance in DISTANCES:
            for angle in [0,1]:
                var direction:=Vector3(.25,.08,-1.0) if angle==0 else Vector3(1.0,.08,-.25)
                camera.global_position=center+direction.normalized()*distance
                camera.look_at(center)
                for frame in range(3):
                    await process_frame
                    await RenderingServer.frame_post_draw
                var info: int=RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
                check(info==(counts[0] if distance<=60.0 else counts[1]),"unexpected primitive count at "+str(distance))
                samples.append({"pose":pose,"distance":distance,"angle":angle,"visible_primitives":info})
                print("NATIVE_LOD ",samples[-1])
                var path: String=folder+"/%s_%s_%s.png"%[pose,str(int(distance)),str(angle)]
                check(root.get_texture().get_image().save_png(path)==OK,"capture failed")
                captures+=1
    var report: Dictionary={"sha256":SHA,"triangles":counts,"native_threshold":0.04,"packed_base_equal":packed_equal,"saved_scene_base_equal":saved_equal,"samples":samples,"base_arrays_identical":source==generated,"captures":captures,"poses":POSES,"distances_m":DISTANCES,"production_approved":false,"pass":not failed}
    var file:=FileAccess.open(folder+"/lod_godot.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "))
    print("LILA_LOD_RESULT ",JSON.stringify(report))
    stage.queue_free()
    await process_frame
    quit(1 if failed else 0)
