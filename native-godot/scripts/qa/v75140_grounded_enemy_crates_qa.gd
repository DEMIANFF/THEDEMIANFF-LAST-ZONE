extends SceneTree
## V75.140: physical opponent caches stand on their support surfaces instead
## of looking like bobbing, spinning sphere prototypes. World pickups keep
## their existing visuals. No extra ammo, medkits, collision actors or rewards.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75140_GROUNDED_ENEMY_CRATES "+why)


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
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)

    var first: CharacterBody3D=combat._targets[0]
    var spot:=Vector2(8.0,-22.0)
    first.global_position=Vector3(spot.x,
        terrain.height_at(spot.x,spot.y)+2.0,spot.y)
    first._magazine=7
    first._field_medkits=0
    check(first.health==200.0 and
        first.take_training_damage(999.0,player),
        "real 200 HP rival did not leave genuine carried ammunition")

    var cache: Area3D=director.get_node_or_null(
        "AuroraOpponentLoot1") as Area3D
    check(cache!=null and cache.from_opponent and
        cache.pickup_type=="ammo_ar" and cache.quantity==7,
        "death did not create finite physical ammo")
    if cache!=null:
        var shell: MeshInstance3D=cache.get_node_or_null(
            "SupplyCacheVisual/AuroraSupplyPod") as MeshInstance3D
        var stripe: MeshInstance3D=cache.get_node_or_null(
            "SupplyCacheVisual/OpponentCacheBand") as MeshInstance3D
        var lid: MeshInstance3D=cache.get_node_or_null(
            "SupplyCacheVisual/OpponentCacheLid") as MeshInstance3D
        var label: Label3D=cache.get_node_or_null(
            "SupplyCacheVisual/SupplyLabel") as Label3D
        check(shell!=null and shell.mesh is BoxMesh and
            stripe!=null and stripe.mesh is BoxMesh and
            lid!=null and lid.mesh is BoxMesh and
            label!=null and label.text.contains("RIVAL /") and
            label.text.contains("x7"),
            "opponent ammo cache is still a spherical placeholder")
        check(cache.get_node_or_null("LootPickupRange") is CollisionShape3D,
            "restyled cache lost the existing physical pickup range")
        var visual: Node3D=cache.get_node("SupplyCacheVisual")
        var angle_before: float=visual.rotation.y
        cache._pickup_clock=10.0
        cache._process(.7)
        check(visual.position.is_equal_approx(Vector3.ZERO) and
            absf(visual.rotation.y-angle_before)<.0001,
            "enemy crate still bobs or spins off its support surface")

    # A genuine unused medkit must use the same grounded crate without
    # mounting extra imported gear rigs on top of the death cache.
    var second: CharacterBody3D=combat._targets[1]
    second._magazine=0
    second._field_medkits=1
    check(second.take_training_damage(999.0,player),
        "physical medkit-carrying rival death failed")
    var med: Area3D=director.get_node_or_null(
        "AuroraOpponentLoot2") as Area3D
    check(med!=null and med.pickup_type=="medkit" and
        med.quantity==1 and med.from_opponent,
        "medkit cache was replaced by fake ammo")
    if med!=null:
        var med_visual: Node3D=med.get_node("SupplyCacheVisual")
        var med_body: MeshInstance3D=med_visual.get_node(
            "AuroraSupplyPod") as MeshInstance3D
        check(med_body.mesh is BoxMesh and med_body.visible and
            med_visual.get_node_or_null("OriginalAuroraGearPickup")==null,
            "opponent medkit cache retained a floating duplicate 3D prop")

    # Ordinary world supplies continue to show their original hovering
    # spherical identity; the new visual must apply only to rival death loot.
    var world: Area3D=director.get_node_or_null("AuroraLoot1") as Area3D
    check(world!=null and not world.from_opponent,
        "original world supply missing")
    if world!=null:
        var world_mesh: MeshInstance3D=world.get_node(
            "SupplyCacheVisual/AuroraSupplyPod") as MeshInstance3D
        var world_visual: Node3D=world.get_node("SupplyCacheVisual")
        check(world_mesh.mesh is SphereMesh and
            world_visual.get_node_or_null("OpponentCacheBand")==null,
            "world loot was accidentally converted to enemy crates")
        world._pickup_clock=10.0
        var world_angle: float=world_visual.rotation.y
        world._process(.7)
        check(world_visual.rotation.y>world_angle,
            "original world pickup no longer rotates")
    check(director._active_opponent_drop_count()==2,
        "physical visual change created phantom items or consumed loot")
    if not failed:
        print("V75140_GROUNDED_ENEMY_CRATES PASS real_ammo=7 "+
            "real_medkit=1 static_crates=1 animated_world_loot=1 "+
            "physical_pickup=1 active_budget=2 no_fake_items=1")
    game.queue_free()
    await process_frame
    quit(1 if failed else 0)
