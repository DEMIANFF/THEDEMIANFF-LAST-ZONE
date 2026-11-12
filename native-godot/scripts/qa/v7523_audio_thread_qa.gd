extends SceneTree
## The Motorola V75.22 process crashed on Android's AudioTrack callback
## (SIGSEGV in libgodot_android.so), not in the last saved navigation marker.
## Verify active, audible sound cues while avoiding the Godot 4.7.2
## AudioStreamPlayer3D live-playback bus-detail replacement race.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,detail: String) -> void:
    if not ok:
        failed=true
        push_error("V7523_AUDIO_THREAD "+detail)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var sound: Node3D=game.get_node("AuroraSoundStage")
    var player: CharacterBody3D=game.get_node("Operator")
    var camera: Camera3D=player.get_view_camera()
    check(camera!=null,"missing real listener camera")
    check(sound.sound_count()>=10,"authored sound library disabled by workaround")
    check(sound._voices.size()>=6,"normal gunfire/footstep pool removed")
    check(sound._world_voices.size()==5,"real enemy gunfire voice pool removed")
    check(sound._world_buses.size()==sound._world_voices.size() and
        sound._world_panners.size()==sound._world_voices.size(),
        "per-voice directional audio buses not configured")

    for i in range(sound._world_voices.size()):
        var voice: Node=sound._world_voices[i]
        check(voice!=null and not (voice is AudioStreamPlayer3D),
            "Android native audio race path still uses AudioStreamPlayer3D")
        var bus: int=AudioServer.get_bus_index((voice as AudioStreamPlayer).bus)
        check(bus>=0 and bus==sound._world_buses[i],
            "fixed world voice bus changed after startup")
        check(AudioServer.get_bus_effect_count(bus)>=1 and
            AudioServer.get_bus_effect(bus,0) is AudioEffectPanner,
            "directional panner not on world voice bus")

    var right: Vector3=camera.global_basis.x
    right.y=0.0
    right=right.normalized()
    sound.play_world_shot(camera.global_position+right*8.0)
    await process_frame
    var pan_right: float=sound._world_panners[0].pan
    sound.play_world_shot(camera.global_position-right*8.0)
    await process_frame
    var pan_left: float=sound._world_panners[1].pan
    check(pan_right>.25 and pan_left<-.25,
        "gunfire lost left/right positioning: "+str(pan_right)+"/"+str(pan_left))
    check(sound._world_voices[0].playing and sound._world_voices[1].playing,
        "workaround muted or dropped positional gunfire")
    for i in range(70):
        await process_frame
        if i%9==0:
            sound.play_world_shot(camera.global_position+
                right*float(7+i%11))
            sound.play_event("foot_stone")
    check(sound._cursor>0 and sound._world_cursor>=0,
        "pooled sounds stopped responding under repeated audio updates")
    sound.set_enabled(false)
    for voice in sound._world_voices:
        check(not voice.playing,"disabling audio left world voice playing")
    print("V7523_AUDIO_THREAD PASS Godot mixer barrier and real PCM panned ",
        "world gunfire without live AudioStreamPlayer3D bus swaps")
    quit(1 if failed else 0)
