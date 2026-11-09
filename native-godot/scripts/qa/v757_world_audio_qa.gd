extends SceneTree
## V75.7 mobile repair gate: house/terrain clearance and functioning PCM mixer.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V757_WORLD_AUDIO "+why)


func _verify() -> void:
    var scene: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    await physics_frame
    await physics_frame
    var terrain=scene.get_node("AuroraTerrain")
    var quarter=scene.get_node("PuertoAuroraCoastalQuarter")
    var sound=scene.get_node("AuroraSoundStage")
    var player=scene.get_node("Operator")
    var combat=scene.get_node("CombatRange")
    check(sound.sound_count()>=11,"too few distinct audio cues")
    check(sound._voices.size()>=6,"polyphony not pooled")
    check(AudioServer.get_bus_index("AuroraSFX")>=0,"SFX mixer bus absent")
    check(AudioServer.get_bus_index("AuroraAmbience")>=0,"ambience mixer bus absent")
    for key in ["ar_fire","awm_fire","foot_stone","foot_snow","reload","hit","impact","wind","heal"]:
        var stream: AudioStreamWAV=sound._samples.get(key)
        check(stream!=null,"missing playable "+key)
        if stream:
            check(stream.mix_rate==22050 and stream.data.size()>2000,"invalid authored sample "+key)
    var first:int=sound._cursor
    combat.shot_fired.emit(0,false)
    check(sound._cursor==(first+1)%sound._voices.size(),"gunshot event not connected")
    first=sound._cursor
    player.footstep.emit(true)
    check(sound._cursor==(first+1)%sound._voices.size(),"footsteps not connected")
    first=sound._cursor
    player.player_damaged.emit(2.0)
    check(sound._cursor==(first+1)%sound._voices.size(),"damage cue not connected")

    # All four houses and main plaza must be level and aligned with the
    # actual physics heightfield. Zero ground intrusion into occupied rooms.
    var highest_deviation: float=0.0
    for spot in [Vector2(-4,42),Vector2(19,43),Vector2(43,41),
                 Vector2(62,28),Vector2(20,28),Vector2(29,26),
                 Vector2(5,20),Vector2(57,13)]:
        var y: float=terrain.height_at(spot.x,spot.y)
        highest_deviation=maxf(highest_deviation,absf(y-7.0))
        check(absf(y-7.0)<.08,"urban grade not planar at "+str(spot)+": "+str(y))
    var spaces:=scene.get_world_3d().direct_space_state
    for i in range(4):
        var house: Node3D=quarter.get_node("AuroraCoastalVilla"+str(i))
        var flat_y: float=terrain.height_at(house.global_position.x,house.global_position.z)
        check(absf(house.global_position.y-flat_y)<.18,"floating house "+str(i))
        for sample in [Vector3(0,.90,0),Vector3(-1.1,.90,-1.5),Vector3(1.1,.90,1.1)]:
            var position: Vector3=house.to_global(sample)
            var collider_ray:=PhysicsRayQueryParameters3D.create(
                position+Vector3.UP*.15,position-Vector3.UP*.3)
            collider_ray.collide_with_areas=false
            var hit: Dictionary=spaces.intersect_ray(collider_ray)
            check(hit.is_empty(),"terrain or obstacle penetrates house interior "+str(i)+" "+str(hit.get("collider")))
    var pavement: MeshInstance3D=quarter.get_node("AuroraCobblestoneMarketPlaza")
    check(pavement.mesh!=null,"paved plaza missing")
    check(absf(terrain.height_at(19,28)-terrain.height_at(27,28))<.09,
        "flat street still behaves like snow mountain")
    var camera: Camera3D=player.get_view_camera()
    check(camera!=null,"TPS camera disappeared")
    check(player._camera_collision_query.collision_mask==1,"camera world collision check disabled")
    print("V757_WORLD_AUDIO PASS plateau_error=",highest_deviation,
        " houses=",quarter.buildings_built," audio_samples=",sound.sound_count(),
        " polyphony=",sound._voices.size()," camera_collision=true")
    quit(1 if failed else 0)
