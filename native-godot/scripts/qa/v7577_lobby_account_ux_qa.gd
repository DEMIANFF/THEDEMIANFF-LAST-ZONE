extends SceneTree
## V75.77: mobile lobby hierarchy and visibly gated Firebase sign-in.
## Headless checks DO NOT contact Firebase or assign cloud identities.
const BRIDGE=preload("res://scripts/persistence/aurora_firebase_bridge.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool, detail: String) -> void:
    if not ok:
        failed=true
        push_error("V7577_LOBBY_ACCOUNT "+detail)

func _verify() -> void:
    # Guard against the exact V75.76 device regression: JNISingleton
    # exposes Java methods via has_java_method(), not Object.has_method().
    if OS.get_environment("AURORA_QA_EXPORTED")!="1":
        var bridge_source: String=FileAccess.get_file_as_string(
            "res://scripts/persistence/aurora_firebase_bridge.gd")
        check(bridge_source.contains('native.call("has_java_method"') and
            not bridge_source.contains("native.has_method(method_name)"),
            "Firebase JNI contract must use Godot 4.7 Java method introspection")
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    await process_frame
    check(front._selected_tab=="JUGAR","initial tab must be JUGAR")
    check(front._lobby_nav.get_child_count()==0,
        "obsolete nine hidden navigation entries reappeared")
    check(front._bottom_navigation.get_child_count()==5 and
        front._bottom_navigation.get_child(0).name=="BottomJUGAR",
        "real JUGAR action must be first in the active footer")
    check(front._battle_entry.visible and not front._training_entry.visible,
        "classic must be ready on initial lobby")
    check(front._lobby_section_title.text.contains("BATTLE ROYALE"),
        "lobby lacks Battle Royale mode card heading")
    # V75.155 retains six commerce shortcuts and five footer actions.
    # PRESET moved exclusively under the top-right settings gear.
    var play_footer: Button=front._bottom_navigation.get_node_or_null(
        "BottomJUGAR") as Button
    check(front._left_shortcuts.get_child_count()==6 and
        front._bottom_navigation.get_child_count()==5 and
        front._bottom_navigation.get_node_or_null("BottomPRESET")==null and
        play_footer!=null and play_footer.is_visible_in_tree() and
        front._social_panel.visible,
        "real five-button footer must offer a visible return to JUGAR")
    check(front._preview_container.find_child("AuroraSentinelCompanion",true,false)!=null,
        "live Base Aurora sentinel companion missing")

    front._select_tab("CUENTA")
    await process_frame
    check(front._lobby_section_title.text=="MI CUENTA","dedicated account heading missing")
    check(not front._auth_google_button.visible and not front._auth_guest_button.visible and
        front._login_manage_button.visible,
        "Google/Guest must be exclusive to a dedicated login screen")
    check(front._account_connection_label.visible and
        front._account_connection_label.text.contains("CONEXIÓN PENDIENTE"),
        "precise blocked Firebase status is not visibly explained")
    check(front._firebase_check_button.visible and
        front._name_entry.visible and front._name_save_button.visible,
        "account check and editable local name unavailable")
    check(front._info.text.contains("ID OFICIAL: PENDIENTE") and
        not front._info.text.contains("ID OFICIAL: 00001"),
        "account forged a numeric ID")
    check(not front._battle_entry.visible and not front._match_mode_selector.visible,
        "account controls obscured by the match UI")
    for resolution in [Vector2i(964,434),Vector2i(960,540),
            Vector2i(1280,720),Vector2i(2712,1220)]:
        root.size=resolution
        await process_frame
        await process_frame
        front._layout_safe()
        await process_frame
        var safe: Rect2=root.get_visible_rect()
        for ctl in [front._firebase_check_button,front._login_manage_button,
                front._name_entry,front._name_save_button]:
            check(ctl.is_visible_in_tree() and safe.encloses(ctl.get_global_rect()),
                "Account action clipped: "+ctl.name+" "+str(resolution))
        check(safe.encloses(front._preview_container.get_global_rect()),
            "live 3D operator clipped in Account: "+str(resolution))
    front._check_firebase_connection()
    check(front._info.text.contains("SIN CONEXIÓN") and
        not bool(BRIDGE.status().get("ready",true)),
        "blocked device showed a fake Firebase connection")
    # Follow the user-facing button instead of calling a private helper.
    # Account must return to the live match panel without losing the roster.
    play_footer.pressed.emit()
    await process_frame
    check(front._selected_tab=="JUGAR" and front._battle_entry.visible and
        front._match_mode_selector.visible and
        not front._auth_google_button.visible and not front._auth_guest_button.visible,
        "visible JUGAR footer did not restore the live Battle Royale panel")
    front._welcome()
    await process_frame
    check(front._login_google_button.visible and front._login_guest_button.visible,
        "real Google and anonymous entry screen is missing")
    check(front._login_status_label.text.contains("PENDIENTE"),
        "headless login screen falsely claims authenticated Firebase")
    front.queue_free()
    await process_frame
    if not failed:
        print("V7577_LOBBY_ACCOUNT PASS nav=commerce_and_bottom login=entry_only "+
            "android=fail_closed mobile=964x434 identity=not_fabricated")
    quit(1 if failed else 0)
