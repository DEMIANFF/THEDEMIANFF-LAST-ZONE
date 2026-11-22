extends SceneTree
const RESOLUTION=preload("res://scripts/ui/aurora_lobby_resolution.gd")
const QUALITY=preload("res://scripts/render/aurora_render_budget.gd")

var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func _check(condition: bool,reason: String) -> void:
    if not condition:
        failed=true
        push_error("V75116_ARCTIC_AIRFIELD "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var boot:=load("res://scenes/Boot.tscn") as PackedScene
    var front: Control=boot.instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_loading("CARGANDO RECURSOS","Preparando Base Aurora")
    await process_frame
    var normal_top: float=front._loading_surface_plate.anchor_top
    front._startup_failed()
    await process_frame
    await process_frame
    _check(front._loading_retry.is_visible_in_tree() and
        not front._loading_meter.is_visible_in_tree() and
        front._loading_surface_plate.anchor_top<normal_top and
        front._loading_surface_plate.get_global_rect().encloses(
            front._loading_retry.get_global_rect()),
        "startup error must expose an in-bounds retry action")

    front._welcome()
    await process_frame
    _check(front._arctic_art.is_visible_in_tree() and front._preview_container==null,
        "signin must not allocate the live lobby world")
    front._login_local_button.pressed.emit()
    await process_frame
    await process_frame
    var viewport:=front._preview_container.get_node("PreviewViewport") as SubViewport
    var scene:=viewport.get_node("AuroraCharacterStage") as Node3D
    var airfield:=scene.get_node("AuroraReal3DLobbyEnvironment") as Node3D
    _check(not front._arctic_art.is_visible_in_tree() and not viewport.transparent_bg,
        "the lobby must fill its frame from the actual 3D world")
    var atmosphere:=scene.get_node_or_null("AuroraAirfieldAtmosphere") as WorldEnvironment
    _check(atmosphere!=null and atmosphere.environment.background_mode==Environment.BG_SKY
        and atmosphere.environment.fog_enabled and atmosphere.environment.sky!=null,
        "live sky and depth fog are missing")
    var portrait_key:=scene.get_node("AuroraPortraitKey") as DirectionalLight3D
    var portrait_spot:=scene.get_node_or_null("AuroraPortraitSpot") as SpotLight3D
    _check(not portrait_key.shadow_enabled and portrait_spot!=null and
        portrait_spot.shadow_enabled and portrait_spot.spot_range<5.0 and
        viewport.positional_shadow_atlas_size==512,
        "portrait shadow must stay inside the lobby's positional atlas")

    var batches:=airfield.find_children("*","MultiMeshInstance3D",true,false)
    var instances:=0
    for item in batches:
        instances+=(item as MultiMeshInstance3D).multimesh.instance_count
    _check(batches.size()<=12 and instances>=160,
        "repeated airfield fittings must share mesh batches")
    var roof_left:=airfield.get_node_or_null("HangarRoofSlopeL") as MeshInstance3D
    var roof_right:=airfield.get_node_or_null("HangarRoofSlopeR") as MeshInstance3D
    _check(roof_left!=null and roof_right!=null and
        roof_left.basis.x.y*roof_right.basis.x.y<0.0 and
        airfield.has_node("HangarGable") and airfield.has_node("HangarRecessedDoors"),
        "hangar must have pitched roof, gable and recessed doors")
    var dish:=airfield.find_child("AuroraRadarDish",true,false) as MeshInstance3D
    _check(dish!=null and dish.mesh.get_aabb().size.z>=.45 and
        dish.mesh.get_aabb().size.x>2.5,"radar must contain a concave dish mesh")

    front._apply_preview_skin("aurora_base")
    var body:=front._preview_avatar.find_child("Lila_Aurora_Mesh",true,false) as MeshInstance3D
    var rig: Skeleton3D
    if body!=null:
        rig=body.get_node_or_null(body.skeleton) as Skeleton3D
    _check(body!=null and body.material_override is ShaderMaterial and rig!=null,
        "Lila must use her original skinned mesh and viewport material")
    if rig!=null:
        for joint in ["LeftHand","RightHand"]:
            var bone:=rig.find_bone(joint)
            _check(bone>=0 and rig.get_bone_global_pose(bone).origin.is_finite(),
                "invalid animated operator joint "+joint)

    for size in [Vector2i(964,434),Vector2i(1280,720),Vector2i(2712,1220)]:
        root.size=size
        await process_frame
        front._layout_safe()
        await process_frame
        var safe:=root.get_visible_rect()
        var battle: Rect2=front._battle_entry.get_global_rect()
        _check(safe.encloses(battle) and
            not battle.intersects(front._match_mode_selector.get_global_rect()) and
            not battle.intersects(front._bottom_navigation.get_global_rect()),
            "overlapping match controls at "+str(size))
        var profile: String=QUALITY.read_profile()
        var budget: float=float(RESOLUTION.PIXEL_BUDGETS.get(profile,1550000.0))
        _check(front._preview_container.stretch_shrink==
            RESOLUTION.shrink_for_size(safe.size,profile) and
            float(viewport.size.x*viewport.size.y)<=budget+5000.0,
            "lobby 3D exceeds selected quality profile "+profile+
            " at "+str(size)+", target "+str(viewport.size))

    var freed_world: WeakRef=weakref(viewport)
    front._welcome()
    await process_frame
    await process_frame
    _check(freed_world.get_ref()==null and front._preview_container==null,
        "old airfield viewport retained after returning to signin")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75116_ARCTIC_AIRFIELD PASS batches=%d fittings=%d resolutions=3 freed=1"
            %[batches.size(),instances])
    quit(1 if failed else 0)
