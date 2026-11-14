extends SceneTree
## V75.74: readiness must fail closed without a verified native bridge.
## CI is headless; nobody logs in, receives an ID or contacts production.
const FIREBASE=preload("res://scripts/persistence/aurora_firebase_bridge.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7574_FIREBASE_PREFLIGHT "+reason)


func _verify() -> void:
    var agreement: Dictionary=FIREBASE.contract()
    check(agreement.get("singleton")=="AuroraFirebase" and
        int(agreement.get("api_version",-1))==1 and
        agreement.get("requires_gradle")==true and
        agreement.get("requires_app_check")==true,
        "native transport contract is malformed")
    var state: Dictionary=FIREBASE.status()
    check(not bool(state.get("ready",true)) and
        state.get("app_check")=="not_verified" and
        state.get("player_id")=="not_assigned",
        "headless client falsely announced Firebase or an official ID")
    for provider in ["guest","google","unknown"]:
        var reply: Dictionary=FIREBASE.request_sign_in(provider)
        check(not bool(reply.get("queued",true)) and
            not bool(reply.get("authenticated",true)),
            "unverified native bridge dispatched a login: "+provider)

    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    front._show_lobby()
    await process_frame
    front._select_tab("CUENTA")
    check(front._firebase_check_button!=null and
        front._firebase_check_button.is_visible_in_tree(),
        "account has no functional Firebase readiness check")
    check(not front._battle_entry.visible and
        not front._match_mode_selector.visible,
        "Firebase diagnostics overlap gameplay buttons")
    front._check_firebase_connection()
    check(front._info.text.contains("SIN CONEXIÓN") and
        front._info.text.contains("App Check") and
        front._info.text.contains("No se ha iniciado sesión"),
        "account status announces a fake Firebase connection")
    for resolution in [Vector2i(960,540),Vector2i(1280,720)]:
        root.size=resolution
        await process_frame
        await process_frame
        front._layout_safe()
        check(root.get_visible_rect().encloses(
            front._firebase_check_button.get_global_rect()),
            "Firebase status control exceeds mobile safe layout")
    front._select_tab("PERSONAJE")
    check(not front._firebase_check_button.visible and
        front._battle_entry.visible,
        "Firebase diagnostics failed to restore Classic lobby controls")
    front.queue_free()
    await process_frame
    if not failed:
        print("V7574_FIREBASE_PREFLIGHT PASS plugin=absent auth=blocked "+
            "app_check=unverified official_id=unassigned mobile=bounded")
    quit(1 if failed else 0)
