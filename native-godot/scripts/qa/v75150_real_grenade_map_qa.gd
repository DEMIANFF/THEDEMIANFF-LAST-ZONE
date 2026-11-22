extends SceneTree
## V75.150 real, moving grenade and 50-fighter BR share ONE map threat source.
## HUD location is camera-relative and contains no fictional contacts.
const GRENADE=preload("res://scripts/combat/aurora_grenade.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75150_REAL_GRENADE_MAP "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    var tactical: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    var warning: Label=hud.get_node(
        "AuroraTacticalOverlay/LivePhysicalGrenadeThreat")
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    check(combat.nearby_live_grenade_hazards(Vector2.ZERO).is_empty() and
        (radar.call("nearby_live_grenade_hazards") as Array).is_empty() and
        (tactical.call("_live_active_grenades") as Array).is_empty() and
        not warning.visible,
        "training mode fabricated grenade pings or audible warnings")

    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        combat._targets.size()==49,
        "physical BR roster was reduced by tactical threat display")
    var at:=Vector2(8.0,-22.0)
    player.global_position=Vector3(at.x,
        terrain.height_at(at.x,at.y)+1.4,at.y)
    player.set("_yaw",0.0)
    var grenade: Node3D=GRENADE.new()
    combat.add_child(grenade)
    grenade.global_position=player.global_position+Vector3(4.0,.4,0)
    grenade.velocity=Vector3.ZERO
    grenade.excluded=player.get_rid()
    grenade.set_physics_process(false)
    grenade.audible_fuse.connect(combat._on_grenade_audible_fuse)
    grenade.detonated.connect(combat._on_grenade_detonated)
    combat._grenades.append(grenade)
    grenade._remaining=.72
    var near: Array[Dictionary]=combat.nearby_live_grenade_hazards(
        Vector2(player.global_position.x,player.global_position.z))
    check(near.size()==1 and
        (near[0]["at"] as Vector2).distance_to(
        Vector2(grenade.global_position.x,grenade.global_position.z))<.01
        and absf(float(near[0]["seconds_left"])-.72)<.01,
        "map threat coordinates are not from the moving physical grenade")
    check((radar.call("nearby_live_grenade_hazards") as Array).size()==1
        and (tactical.call("_live_active_grenades") as Array).size()==1,
        "minimap and tactical map read different grenade sources")
    check(combat.nearby_live_grenade_hazards(
        Vector2(player.global_position.x,player.global_position.z),
        32.0,0).is_empty(), "zero-marker budget exposed an explosive")
    check(combat.nearby_live_grenade_hazards(
        Vector2(player.global_position.x+100.0,player.global_position.z),
        32.0,3).is_empty(), "remote grenade leaked on island-wide radar")

    grenade._physics_process(.04)
    check(warning.visible and warning.text.contains("GRANADA CERCANA")
        and warning.text.contains("DER") and
        warning.text.contains("4m"),
        "real, north-facing camera did not get right-side warning")
    # A Godot -90 degree yaw faces world EAST (+X), so this same real
    # projectile must now be ahead, not on the right. Positive +90 yaw
    # faces WEST and must correctly put the projectile behind us.
    player.set("_yaw",-PI*.5)
    hud.show_real_grenade_warning(.6,grenade.global_position)
    check(warning.text.contains("FRENTE"),
        "east-facing physical camera fails to put eastern grenade ahead")
    player.set("_yaw",PI*.5)
    hud.show_real_grenade_warning(.6,grenade.global_position)
    check(warning.text.contains("DETRAS"),
        "west-facing physical camera fails to put eastern grenade behind")
    player.set("_yaw",0.0)
    grenade.global_position=player.global_position+Vector3(-4,.4,0)
    hud.show_real_grenade_warning(.6,grenade.global_position)
    check(warning.text.contains("IZQ"),
        "negative x grenade did not produce a left warning")

    # Same real projectile moves out of audible/visible range.
    grenade.global_position=player.global_position+Vector3(60,0,0)
    check(combat.nearby_live_grenade_hazards(
        Vector2(player.global_position.x,player.global_position.z)).is_empty()
        and (radar.call("nearby_live_grenade_hazards") as Array).is_empty()
        and (tactical.call("_live_active_grenades") as Array).is_empty(),
        "remote grenade persists as a phantom minimap/match marker")
    grenade.global_position=player.global_position+Vector3(3,.4,0)
    grenade._remaining=.02
    grenade._physics_process(.03)
    check(bool(grenade.get("_spent")) and
        combat.nearby_live_grenade_hazards(
        Vector2(player.global_position.x,player.global_position.z)).is_empty(),
        "spent physical grenade remains a map danger icon")
    combat.end_sector_battle()
    director.match_ended=true
    check((radar.call("nearby_live_grenade_hazards") as Array).is_empty()
        and (tactical.call("_live_active_grenades") as Array).is_empty()
        and not warning.visible,
        "match end leaked a stale grenade or hazard warning")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75150_REAL_GRENADE_MAP PASS 50_fighters=1 "+
            "same_physical_map_source=1 near_only=1 maximum3=1 "+
            "HUD_camera_bearing=LEFT_RIGHT_FRONT no_remote=1 "+
            "no_spent_icons=1 no_training_or_postmatch_ghost=1")
    quit(1 if failed else 0)
