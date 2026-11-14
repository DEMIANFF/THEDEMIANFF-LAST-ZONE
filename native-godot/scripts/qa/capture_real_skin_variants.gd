extends SceneTree
## V75.90: only authentic Godot renders of real Lila GLB armor materials.
const COSMETICS=preload("res://scripts/player/aurora_operator_cosmetics.gd")

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await process_frame
    front._enter_local_lobby()
    for i in range(10):
        await process_frame
    var visual: Node3D=front._preview_avatar
    if visual==null:
        push_error("V7586_SKIN_RENDER no actual skinned operator")
        quit(1)
        return
    var kit: MeshInstance3D=visual.find_child(
        "LilaAuroraSignatureKit",true,false) as MeshInstance3D
    if kit==null or kit.mesh==null or kit.mesh.get_surface_count()<3:
        push_error("V7586_SKIN_RENDER original PBR armor missing")
        quit(2)
        return
    for name in ["aurora_base","aurora_glacier","aurora_ember"]:
        if not COSMETICS.apply_to_operator(visual,name):
            push_error("V7586_SKIN_RENDER cannot apply "+name)
            quit(3)
            return
        var material: Material=kit.get_surface_override_material(2)
        if (material!=null)==(name=="aurora_base"):
            push_error("V7586_SKIN_RENDER material did not change "+name)
            quit(4)
            return
        for frame in range(6):
            await process_frame
        await RenderingServer.frame_post_draw
        var image: Image=root.get_texture().get_image()
        var path: String="res://out/aurora-v75-90-skin-"+name+".png"
        if image.save_png(path)!=OK:
            push_error("V7586_SKIN_RENDER file missing "+path)
            quit(5)
            return
    if not COSMETICS.apply_to_operator(visual,"aurora_base") or (
            kit.get_surface_override_material(2)!=null):
        push_error("V7586_SKIN_RENDER failed to restore source material")
        quit(6)
        return
    front.queue_free()
    await process_frame
    print("V7586_ORIGINAL_SKIN_RENDER PASS real_lila=1 "+
        "base=png glacier=png ember=png material_reset=1")
    quit(0)
