extends SceneTree
## V75.89 — 50 physical agents with bounded true line-of-sight candidates,
## staggered initial CPU workload and no despawn/synthetic hit paths.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7589_BOT_AI_BUDGET "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var operator: CharacterBody3D=game.get_node("Operator")
    var nav: Node3D=game.get_node("AuroraNavigation")
    for actor in combat._targets:
        actor.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    operator.set_physics_process(false)
    nav.set_physics_process(false)
    for actor in combat._targets:
        actor.set_physics_process(false)
    check(combat.active_fighter_count()==50 and combat._targets.size()==49,
        "true 1+49 CharacterBody3D battle roster was reduced or fabricated")
    var senses: Dictionary={}
    var routes: Dictionary={}
    for actor in combat._targets:
        check(actor.sector_battle and actor.health==100.0 and
            actor._foes.size()==49 and
            actor.get_node_or_null("OpponentCollider") is CollisionShape3D,
            "a living opponent lacks physics body, adversaries or collision")
        check(actor._sense_clock>=.04 and actor._sense_clock<.38 and
            actor._route_clock>=.08 and actor._route_clock<.51,
            "AI tactical workload is not distributed across landing frames")
        senses[snappedf(actor._sense_clock,.001)]=true
        routes[snappedf(actor._route_clock,.001)]=true
    check(senses.size()>=9 and routes.size()>=8,
        "49 bots still synchronize expensive perception/pathfinding bursts")
    var attacker: CharacterBody3D=combat._targets[0]
    var nearest: Array[Dictionary]=attacker._nearest_sight_candidates()
    check(nearest.size()<=BOT.MAX_VISION_RAYS,
        "bot allocates a full roster of candidates rather than five closest")
    var closest_real: float=INF
    var player_d2: float=attacker.global_position.distance_squared_to(
        operator.global_position)
    if player_d2<BOT.SIGHT_RANGE*BOT.SIGHT_RANGE:
        closest_real=minf(closest_real,player_d2)
    for foe in combat._targets:
        if foe==attacker:
            continue
        var d2: float=attacker.global_position.distance_squared_to(
            foe.global_position)
        if d2<BOT.SIGHT_RANGE*BOT.SIGHT_RANGE:
            closest_real=minf(closest_real,d2)
    if closest_real<INF:
        check(not nearest.is_empty() and
            absf(float(nearest[0]["distance_sq"])-closest_real)<.001,
            "bounded candidate list discarded the true nearest living foe")
    var last_distance: float=0.0
    for candidate in nearest:
        var foe: CharacterBody3D=candidate["foe"]
        var dist: float=float(candidate["distance_sq"])
        check(is_instance_valid(foe) and
            (foe==operator or foe.health>0.0) and
            dist>=last_distance and dist<BOT.SIGHT_RANGE*BOT.SIGHT_RANGE,
            "near-sight list is out of order, fake or out of range")
        last_distance=dist
    attacker._sense_player()
    check(attacker.vision_rays_last<=BOT.MAX_VISION_RAYS and
        attacker.vision_rays_total>=attacker.vision_rays_last,
        "physical occlusion queries exceed 5 rays per perception interval")
    # KO one current candidate; living actors must remain selectable.
    if not nearest.is_empty():
        var defeated: CharacterBody3D=nearest[0]["foe"]
        if defeated!=operator:
            defeated.health=0.0
            for candidate in attacker._nearest_sight_candidates():
                check(candidate["foe"]!=defeated,
                    "dead enemy can still be selected as a true combat target")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7589_BOT_AI_BUDGET PASS physical_roster=50 "+
            "staggered_navigation=49 staggered_sight=49 "+
            "candidate_cap=5 real_LOS=5 targets=physical online=false")
    quit(1 if failed else 0)
