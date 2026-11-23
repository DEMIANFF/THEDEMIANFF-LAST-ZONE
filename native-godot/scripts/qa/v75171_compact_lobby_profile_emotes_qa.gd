extends SceneTree
## V75.171 real Motorola lobby reference: video-guided workflow, NOT
## screenshot-based fake controls. Tests official player-facing navigation,
## local profile ledger, native authentication rules and actual Lila emotes.
const BRIDGE=preload("res://scripts/persistence/aurora_firebase_bridge.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,detail: String) -> void:
    if not ok:
        failed=true
        push_error("V75171_REAL_LOBBY "+detail)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    check(front.stage=="welcome" and
        front._loading_meter.value>=99.0,
        "the true Godot resource loader did not reach the entry screen")
    check(front._login_google_button!=null and
        front._login_guest_button!=null and
        front._login_local_button!=null and
        front._login_google_button.is_visible_in_tree(),
        "actual Google, Guest and Offline actions missing from first login")
    check(not bool(BRIDGE.session_state().get("authenticated",false)),
        "desktop/headless session must not fabricate authenticated Firebase")
    # Load the frontend script after the real Godot scene/autoload context
    # is initialized. A top-level preload fails --check-only because the
    # lobby music autoload is not registered in that isolated parse stage.
    var session_policy: Script=load("res://scripts/ui/aurora_frontend.gd")
    check(bool(session_policy.call("_can_resume_native_session",
        {"authenticated":true,"pending":false},true,false)) and
        bool(session_policy.call("_can_resume_native_session",
        {"authenticated":true,"pending":false},false,true)) and
        not bool(session_policy.call("_can_resume_native_session",
        {"authenticated":true,"pending":true},true,false)) and
        not bool(session_policy.call("_can_resume_native_session",
        {"authenticated":false,"pending":false},true,true)) and
        not bool(session_policy.call("_can_resume_native_session",
        {"authenticated":true,"pending":false},false,false)),
        "auth auto-resume must require an existing confirmed SDK session "+
        "and either startup or an actual user sign-in; never fake login")
    front._enter_local_lobby()
    await process_frame
    front._layout_safe()
    await process_frame
    check(front.stage=="lobby" and front._game==null and
        front._preview_avatar!=null and
        front._preview_avatar.find_child(
            "Lila_Aurora_Mesh",true,false)!=null,
        "real skinned Lila or local lobby missing")

    var mode: OptionButton=front._match_mode_selector
    check(mode!=null and mode.get_item_count()==3 and
        mode.get_item_text(0)=="CLÁSICO" and
        mode.get_item_text(1)=="CLASIFICATORIA" and
        mode.get_item_text(2)=="ENTRENAMIENTO",
        "selector must display only three clean player-facing modes")
    check(front._lobby_menu_backplate==null and
        front.find_child("LobbyMenuBackplate",true,false)==null,
        "full-height opaque menu rail still obscures real Aurora geometry")
    check(not front._lobby_section_title.visible and
        not front._lobby_section_hint.visible and
        not front._lobby_mode_caption.visible and
        not front._lobby_compact_intel.visible and
        not front._lobby_match_facts.visible and
        front._lobby_match_facts.get_child_count()==0,
        "50-player/49-AI/zone labels or redundant BR panels remain")
    check(front._battle_entry.text=="INICIAR" and
        front._battle_entry.is_visible_in_tree() and
        front._play_match_card.get_global_rect().encloses(
            front._battle_entry.get_global_rect()) and
        front._play_match_card.get_global_rect().encloses(
            mode.get_global_rect()),
        "the single working mode selector or start escaped the compact card")
    check(front._social_panel.get_node(
        "SocialContent/AuroraFourMemberSquad").get_child_count()==4,
        "local squad must preserve the four actual places")
    check(front._left_shortcuts.get_child_count()==5 and
        front._left_shortcuts.get_node_or_null("QuickJUGAR")==null and
        front._bottom_navigation.get_child_count()==5 and
        front._bottom_navigation.get_node_or_null("BottomPRESET")==null,
        "five unique left + five footer actions required; no duplicate JUGAR")

    var avatar: Node3D=front._preview_avatar
    check(front._gesture_button==null and
        front._operator_controls.is_empty() and
        not front._preview_caption.visible,
        "obsolete GESTO, rotation arrows, VISTA or operator nameplate remain")
    check(front._emote_wheel!=null and
        not front._emote_wheel.visible and
        front._emote_wheel.find_child(
            "AuroraAvailableCharacterEmote",true,false)!=null,
        "tap-to-open authentic emotes not installed")
    var press:=InputEventMouseButton.new()
    press.button_index=MOUSE_BUTTON_LEFT
    press.pressed=true
    var real_bounds: Rect2=front._portrait_character_hit_rect()
    check(real_bounds.has_area() and
        front._preview_hit_character(real_bounds.get_center()) and
        not front._preview_hit_character(Vector2(260,200)),
        "only the real operator should be selectable, not the hangar")
    press.position=real_bounds.get_center()
    front._preview_input(press)
    press.pressed=false
    front._preview_input(press)
    check(front._emote_wheel.visible,
        "tapping Lila did not reveal actual emote choices")
    var close: Button=front._emote_wheel.find_child(
        "CloseCharacterEmotes",true,false) as Button
    if close!=null:
        close.pressed.emit()
    check(not front._emote_wheel.visible,
        "emotes could not be dismissed")
    check(avatar==front._preview_avatar,
        "emote interaction replaced Lila's skinned model")

    # The profile in the TOP-LEFT is a native panel over the real lobby.
    # Its numbers are read from the signed offline match ledger.
    check(front._top_account_button.is_visible_in_tree() and
        front._top_account_button.get_global_rect().get_center().x<
            root.get_visible_rect().size.x*.34 and
        not front._stats_strip.visible,
        "player profile is not at top-left or obsolete 0P/0V strip remains")
    front._top_account_button.pressed.emit()
    var profile: Control=front._profile_overlay
    check(profile!=null and profile.is_visible_in_tree() and
        profile.find_child("RealPlayerProfilePanel",true,false)!=null,
        "profile action does not open real player information")
    var current: Dictionary=front._offline_records.snapshot()
    var actual: Array[int]=[
        int(current.get("played",0)),int(current.get("wins",0)),
        int(current.get("kills",0))]
    for i in range(3):
        check(front._profile_stat_labels.size()>i and
            front._profile_stat_labels[i].text==str(actual[i]),
            "profile invented matches, victories or kills at index "+str(i))
    check(front._profile_id_label.text.contains("LOCAL") and
        not front._profile_id_label.text.contains("ID 00000"),
        "unverified Firebase ID displayed as official")
    var close_profile: Button=profile.find_child(
        "CloseRealProfile",true,false) as Button
    if close_profile!=null:
        close_profile.pressed.emit()
    check(not profile.visible and front.stage=="lobby",
        "closing profile did not return to actual Lila lobby")

    mode.select(1)
    mode.item_selected.emit(1)
    check(not front._battle_entry.visible and
        front._lobby_mode_status.visible and
        front._lobby_mode_status.text.contains("BLOQUEADA"),
        "ranked mode falsely starts a local/online match")
    mode.select(2)
    mode.item_selected.emit(2)
    check(front._training_entry.visible and
        front._training_entry.text=="INICIAR",
        "real training mode is inaccessible through the only selector")
    mode.select(0)
    mode.item_selected.emit(0)
    check(front._battle_entry.visible and
        front._battle_entry.text=="INICIAR",
        "selecting Classic did not restore the real BR launch")
    root.size=Vector2i(1280,720)
    await process_frame
    front._layout_safe()
    await process_frame
    check(not front._play_match_card.get_global_rect().intersects(
        front._social_panel.get_global_rect()) and
        not front._play_match_card.get_global_rect().intersects(
        front._bottom_navigation.get_global_rect()),
        "responsive desktop/phone lobby has overlapping real panels")
    root.size=Vector2i(964,434)
    await process_frame
    front._layout_safe()
    front._welcome()
    await process_frame
    check(front.stage=="welcome" and
        front._preview_container==null and
        front._emote_wheel==null and
        not front._profile_overlay.visible and
        not front._auto_resume_on_entry,
        "account-management return leaks 3D memory or auto-skips chooser")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75171_REAL_LOBBY PASS real_mobile_UI=1 genuine_profile=1 "+
            "modes=3 ranked_gated=1 training=1 click_emotes=1 "+
            "drag_rotation=V75108 automatic_auth_policy=1 "+
            "login=real_async_3 layout_964=1 layout_1280=1")
    quit(1 if failed else 0)
