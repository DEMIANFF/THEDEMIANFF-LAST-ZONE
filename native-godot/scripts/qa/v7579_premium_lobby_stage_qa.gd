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
    # Match the actual Motorola landscape target before measuring composition.
    root.size=Vector2i(964,434)
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
    # V75.79 expected FOV <=40, but this cropped Lila behind the upper
    # header and bottom rail in the actual V75.109 screenshot. V75.111
    # uses a wider lens. Test the real on-screen rig, not an obsolete
    # numeric camera setting.
    var avatar: Node3D=front._preview_avatar
    require(avatar!=null and camera.current and camera.position.z<=3.2,
        "Real Lila and the active lobby camera must remain available")
    var top: float=INF
    var bottom: float=-INF
    var projected_corners: int=0
    for item in avatar.find_children("*","MeshInstance3D",true,false):
        var mesh:=item as MeshInstance3D
        if not mesh.visible:
            continue
        var bounds: AABB=mesh.get_aabb()
        for corner in range(8):
            var position: Vector3=mesh.to_global(bounds.get_endpoint(corner))
            if camera.is_position_behind(position):
                continue
            var pixel: Vector2=camera.unproject_position(position)
            top=minf(top,pixel.y)
            bottom=maxf(bottom,pixel.y)
            projected_corners+=1
    var screen_height: float=maxf(float(viewport.size.y),1.0)
    var coverage: float=(bottom-top)/screen_height
    require(projected_corners>=8 and is_finite(coverage) and
        coverage>=.42 and coverage<=.785 and
        top>=screen_height*.105 and bottom<=screen_height*.89,
        "Lila must fill the middle stage without clipping her head or feet: "+
        "coverage="+str(coverage)+" bounds="+str(Vector2(top,bottom)))
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
