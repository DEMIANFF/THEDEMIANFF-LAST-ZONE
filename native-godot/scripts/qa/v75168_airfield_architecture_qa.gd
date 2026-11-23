extends SceneTree
## V75.168 validates actual geometry in the SAME Godot lobby scene, not
## promotional screens or a duplicated environment. Preservation of
## existing 3D batch count, original Lila and the five-button UX is required.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75168_ARCHITECTURE "+reason)

func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    await process_frame
    front._layout_safe()
    var world: Node3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage")
    var stage: Node3D=world.get_node("AuroraReal3DLobbyEnvironment")
    check(stage!=null and front._preview_avatar!=null and
        front._preview_avatar.find_child("Lila_Aurora_Mesh",true,false)!=null,
        "live skinned Lila must remain in the authentic physical 3D airfield")
    var parts: Array[String]=[
        "AuroraHangarRoofExhaust0",
        "AuroraHangarRoofExhaust1",
        "AuroraStationEntryCanopy"
    ]
    for name in parts:
        var part: MeshInstance3D=stage.get_node_or_null(name) as MeshInstance3D
        check(part!=null and part.mesh is BoxMesh and
            part.material_override is StandardMaterial3D,
            "missing actual mesh for physically detailed facility: "+name)
    var batches: Array=stage.find_children("*","MultiMeshInstance3D",true,false)
    var fittings: int=0
    var new_material_batches: int=0
    for batch in batches:
        var mesh: MultiMeshInstance3D=batch as MultiMeshInstance3D
        fittings+=mesh.multimesh.instance_count
        if mesh.name.begins_with("AirfieldFittings"):
            new_material_batches+=1
    check(batches.size()<=12 and new_material_batches<=7 and
        fittings>=630 and fittings<=760,
        "structural details must reuse existing mobile MultiMesh materials, "+
        "batches="+str(batches.size())+" fittings="+str(fittings))
    var runway: Dictionary=stage._runway_batch_audit
    check(int(runway.get("edge_count",-1))==44 and
        int(runway.get("center_count",-1))==7 and
        bool(runway.get("side_submitted",false)) and
        bool(runway.get("center_submitted",false)),
        "original physically marked airfield failed GPU submission")
    var directional: Array=stage.find_children("*","DirectionalLight3D",true,false)
    var pointlights: Array=stage.find_children("*","OmniLight3D",true,false)
    check(directional.size()==0 and pointlights.size()<=5,
        "architectural detail must not incur dynamic shadow or light costs")
    check(front._bottom_navigation.get_child_count()==5 and
        front._left_shortcuts.get_child_count()==6 and
        not front._top_social_button.is_visible_in_tree() and
        front._mode_gallery_entry==null,
        "visual polish recreated duplicate lobby actions")
    front._top_settings_button.pressed.emit()
    check(front._settings_modal!=null and
        front._settings_modal.find_child("HUDPresetSelector",true,false)!=null,
        "visual changes broke canonical HUD/controls/settings")
    if front._settings_modal!=null:
        front._settings_modal.call("_close")
    front._welcome()
    await process_frame
    check(front._preview_container==null,
        "return from lobby retains GPU airfield render target")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75168_ARCHITECTURE PASS genuine_facilities=3 "+
            "runway_marks=51 batches<=12 details_batched=1 "+
            "Lila_skinned=1 HUD_single=1 mobile_vram_released=1")
    quit(1 if failed else 0)
