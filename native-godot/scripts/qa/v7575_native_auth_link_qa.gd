extends SceneTree
## Android Firebase plugin is distributed separately; current Vulkan preview
## remains fail-closed. No test signs in, reaches Firebase, or grants an ID.
const BRIDGE=preload("res://scripts/persistence/aurora_firebase_bridge.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7575_AUTH_LINK "+reason)


func _verify() -> void:
    var contract: Dictionary=BRIDGE.contract()
    check(contract.get("singleton")=="AuroraFirebase" and
        contract.get("session_method")=="getSessionState",
        "Godot/Java native session contract missing")
    var state: Dictionary=BRIDGE.status()
    check(not bool(state.get("ready",true)),
        "unconfigured QA APK claimed a real App Check transport")
    var session: Dictionary=BRIDGE.session_state()
    check(not bool(session.get("authenticated",true)) and
        not bool(session.get("identity_confirmed",true)),
        "preview APK invented a Firebase login or assigned official ID")
    for identity in ["guest","google","invalid"]:
        var result: Dictionary=BRIDGE.request_sign_in(identity)
        check(not bool(result.get("queued",true)) and
            not bool(result.get("authenticated",true)),
            "missing native plugin accepted identity: "+identity)

    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    front._show_lobby()
    await process_frame
    front._select_tab("CUENTA")
    check(front._auth_guest_button!=null and front._auth_google_button!=null,
        "Godot lacks Google and guest native request controls")
    check(front._auth_guest_button.visible and
        front._auth_google_button.visible and
        front._auth_guest_button.disabled and front._auth_google_button.disabled,
        "login choices must remain visible but gated without native Firebase")
    check(front._info.text.contains("ID OFICIAL: PENDIENTE"),
        "account forged a permanent ID without a backend")
    front._start_native_auth("guest")
    check(front._info.text.contains("ACCESO NO INICIADO"),
        "blocked guest request was presented as successful")
    front._start_native_auth("google")
    check(front._info.text.contains("ACCESO NO INICIADO"),
        "blocked Google request was presented as successful")
    front._check_firebase_connection()
    check(front._info.text.contains("SIN CONEXIÓN"),
        "Firebase preflight must remain fail-closed on current preview")
    check(front._auth_guest_button.visible and front._auth_google_button.visible and
        front._auth_guest_button.disabled and front._auth_google_button.disabled,
        "preflight must preserve visible but disabled login actions")

    for res in [Vector2i(960,540),Vector2i(1280,720)]:
        root.size=res
        await process_frame
        await process_frame
        front._layout_safe()
        check(root.get_visible_rect().encloses(
            front._firebase_check_button.get_global_rect()),
            "Firebase check control clipped at "+str(res))
    front._select_tab("JUGAR")
    check(front._battle_entry.visible and
        not front._auth_guest_button.visible and
        not front._auth_google_button.visible,
        "local Classic controls were not restored after Account")
    front.queue_free()
    await process_frame
    if not failed:
        print("V7575_AUTH_LINK PASS guest=sdk_gated google=sdk_gated "+
            "appcheck=not_verified official_id=none preview=safe")
    quit(1 if failed else 0)
