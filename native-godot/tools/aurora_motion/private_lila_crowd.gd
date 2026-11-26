extends SceneTree
# Isolated visual load review, not a BR simulation.
const SHA="236056e220607d9e8920b5be924e12ef84ba88e5a928edae5e46b43fe7b419e3"
const DISTANCES=[15.0,30.0,60.0,100.0,150.0]
var failed: bool=false
func _initialize() -> void:
    call_deferred("_review")
func check(ok: bool, why: String) -> void:
    if not ok:
        failed=true
        push_error("LILA_CROWD "+why)
func _review() -> void:
    var args: PackedStringArray=OS.get_cmdline_user_args()
    if args.size()!=2 or FileAccess.get_sha256(args[0])!=SHA or not args[1].is_absolute_path():
        quit(2)
        return
    var output: String=args[1]
    DirAccess.make_dir_recursive_absolute(output)
    var scene: PackedScene=ResourceLoader.load(args[0],"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
    if scene==null:
        quit(2)
        return
    root.size=Vector2i(800,800)
    var stage:=Node3D.new()
    root.add_child(stage)
    var env:=WorldEnvironment.new()
    env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_COLOR
    env.environment.background_color=Color(.16,.18,.22)
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color=Color(.88,.91,1.0)
    env.environment.ambient_light_energy=.85
    stage.add_child(env)
    var light:=DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-35,-25,0)
    light.light_energy=1.2
    stage.add_child(light)
    var camera:=Camera3D.new()
    camera.fov=40.0
    camera.far=200.0
    stage.add_child(camera)
    camera.current=true
    var native: ArrayMesh
    var control:=ArrayMesh.new()
    var meshes: Array[MeshInstance3D]=[]
    var rigs: Array[Skeleton3D]=[]
    var anims: Array[AnimationPlayer]=[]
    for row in range(5):
        for col in range(10):
            var v: Node3D=scene.instantiate() as Node3D
            stage.add_child(v)
            var m: MeshInstance3D=v.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
            var rig: Skeleton3D=v.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
            var anim: AnimationPlayer=v.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
            check(rig.get_bone_count()==56 and anim.get_animation_list().size()==27,"instance rig or clips")
            if native==null:
                native=m.mesh as ArrayMesh
                control.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,native.surface_get_arrays(0))
                control.surface_set_material(0,native.surface_get_material(0))
            check(m.mesh==native,"shared mesh resource")
            var height: float=m.get_aabb().size.y*m.global_basis.y.length()
            v.scale*=1.76/height
            var center: Vector3=m.to_global(m.get_aabb().get_center())
            var d: float=DISTANCES[row]
            v.global_position+=Vector3((float(col)-4.5)*.054*d,(float(row)-2.0)*.12*d,-d)-center
            anim.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
            meshes.append(m)
            rigs.append(rig)
            anims.append(anim)
    var samples: Array[Dictionary]=[]
    for pose in ["AuroraArmedIdle","AuroraArmedRun","AuroraCrouch"]:
        for i in range(50):
            var a: AnimationPlayer=anims[i]
            a.play(pose)
            a.seek(a.get_animation(pose).length*(.1+.08*float(i%10)),true)
            a.advance(0.0)
            rigs[i].force_update_all_bone_transforms()
        for mode in ["full","native"]:
            for m in meshes:
                m.mesh=control if mode=="full" else native
            for frame in range(2):
                await process_frame
                await RenderingServer.frame_post_draw
            var rid: RID=root.get_viewport_rid()
            var primitives: int=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
            var objects: int=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
            var draws: int=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
            var expected: int=50*95885 if mode=="full" else 30*95885+20*47931
            check(objects==50 and primitives==expected,"unexpected crowd count "+str([objects,primitives,expected]))
            var sample: Dictionary={"pose":pose,"mode":mode,"objects":objects,"triangles":primitives,"draw_calls":draws,"expected_triangles":expected}
            samples.append(sample)
            print("CROWD ",JSON.stringify(sample))
            check(root.get_texture().get_image().save_png(output+"/"+pose+"_"+mode+".png")==OK,"capture")
    var report: Dictionary={"scene_sha256":SHA,"instances":50,"samples":samples,"distances_m":DISTANCES,"renderer":RenderingServer.get_current_rendering_method(),"production_approved":false,"pass":not failed}
    var file:=FileAccess.open(output+"/crowd_report.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "))
    print("LILA_CROWD_RESULT ",JSON.stringify(report))
    stage.queue_free()
    await process_frame
    quit(1 if failed else 0)
