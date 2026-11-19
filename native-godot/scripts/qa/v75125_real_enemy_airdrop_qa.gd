extends SceneTree
## Actual 49 CharacterBody3D actor descent, no phantom landing teleport.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75125_REAL_ENEMY_AIRDROP "+reason)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var player: CharacterBody3D=game.get_node("Operator")
    await physics_frame
    director.begin_aircraft_phase()
    check(not director._rivals_departed and not combat.visible,
        "rivals are awake in ground combat during flight")
    director._on_rival_airdrop_started()
    director._stage_rival_airdrops(.5)
    var first: CharacterBody3D=combat._targets[0]
    check(first._airdrop_stage in ["waiting","descending"],
        "first physical rival was not assigned an aircraft route")
    first._airdrop_delay=0.0
    for i in range(4):
        await physics_frame
    var upper: float=first.global_position.y
    check(first._airdrop_stage=="descending" and
        upper>terrain.height_at(first.global_position.x,
            first.global_position.z)+35.0 and
        first._airdrop_canopy!=null and first._airdrop_canopy.visible and
        first.get_node_or_null("OpponentCollider") is CollisionShape3D,
        "rival lacks moving capsule or visible low-poly parachute")
    for i in range(5):
        await physics_frame
    check(first.global_position.y<upper-.25,
        "enemy parachute was a visual mockup without physical descent")
    director._on_airdrop_landed()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    check(combat._targets.size()==49 and
        combat.active_fighter_count()==50 and
        first.sector_battle and first.health==BOT.MAX_HEALTH,
        "real aircraft drop reduced the physical 50-person roster")
    check(first.global_position.y>terrain.height_at(
        first.global_position.x,first.global_position.z)+30.0,
        "BR start snapped an already-falling enemy onto the ground")
    # The expanded island must actually receive real rivals outside the
    # former 205m ring, not 49 bots crowded around the original village.
    var outer_assignments: int=0
    var frontier_assignments: int=0
    for rival in combat._targets:
        if rival.spawn_coordinates.distance_to(director.CENTER)>205.0:
            outer_assignments+=1
    for site in combat.FRONTIER_SPAWN_SITES:
        for rival in combat._targets:
            if rival.spawn_coordinates.distance_to(site)<14.0:
                frontier_assignments+=1
                break
    check(outer_assignments>=2 and frontier_assignments>=2,
        "expanded BR is still deploying every physical rival near old town")
    for rival in combat._targets:
        rival.set_physics_process(false)
    if not failed:
        print("V75125_REAL_ENEMY_AIRDROP PASS physics=1 "+
            "canopy=1 physical_drop=1 no_teleport=1 "+
            "outer_rivals=1 roster=50")
    quit(1 if failed else 0)
