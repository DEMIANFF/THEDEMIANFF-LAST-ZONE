extends SceneTree
## V75.99: physical Aurora cover prevents omniscient visual locks.
## Already-heard enemy position still allows bounded TRUE wall damage,
## while a dead CharacterBody3D cannot consume a rival's ammunition.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const COVER=preload("res://scripts/combat/aurora_deployable_cover.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7599_COVER_VISIBILITY "+why)


func _verify() -> void:
    check(BOT.COVER_PROBE_SECONDS>=.4 and BOT.COVER_PROBE_SECONDS<=.8,
        "49 enemies would query occluded wall every physics frame")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var nav: Node3D=game.get_node("AuroraNavigation")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat._targets.size()==49 and combat.active_fighter_count()==50,
        "BR lost physical 49 rivals or player")

    # Same known open test location used by V75.50 real bot firearm QA.
    # The cover is genuinely registered in PhysicsServer with a damageable
    # solid collision and original Aurora meshes, NOT a fake raycast return.
    var attacker: CharacterBody3D=combat._targets[0]
    attacker._foes.clear() # Isolate just this visual-contact test
    var base_y: float=terrain.height_at(105.0,20.0)
    attacker.global_position=Vector3(105.0,base_y+2.0,17.0)
    player.global_position=Vector3(105.0,base_y+2.0,23.0)
    var ice: StaticBody3D=COVER.new()
    ice.name="PhysicalSightOccluder"
    game.add_child(ice)
    ice.global_position=Vector3(105.0,base_y+1.30,20.0)
    await physics_frame
    await physics_frame
    check(ice.is_in_group("aurora_deployable_cover") and
        ice.get_node_or_null("AuroraIceWallCollision") is CollisionShape3D,
        "cover does not have real blocking geometry")
    check(not attacker._has_verified_sight(player) and
        attacker._has_line_of_fire(player),
        "destructible cover incorrectly grants real body visual contact")
    attacker._last_seen=player.global_position
    attacker._alert_time=4.5
    attacker._target_visible=false
    attacker._target_actor=null
    attacker._sense_player()
    check(not attacker._target_visible and attacker._target_actor==null and
        attacker._last_seen.distance_to(player.global_position)<.001,
        "physics LOS test acquired a hidden human through physical cover")

    var hp_before: float=float(ice.get("health"))
    var rounds_before: int=attacker._magazine
    var shots_before: int=attacker.shots_fired
    var human_hp: float=player.training_health
    attacker._cover_probe_clock=0.0
    attacker._attack_clock=0.0
    check(attacker._fire_at_last_known_cover() and
        is_equal_approx(float(ice.get("health")),hp_before-12.0) and
        attacker.shots_fired==shots_before+1 and
        attacker._magazine==rounds_before-1 and
        attacker._cover_probe_clock>=BOT.COVER_PROBE_SECONDS and
        player.training_health==human_hp and
        not attacker._target_visible,
        "bot failed to shoot REAL destructible cover without player wallhack")
    check(not attacker._fire_at_last_known_cover() and
        attacker.shots_fired==shots_before+1,
        "same active AI fired into cover twice without weapon cooldown")

    player.global_position+=Vector3(1.2,0,0)
    check(not attacker._has_verified_sight(player) and
        attacker._last_seen!=player.global_position,
        "moving hidden operator through Aurora wall updated bot knowledge")

    # An eliminated collision body must not remain targetable nor consume
    # real ammunition. Use the same actual health-death signal pipeline.
    var dead: CharacterBody3D=combat._targets[1]
    dead.take_training_damage(500.0,null)
    var before_dead_ammo: int=attacker._magazine
    var before_dead_shots: int=attacker.shots_fired
    check(dead.health==0.0 and not attacker._is_live_foe(dead) and
        not attacker._has_verified_sight(dead) and
        not attacker._has_line_of_fire(dead) and
        not attacker._fire_at_target(dead) and
        attacker._magazine==before_dead_ammo and
        attacker.shots_fired==before_dead_shots,
        "dead physical body retained LOS or caused wasteful automatic fire")

    # A destroyed physical barrier restores vision on the next raycast,
    # not by granting x-ray sight while the barrier still has health.
    ice.call("take_damage",COVER.MAX_HEALTH)
    await physics_frame
    await physics_frame
    attacker._sense_player()
    check(attacker._has_verified_sight(player) and
        attacker._target_actor==player and attacker._target_visible,
        "destroying a real Aurora wall did not restore physical LOS")
    attacker._last_seen=Vector3(105.0,base_y+2.0,23.0)
    attacker._target_visible=true
    attacker._cover_probe_clock=0.0
    check(not attacker._fire_at_last_known_cover(),
        "bot kept shooting invisible cover while player visibly in sight")

    game.queue_free()
    await process_frame
    if not failed:
        print("V7599_COVER_VISIBILITY PASS roster=50 "+
            "occluded_player_untracked=1 physics_cover_damage=12 "+
            "cover_probes_bounded=1 ammo_consumed_once=1 "+
            "dead_actor_fire_blocked=1 LOS_after_break=restored "+
            "online=false motorola_fps=unmeasured")
    quit(1 if failed else 0)
