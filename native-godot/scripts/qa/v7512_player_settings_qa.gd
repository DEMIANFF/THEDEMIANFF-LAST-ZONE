extends SceneTree
## Native Godot ConfigFile persistence + camera input integration, not a mock UI.
const OPTIONS=preload("res://scripts/persistence/player_settings.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(condition: bool,detail: String) -> void:
    if not condition:
        failed=true
        push_error("V7512_SETTINGS "+detail)


func _verify() -> void:
    var path: String="user://qa/v7512_settings.cfg"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
    for suffix in ["",".tmp",".bak"]:
        var absolute: String=ProjectSettings.globalize_path(path+suffix)
        if FileAccess.file_exists(absolute):
            DirAccess.remove_absolute(absolute)
    var options=OPTIONS.new(path)
    check(not options.loaded and is_equal_approx(options.multiplier("general"),1.0),
        "initial default should be safe")
    check(options.save_sensitivity({
        "general":165.0,"ads":80.0,"red_dot":130.0,
        "scope_2x":115.0,"scope_4x":75.0,"scope_8x":45.0
    })==OK,"per-scope settings could not be saved")
    var restored=OPTIONS.new(path)
    check(restored.loaded and not restored.recovered,"saved options not reloadable")
    check(is_equal_approx(restored.multiplier("general"),1.65),"general sensitivity lost")
    check(is_equal_approx(restored.multiplier("ads"),.8),"ADS sensitivity lost")
    check(is_equal_approx(restored.multiplier("scope_2x"),1.15),"2x sensitivity lost")
    check(is_equal_approx(restored.multiplier("scope_4x"),.75),"4x sensitivity lost")
    check(is_equal_approx(restored.multiplier("scope_8x"),.45),"AWM 8x sensitivity lost")
    check(restored.save_graphics("alta")==OK,"graphics preset could not be saved")
    check(OPTIONS.new(path).fps_limit()==60,"graphics fps selection not persisted")
    check(restored.save_sensitivity({"scope_8x":NAN})==ERR_INVALID_PARAMETER,
        "NaN sensitivity accepted")
    check(restored.save_graphics("inexistente")==ERR_INVALID_PARAMETER,
        "unrecognized graphics option accepted")
    check(restored.save_sensitivity({"scope_8x":80.0})==OK,
        "second update failed to create recoverable backup")
    # Last known-valid backup contains x8 = 45, not the corrupt/new 80.
    var damaged:=FileAccess.open(path,FileAccess.WRITE)
    check(damaged!=null,"could not open primary to verify recovery")
    if damaged:
        damaged.store_string("broken")
        damaged.close()
    var recovered=OPTIONS.new(path)
    check(recovered.recovered and recovered.loaded,"backup not used after corruption")
    check(is_equal_approx(recovered.multiplier("scope_8x"),.45),
        "recovery selected corrupt or wrong sensitivity")
    check(recovered.fps_limit()==60,"graphics preset lost during recovery")

    # Verify aim motion uses the actual scope scale, not only saved values.
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var player=world.get_node("Operator")
    for bot in world.get_node("CombatRange")._targets:
        bot.set_physics_process(false)
    player.look_multiplier=1.0
    player.ads_multiplier=1.0
    player._scope_sensitivity={
        "red_dot":1.0,"scope_2x":1.15,"scope_4x":.75,"scope_8x":.45
    }
    player.set_ads(true,2.0)
    player._desired_yaw=0.0
    player._turn_camera(Vector2(100,0))
    var look_2x: float=absf(player._desired_yaw)
    player.set_ads(true,8.0)
    player._desired_yaw=0.0
    player._turn_camera(Vector2(100,0))
    var look_8x: float=absf(player._desired_yaw)
    check(look_2x>look_8x*2.0 and look_8x>0.0,
        "per-scope ADS not applied to real player camera")
    print("V7512_SETTINGS PASS persisted,graphics,recovery,validation,aim_2x=",look_2x,
        " aim_8x=",look_8x)
    quit(1 if failed else 0)
