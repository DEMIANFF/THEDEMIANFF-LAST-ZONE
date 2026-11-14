extends SceneTree
## V75.87: 50-player BR is the only public count. Training is separate.
## Tests real Godot lobby, aircraft entry and physics-bot roster.
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7587_SINGLE_BR50 "+why)


func _verify() -> void:
    check(COMBAT.CLASSIC_BR_PARTICIPANTS==50,
        "gameplay's single official roster count must be 50")
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await process_frame
    front._enter_local_lobby()
    await process_frame
    check(front.stage=="lobby" and
        front.find_child("OfflineEncounterSize",true,false)==null,
        "the old 9/20/30/50 test-size dropdown remains in the lobby")
    check(front._lobby_section_hint.text.contains("50 PARTICIPANTES") and
        front._lobby_mode_caption.visible and
        front._lobby_mode_caption.text.contains("49 IA") and
        front._battle_entry.text=="INICIAR" and
        front._battle_entry.is_visible_in_tree(),
        "live Battle Royale launch does not present a single 50-fighter mode")
    front._select_tab("CUENTA")
    front._select_tab("JUGAR")
    check(front.find_child("OfflineEncounterSize",true,false)==null,
        "navigation rebuilt a forbidden player-count dropdown")
    front.queue_free()
    await process_frame

    # A Training HUD can also request BR. That path must not accidentally
    # start the old nine-person internal performance-test roster.
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    check(combat.encounter_size==9,
        "internal QA fixture default must remain isolated from real deployment")
    director.begin_aircraft_phase()
    check(director.mode=="aircraft" and
        combat.encounter_size==COMBAT.CLASSIC_BR_PARTICIPANTS,
        "aircraft deployment did not force official 50 participants")
    director._on_airdrop_landed()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(director.mode=="sector_battle" and
        combat._targets.size()==49 and combat.active_fighter_count()==50,
        "genuine local BR did not instantiate 49 physical rivals")
    var colliders: int=0
    for opponent in combat._targets:
        if opponent.get_node_or_null("OpponentCollider") is CollisionShape3D:
            colliders+=1
    check(colliders==49,"BR opponents have no actual physical hitboxes")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7587_SINGLE_BR50 PASS no_selector=1 mode=classic "+
            "aircraft=50 physical_rivals=49 collisions=49 "+
            "multiplayer_online=not_claimed")
    quit(1 if failed else 0)
