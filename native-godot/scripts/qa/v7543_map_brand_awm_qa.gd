extends SceneTree
## Acceptance for Motorola feedback: map typography, discoverable real AWM,
## non-overlapping identity, correct game title and new boot splash.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,description: String) -> void:
    if not ok:
        failed=true
        push_error("V7543_MAP_AWM "+description)


func _verify() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var player: CharacterBody3D=world.get_node("Operator")
    var combat: Node3D=world.get_node("CombatRange")
    var director: Node3D=world.get_node("AuroraSectorMatch")
    var terrain: StaticBody3D=world.get_node("AuroraTerrain")
    var hud: CanvasLayer=world.get_node("TrainingHUD")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await process_frame

    var map: Control=hud.get_node("AuroraTacticalOverlay/AuroraFullTacticalMap")
    check(map.get("terrain")==terrain,
        "real tactical map lost connection to physical island")
    map.call("_ensure_terrain_texture")
    var texture: ImageTexture=map.get("_terrain_texture") as ImageTexture
    check(texture!=null and texture.get_width()>=160,
        "map is still the old 35x35 block render")
    var point: Vector2=Vector2(8,24)
    var pos: Vector2=map.call("project",point)
    var reverse: Vector2=map.call("unproject",pos)
    check(reverse.distance_to(point)<.02,
        "central AWM map location does not follow real world coordinates")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    await process_frame
    check(director.get_loot_remaining()==25,
        "new AWM location duplicated or deleted match supplies")
    var pickup: Area3D=director.get_node("AuroraAWMWeaponPickup")
    check(pickup.pickup_type=="weapon_awm" and
        pickup.world_spot.distance_to(point)<.01 and not pickup.collected,
        "physical AWM missing from reachable central plaza")
    check(pickup.get_node_or_null(
        "SupplyCacheVisual/AWMWorldBeacon")!=null,
        "sniper weapon has no prominent world navigation beacon")
    var label: Label3D=pickup.get_node(
        "SupplyCacheVisual/SupplyLabel") as Label3D
    check(label.text=="RECOGER AWM" and label.no_depth_test,
        "sniper pickup label cannot be seen while searching")
    check(absf(pickup.global_position.y-.50-
        terrain.height_at(point.x,point.y))<.07,
        "sniper pickup floats above or below the plaza terrain")
    check(not combat.weapon_owned[1],
        "Battle Royale still starts with unearned AWM")
    player.global_position=Vector3(point.x,pickup.global_position.y-.50,point.y)
    player.velocity=Vector3.ZERO
    await physics_frame
    pickup._collect(player)
    check(pickup.collected and combat.weapon_owned[1],
        "visible physical AWM cannot be picked up and equipped")
    combat._on_weapon()
    check(combat.weapon_index==1,
        "sniper switch cannot equip AWM after pickup")

    var frontend: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(frontend)
    await process_frame
    check(str(ProjectSettings.get_setting("application/config/name")).begins_with(
        "THEDEMIAN: LAST ZONE"),"old FF game title remains in app metadata")
    check(bool(ProjectSettings.get_setting("application/boot_splash/fullsize")),
        "Godot loading image remains too small")
    var splash: Texture2D=load("res://assets/ui/aurora_splash.png") as Texture2D
    check(splash!=null and splash.get_width()>=480,
        "renamed original PNG splash missing or too small")
    var emblem: TextureRect=frontend.get_node(
        "AuroraMenuSurface/LastZoneAuroraEmblem") as TextureRect
    check(emblem.anchor_left>.65 and emblem.anchor_right<.96 and
        emblem.anchor_top<.20 and emblem.anchor_bottom<.48,
        "welcome logo still overlaps the entrance and flight settings")
    var title_found: bool=false
    for node in frontend._page.get_children():
        if node is Label and node.text=="THEDEMIAN: LAST ZONE":
            title_found=true
    check(title_found,"welcome title still contains FF")
    frontend._show_lobby()
    var portrait: Node3D=frontend._preview_avatar
    var anim: AnimationPlayer=portrait.find_child(
        "AnimationPlayer",true,false) as AnimationPlayer
    check(anim!=null and anim.current_animation=="AuroraIdle",
        "lobby still uses empty-handed armed pose without a visible rifle")
    check(emblem.anchor_left>.89 and emblem.anchor_right<.98 and
        emblem.anchor_bottom<.15,
        "lobby logo still overlaps stats or face of Lila")
    check(frontend._profile_strip.text.contains("THEDEMIAN: LAST ZONE")
        and not frontend._profile_strip.text.contains("THEDEMIANFF"),
        "lobby player profile has old brand")
    frontend._select_tab("ARMAS")
    check(frontend._info.text.contains("PLAZA (8, 24)"),
        "lobby gives no directions to the physical AWM spawn")

    if not failed:
        print("V7543_MAP_AWM PASS map_texture=160 world_awm=8_24 "+
            "beacon=1 equip=1 title_no_ff=1 boot_fullsize=1 "+
            "welcome_logo=clear lobby_logo=clear")
    quit(1 if failed else 0)
