extends SceneTree
## V75.149: an actual, moving grenade's near-operator fuse drives an
## authored procedural PCM cue through the existing sound/volume bus.
## A distant grenade does not ping the player's speakers or reveal rivals.
const GRENADE=preload("res://scripts/combat/aurora_grenade.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75149_REAL_FUSE_AUDIO "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var sound: Node=game.get_node("AuroraSoundStage")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    var cue: AudioStream=sound._samples.get("grenade_fuse")
    check(cue!=null and sound._voices.size()==8 and
        combat.grenade_fuse_close.get_connections().size()==1,
        "physical fuse audio lacks authored sample or live SFX connection")
    if cue is AudioStreamWAV:
        check((cue as AudioStreamWAV).mix_rate==22050 and
            (cue as AudioStreamWAV).data.size()>2000 and
            (cue as AudioStreamWAV).loop_mode==AudioStreamWAV.LOOP_DISABLED,
            "short pre-rendered PCM alarm is missing or loops unsafely")
    # The existing procedural gunfire, AWM bolt and ambience are retained.
    check(sound._samples.has("awm_fire") and
        sound._samples.has("awm_bolt") and sound._samples.has("grenade"),
        "new warning stole the original blast or firearm audio slots")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    sound.set_enabled(true)
    check(combat.active_fighter_count()==50 and
        not player.royale_eliminated,
        "fuse sound test was not attached to a real 50-body combat scene")
    var source: Node3D=GRENADE.new()
    combat.add_child(source)
    source.excluded=player.get_rid()
    source.global_position=player.global_position+Vector3(1.0,.5,0.0)
    source.velocity=Vector3.ZERO
    source.set_physics_process(false)
    source.audible_fuse.connect(combat._on_grenade_audible_fuse)
    var first: int=sound._cursor
    source._remaining=.76
    source._physics_process(.04)
    var warning: Label=hud.get_node(
        "AuroraTacticalOverlay/LivePhysicalGrenadeThreat") as Label
    check(sound._cursor==(first+1)%sound._voices.size() and
        sound._voices[first].stream==cue and warning.visible,
        "physical near-fuse event did not play the actual alert in SFX pool")
    var next: int=sound._cursor
    source._physics_process(.04)
    check(sound._cursor==next,
        "granular physics ticks duplicated a .25-second fuse alert")

    # Moving the existing physical grenade far away must produce no new
    # audible notification. The scan itself never reveals hidden rivals.
    source.global_position=player.global_position+Vector3(130.0,3.0,0.0)
    source._remaining=.55
    source._fuse_warning_clock=0.0
    source._physics_process(.03)
    check(sound._cursor==next,
        "out-of-range grenade generated false player audio")
    combat.end_sector_battle()
    source._fuse_warning_clock=0.0
    source._remaining=.40
    source.global_position=player.global_position+Vector3(1.0,.5,0.0)
    source._physics_process(.03)
    check(sound._cursor==next and not warning.visible,
        "ended battle emitted ghost grenade audio or HUD warnings")
    sound.set_enabled(false)
    game.queue_free()
    await process_frame
    if not failed:
        print("V75149_REAL_FUSE_AUDIO PASS real_50_bodies=1 "+
            "one_PCM_beep=1 true_fuse_signal=1 short_nonlooping=1 "+
            "no_per_tick_spam=1 no_remote_ping=1 no_ended_round_ghost=1")
    quit(1 if failed else 0)
