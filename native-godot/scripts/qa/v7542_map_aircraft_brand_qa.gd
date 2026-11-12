extends SceneTree
## Acceptance for the ORIGINAL Puerto Aurora real tactical map, aircraft GL
## and two-hand armed-operator visuals. Never passes on static mockups.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7542_MAP_AIRCRAFT "+why)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await process_frame
    var map: Control=hud.get_node("AuroraTacticalOverlay/AuroraFullTacticalMap")
    var button: Button=hud.get_node("AuroraTacticalOverlay/MAPA")
    check(map!=null and button!=null and map.get("terrain")==terrain and
        map.get("player")==player and map.get("director")==director,
        "full-screen map did not bind real live island, player and match director")
    check(not map.visible and button.visible,
        "map should remain closed until player taps its actual HUD button")
    hud._toggle_map()
    check(map.visible,"MAPA button did not open real map")
    var target:=Vector2(23.0,-15.0)
    var projected: Vector2=map.call("project",target)
    var result: Vector2=map.call("unproject",projected)
    check(target.distance_to(result)<.01,
        "terrain-to-screen and back projection are inconsistent")
    map.call("mark",target)
    check((map.get("waypoint") as Vector2).distance_to(target)<.1,
        "touchable map did not save true world position as waypoint")
    var saved:=ConfigFile.new()
    check(saved.load("user://aurora_map_waypoint.cfg")==OK and
        is_equal_approx(float(saved.get_value("waypoint","x",0)),target.x),
        "map marker not persisted")
    map.call("_zoom_at",1.32)
    check(float(map.get("zoom"))>1.2,
        "zoom+ did not change world scale")
    map.call("_route")
    check(not bool(map.get("_follow_player")),
        "route planner cannot frame player and waypoint")
    map.call("_clear_waypoint")
    check(not (map.get("waypoint") as Vector2).is_finite(),
        "map marker cannot be removed")
    hud._toggle_map()
    check(not map.visible,"MAPA button did not close map")

    director.begin_aircraft_phase()
    var flight: Node3D=director.get("_flight") as Node3D
    var craft: Node3D=player.get_node("AuroraTransportAircraft")
    check(flight!=null and craft!=null and str(flight.get("phase"))=="aircraft",
        "airdrop did not create true flying aircraft")
    check(craft.get_node("TransportMainWings") is MeshInstance3D and
        craft.get_node("TransportMainWings").mesh is ArrayMesh,
        "aircraft still built from rectangular box wings")
    check(craft.get_node("TransportFuselage").mesh is ArrayMesh,
        "transport still uses a raw cylinder instead of tapered airframe")
    check(craft.get_node("AuroraCockpitGlass").mesh is ArrayMesh,
        "aircraft has no actual sloped cockpit windshield")
    for side in [-1,1]:
        check(craft.get_node_or_null("AuroraTurboprop%d"%side)!=null and
            craft.get_node_or_null("AuroraEngineCowling%d"%side)!=null,
            "missing engine nacelles and cowling on aircraft")
        for blade in range(3):
            check(craft.get_node_or_null("AuroraPropeller%d_%d"%[side,blade])!=null,
                "missing low-poly 3-blade propeller geometry")
    check(absf(float(flight.ROUTE_START_Z)-76.0)<.01 and
        absf(float(flight.ROUTE_END_Z)+78.0)<.01,
        "interactive map line not tied to real aircraft path")
    hud._toggle_map()
    check(map.visible and map.get("director")==director and
        hud.get_node("AuroraTacticalOverlay/MAPA").visible,
        "full map cannot open during actual aircraft deployment")
    hud._toggle_map()

    var weapons: Node3D=combat._weapon_visuals
    check(weapons.attachment_uses_hand and weapons.right_hand_socket!=null,
        "AR weapon is not attached to actual animated hand bone")
    player.rotation.y=0.0
    player._camera_pivot.rotation.y=1.0
    player._ads_active=false
    player._fire_held=false
    weapons._align_mount_to_sight()
    var body_forward: Vector3=-player.global_basis.z
    var weapon_forward: Vector3=-weapons.mount.global_basis.z
    check(body_forward.dot(weapon_forward)>.95,
        "free-camera rotation detached weapon from operator torso")
    check(weapons.mount.global_position.distance_to(
        weapons.right_hand_socket.global_position)<.15,
        "held weapon is not positioned in the skinned right hand")
    player._ads_active=true
    weapons._align_mount_to_sight()
    var aimed: Vector3=-weapons.mount.global_basis.z
    var camera: Camera3D=player.get_view_camera()
    check(aimed.dot(-camera.global_basis.z)>.95,
        "ADS no longer points real gun mesh along the camera reticle")
    player._ads_active=false
    var skeleton: Skeleton3D=weapons.right_hand_socket.get_parent() as Skeleton3D
    var left_id: int=skeleton.find_bone("rig_LeftHand")
    var right_id: int=skeleton.find_bone("rig_RightHand")
    check(left_id>=0 and right_id>=0,
        "operator rig missing articulated left and right hands")

    var boot: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(boot)
    await process_frame
    check(ResourceLoader.exists("res://icon.svg") and
        ProjectSettings.get_setting("application/boot_splash/image")=="res://assets/ui/aurora_splash.png",
        "original logo was not integrated into the engine loading screen")
    check(boot.get_node_or_null("AuroraMenuSurface/LastZoneAuroraEmblem")!=null,
        "missing original brand emblem from start and lobby")
    check(boot.stage=="welcome","loading brand replaced splash navigation")
    if not failed:
        print("V7542_MAP_AIRCRAFT PASS real_map=1 waypoint=1 "+
            "route=1 zoom=1 aircraft_mesh=1 motors=2 propellers=6 "+
            "handheld_AR=1 free_camera_grip=1 logo_splash=1")
    quit(1 if failed else 0)
