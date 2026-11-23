extends SceneTree
## V75.81: real 50-agent offline match + definitive 11-minute ring QA.
## Runs on Main.tscn with actual CharacterBody3D opponents, not fake accounts.
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const DIRECTOR=preload("res://scripts/match/sector_director.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7581_50_AI_FINAL_ZONE "+reason)


func _verify() -> void:
    check(COMBAT.ALLOWED_ENCOUNTERS==[9,20,30,50],
        "50-person actual local AI mode is not selectable")
    check(DIRECTOR.SHRINK_DURATION==600.0 and
        DIRECTOR.OVERTIME_DURATION==60.0 and
        DIRECTOR.OVERTIME_RADIUS>0.0,
        "11-minute real final ring is not configured")
    # One genuine BR mode, no debug-facing player-count dropdown.
    var menu: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(menu)
    await menu.wait_for_startup()
    await process_frame
    menu._enter_local_lobby()
    await process_frame
    check(menu.find_child("OfflineEncounterSize",true,false)==null and
        not menu._lobby_section_hint.visible and
        menu._match_mode_selector.get_item_text(0)=="CLÁSICO" and
        menu._battle_entry.text=="INICIAR",
        "fixed 50-player BR must remain playable without duplicate labels")
    menu.queue_free()
    await process_frame
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    # Avoid AI movements while verifying roster, geometry and zone.
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(50)
    check(combat.encounter_size==50,"50-agent match request was rejected")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat._targets.size()==49 and
        combat.active_fighter_count()==50,
        "real physical 49-bot roster or living player is missing")
    var distant_lod: int=0
    var physical_colliders: int=0
    for rival in combat._targets:
        if not is_instance_valid(rival):
            continue
        if rival.distance_lod:
            distant_lod+=1
        if rival.get_node_or_null("OpponentCollider") is CollisionShape3D:
            physical_colliders+=1
        check(rival.health>0.0 and rival.sector_battle,
            "player counted as alive without a combat-ready bot")
    check(physical_colliders==49 and distant_lod==41,
        "50 participants fabricated or stripped of physical colliders/LOD")
    var last_radius: float=DIRECTOR.INITIAL_RADIUS
    for second in range(0,661,5):
        var state: Dictionary=director.zone_state_at(float(second))
        var ring: float=float(state["radius"])
        check(ring<=last_radius+.0001 and
            ring>=DIRECTOR.OVERTIME_RADIUS-.0001,
            "storm grew, vanished or exceeded final radius at "+str(second))
        last_radius=ring
    var at_600: Dictionary=director.zone_state_at(600.0)
    var at_630: Dictionary=director.zone_state_at(630.0)
    var at_660: Dictionary=director.zone_state_at(660.0)
    check(absf(float(at_600["radius"])-DIRECTOR.FINAL_RADIUS)<.001 and
        int(at_600["remaining"])==60 and
        float(at_630["radius"])<DIRECTOR.FINAL_RADIUS and
        float(at_630["radius"])>DIRECTOR.OVERTIME_RADIUS and
        absf(float(at_660["radius"])-DIRECTOR.OVERTIME_RADIUS)<.001 and
        int(at_660["remaining"])==0,
        "real final ring does not close gradually between 10:00 and 11:00")
    combat.set_encounter_size(9)
    combat.begin_sector_battle()
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat._targets.size()==8 and
        combat.active_fighter_count()==9,
        "reducing 50 to nine left stale living opponents")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7581_50_AI_FINAL_ZONE PASS roster=50 collision=49 "+
            "distant_lod=41 reduced=9 overtime=600_to_660 "+
            "online=false phone_performance=not_measured")
    quit(1 if failed else 0)
