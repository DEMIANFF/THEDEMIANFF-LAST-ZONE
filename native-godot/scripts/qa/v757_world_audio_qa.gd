extends SceneTree
## Audio/terrain regression: playable cues, supported houses and paving aligned
## to the REAL terrain heightfield (not obsolete hard-coded street heights).
const RESIDENTIAL=preload("res://scripts/world/coastal_residential_layout.gd")
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
    check(sound._world_voices.size()>=4,"3D enemy audio not pooled")
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
    var contact: int=sound._foot_index
    player.foot_contact.emit(true,false)
    check(sound._foot_index==contact+1 and sound._steps.playing and
        sound._steps.stream in sound._walking_steps,"operator contact did not play a walking sample")
    var nearby: int=sound._step_cursor
    combat._targets[0].foot_contact.emit(player.global_position+Vector3.RIGHT*5.0,true,true)
    check(sound._step_cursor==(nearby+1)%sound.SPATIAL_STEPS and
        sound._spatial_addendum[nearby].stream in sound._running_steps,
        "nearby rival contact did not use the positional run sample")
    first=sound._cursor
    player.player_damaged.emit(2.0)
    check(sound._cursor==(first+1)%sound._voices.size(),"damage cue not connected")
    var spatial_before: int=sound._world_cursor
    combat._targets[0].weapon_fired.emit(combat._targets[0].global_position)
    check(sound._world_cursor==(spatial_before+1)%sound._world_voices.size(),
        "real AI gunfire not audible at world position")

    # Verify the actual eight foundation pads rather than four original
    # house coordinates plus street points. Streets and plazas intentionally
    # conform to the sculpted heightfield; the pads remain strictly level.
    var highest_deviation: float=0.0
    for site in RESIDENTIAL.SITES:
        var ground: float=terrain.height_at(site.x,site.y)
        highest_deviation=maxf(highest_deviation,
            absf(ground-RESIDENTIAL.PAD_HEIGHT))
        check(absf(ground-RESIDENTIAL.PAD_HEIGHT)<.08,
            "coastal foundation not level at "+str(Vector2(site.x,site.y))+
            ": "+str(ground))
    var spaces:=scene.get_world_3d().direct_space_state
    for i in range(RESIDENTIAL.HOUSE_COUNT):
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
    # Legacy architecture must not have snow hills inside physical rooms.
    var old_sites: Array[String]=[
        "CENTRO_DE_EXPLORACION","TALLER_HELIOS",
        "ESTACION_METEOROLOGICA","PUESTO_VORTEX"]
    for name in old_sites:
        var legacy: Node3D=scene.get_node("PuertoAuroraSector/"+name)
        for inside in [Vector2.ZERO,Vector2(2.0,2.0),Vector2(-2.0,-2.0),
                       Vector2(2.0,-2.0),Vector2(-2.0,2.0)]:
            var place: Vector3=legacy.to_global(Vector3(inside.x,0,inside.y))
            var ground_y: float=terrain.height_at(place.x,place.z)
            check(ground_y<=legacy.global_position.y+.07,
                "snow penetrates legacy interior "+name+" at "+str(inside))
    var pavement: MeshInstance3D=quarter.get_node("AuroraCobblestoneMarketPlaza")
    check(pavement.mesh!=null,"paved plaza missing")
    # The market and pedestrian lanes are projected onto the same 96x96
    # terrain triangles: check the actual paving mesh, not an obsolete
    # assumption that the entire district is uniformly 7 m above sea level.
    # The new terrain access test separately checks ramp grade and an
    # uninterrupted walkable route between homes and the inland mountains.
    var verified_paving_vertices: int=0
    var largest_paving_gap: float=0.0
    var paving_mesh: ArrayMesh=pavement.mesh as ArrayMesh
    check(paving_mesh!=null and paving_mesh.get_surface_count()>0,
        "paved plaza mesh has no visible terrain-conforming surface")
    if paving_mesh!=null and paving_mesh.get_surface_count()>0:
        var mesh_arrays: Array=paving_mesh.surface_get_arrays(0)
        var paved_vertices: PackedVector3Array=mesh_arrays[Mesh.ARRAY_VERTEX]
        var stride: int=maxi(1,int(paved_vertices.size()/64))
        for idx in range(0,paved_vertices.size(),stride):
            var vertex: Vector3=pavement.to_global(paved_vertices[idx])
            var gap: float=absf(vertex.y-terrain.height_at(vertex.x,vertex.z)-.055)
            largest_paving_gap=maxf(largest_paving_gap,gap)
            check(gap<.02,
                "paving hovers or cuts into actual terrain at "+str(vertex)+
                " gap="+str(gap))
            verified_paving_vertices+=1
    check(verified_paving_vertices>=16,
        "insufficient physical paving samples checked")
    var camera: Camera3D=player.get_view_camera()
    check(camera!=null,"TPS camera disappeared")
    check(player._camera_collision_query.collision_mask==1,"camera world collision check disabled")
    if not failed:
        print("V757_WORLD_AUDIO PASS plateau_error=",highest_deviation,
            " houses=",quarter.buildings_built,
            " paving_vertices=",verified_paving_vertices,
            " paving_gap=",largest_paving_gap,
            " audio_samples=",sound.sound_count(),
            " polyphony=",sound._voices.size()," camera_collision=true")
    sound.set_enabled(false)
    await create_timer(.12).timeout
    quit(1 if failed else 0)
