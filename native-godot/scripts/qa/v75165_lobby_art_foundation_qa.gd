extends SceneTree
## V75.165 authentic 3D art acceptance. The boot scene, skinned Lila,
## materials and original controls must remain usable at Motorola size.
var failed: bool=false


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75165_LOBBY_ART "+reason)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    await process_frame
    front._layout_safe()
    await process_frame
    var viewport: SubViewport=front._preview_container.get_node("PreviewViewport")
    var scene: Node3D=viewport.get_node("AuroraCharacterStage")
    var stage: Node3D=scene.get_node("AuroraReal3DLobbyEnvironment")
    var env: WorldEnvironment=scene.get_node("AuroraAirfieldAtmosphere")
    check(viewport!=null and stage!=null and env!=null,
        "actual live 3D lobby scene was replaced by a flat picture")
    if viewport==null or stage==null or env==null:
        front.queue_free()
        quit(1)
        return
    var sky: ShaderMaterial=env.environment.sky.sky_material as ShaderMaterial
    check(sky!=null and sky.shader.code.contains("polar_luminance") and
        sky.shader.code.contains("AT_CUBEMAP_PASS"),
        "original aurora sky material is missing GPU-cost guards")
    var fittings: Array=stage.find_children("*","MultiMeshInstance3D",true,false)
    var total_instances: int=0
    for mesh in fittings:
        var inst: MultiMeshInstance3D=mesh as MultiMeshInstance3D
        total_instances+=inst.multimesh.instance_count
    check(fittings.size()<=12 and total_instances>=230,
        "physical roof/drain/facade geometry did not stay batched")
    check(stage.get_node_or_null("HangarRoofSlopeL")!=null and
        stage.get_node_or_null("HangarRoofSlopeR")!=null and
        stage.get_node_or_null("AuroraRadarRotatingHead")!=null,
        "operational station geometry or animated radar disappeared")
    var rig: Node3D=front._preview_avatar
    check(rig!=null and rig.find_child("Lila_Aurora_Mesh",true,false)!=null,
        "original skinned Lila rig must remain in playable lobby")
    var footer: HBoxContainer=front._bottom_navigation
    check(footer.get_child_count()==5 and
        footer.get_node_or_null("BottomPRESET")==null and
        front._mode_gallery_entry==null,
        "lobby gained duplicated modes or preset buttons")
    check(front._match_mode_selector.is_visible_in_tree() and
        front._battle_entry.text=="INICIAR",
        "real right-side BR action is not usable")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75165_LOBBY_ART PASS real_stage=1 original_lila=1 "+
            "roof_station_radar=1 batched_instances="+str(total_instances)+
            " aurora_shader=1 controls=5 mode_selector=1 android_pending=1")
    quit(1 if failed else 0)
