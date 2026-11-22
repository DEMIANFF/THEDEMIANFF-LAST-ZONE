extends SceneTree
## Live 50-fighter BR with actual Godot grenade physics, proximity hearing,
## AI healing interruption, collision-aware explosive damage and phone HUD.
const GRENADE=preload("res://scripts/combat/aurora_grenade.gd")
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75148_GRENADE_EVASION "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var warning: Label=hud.get_node(
        "AuroraTacticalOverlay/LivePhysicalGrenadeThreat") as Label
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    check(not warning.visible and
        GRENADE.FUSE_SECONDS>GRENADE.AUDIBLE_FUSE_START_SECONDS and
        GRENADE.AUDIBLE_FUSE_INTERVAL_SECONDS>=.2,
        "training started with a fictitious grenade warning")
    # The public lobby selects a single 50-player classic roster.
    # A standalone QA scene must use the SAME gameplay contract.
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        combat._targets.size()==49 and
        combat.grenade_evasion_alerts==0,
        "a 50-fighter match was replaced or started with fake grenade events")

    var site:=Vector2(8.0,-22.0)
    var y: float=terrain.height_at(site.x,site.y)
    player.global_position=Vector3(site.x,y+2.0,site.y)
    var bot: CharacterBody3D=combat._targets[0]
    bot.global_position=Vector3(site.x+3.0,y+2.0,site.y)
    bot.safe_center=site
    bot.safe_radius=80.0
    bot.next_zone_active=false
    bot.health=100.0
    bot._field_medkits=1
    bot._target_visible=false
    bot._heal_cooldown=0.0
    bot._reload_remaining=0.0
    check(bot._begin_field_heal() and
        bot._heal_remaining>0.0,
        "physical AI rival did not start a real timed medkit channel")

    var grenade: Node3D=GRENADE.new()
    combat.add_child(grenade)
    grenade.global_position=Vector3(site.x+1.0,y+2.4,site.y)
    grenade.velocity=Vector3.ZERO
    grenade.excluded=player.get_rid()
    grenade.set_physics_process(false)
    grenade.audible_fuse.connect(combat._on_grenade_audible_fuse)
    grenade.detonated.connect(combat._on_grenade_detonated)
    grenade._remaining=.85
    grenade._physics_process(.04)
    check(combat.grenade_evasion_alerts>=1 and
        bot.grenade_dodges==1 and
        bot._grenade_evasion_left>0.0 and
        bot._grenade_last_at.is_finite(),
        "nearby real grenade fuse did not alert physical AI")
    check(bot._heal_remaining==0.0 and
        bot._field_medkits==1 and
        bot.heal_channels_interrupted>=1,
        "real enemy did not interrupt a pending finite medkit")
    check(warning.visible and warning.text.contains("GRANADA CERCANA"),
        "player's physical grenade proximity did not reach mobile HUD")
    grenade._physics_process(.04)
    check(bot.grenade_dodges==1,
        "repeated .25-second fuse notices created new fictitious dodges")
    var retreat: float=bot.global_position.distance_to(
        bot._grenade_last_at)
    bot._physics_process(.016)
    check(bot.behavior=="grenade_escape" and
        bot.health==100.0 and bot._grenade_evasion_left>0.0,
        "AI failed to prioritize the grenade escape movement over pursuit")

    var far: CharacterBody3D=combat._targets[1]
    far.global_position=Vector3(site.x+45.0,y+2.0,site.y)
    check(not far.warn_explosive(grenade.global_position,.5) and
        far.grenade_dodges==0,
        "grenade warning granted all 49 rivals omniscient explosive detection")
    var grenade_source: Vector3=grenade.global_position
    var damage_near: float=combat._blast_damage_to(grenade_source,bot)
    var damage_far: float=combat._blast_damage_to(grenade_source,far)
    check(damage_near>0.0 and damage_far==0.0,
        "explosion radius is no longer based on actual world metres")
    grenade._remaining=.015
    grenade._physics_process(.03)
    check(grenade._spent and
        combat.get_node_or_null("AuroraPhysicalBlastRing") is MeshInstance3D and
        bot.health<100.0,
        "real detonation did not damage nearby enemy and draw ground shockwave")

    hud.clear_real_grenade_warning()
    check(not warning.visible,
        "match cleanup left an explosive threat label after the fuse")
    director.match_ended=true
    combat.end_sector_battle()
    combat._on_grenade_audible_fuse(Vector3(site.x,y+2.0,site.y),.5)
    check(not warning.visible,
        "ended battle still exposed stale grenade warnings")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75148_GRENADE_EVASION PASS fighters=50 real_grenade=1 "+
            "fuse_signal=1 nearby_AI_dodges=1 finite_heal_interrupted=1 "+
            "no_remote_threat=1 true_blast_radius=1 shockwave_mesh=1 "+
            "mobile_warning=1 no_phantom_after_result=1")
    quit(1 if failed else 0)
