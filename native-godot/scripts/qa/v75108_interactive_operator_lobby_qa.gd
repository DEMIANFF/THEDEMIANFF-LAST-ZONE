extends SceneTree
## V75.171: real touch rotation, character-tap emote, account and cosmetic
## workflows. No separate turn arrows, VISTA, GESTO or operator nameplate.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75108_OPERATOR_LOBBY "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    check(front.stage=="welcome","login is not separate from the lobby")
    front._enter_local_lobby()
    await process_frame
    front._layout_safe()
    var avatar: Node3D=front._preview_avatar
    check(avatar!=null and front._game==null and
        front._preview_container!=null,
        "live skinned Lila 3D preview missing")
    if avatar==null:
        quit(1)
        return
    var camera: Camera3D=front._preview_container.get_node_or_null(
        "PreviewViewport/AuroraCharacterStage/LobbyPortraitCamera") as Camera3D
    check(camera!=null,"actual portrait camera missing")
    check(front._gesture_button==null and
        front._operator_controls.is_empty() and
        not front._preview_caption.visible,
        "obsolete arrows, VISTA, GESTO or nameplate still block character")

    var animator: AnimationPlayer=avatar.find_child("AnimationPlayer",true,false) as AnimationPlayer
    check(animator!=null and int(animator.get_meta("aurora_lobby_planted_tracks",0))>=9,
        "lobby did not inherit corrected lower-body stance")
    if animator!=null and animator.has_animation("AuroraIdle"):
        var idle: Animation=animator.get_animation("AuroraIdle")
        var planted: Animation=animator.get_animation("AuroraArmedIdle")
        for i in range(planted.get_track_count()):
            var path: NodePath=planted.track_get_path(i)
            var type: Animation.TrackType=planted.track_get_type(i)
            if path.get_subname_count()==0 or type not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D] or planted.track_get_key_count(i)==0:
                continue
            if str(path.get_subname(0)) not in ["Hips","LeftUpLeg","RightUpLeg","LeftLeg","RightLeg","LeftFoot","RightFoot","LeftToeBase","RightToeBase"]:
                continue
            var track: int=idle.find_track(path,type)
            check(track>=0,"missing planted lower-body track "+str(path))
            if track>=0:
                check(idle.track_get_key_count(track)==2 and
                    idle.track_get_key_value(track,0)==planted.track_get_key_value(i,0) and
                    idle.track_get_key_value(track,1)==planted.track_get_key_value(i,0),
                    "lobby idle drifts away from planted pose "+str(path))
        check(animator.get_node_or_null("LobbyGestureTimer")==null,
            "automatic emote still interrupts neutral lobby pose")
        front._play_lobby_gesture()
        check(animator.current_animation=="aurora_lobby/Motion",
            "explicit gesture no longer works")
        animator.play("AuroraIdle")
    var original: float=avatar.rotation.y
    var press:=InputEventMouseButton.new()
    press.button_index=MOUSE_BUTTON_LEFT
    press.pressed=true
    press.position=Vector2(445,200)
    front._preview_input(press)
    var drag:=InputEventMouseMotion.new()
    drag.position=Vector2(525,200)
    drag.relative=Vector2(80,0)
    front._preview_input(drag)
    var release:=InputEventMouseButton.new()
    release.button_index=MOUSE_BUTTON_LEFT
    release.pressed=false
    release.position=Vector2(525,200)
    front._preview_input(release)
    check(absf(angle_difference(original,avatar.rotation.y))>.35,
        "swiping did not rotate the actual character")
    check(not front._emote_wheel.visible,
        "dragging the character accidentally opened the emote wheel")

    var tap:=InputEventMouseButton.new()
    tap.button_index=MOUSE_BUTTON_LEFT
    var silhouette: Rect2=front._portrait_character_hit_rect()
    check(silhouette.has_area(),
        "3D Lila must project into an actual nonempty touch silhouette")
    check(front._preview_hit_character(silhouette.get_center()) and
        not front._preview_hit_character(Vector2(275,180)),
        "tap target reaches the real rig but not the hangar background")
    tap.position=silhouette.get_center()
    tap.pressed=true
    front._preview_input(tap)
    tap.pressed=false
    front._preview_input(tap)
    check(front._emote_wheel.visible and
        front._emote_wheel.find_child(
            "AuroraAvailableCharacterEmote",true,false)!=null,
        "tapping Lila did not open real selectable emotes")
    var close: Button=front._emote_wheel.find_child(
        "CloseCharacterEmotes",true,false) as Button
    check(close!=null and close.is_visible_in_tree(),
        "emote selector close action not reachable")
    if close!=null:
        close.pressed.emit()
    check(not front._emote_wheel.visible,
        "emote selection has no closing interaction")
    var saved_skin: Dictionary=front._offline_records.cosmetic_state().duplicate(true)
    front._select_tab("PERSONAJE")
    check(front._shop_selector.is_visible_in_tree() and
        not front._shop_buy_button.visible,
        "genuine character skin selection was removed")
    front._on_shop_skin_selected(2)
    check(front._preview_skin_applied=="aurora_ember" and
        saved_skin==front._offline_records.cosmetic_state(),
        "3D skin preview incorrectly spent currency or changed entitlement")
    front._select_tab("JUGAR")
    check(front._preview_skin_applied==str(saved_skin["equipped"]) and
        front._battle_entry.visible and front._social_panel.visible,
        "return to BR lost equipped skin or match access")
    front._select_tab("TIENDA")
    check(front._shop_selector.visible and front._shop_buy_button.visible,
        "local store disappeared during lobby cleanup")
    front._select_tab("JUGAR")

    front._welcome()
    await process_frame
    check(front._preview_avatar==null and front._emote_wheel==null and
        front._operator_controls.is_empty(),
        "leaving lobby leaked the skinned rig or emote UI")
    front._enter_local_lobby()
    await process_frame
    check(front._preview_avatar!=null and front._emote_wheel!=null and
        not front._emote_wheel.visible and front._game==null,
        "lobby return did not reconstruct real tap-to-emote preview")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75108_OPERATOR_LOBBY PASS swipe=actual_rotation "+
            "tap=emote_panel no_arrows=1 skins=real_readonly "+
            "lobby_release=1 BR_playable=1")
    quit(1 if failed else 0)
