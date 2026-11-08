extends SceneTree
## Verifies crouch geometry, animation model not squashed, blocked stand-up
## and HUD synchronized to REAL CharacterBody3D state.

func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var scene: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    var player:=scene.get_node("Operator") as CharacterBody3D
    var hud:=scene.get_node("TrainingHUD") as CanvasLayer
    for i in range(75):
        await physics_frame
    var mesh: Node3D=player.get_node_or_null("AuroraFemaleRiggedOperator") as Node3D
    var initial_scale: Vector3=mesh.scale if mesh else Vector3.ONE
    player.set_crouch(true)
    if not player._crouching or (hud._crouch_button as Button).text!="LEVANTAR":
        push_error("STANCE_QA crouching failed or HUD displays wrong label")
        quit(186)
        return
    if mesh and not mesh.scale.is_equal_approx(initial_scale):
        push_error("STANCE_QA crouch wrongly scales entire character mesh")
        quit(187)
        return
    var blocker:=StaticBody3D.new()
    blocker.name="LowCeilingTestObstacle"
    scene.add_child(blocker)
    blocker.global_position=player.global_position+Vector3.UP*1.66
    var collider:=CollisionShape3D.new()
    collider.name="LowCeilingShape"
    var shape:=BoxShape3D.new()
    shape.size=Vector3(2.0,.30,2.0)
    collider.shape=shape
    blocker.add_child(collider)
    await physics_frame
    player.set_crouch(false)
    if not player._crouching or (hud._crouch_button as Button).text!="LEVANTAR":
        push_error("STANCE_QA stood into physical low ceiling or HUD lied")
        quit(188)
        return
    blocker.get_parent().remove_child(blocker)
    blocker.queue_free()
    await physics_frame
    player.set_crouch(false)
    if player._crouching or (hud._crouch_button as Button).text!="AGACHAR":
        push_error("STANCE_QA could not stand after clearance restored")
        quit(189)
        return
    print("STANCE_QA PASS: rig never squashed, low-ceiling collision blocks stand, stance and HUD agree")
    quit(0)
