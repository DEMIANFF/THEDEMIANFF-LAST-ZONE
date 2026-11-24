extends SceneTree
## V75.178 + V75.183 regression: same original character at all ranges, real weapon slot 4,
## gear-case 3D loot and bounded empty death crate feedback.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const FAMILIES=preload("res://scripts/combat/aurora_weapon_families.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75178_REAL_COMBAT_PRESENTATION "+reason)


func _verify() -> void:
    check(ResourceLoader.exists(
        "res://assets/characters/aurora_operator.glb","PackedScene"),
        "original humanoid opponent scene not available in build")
    check(WEAPONS.KRISS==4 and
        FAMILIES.family_for_slot(WEAPONS.KRISS)==FAMILIES.SMG and
        ResourceLoader.exists(str(WEAPONS.ENTRIES[WEAPONS.KRISS]["asset"])),
        "Vector 3D missing from original stable weapon catalog")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    var real_supply: Area3D=director.get_node_or_null(
        "AuroraLoot1") as Area3D
    var source: MeshInstance3D=real_supply.get_node_or_null(
        "SupplyCacheVisual/AuroraSupplyPod") as MeshInstance3D
    check(source!=null and source.mesh is BoxMesh,
        "world pickup remains a circular prototype")
    var beacon: MeshInstance3D=real_supply.get_node_or_null(
        "SupplyCacheVisual/SupplyBeacon") as MeshInstance3D
    check(beacon!=null and beacon.mesh is BoxMesh,
        "circular loot-floor cylinder survived equipment visual overhaul")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var hit_arc: Control=hud.get_node_or_null(
        "AuroraTacticalOverlay/AuroraRealDamageDirection") as Control
    check(hit_arc!=null,
        "real source-driven incoming-damage compass missing")
    if hit_arc!=null:
        var player: CharacterBody3D=game.get_node("Operator")
        hud.show_incoming_fire(
            player.global_position+Vector3(0,0,-5),player)
        check(float(hit_arc.get("_remaining"))>0.0,
            "actual incoming muzzle direction did not illuminate HUD")
    var count: int=director.get_loot_remaining()
    director._spawn_empty_opponent_marker(Vector3(2,8,-12),"SIN OBJETOS")
    check(director._empty_death_markers.size()==1 and
        director.get_loot_remaining()==count,
        "empty death crate fabricated live inventory or ignored real death")
    for i in range(19):
        director._spawn_empty_opponent_marker(
            Vector3(float(i),8.0,-12),"SIN OBJETOS")
    check(director._empty_death_markers.size()==director.MAX_EMPTY_DEATH_MARKERS and
        director.get_loot_remaining()==count,
        "empty corpse markers leaked GPU nodes or invented supplies")
    director.start_sector_battle()
    director.set_process(false)
    check(director._empty_death_markers.is_empty(),
        "new match retained stale corpses from previous round")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75178_REAL_COMBAT_PRESENTATION PASS far=original_humanoid "+
            "Vector=real_slot4 world_loot=gear_case "+
            "empty_corpses=bounded no_fake_loot=1 reset=1")
    quit(1 if failed else 0)
