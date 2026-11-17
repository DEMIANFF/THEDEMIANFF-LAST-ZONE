extends SceneTree
## Live physics tests run with real original car GLBs installed privately.
## Public CI verifies no imaginary drivable cars or leaking touch controls.
const VEHICLE=preload("res://scripts/world/aurora_driveable_vehicle.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("AURORA_REAL_VEHICLES "+message)


func _verify() -> void:
    check(VEHICLE.SOURCE_FILES.size()==2 and
        not VEHICLE.source_available("nonexistent_car"),
        "source whitelist changed or imaginary model accepted")
    check(VEHICLE.MAX_FORWARD_MPS<=28.0 and
        VEHICLE.MAX_REVERSE_MPS<=8.0 and
        VEHICLE.SAFE_ENTRY_RADIUS<4.0,
        "unsafe speed or remote-enter radius")
    var main: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(main)
    var sector: Node3D=main.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=main.get_node("Operator")
    var combat: Node3D=main.get_node("CombatRange")
    var hud: CanvasLayer=main.get_node("TrainingHUD")
    combat.set_encounter_size(50)
    sector.start_sector_battle()
    sector.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot: CharacterBody3D in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    var available: int=0
    for kind in ["Toyota","BMW"]:
        available+=1 if VEHICLE.source_available(kind) else 0
    check(sector._driveable_cars.size()==available,
        "vehicle counts differ from real imported sources")
    check(not hud._vehicle_action_button.visible,
        "a vehicle action leaked into the HUD without proximity")
    hud.set_vehicle_context(true,false,0.0)
    check(hud._vehicle_action_button.visible and
        hud._vehicle_action_button.text=="CONDUCIR",
        "real proximity entry UI did not appear")
    hud.set_vehicle_context(false,true,35.4)
    check(hud._vehicle_action_button.text=="BAJAR" and
        hud._vehicle_speed_label.text=="AUTO 35 km/h" and
        not hud.get_node("AuroraTacticalOverlay/DirectionalFirePad").visible,
        "driving UI did not disable shooting or display real speed")
    hud.set_vehicle_context(false,false,0.0)
    check(not hud._vehicle_action_button.visible and
        hud.get_node("AuroraTacticalOverlay/DirectionalFirePad").visible,
        "vehicle overlay persists after safe exit")
    for car in sector._driveable_cars:
        check(car is VehicleBody3D and car._model_ready and
            car._source_visual is Node3D and car.freeze,
            "authored car geometry did not mount to genuine wheel physics")
        var wheels: int=0
        for part in car.get_children():
            if part is VehicleWheel3D:
                wheels+=1
        check(wheels==4 and car.get_node_or_null(
            "AuroraRigidChassisCollision") is CollisionShape3D,
            "vehicle suspension or physical chassis is missing")
        check(car.driver==null and not car.can_enter(player),
            "a parked model can be boarded from across the map")
    sector._remove_driveable_vehicles()
    check(sector._driveable_cars.is_empty() and
        not player.vehicle_ride_active(),
        "vehicle bodies or player riding leaked into next round")
    main.queue_free()
    await process_frame
    if not failed:
        print("AURORA_REAL_VEHICLES PASS source_cars=",available,
            " authentic_models_only=1 4_physical_wheels=1 touch_ui_safe=1")
    quit(1 if failed else 0)
