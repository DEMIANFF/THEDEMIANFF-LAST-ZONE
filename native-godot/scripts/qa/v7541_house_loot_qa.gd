extends SceneTree
## Regressions from real Motorola screenshots: roofless buildings, snow
## protruding into historic rooms and AWM ammunition buried under a floor.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(condition: bool,message: String) -> void:
    if not condition:
        failed=true
        push_error("V7541_HOUSE_LOOT "+message)


func _verify() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var terrain: StaticBody3D=world.get_node("AuroraTerrain")
    var district: Node3D=world.get_node("PuertoAuroraSector")
    var quarter: Node3D=world.get_node("PuertoAuroraCoastalQuarter")
    var combat: Node3D=world.get_node("CombatRange")
    var director: Node3D=world.get_node("AuroraSectorMatch")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    var originals: Array[String]=[
        "CENTRO_DE_EXPLORACION","TALLER_HELIOS",
        "ESTACION_METEOROLOGICA","PUESTO_VORTEX"]
    var lots: Array[Vector4]=[
        Vector4(18,-8,16,12),Vector4(-19,-29,14,11),
        Vector4(46,-36,11,10),Vector4(-48,22,12,12)]
    for i in range(originals.size()):
        var house: Node3D=district.get_node(originals[i])
        var ceiling: MeshInstance3D=house.get_node(
            "SealedInteriorCeiling") as MeshInstance3D
        var solid: StaticBody3D=house.get_node(
            "SealedInteriorCeilingCollider") as StaticBody3D
        check(ceiling.mesh!=null and solid.get_child_count()>0,
            originals[i]+" has no visible and physically sealed ceiling")
        var y: float=terrain.height_at(lots[i].x,lots[i].y)
        for xx in [-.43,.0,.43]:
            for zz in [-.43,.0,.43]:
                var at:=Vector2(lots[i].x+lots[i].z*xx,
                    lots[i].y+lots[i].w*zz)
                check(absf(terrain.height_at(at.x,at.y)-y)<.11,
                    originals[i]+" mountain protrudes into floor "+str(at))
        check(house.position.y+.10-y>.40,
            "historic indoor floor is buried inside the leveled terrain")
    for i in range(quarter.HOUSE_COUNT):
        var home: Node3D=quarter.get_node("AuroraCoastalVilla"+str(i))
        var seal: StaticBody3D=home.get_node(
            "SealedVillaCeilingSolid") as StaticBody3D
        check(seal.get_child_count()>0,
            "villa "+str(i)+" ceiling is missing collision support")
        check(home.get_node_or_null("TerracottaGableRoof")!=null,
            "villa "+str(i)+" exterior roofing disappeared")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    check(director.get_loot_remaining()==25,
        "all 25 original and added pickups must remain available")
    var old_ammo: Area3D=director.get_node("AuroraLoot3")
    var old_floor: Node3D=district.get_node("CENTRO_DE_EXPLORACION")
    check(absf(old_ammo.global_position.y-.50-(old_floor.position.y+.10))<.06,
        "historic AWM ammunition was placed below the raised indoor deck")
    var outdoor: Area3D=director.get_node("AuroraLoot1")
    var pos: Vector2=outdoor.world_spot
    check(absf(outdoor.global_position.y-.50-
        terrain.height_at(pos.x,pos.y))<.06,
        "outdoor pickup is not sitting on the real terrain")
    for i in range(quarter.HOUSE_COUNT):
        var loot: Area3D=director.get_node("AuroraInteriorLoot"+str(i+1))
        var level: float=quarter.interior_supply_spots[i].y
        check(absf(loot.global_position.y-.50-level)<.065,
            "indoor loot "+str(i)+" below/above floor height by "+
            str(loot.global_position.y-.50-level))
        check(loot.get_node_or_null("SupplyCacheVisual")!=null,
            "indoor item "+str(i)+" lost its real visual")
    if not failed:
        print("V7541_HOUSE_LOOT PASS historic_flat=4 roofs=12 "+
            "coastal_roofs=8 old_AWM_on_floor=1 indoor_loot=8 outside=1")
    quit(1 if failed else 0)
