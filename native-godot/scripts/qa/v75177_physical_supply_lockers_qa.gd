extends SceneTree
## V75.177 tests a complete NEW gameplay loop: visible world locker,
## tap-to-open, line of sight, terrain-supported physical reward, inventory
## unchanged until collision, minimap state, reset and one-shot integrity.
const LOCKER=preload("res://scripts/match/aurora_supply_locker.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


## Route a real landscape touchscreen event through Godot GUI, not only
## .pressed.emit() on an inert button.
func _tap(button: Button) -> void:
    var center: Vector2=button.get_global_transform_with_canvas()*(
        button.size*.5)
    var event:=InputEventScreenTouch.new()
    event.index=0
    event.position=root.get_final_transform()*center
    event.pressed=true
    Input.parse_input_event(event)
    await process_frame
    event=event.duplicate()
    event.pressed=false
    Input.parse_input_event(event)
    await process_frame


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75177_PHYSICAL_LOCKERS "+message)


func _verify() -> void:
    root.size=Vector2i(964,434)
    check(LOCKER.is_in_reach(Vector3.ZERO,Vector3(2.7,0,0))
        and not LOCKER.is_in_reach(Vector3.ZERO,Vector3(3.1,0,0))
        and not LOCKER.is_in_reach(Vector3.ZERO,Vector3(0,3,0))
        and not LOCKER.is_in_reach(Vector3.ZERO,Vector3.INF),
        "physical access must reject remote, vertical and invalid positions")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    check(director._supply_lockers.is_empty() and
        hud._supply_locker_button!=null and
        not hud._supply_locker_button.visible,
        "interactable locker appears in training without a BR round")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot: CharacterBody3D in combat._targets:
        bot.set_physics_process(false)
    var lockers: Array=director._supply_lockers
    check(lockers.size()>=2 and lockers.size()<=4,
        "active BR must spawn two to four separated physical lockers")
    if lockers.is_empty():
        game.queue_free()
        await process_frame
        quit(1)
        return
    var first: StaticBody3D=lockers[0]
    var contents: Array=first.authored_contents.duplicate()
    check(contents.size()==2 and first.has_node("SupplyLockerCover") and
        first.has_node("FunctionalHingedLid"),
        "the sealed box is not authored collision geometry with contents")
    var first_at:=Vector2(first.global_position.x,first.global_position.z)
    var pre_count: int=director.get_loot_remaining()
    var before: Dictionary=combat.inventory_snapshot()
    director._on_supply_interact()
    await physics_frame
    check(not first.opened and director.get_loot_remaining()==pre_count and
        director.lockers_opened==0,
        "remote interaction opens a cache without reaching it")

    # A body collider blocks the sight line from the real player.
    var player_at: Vector3=first.global_position+Vector3(1.85,-.34,0)
    player.global_position=player_at
    player.velocity=Vector3.ZERO
    await physics_frame
    var wall:=StaticBody3D.new()
    wall.name="LockerOcclusionQA"
    wall.collision_layer=1
    wall.collision_mask=0
    # Parent it BEFORE global transforms: querying a detached Node3D
    # produces Godot's "!is_inside_tree()" error in headless Android QA.
    game.add_child(wall)
    wall.global_position=first.global_position+Vector3(.9,.55,0)
    var shape:=CollisionShape3D.new()
    var bounds:=BoxShape3D.new()
    bounds.size=Vector3(.22,3.0,3.0)
    shape.shape=bounds
    wall.add_child(shape)
    await physics_frame
    check(director._nearest_supply_locker()==null,
        "line-of-sight gate allowed opening through a physical wall")
    director._on_supply_interact()
    await physics_frame
    check(not first.opened and director.get_loot_remaining()==pre_count,
        "blocked press grants concealed supplies through a wall")
    wall.queue_free()
    await physics_frame
    check(director._nearest_supply_locker()==first,
        "unobstructed on-foot world interaction cannot find the real locker")

    director._refresh_supply_interaction()
    check(hud._supply_locker_button.visible and
        not hud._supply_locker_button.disabled and
        hud._supply_locker_caption.text.contains("DEPÓSITO"),
        "nearby locker is not an interactable mobile HUD action")
    check(first_at in director.nearby_unopened_supply_lockers(first_at),
        "physical sealed cache missing from the local tactical map")
    check(first_at in hud._map_overlay._live_sealed_lockers() and
        first_at in hud._training_radar.nearby_sealed_lockers(),
        "map/minimap do not share the same real world-locker source")

    # Physical mobile tap starts a 1.25-second committed, interruptible
    # action. Opening is not an instant menu reward.
    await _tap(hud._supply_locker_button)
    await physics_frame
    check(director._search_locker==first and
        not first.opened and director.lockers_opened==0 and
        hud._supply_locker_progress.visible,
        "touch did not begin a timed real-world supply search")
    check(combat.inventory_snapshot()==before,
        "starting a search directly granted virtual inventory")
    # Interrupt with movement before the channel finishes. The intact
    # container must remain available for a new deliberate attempt.
    player._move_axis=Vector2(1,0)
    await physics_frame
    player._move_axis=Vector2.ZERO
    check(director._search_locker==null and not first.opened and
        director.get_loot_remaining()==pre_count,
        "movement failed to interrupt the search before opening")
    # The interaction must be visible again after an interrupted search,
    # even if a vehicle has a separate contextual action nearby.
    await physics_frame
    director._refresh_supply_interaction()
    check(hud._supply_locker_button.visible and
        not hud._supply_locker_button.disabled,
        "interrupted search did not reenable the same physical crate")
    await _tap(hud._supply_locker_button)
    await physics_frame
    check(director._search_locker==first and not first.opened,
        "retry did not restart the intentional search channel")
    await create_timer(director.LOCKER_SEARCH_SECONDS+.3).timeout
    await process_frame
    check(first.opened and director.lockers_opened==1 and
        director._search_locker==null,
        "completed guarded search did not open the physical locker")
    var gained_loot: int=int(combat.inventory_snapshot()["loot_collected"])-(
        int(before["loot_collected"]))
    check(director.get_loot_remaining()-pre_count+gained_loot==
        contents.size(),
        "opened locker did not produce conserved physical Area3D contents")
    check(first_at not in director.nearby_unopened_supply_lockers(first_at),
        "opened locker still appears as a sealed cache on the map")
    var first_reward: Area3D=director.get_node_or_null(
        "AuroraLocker%dRealLoot1"%first.sector_id) as Area3D
    var second_reward: Area3D=director.get_node_or_null(
        "AuroraLocker%dRealLoot2"%first.sector_id) as Area3D
    var reward: Area3D=first_reward if is_instance_valid(
        first_reward) else second_reward
    check(reward!=null or gained_loot==contents.size(),
        "physical reward did not remain in world nor enter inventory on contact")
    if is_instance_valid(reward):
        check(not reward.collected and reward.has_node("LootPickupRange"),
            "remaining locker content is not a real collectible 3D item")
        check(is_equal_approx(reward.global_position.y,
            float(game.get_node("AuroraTerrain").height_at(
                reward.world_spot.x,reward.world_spot.y))+.50),
            "opened locker loot floats or sinks below the island")
    director._on_supply_interact()
    await physics_frame
    check(director.lockers_opened==1 and
        director._search_locker==null,
        "duplicate search incorrectly reopened the same physical cache")
    # If there is a world item outside contact range, it must be obtained
    # through the original real Area3D contact, not a UI cheat.
    if is_instance_valid(reward):
        player.global_position=reward.global_position-Vector3.UP*.5
        await physics_frame
        if is_instance_valid(reward) and not reward.collected:
            reward._collect(player)
        check(int(combat.inventory_snapshot()["loot_collected"])>
            int(before["loot_collected"]),
            "a true physical reward contact did not update combat inventory")
    director.start_sector_battle()
    director.set_process(false)
    check(director.lockers_opened==0 and
        director._supply_lockers.size()>=2 and
        not director._supply_lockers[0].opened,
        "the next real round inherited opened crates or duplicated rewards")
    director._finish(false)
    check(director.nearby_unopened_supply_lockers(first_at).is_empty() and
        not hud._supply_locker_button.visible,
        "completed/defeated BR still exposes actionable sealed lockers")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75177_PHYSICAL_LOCKERS PASS sealed_3d=1 wall_blocked=1 "+
            "tap=real_HUD collision_reward=1 no_instant_grant=1 "+
            "one_shot=1 terrain=1 map_radar=1 round_reset=1")
    quit(1 if failed else 0)
