extends SceneTree
## V75.79: validate real winter station 3D assets and battle-royale UI.
## No screenshots or simulated accounts count as interactive game content.
var failures: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func require(ok: bool,message: String) -> void:
    if not ok:
        failures=true
        push_error("V7579_PREMIUM_LOBBY "+message)


func _verify() -> void:
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    await process_frame
    require(front.stage=="welcome","dedicated Firebase login is not the entry screen")
    require(front._login_google_button.visible and front._login_guest_button.visible,
        "Google and Guest login options are hidden")
    front._enter_local_lobby()
    await process_frame
    var viewport: SubViewport=front._preview_container.get_node(
        "PreviewViewport") as SubViewport
    var scene: Node3D=viewport.get_node("AuroraCharacterStage") as Node3D
    var station: Node3D=scene.get_node("AuroraReal3DLobbyEnvironment") as Node3D
    for element in ["AuroraResearchStation","StationSnowCap",
            "AuroraRadarDish","AuroraBackboard","WatchtowerCabin",
            "AuroraSupplyCrate","BaseAuroraSnowFir",
            "PolarAuroraCurtain","AuroraSnowPeak"]:
        require(station.find_child(element,true,false)!=null,
            "Missing original winter stage feature: "+element)
    var camera: Camera3D=scene.get_node("LobbyPortraitCamera") as Camera3D
    require(camera.fov<=40.0 and camera.position.z<=3.2,
        "Lila must fill the middle stage at Motorola resolution")
    require(front._preview_container.visible and
        scene.get_node_or_null("AuroraSentinelCompanion")!=null,
        "original sentinel and rotating Lila are not both visible")
    require(front._battle_entry.text=="INICIAR" and
        front._battle_entry.visible,
        "prominent working Battle Royale INICIAR is missing")
    require(front._social_panel.visible and
        front._social_status_label.text.contains("Sin amigos conectados"),
        "squad panel has fabricated online status")
    require(front._currency_strip.text.contains("MONEDAS") and
        front._currency_strip.text.contains("DIAMANTES"),
        "currency wallet is hidden")
    var btn: Button=front._battle_entry
    require(btn.has_theme_stylebox_override("normal"),
        "INICIAR has no styled live button")
    var gold: StyleBoxFlat=btn.get_theme_stylebox("normal") as StyleBoxFlat
    require(gold!=null and gold.shadow_size>=3,
        "live game action lacks new golden depth")
    front._select_tab("OBJETIVOS")
    require(not front._battle_entry.visible,
        "INICIAR overlaps Events/Missions content")
    front._select_tab("JUGAR")
    require(front._battle_entry.visible,
        "Battle Royale INICIAR not restored after navigation")
    for dimensions in [Vector2i(964,434),Vector2i(1280,720),
            Vector2i(2712,1220)]:
        root.size=dimensions
        await process_frame
        await process_frame
        front._layout_safe()
        await process_frame
        var safe: Rect2=root.get_visible_rect()
        for element in [front._preview_container,front._battle_entry,
                front._top_account_button,front._top_settings_button,
                front._bottom_navigation]:
            require(safe.encloses(element.get_global_rect()),
                "Mobile UI clipped "+element.name+" at "+str(dimensions))
    front.queue_free()
    await process_frame
    if not failures:
        print("V7579_PREMIUM_LOBBY PASS station=real3d snow=original "+
            "lila=larger sentinel=authored hud=unclipped account=separate "+
            "combat_access=retained pricing=not_fabricated")
    quit(1 if failures else 0)
