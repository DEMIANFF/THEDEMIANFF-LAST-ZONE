extends SceneTree
## V75.98 — no omniscient opponent pursuit when real gunfire is only
## heard behind cover. 50 physical agents remain present; target contact
## updates only after a real LOS confirmation, never via a hidden player.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7598_KNOWN_CONTACT_AI "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var nav: Node3D=game.get_node("AuroraNavigation")
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    nav.set_physics_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat._targets.size()==49 and combat.active_fighter_count()==50,
        "50 live physical combatants disappeared from a real BR")

    var listener: CharacterBody3D=combat._targets[0]
    var shooter: CharacterBody3D=combat._targets[1]
    var sound_position: Vector3=listener.global_position+Vector3(8.0,0,0)
    listener._target_visible=false
    listener._target_actor=null
    listener._alert_time=0.0
    listener.hear_gunshot(sound_position,shooter)
    check(listener.heard_shots==1 and listener._alert_time>=4.0 and
        listener._last_seen.distance_to(sound_position)<.001 and
        listener._target_actor==null and not listener._target_visible,
        "hearing a physical muzzle event gave an unauthorized sight lock")

    var original: Vector3=listener.global_position
    var far_a: Vector3=original+Vector3(72,0,64)
    var far_b: Vector3=original+Vector3(-83,0,-75)
    check(BOT.confirmed_contact_position(sound_position,player,false)==
        sound_position and
        BOT.confirmed_contact_position(sound_position,null,false)==
        sound_position,
        "unseen actor's live location was read instead of last gunfire")
    player.global_position=far_a
    check(BOT.confirmed_contact_position(sound_position,player,true)==far_a,
        "confirmed visual contact does not update pursuit direction")
    player.global_position=far_b
    check(BOT.confirmed_contact_position(sound_position,player,false)==
        sound_position and
        BOT.confirmed_contact_position(sound_position,player,true)==far_b,
        "bot tracks an unseen player behind walls during acoustic pursuit")

    # Two real physics navigation ticks from precisely the same bot origin,
    # last sound and AI state. Moving the unseen player over 200m must not
    # change the bot's pursuit command by a single stealth omniscience tick.
    var saved_navigation: Node3D=listener.navigation
    listener.navigation=null
    listener._target_visible=false
    listener._target_actor=null
    listener._sense_clock=100.0
    listener._attack_clock=100.0
    listener._alert_time=4.5
    listener.safe_radius=INF
    listener.next_zone_active=false
    listener._field_medkits=0
    listener.velocity=Vector3.ZERO
    player.global_position=far_a
    listener._physics_process(.032)
    var speed_a: Vector2=Vector2(listener.velocity.x,listener.velocity.z)
    check(listener.behavior=="pursuit" and speed_a.length()>.01,
        "bot does not physically investigate actual heard contact")
    listener.global_position=original
    listener.velocity=Vector3.ZERO
    listener._sense_clock=100.0
    listener._attack_clock=100.0
    listener._alert_time=4.5
    listener._target_visible=false
    listener._target_actor=null
    listener._last_seen=sound_position
    player.global_position=far_b
    listener._physics_process(.032)
    var speed_b: Vector2=Vector2(listener.velocity.x,listener.velocity.z)
    check(listener.behavior=="pursuit" and
        speed_a.distance_to(speed_b)<.04 and
        listener._last_seen.distance_to(sound_position)<.001,
        "unseen human relocation secretly changed a real bot pursuit path")

    # Visual confirmation can use the true coordinate; ending the match
    # restores all 49 bot minds without permanent audio tracking.
    check(BOT.confirmed_contact_position(sound_position,player,true)==
        player.global_position,
        "LOS-confirmed target is still constrained to obsolete audio")
    listener.navigation=saved_navigation
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        listener.heard_shots==0 and
        listener._last_seen==Vector3.ZERO and
        listener._target_actor==null,
        "new BR inherited audible contact or reduced physical roster")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7598_KNOWN_CONTACT_AI PASS physical_roster=50 "+
            "heard_without_sight=1 hidden_player_tracking=0 "+
            "true_sound_navigation=1 visual_confirmation=1 "+
            "restarted_ai=clean online=false motorola_fps=unmeasured")
    quit(1 if failed else 0)
