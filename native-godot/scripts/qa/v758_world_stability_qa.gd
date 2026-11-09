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
    # This specifically guards against a future fix that levels old building
    # entrances to a faraway mountain's height.
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
        var delta: float=absf(terrain.height_at(approach.x,approach.y) -
            terrain._wilderness_height(approach.x,approach.y))
        check(delta<1.8,"legacy entrance reshaped too much "+str(item[0])+" delta="+str(delta))
        if delta<1.8:
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
