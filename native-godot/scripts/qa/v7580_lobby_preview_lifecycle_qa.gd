extends SceneTree
## V75.80: lifecycle regression for real Godot lobby 3D resources.
## The welcome UI must not allocate a hidden rig/viewport.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func require(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7580_PREVIEW_LIFECYCLE "+reason)


func _verify() -> void:
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await process_frame
    require(front.stage=="welcome","did not start on the login screen")
    require(front._preview_container==null and front._preview_avatar==null,
        "welcome allocated a skinned 3D character or SubViewport")
    require(front._surface.get_node_or_null("AvatarPreview")==null,
        "welcome retained hidden AvatarPreview node")
    front._enter_local_lobby()
    await process_frame
    require(front.stage=="lobby" and front._preview_container!=null,
        "entering lobby did not create 3D preview")
    require(front._preview_avatar!=null,
        "entering lobby did not load real Lila model")
    var first_id: int=front._preview_container.get_instance_id()
    front._top_account_button.emit_signal("pressed")
    require(front._selected_tab=="CUENTA",
        "account shortcut cannot reach account management")
    front._login_manage_button.emit_signal("pressed")
    await process_frame
    require(front.stage=="welcome",
        "account switch failed to return to login")
    require(front._preview_container==null and front._preview_avatar==null,
        "account switch retained renderer references")
    require(front._surface.get_node_or_null("AvatarPreview")==null,
        "account switch failed to free old SubViewport")
    front._enter_local_lobby()
    await process_frame
    require(front.stage=="lobby" and front._preview_container!=null,
        "returning to lobby failed to recreate renderer")
    if front._preview_container!=null:
        require(front._preview_container.get_instance_id()!=first_id,
            "re-entering lobby reused a stale render target")
        var viewport: SubViewport=front._preview_container.get_node_or_null(
            "PreviewViewport") as SubViewport
        require(viewport!=null and viewport.own_world_3d,
            "new lobby renderer has no isolated 3D world")
        require(front._preview_container.get_node_or_null(
            "PreviewViewport/AuroraCharacterStage/AuroraSentinelCompanion")!=null,
            "companion was lost after login/lobby transition")
    front.queue_free()
    await process_frame
    if not failed:
        print("V7580_PREVIEW_LIFECYCLE PASS welcome=no_3d_alloc "+
            "lobby=real_rig logout=freed reentry=fresh_viewport "+
            "sentinel=retained")
    quit(1 if failed else 0)
