extends SceneTree
## V75.144: original SCAR/MP40/AWM GLB world pickups sit on the real
## terrain/deck support. Unlike floating supply pods they do not spin.
## Live Area3D pickup, authored Grip, and actual inventory stay intact.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75144_GROUNDED_WEAPON_MODELS "+reason)


func _model(pickup: Area3D) -> Node3D:
    var display: Node3D=pickup.get_node("SupplyCacheVisual")
    for child in display.get_children():
        if child is Node3D and child.has_meta("aurora_ground_weapon"):
            return child as Node3D
    return null


func _world_mesh_bounds(visual: Node3D) -> AABB:
    var lo:=Vector3(INF,INF,INF)
    var hi:=Vector3(-INF,-INF,-INF)
    var count: int=0
    for element in visual.find_children("*","MeshInstance3D",true,false):
        var mesh: MeshInstance3D=element as MeshInstance3D
        if mesh.mesh==null:
            continue
        count+=1
        var box: AABB=mesh.get_aabb()
        for vertex in range(8):
            var pos: Vector3=mesh.to_global(box.get_endpoint(vertex))
            lo=lo.min(pos)
            hi=hi.max(pos)
    if count==0:
        return AABB()
    return AABB(lo,hi-lo)


func _check_weapon(pickup: Area3D,terrain: StaticBody3D,
        expected: String) -> void:
    check(pickup!=null and pickup.pickup_type==expected,
        "expected real physical weapon "+expected)
    if pickup==null:
        return
    var model: Node3D=_model(pickup)
    check(model!=null and model.visible and
        pickup.get_node_or_null("LootPickupRange") is CollisionShape3D,
        "original imported "+expected+" lost visual or physics collider")
    if model==null:
        return
    var bounds: AABB=_world_mesh_bounds(model)
    var ground: float=(pickup.surface_height_override
        if is_finite(pickup.surface_height_override) else
        terrain.height_at(pickup.world_spot.x,pickup.world_spot.y))
    var centre: Vector3=bounds.get_center()
    check(bounds.size.length_squared()>.01 and
        absf(bounds.position.y-ground-.075)<.035 and
        absf(centre.x-pickup.global_position.x)<.10 and
        absf(centre.z-pickup.global_position.z)<.10,
        "original "+expected+" appears off the real floor/beacon")
    check(bounds.size.y<maxf(bounds.size.x,bounds.size.z)*.85,
        "original "+expected+" rifle stands vertically in the ground")
    var display: Node3D=pickup.get_node("SupplyCacheVisual")
    var yaw: float=display.rotation.y
    var height: float=display.position.y
    pickup._pickup_clock=10.0
    pickup._process(.7)
    check(absf(display.rotation.y-yaw)<.0001 and
        absf(display.position.y-height)<.0001,
        "real weapon spins and hovers like prototype ammo: "+expected)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.open_training_armory()
    for item in ["weapon_scar","weapon_mp40"]:
        var pickup: Area3D=combat._training_armory.get_node_or_null(
            "Training_"+item) as Area3D
        _check_weapon(pickup,terrain,item)
    var scar: Area3D=combat._training_armory.get_node(
        "Training_weapon_scar") as Area3D
    var original_grip: Node3D=scar.find_child("Grip",true,false) as Node3D
    check(original_grip!=null and
        original_grip.global_position.distance_to(scar.global_position)<.45,
        "SCAR's real physical grip detached from collectible source GLB")
    # The armory pickup still changes real inventory; this is not a
    # separate showcase image or a fake newly granted weapon.
    check(combat.collect_sector_loot("weapon_scar") and
        bool(combat.weapon_owned[WEAPONS.SCAR]),
        "actual SCAR ammo/weapon inventory contract was broken")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var awm: Area3D=director.get_node_or_null(
        "AuroraAWMWeaponPickup") as Area3D
    _check_weapon(awm,terrain,"weapon_awm")
    check(awm!=null and
        awm.get_node_or_null("SupplyCacheVisual/PickupAWMModel")!=null,
        "battle AWM uses a decorative prototype instead of the actual GLB")
    check(not bool(combat.weapon_owned[WEAPONS.AWM]),
        "battle rifle was granted without the physical AWM pickup")

    # Existing ammo pods remain animated; only weapon GLBs are grounded.
    var ammo: Area3D=director.get_node_or_null("AuroraLoot1") as Area3D
    check(ammo!=null and not ammo.pickup_type.begins_with("weapon_"),
        "no ordinary supply to check unchanged animation")
    if ammo!=null:
        var display: Node3D=ammo.get_node("SupplyCacheVisual")
        var before: float=display.rotation.y
        ammo._pickup_clock=10.0
        ammo._process(.7)
        check(display.rotation.y>before,
            "world ammo was accidentally made static")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75144_GROUNDED_WEAPON_MODELS PASS scar_real_glb=1 "+
            "mp40_real_glb=1 battle_awm_real_glb=1 floor_seated=1 "+
            "static_weapon=1 animated_ammo=1 real_colliders=1 "+
            "inventory_unchanged=1")
    quit(1 if failed else 0)
