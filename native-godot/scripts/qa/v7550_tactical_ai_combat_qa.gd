extends SceneTree
## V75.50 real integrated opponent tactics; never simulated online users.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const NAV=preload("res://scripts/ai/aurora_navigation.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7550_TACTICAL_AI "+reason)

func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Android Mobile Vulkan renderer switched unintentionally")
    check(BOT.MAGAZINE_CAPACITY==18 and BOT.RELOAD_SECONDS>=2.0 and
        BOT.BURST_ROUNDS==2 and BOT.MAX_VISION_RAYS<=5,
        "AI magazines, burst timing or mobile LOS budget regressed")
    check(NAV.COVER_ROUTE_PROBE_LIMIT<=8,
        "cover planner may create unbounded synchronous A* requests")
    var safe: Vector3=BOT.safe_zone_destination(
        Vector3(130.0,5.0,-24.0),Vector2(0.0,-24.0),112.0)
    check(safe.is_finite() and safe.x>40.0 and safe.x<112.0 and
        absf(safe.z+24.0)<.001 and is_equal_approx(safe.y,5.0),
        "zone escape should find an inner safe radius without clumping center")
    var inner: Vector3=BOT.safe_zone_destination(
        Vector3(12.0,3.0,0.0),Vector2.ZERO,12.0)
    check(inner.is_finite() and
        Vector2(inner.x,inner.z).length()<12.0,
        "late-stage zone escape did not find a real safe point")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var nav: Node3D=game.get_node("AuroraNavigation")
    for enemy in combat._targets:
        enemy.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for enemy in combat._targets:
        enemy.set_physics_process(false)
    check(combat._targets.size()==8 and combat.active_fighter_count()==9,
        "real physical opponent roster or battle start missing")
    var attacker: CharacterBody3D=combat._targets[0]
    var target: CharacterBody3D=combat._targets[1]
    var y: float=terrain.height_at(105.0,20.0)+2.0
    attacker.global_position=Vector3(105.0,y,17.0)
    target.global_position=Vector3(105.0,y,23.0)
    attacker.velocity=Vector3.ZERO
    target.velocity=Vector3.ZERO
    attacker.safe_radius=INF
    attacker._target_actor=target
    attacker._target_visible=true
    attacker._last_seen=target.global_position
    attacker._alert_time=3.0
    attacker._sense_clock=10.0
    attacker._attack_clock=0.0
    attacker._magazine=1
    attacker._reload_remaining=0.0
    attacker._strafe_clock=0.0
    await physics_frame
    await physics_frame
    var hp_before: float=target.health
    attacker._physics_process(.016)
    check(attacker.behavior=="strafe" and attacker._strafe_clock>0.0,
        "visible nearby enemies do not change their side-step position")
    check(attacker.shots_fired==1 and target.health<hp_before,
        "live physics ray did not hit opponent in finite final-round shot")
    check(combat.bot_tracer_events>=1 and
        combat._bot_tracers.size()==combat.BOT_TRACER_CAPACITY and
        combat._bot_tracers.any(func(t: MeshInstance3D): return t.visible),
        "real enemy shooting did not render a pooled red physics-grounded projectile")
    check(attacker._magazine==0 and attacker._reload_remaining>2.0,
        "spent magazine failed to initiate a timed tactical reload")
    var sound_count: int=attacker.shots_fired
    attacker._attack_clock=0.0
    attacker._physics_process(.016)
    check(attacker.shots_fired==sound_count,
        "opponent fired during reload instead of pausing combat")
    attacker._attack_clock=10.0
    attacker._reload_remaining=.01
    attacker._physics_process(.02)
    check(attacker._reload_remaining==0.0 and
        attacker._magazine==BOT.MAGAZINE_CAPACITY and
        attacker.reloads_completed==1,
        "timed magazine refill failed without simulated infinite ammunition")
    attacker._target_visible=false
    attacker._target_actor=null
    attacker._sense_player()
    check(attacker.vision_rays_last>=1 and
        attacker.vision_rays_last<=BOT.MAX_VISION_RAYS and
        attacker.vision_rays_total>=attacker.vision_rays_last,
        "target acquisition performed unbounded physics LOS raycasts")
    target.health=0.0
    attacker._sense_player()
    check(attacker._target_actor!=target,
        "dead opponent remains targetable by autonomous shooter")
    attacker.health=100.0
    check(not attacker.take_training_damage(-20.0) and
        not attacker.take_training_damage(NAN) and attacker.health==100.0,
        "invalid AI damage can heal an enemy or introduce NaNs")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    nav.set_physics_process(false)
    for enemy in combat._targets:
        enemy.set_physics_process(false)
    check(attacker._magazine==BOT.MAGAZINE_CAPACITY and
        attacker._reload_remaining==0.0 and attacker.reloads_completed==0 and
        attacker.shots_fired==0 and attacker.vision_rays_total==0,
        "round restart leaked magazines, wounds or AI perception statistics")
    if not failed:
        print("V7550_TACTICAL_AI PASS physical_burst=1 timed_reload=1 "+
            "str a fe=1 zone_escape=1 bounded_LOS=1 invalid_damage=1 reset=1".replace("str a fe","strafe"))
    quit(1 if failed else 0)
