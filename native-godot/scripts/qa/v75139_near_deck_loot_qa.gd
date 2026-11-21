extends SceneTree
## A dying rival in a short fall over a raised, physically collidable deck
## leaves its finite inventory on that surface, not under it in the terrain.
## The existing v75126 regression covers deaths 25 metres above the ground.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75139_NEAR_DECK_LOOT "+why)


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

    var at:=Vector2(8.0,-22.0)
    var ground_y: float=terrain.height_at(at.x,at.y)
    # This is a real StaticBody3D floor with collision, not a fabricated
    # elevation override; the director must discover it through physics.
    var deck:=StaticBody3D.new()
    deck.name="PhysicalRaisedDeckForLootTest"
    deck.collision_layer=1
    deck.collision_mask=0
    game.add_child(deck)
    deck.global_position=Vector3(at.x,ground_y+1.5,at.y)
    var deck_shape:=CollisionShape3D.new()
    var slab:=BoxShape3D.new()
    slab.size=Vector3(3.0,.4,3.0)
    deck_shape.shape=slab
    deck.add_child(deck_shape)
    await physics_frame

    var deck_top: float=ground_y+1.7
    var victim: CharacterBody3D=combat._targets[0]
    victim.set_physics_process(false)
    victim.global_position=Vector3(at.x,deck_top+1.05,at.y)
    victim.velocity=Vector3(0.0,-3.0,0.0)
    # The actor must not report a grounded contact at death; otherwise the
    # old is_on_floor gate could hide the bug this test is meant to catch.
    var previous_mask: int=victim.collision_mask
    victim.collision_mask=0
    victim.move_and_slide()
    victim.collision_mask=previous_mask
    check(not victim.is_on_floor(),
        "test precondition failed: falling victim still marked grounded")
    victim._magazine=7
    victim._field_medkits=0
    check(victim.health==200.0,
        "physical enemy must begin at 200 HP")
    check(victim.take_training_damage(999.0,player),
        "physical rival was not eliminated")

    var drop: Area3D=director.get_node_or_null(
        "AuroraOpponentLoot1") as Area3D
    check(drop!=null and director._active_opponent_drop_count()==1,
        "real death did not produce one physical cache")
    if drop!=null:
        check(drop.from_opponent and drop.quantity==7 and
            drop.pickup_type=="ammo_ar",
            "cache invented ammunition or lost the victim inventory")
        check(absf(drop.global_position.y-(deck_top+.50))<.10,
            "falling rival cache clipped underneath raised physical floor: "+
            str(drop.global_position.y)+" expected "+str(deck_top+.50))
        check(drop.get_node_or_null("LootPickupRange") is CollisionShape3D,
            "raised-floor cache has no actual pickup collision")
    director._on_opponent_eliminated(victim,player)
    check(director._opponent_drops_spawned==1,
        "duplicate notification emitted a second death cache")

    if not failed:
        print("V75139_NEAR_DECK_LOOT PASS falling=1 physical_deck=1 "+
            "real_200_HP=1 ammo=7 snap_deck=1 no_duplicates=1")
    game.queue_free()
    await process_frame
    quit(1 if failed else 0)
