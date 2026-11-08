extends SceneTree
## End-to-end Godot test for three mobile camera modes. No Android hardware claim.


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player:=game.get_node("Operator") as CharacterBody3D
    var combat:=game.get_node("CombatRange") as Node3D
    var hud:=game.get_node("TrainingHUD") as CanvasLayer
    var pad:=game.get_node("TrainingHUD/AuroraTacticalOverlay/DirectionalFirePad") as Control
    var reticle:=game.get_node("TrainingHUD/AuroraTacticalOverlay/AimReticle") as Control
    var camera:=player.get_view_camera() as Camera3D
    if pad == null or reticle == null or camera == null:
        push_error("TPS fire/reticle/camera not initialized")
        quit(50)
        return
    for i in range(110):
        await physics_frame
    if not player.is_on_floor():
        push_error("Camera regression: player fell through terrain")
        quit(51)
        return

    # FREE LOOK should orbit without rotating an idle player.
    var body_yaw: float=player.rotation.y
    player._turn_camera(Vector2(98, -23))
    for i in range(25):
        await physics_frame
    var viewed_yaw: float=player.get("_yaw")
    if absf(viewed_yaw)<.14 or absf(angle_difference(body_yaw,player.rotation.y))>.09:
        push_error("Free look forced idle character to rotate or ignored swipe")
        quit(52)
        return
    var world_forward: Vector3=-camera.global_transform.basis.z
    var camera_yaw: float=atan2(-world_forward.x,-world_forward.z)
    if absf(angle_difference(viewed_yaw,camera_yaw))>.07:
        push_error("Camera yaw doubled when body/pivot rotated")
        quit(53)
        return
    print("TPS_QA FREE_CAMERA yaw=",viewed_yaw," body=",player.rotation.y)

    # FIRE DRAG must hold trigger and rotate active camera at the same time.
    var touch:=InputEventScreenTouch.new()
    touch.index=7
    touch.position=pad.size*.5
    touch.pressed=true
    pad._gui_input(touch)
    if combat.tracer_events<1:
        push_error("Real ray firing created no visible temporary tracer")
        quit(66)
        return
    if not combat.trigger_held:
        push_error("Fire pad did not press real weapon trigger")
        quit(54)
        return
    var before_yaw: float=player.get("_desired_yaw")
    var drag:=InputEventScreenDrag.new()
    drag.index=7
    drag.position=touch.position+Vector2(-61,-22)
    drag.relative=Vector2(-61,-22)
    pad._gui_input(drag)
    if absf(player.get("_desired_yaw")-before_yaw)<.06:
        push_error("Firepad drag did not change camera aim")
        quit(55)
        return
    var release:=InputEventScreenTouch.new()
    release.index=7
    release.pressed=false
    release.position=drag.position
    pad._gui_input(release)
    if combat.trigger_held:
        push_error("Releasing fire drag left automatic firing active")
        quit(56)
        return
    print("TPS_QA FIRE_DRAG uses owned touch pointer and controls view")

    # ADS cycle belongs to the weapon (AR x2 -> x4, AWM x8 only).
    combat.weapon_index=0
    combat.current_zoom=1.0
    combat._on_aim()
    if not is_equal_approx(combat.current_zoom,2.0) or not is_equal_approx(reticle.zoom,2.0):
        push_error("AR x2 ADS not activated")
        quit(57)
        return
    combat._on_aim()
    if not is_equal_approx(combat.current_zoom,4.0) or not is_equal_approx(reticle.zoom,4.0):
        push_error("AR x4 ADS not activated")
        quit(58)
        return
    combat._on_aim()
    if combat.aim_active or not is_equal_approx(reticle.zoom,1.0):
        push_error("AR ADS did not return to free view")
        quit(59)
        return
    combat._on_weapon()
    combat._on_aim()
    if combat.weapon_index!=1 or not is_equal_approx(combat.current_zoom,8.0):
        push_error("AWM does not own x8 exclusively")
        quit(60)
        return
    combat._on_aim()
    if combat.aim_active:
        push_error("AWM x8 did not deactivate")
        quit(61)
        return
    print("TPS_QA ADS AR 2x,4x and AWM 8x verified")

    # Crouching changes the real capsule/camera and slows mobility.
    hud._crouch_down()
    if not player._crouching or absf((player.get_node("CapsuleCollider") as CollisionShape3D).position.y-.62)>.02:
        push_error("Crouch did not change actual collision capsule")
        quit(62)
        return
    hud._crouch_down()
    if player._crouching:
        push_error("Crouch button failed to restore stand")
        quit(63)
        return
    var radar:=game.get_node_or_null("TrainingHUD/AuroraTacticalOverlay/AuroraTrainingRadar")
    if radar==null:
        push_error("Tactical radar missing")
        quit(64)
        return
    player.training_health=46.0
    var before_medkits: int=combat.medkits_remaining
    combat._on_heal()
    if absf(player.training_health-91.0)>.01 or combat.medkits_remaining!=before_medkits-1:
        push_error("Training medkit did not heal actual player health / consume inventory")
        quit(65)
        return
    print("TPS_QA PASS: free look, fire drag, optics, crouch, real radar and medkit")
    quit(0)
