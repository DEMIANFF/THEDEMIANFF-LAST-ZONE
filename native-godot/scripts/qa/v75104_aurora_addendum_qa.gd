extends SceneTree

const CONTACTS = preload("res://scripts/animation/aurora_foot_contacts.gd")
const MEDIA = preload("res://scripts/audio/aurora_addendum_audio.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("verify")


func check(result: bool,label: String) -> void:
    if not result:
        push_error("V75104 "+label)
        failed=true


func frames(count: int,physics: bool=false) -> void:
    for i in range(count):
        if physics:
            await physics_frame
        else:
            await process_frame


func _music_fixture() -> AudioStream:
    var sample:=AudioStreamWAV.new()
    sample.mix_rate=22050
    sample.format=AudioStreamWAV.FORMAT_16_BITS
    var data:=PackedByteArray()
    data.resize(22051*2)
    for i in range(22050):
        data.encode_s16(i*2,int(sin(TAU*440.0*float(i)/22050.0)*3800.0))
    sample.data=data
    sample.loop_mode=AudioStreamWAV.LOOP_FORWARD
    sample.loop_end=22050
    return sample


func verify() -> void:
    var clock=CONTACTS.new()
    check(not clock.advance(&"AuroraArmedWalk",.11,1.0,.02) and
        clock.advance(&"AuroraArmedWalk",.15,1.0,.04) and
        not clock.advance(&"AuroraArmedWalk",.15,1.0,.02) and
        not clock.advance(&"AuroraArmedRun",.35,1.0,.02),
        "foot plants repeat or fire on a clip transition")

    var boot:=load("res://scenes/Boot.tscn") as PackedScene
    var front:=boot.instantiate() as Control
    root.add_child(front)
    await front.wait_for_startup()
    await process_frame
    var music: Node=root.get_node("AuroraLobbyMusic")
    var speaker: AudioStreamPlayer=music.get_node("LobbyBGM")
    check(not speaker.playing,"music audible before lobby entry")
    var local_music: AudioStream=MEDIA.imported("aurora_lobby_loop.ogg")
    if local_music==null:
        speaker.stream=_music_fixture()
    front._enter_local_lobby()
    await frames(6)
    check(speaker.playing and music.get_child_count()==1,"lobby did not start the single speaker")
    var playing: AudioStreamPlayback=speaker.get_stream_playback()
    for tab in ["PERSONAJE","ARMAS","MISIONES","TIENDA","PASE","EVENTOS","LUCK ROYALE","CUENTA"]:
        front._select_tab(tab)
        await process_frame
        check(speaker.playing and speaker.get_stream_playback()==playing,"tab restarted the music: "+tab)
    music.enter_lobby()
    check(speaker.get_stream_playback()==playing,"duplicate lobby signal rewound the track")
    front._open_settings()
    var menu: CanvasLayer=front._settings_modal
    menu._show_category("SONIDO")
    var slider:=menu.find_child("Audio_music",true,false) as HSlider
    var prior_volume: float=slider.value
    slider.value=0.0
    var cfg:=ConfigFile.new()
    cfg.load("user://aurora_audio.cfg")
    check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and speaker.playing,
        "music mute stopped playback or missed the bus")
    check(is_zero_approx(float(cfg.get_value("audio","music",-1.0))),"music volume did not persist")
    slider.value=prior_volume
    menu._close()
    music._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
    check(speaker.stream_paused,"app suspension did not pause the lobby source")
    music._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
    check(not speaker.stream_paused and speaker.get_stream_playback()==playing,
        "app resume changed the active source")
    front._show_lobby()
    var avatar: Node3D=front._preview_avatar
    var anim:=avatar.find_child("AnimationPlayer",true,false) as AnimationPlayer
    var rig:=avatar.find_child("Skeleton3D",true,false) as Skeleton3D
    var timer: Timer=anim.get_node("LobbyGestureTimer")
    timer.timeout.emit()
    check(anim.current_animation==&"aurora_lobby/Motion","lobby did not play its retarget")
    anim.advance(.30)
    anim.seek(.03,true)
    rig.force_update_all_bone_transforms()
    var wrist: int=rig.find_bone("RightHand")
    var foot: int=rig.find_bone("RightFoot")
    var first_wrist: Vector3=rig.get_bone_global_pose(wrist).origin
    var first_foot: Vector3=rig.get_bone_global_pose(foot).origin
    anim.seek(2.6,true)
    rig.force_update_all_bone_transforms()
    var wrist_motion: float=first_wrist.distance_to(rig.get_bone_global_pose(wrist).origin)
    var foot_motion: float=first_foot.distance_to(rig.get_bone_global_pose(foot).origin)
    check(wrist_motion>.08 and foot_motion<.02,
        "retarget wrist travel %.3f or planted foot travel %.3f"%[wrist_motion,foot_motion])

    front._launch_hud_editor()
    await frames(12)
    var hud: CanvasLayer=front._game.get_node("TrainingHUD")
    check(hud._hud_editing and speaker.playing and speaker.get_stream_playback()==playing,
        "HUD editor interrupted lobby music")
    hud._hud_edit_close()
    await frames(5)
    check(front.stage=="lobby" and speaker.get_stream_playback()==playing,
        "return from HUD editor created a second playback")
    front._launch(false)
    await frames(6)
    check(front.stage=="training" and not speaker.playing,"real training kept lobby music")
    front._return_to_lobby()
    await frames(4)
    check(speaker.playing and speaker.get_stream_playback()!=playing,"training return did not restart music")

    front._launch(true)
    await frames(6)
    var game: Node3D=front._game
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var flight: Node3D=director._flight
    var sound: Node3D=game.get_node("AuroraSoundStage")
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    check(flight.phase=="aircraft" and not speaker.playing and sound._flight_transition.playing,
        "real aircraft phase did not select overflight or allowed lobby music")
    if local_music!=null:
        check(speaker.stream==local_music and sound._flight_transition.stream==MEDIA.imported("aircraft.ogg") and
            sound._samples["grenade"]==MEDIA.imported("grenade.ogg") and
            sound._walking_steps[0]==MEDIA.imported("walk_0.wav") and
            sound._running_steps[0]==MEDIA.imported("run_0.wav"),"supplied audio was replaced by a fallback")
    var overflight: AudioStreamPlayback=sound._flight_transition.get_stream_playback()
    sound.set_aircraft_audio(true)
    check(sound._flight_transition.get_stream_playback()==overflight,"overflight restarted on duplicate phase")
    flight.jump_from_aircraft()
    await frames(5)
    check(flight.phase=="freefall" and not sound._flight_transition.playing,"jump did not stop overflight")
    flight.deploy_parachute()
    await frames(5)
    check(flight.phase=="parachute" and not sound._flight_transition.playing and not speaker.playing,
        "parachute restored one of the wrong audio layers")

    director.start_sector_battle()
    director.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var platform:=StaticBody3D.new()
    platform.collision_layer=3
    var collider:=CollisionShape3D.new()
    var slab:=BoxShape3D.new()
    slab.size=Vector3(60,.5,60)
    collider.shape=slab
    platform.add_child(collider)
    game.add_child(platform)
    platform.global_position=Vector3(320,20,320)
    player.global_position=Vector3(320,20.28,328)
    player.velocity=Vector3.ZERO
    player._yaw=0.0
    player._desired_yaw=0.0
    player._pitch=0.0
    player._desired_pitch=0.0
    await frames(16,true)
    check(player.is_on_floor() and combat.active_fighter_count()==50,"arena or real roster missing")
    var detonations: Array[Vector3]=[]
    combat.grenade_detonated.connect(func(at: Vector3): detonations.append(at))
    combat.collect_sector_loot("grenade")
    var before: int=sound._blast_cursor
    check(combat.throw_grenade() and combat.grenades_remaining==0 and
        sound._blast_cursor==before,"throw skipped inventory or triggered the sound early")
    if combat._grenades.is_empty():
        quit(1)
        return
    var projectile: Node3D=combat._grenades[0]
    await frames(86,true)
    var rival: CharacterBody3D=combat._targets[0]
    var second: CharacterBody3D=combat._targets[1]
    rival.global_position=projectile.global_position+Vector3(2,0,0)
    second.global_position=projectile.global_position+Vector3(-3,0,0)
    var wall:=StaticBody3D.new()
    var wall_shape:=CollisionShape3D.new()
    var box:=BoxShape3D.new()
    box.size=Vector3(.25,4,8)
    wall_shape.shape=box
    wall.add_child(wall_shape)
    game.add_child(wall)
    wall.global_position=projectile.global_position+Vector3(-1.7,1.0,0)
    var health: float=rival.health
    var protected_health: float=second.health
    await frames(28,true)
    check(detonations.size()==1 and rival.health<health and second.health==protected_health and
        sound._blast_cursor==(before+1)%sound.SPATIAL_BLASTS,
        "physical fuse, occluded damage and one spatial sound diverged")
    check(sound._spatial_addendum[sound.SPATIAL_STEPS+before].playing and combat._grenades.is_empty(),
        "the explosion tail ended with the projectile")
    for i in range(3):
        combat.collect_sector_loot("grenade")
        check(combat.throw_grenade(),"simultaneous particle/voice test failed to launch")
    await frames(115,true)
    check(detonations.size()==4,"three concurrent grenades did not produce exactly three detonations")
    for i in range(sound.SPATIAL_BLASTS):
        check(sound._spatial_addendum[sound.SPATIAL_STEPS+i].playing,"simultaneous blast voice was stolen")
    combat.collect_sector_loot("grenade")
    if combat.throw_grenade():
        combat._grenades[0].global_position=Vector3(500,20,500)
        await frames(5,true)
        check(detonations.size()==4 and combat._grenades.is_empty(),"out-of-bounds projectile detonated")
    else:
        check(false,"out-of-bounds test could not launch")
    combat.collect_sector_loot("grenade")
    check(combat.throw_grenade(),"cancel test could not launch")
    combat.end_sector_battle()
    await frames(10,true)
    check(detonations.size()==4 and combat._grenades.is_empty(),"match end detonated a canceled projectile")
    front._return_to_lobby()
    await frames(5)
    check(speaker.playing and front.stage=="lobby","BR return did not restore lobby music")
    front._welcome()
    check(not speaker.playing,"logout leaked lobby music")
    playing=null
    overflight=null
    speaker.stream=null
    front.queue_free()
    await frames(12)
    if not failed:
        print("V75104_ADDENDUM PASS clip_plants=1 lobby_persistence=1 retarget=1 aircraft_jump=1 grenades=1 local_media=",local_music!=null)
    quit(1 if failed else 0)
