extends SceneTree
## Guard old town access, real foundation clearance, coastal shelf and safe AI paths.
## This suite is deliberately independent of APK export.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool, why: String) -> void:
    if not ok:
        failed=true
        push_error("V758_WORLD_STABILITY "+why)


func _verify() -> void:
    var scene: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    await physics_frame
    await physics_frame
    var terrain=scene.get_node("AuroraTerrain")
    var quarter=scene.get_node("PuertoAuroraCoastalQuarter")
    var city=scene.get_node("PuertoAuroraSector")
    var audio=scene.get_node("AuroraSoundStage")
    # V75.41 intentionally grades the original four building footprints so
    # snow no longer enters them. Instead of rejecting any terrain change,
    # require each true collision ramp to join the new terrain safely and
    # preserve natural slopes beyond the grading transition.
    var preserved: int=0
    var clean_rooms: int=0
    for item in [
        ["CENTRO_DE_EXPLORACION",Vector2(18,-8),12.0],
        ["TALLER_HELIOS",Vector2(-19,-29),11.0],
        ["ESTACION_METEOROLOGICA",Vector2(46,-36),10.0],
        ["PUESTO_VORTEX",Vector2(-48,22),12.0]
    ]:
        var building: Node3D=city.get_node(item[0])
        var site: Vector2=item[1]
        var approach:=Vector2(site.x,site.y+float(item[2])*.5+8.0)
        var entry_ground: float=terrain.height_at(approach.x,approach.y)
        var deck_top: float=building.global_position.y+.10
        var slope: float=absf(deck_top-entry_ground)/8.0
        var physical_ramps: int=0
        for child in building.get_children():
            if child is StaticBody3D and str(child.name).begins_with("AccessibleEntryRamp"):
                var collider: CollisionShape3D=child.get_child(0) as CollisionShape3D
                if collider!=null and collider.shape is ConvexPolygonShape3D:
                    physical_ramps+=1
        # The original entrances contain TWO real consecutive convex ramps.
        # A level lot should keep the full 8m path within walkable grade.
        check(slope<.25 and physical_ramps==2,
            "unsafe legacy entry "+str(item[0])+
            " slope="+str(slope)+" ramps="+str(physical_ramps))
        var wilderness: Vector2=Vector2(site.x,site.y+
            float(item[2])*.5+26.0)
        var legacy_weight: Dictionary=terrain.legacy_grading_weight(
            wilderness.x,wilderness.y)
        check(float(legacy_weight["weight"])<.01,
            "historic grading spilled into distant terrain "+str(item[0]))
        if slope<.25 and physical_ramps==2:
            preserved+=1
        var clear: bool=true
        for local in [Vector2.ZERO,Vector2(2,2),Vector2(-2,-2),
                      Vector2(2,-2),Vector2(-2,2)]:
            var p: Vector3=building.to_global(Vector3(local.x,0,local.y))
            if terrain.height_at(p.x,p.z)>building.global_position.y+.07:
                clear=false
        check(clear,"snow ridge intrudes old room "+str(item[0]))
        if clear:
            clean_rooms+=1
    var new_homes: int=0
    for i in range(4):
        var house: Node3D=quarter.get_node("AuroraCoastalVilla"+str(i))
        var y: float=terrain.height_at(house.global_position.x,house.global_position.z)
        check(absf(y-7.0)<.08,"coastal home not on walkable plateau")
        if absf(y-7.0)<.08:
            new_homes+=1
    check(audio.sound_count()==11,"real audio event catalog missing")
    check(audio._world_voices.size()==5,"positional opponent sound voices missing")
    print("V758_WORLD_STABILITY PASS accessible_legacy_approaches=",preserved,
        " clean_old_interiors=",clean_rooms," coastal_homes=",new_homes,
        " sounds=",audio.sound_count())
    quit(1 if failed else 0)
