extends SceneTree
## Real Android V75.22/V75.23 SIGSEGV symbol/pointer diagnosis:
## pc libgodot_android.so+0x2f8f814 reads mono signed 16-bit PCM.
## x8 = 0x15888 (88200), at exactly 176400 bytes past PCM start.
## Aurora's looping wind used 4s * 22050 frames/s * 2 bytes = 176400
## bytes, with loop_end = 88200 and NO guard. Godot 4.7.2 WAV
## decoder reads the loop_end sample inclusive. Keep looping wind
## playable with an extra copied sample at that boundary.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,detail: String) -> void:
    if not ok:
        failed=true
        push_error("V7524_WAV_GUARD "+detail)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var sound: Node3D=game.get_node("AuroraSoundStage")
    var wind: AudioStreamWAV=sound._samples.get("wind") as AudioStreamWAV
    check(wind!=null,"missing real wind ambience")
    if wind==null:
        quit(1)
        return
    var audible_frames: int=4*22050
    var audio: PackedByteArray=wind.data
    check(wind.format==AudioStreamWAV.FORMAT_16_BITS and
        not wind.stereo and wind.mix_rate==22050,
        "wind PCM encoding must match 16-bit mono Android crash")
    check(wind.loop_mode==AudioStreamWAV.LOOP_FORWARD and
        wind.loop_begin==0 and wind.loop_end==audible_frames,
        "wind lost its original full four-second forward loop")
    check(audio.size()==(audible_frames+1)*2,
        "wind PCM must include exactly one valid decoder guard frame")
    if audio.size()>audible_frames*2:
        check(audio[audible_frames*2]==audio[0] and
            audio[audible_frames*2+1]==audio[1],
            "decoder boundary must duplicate first audible frame")
    check(sound._ambience!=null and sound._ambience.stream==wind and
        sound._ambience.playing,
        "PCM fix must not remove the original looping ambient sound")

    # Exercise the real Godot AudioStreamWAV native decoder across multiple
    # loop boundaries, not a simulated/hand-computed representation.
    var playback: AudioStreamPlayback=wind.instantiate_playback()
    playback.start()
    var decoded_frames: int=0
    for i in range(350):
        var block: PackedVector2Array=playback.mix_audio(1.0,1024)
        check(block.size()>0,"native PCM decoder produced no audio block")
        decoded_frames+=block.size()
        for sample in block:
            if not is_finite(sample.x) or not is_finite(sample.y):
                check(false,"PCM returned non-finite float while looping")
                break
    check(playback.get_loop_count()>0,
        "native WAV decoder did not actually cross the wind loop boundary")
    playback.stop()
    print("V7524_WAV_GUARD PASS native PCM wind decoder ",
        "expected_audio_bytes=",audible_frames*2,
        " padded_bytes=",audio.size(),
        " decoded_frames=",decoded_frames,
        " loop_end=",wind.loop_end)
    quit(1 if failed else 0)
