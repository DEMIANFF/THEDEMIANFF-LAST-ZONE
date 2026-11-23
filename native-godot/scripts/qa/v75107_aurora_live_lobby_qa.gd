extends SceneTree
## Actual V75.107 native 3D lobby acceptance: animation, shop and settings.
## No preview-only images, transactions or fabricated account state.
const COSMETICS=preload("res://scripts/player/aurora_operator_cosmetics.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,detail: String) -> void:
    if not ok:
        failed=true
        push_error("V75107_LOBBY "+detail)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    check(front.stage=="welcome","separate login was not preserved")
    front._enter_local_lobby()
    await process_frame
    check(front.stage=="lobby" and front._game==null,
        "local lobby incorrectly instantiated a match")

    var avatar: Node3D=front._preview_avatar
    check(avatar!=null,"original Lila 3D avatar missing")
    if avatar==null:
        quit(1)
        return
    var wheel: PanelContainer=front._emote_wheel
    check(front._gesture_button==null and wheel!=null and
        wheel.find_child("AuroraAvailableCharacterEmote",true,false)!=null,
        "real tap-to-emote selector replaced with obsolete GESTO button")
    var animator:=avatar.find_child("AnimationPlayer",true,false) as AnimationPlayer
    check(animator!=null,"rigged Lila animation player absent")
    if animator!=null:
        check(animator.has_animation("aurora_lobby/Motion"),
            "lobby clip was not retargeted to real Lila skeleton")
        front._toggle_character_emotes()
        var emote: Button=wheel.find_child(
            "AuroraAvailableCharacterEmote",true,false) as Button
        check(wheel.visible and emote!=null,
            "tapping character did not open actual emotes")
        if emote!=null:
            emote.pressed.emit()
        check(animator.current_animation==&"aurora_lobby/Motion" and
            animator.is_playing() and not wheel.visible,
            "selected emote did not play genuine Lila rig animation")
        animator.stop()
        animator.play("AuroraIdle")

    var stage: Node3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage/AuroraReal3DLobbyEnvironment")
    var rotor:=stage.get_node_or_null("AuroraRadarRotatingHead") as Node3D
    check(rotor!=null and stage.has_node("AuroraHangarPracticalLight") and
        stage.has_node("AuroraLiveBeacon"),
        "animated winter hangar scene is missing real 3D nodes")
    if rotor!=null:
        var before: float=rotor.rotation.y
        # The real scene caps individual dt at .10 to prevent a sudden
        # rotation after background/resume. Test motion across 3 frames.
        for i in range(3):
            stage._process(.5)
        check(absf(angle_difference(before,rotor.rotation.y))>.05,
            "physical radar is static; simulated preview is not acceptable")

    var before_state: Dictionary=front._offline_records.cosmetic_state()
    var original_equipped: String=str(before_state["equipped"])
    var mesh:=avatar.find_child("Lila_Aurora_Mesh",true,false) as MeshInstance3D
    check(mesh!=null and mesh.mesh!=null,"original Lila mesh missing")
    front._select_tab("TIENDA")
    check(front._preview_skin_applied=="aurora_glacier" and
        front._shop_selector.visible,
        "store did not render real 3D glacier outfit")
    front._on_shop_skin_selected(2)
    check(front._preview_skin_applied=="aurora_ember",
        "store preview did not swap the real skinned material")
    if mesh!=null:
        check(mesh.get_surface_override_material(0) is ShaderMaterial,
            "cosmetic preview did not affect the actual rigged mesh")
    check(front._offline_records.cosmetic_state()==before_state,
        "simply previewing a skin changed the player's balance or ownership")
    front._select_tab("JUGAR")
    check(front._preview_skin_applied==original_equipped,
        "leaving shop did not restore the equipped skin")
    check(front._preview_avatar==avatar and front._battle_entry.visible and
        front._social_panel.visible,
        "return to JUGAR rebuilt the rig or hid the match/social controls")

    front._open_settings()
    var settings: CanvasLayer=front._settings_modal
    check(settings!=null and settings._category_buttons.size()==4,
        "native settings navigation incomplete")
    if settings!=null:
        var screen: Button=settings._category_buttons["PANTALLA"] as Button
        var game: Button=settings._category_buttons["PARTIDA"] as Button
        check(screen!=null and game!=null,"settings category buttons absent")
        if screen!=null and game!=null:
            screen.pressed.emit()
            check(settings._category=="PANTALLA",
                "settings screen button has no working action")
            game.pressed.emit()
            check(settings._category=="PARTIDA",
                "settings game button has no working action")
        settings._close()
    await process_frame
    check(not paused and front.stage=="lobby" and front._preview_avatar==avatar,
        "closing settings lost the 3D scene or left the game paused")
    front._welcome()
    front.queue_free()
    await process_frame
    if not failed:
        print("V75107_LOBBY PASS animated_3d_hangar=1 lila_gesture=1 "+
            "skins=real_3d_preview no_fake_purchase=1 settings=real_ui")
    quit(1 if failed else 0)
