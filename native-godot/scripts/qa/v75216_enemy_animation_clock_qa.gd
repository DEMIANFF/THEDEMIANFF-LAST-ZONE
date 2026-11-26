extends SceneTree
const BUDGET=preload("res://scripts/ai/aurora_enemy_animation_budget.gd")
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false
func _initialize() -> void:
    call_deferred("_verify")
func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75216_ENEMY_CLOCK "+why)
func _verify() -> void:
    check(BUDGET.interval_for(12,true)==0.0 and is_equal_approx(BUDGET.interval_for(30,true),1.0/30.0),"near policy")
    check(is_equal_approx(BUDGET.interval_for(50,true),1.0/15.0),"far policy")
    check(BUDGET.interval_for(50,true,18.0)==0.0 and is_equal_approx(BUDGET.interval_for(50,false,18.0),.1),"zoom policy")
    var stage:=Node3D.new()
    root.add_child(stage)
    var observer:=Node3D.new()
    stage.add_child(observer)
    var actor:=Node3D.new()
    stage.add_child(actor)
    actor.position=Vector3(0,0,-50)
    var camera:=Camera3D.new()
    stage.add_child(camera)
    camera.position=Vector3(0,1,0)
    camera.fov=74
    camera.current=true
    var original: PackedScene=load("res://assets/characters/aurora_operator.glb") as PackedScene
    var rig: Node3D=original.instantiate() as Node3D
    actor.add_child(rig)
    var anim: AnimationPlayer=rig.find_child("AnimationPlayer",true,false) as AnimationPlayer
    var budget:=BUDGET.new()
    actor.add_child(budget)
    budget.configure(anim,actor,observer)
    budget.set_process(false)
    anim.play("AuroraIdle")
    anim.advance(0.0)
    var dt: float=1.0/120.0
    for i in range(120):
        budget._process(dt)
    var normal: int=budget.updates
    check(absf(budget.advanced_seconds+budget.elapsed-1.0)<.00001,"invented or lost time")
    check(normal>=14 and normal<=16,"15Hz rate drift")
    var start: float=anim.current_animation_position
    var advanced: float=budget.advanced_seconds
    camera.fov=18.0
    for i in range(120):
        budget._process(dt)
    check(budget.updates-normal==120,"zoom not full rate")
    check(absf(budget.advanced_seconds+budget.elapsed-2.0)<.00001,"zoom changed elapsed time")
    var expected: float=fposmod(start+budget.advanced_seconds-advanced,anim.current_animation_length)
    check(absf(anim.current_animation_position-expected)<.001,"animation playback time mismatch")
    camera.fov=30.0
    var partial: bool=false
    for i in range(100):
        var edge:=Vector3(0,float(i)*.025,-2)
        if not camera.is_position_in_frustum(edge+Vector3.UP) and BUDGET.body_in_view(camera,edge):
            partial=true
            break
    check(partial,"partial body not detected")
    print("V75216_CLOCK normal_updates=",normal," zoom_updates=",budget.updates-normal," elapsed_s=",budget.advanced_seconds," partial_visible=",partial)
    stage.queue_free()
    await process_frame
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    combat.set_encounter_size(50)
    director.start_sector_battle()
    check(combat._targets.size()==49 and combat.active_fighter_count()==50,"initial roster")
    var initial: Dictionary={}
    for bot in combat._targets:
        initial[bot.get_instance_id()]=bot.global_position
    var max_rigs: int=0
    var max_rays: int=0
    for frame in range(180):
        await physics_frame
        max_rigs=maxi(max_rigs,get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size())
        for bot in combat._targets:
            max_rays=maxi(max_rays,bot.vision_rays_last)
    var moved: int=0
    var rays: int=0
    var shots: int=0
    for bot in combat._targets:
        check(initial.has(bot.get_instance_id()) and bot.get_node_or_null("OpponentCollider") is CollisionShape3D,"replaced bot or missing collider")
        if bot.global_position.distance_to(initial[bot.get_instance_id()])>.1:
            moved+=1
        rays+=bot.vision_rays_total
        shots+=bot.shots_fired
    check(combat._targets.size()==49 and max_rigs<=BOT.MAX_DETAILED_ENEMY_RIGS,"roster or rig cap")
    check(max_rays<=BOT.MAX_VISION_RAYS and moved>0 and rays>0,"live AI absent")
    print("V75216_LIVE roster=",combat._targets.size()+1," moved=",moved," vision_rays=",rays," shots=",shots," max_rigs=",max_rigs," max_rays_per_sense=",max_rays," survivors=",combat.active_fighter_count())
    game.queue_free()
    await process_frame
    if not failed:
        print("V75216_ENEMY_CLOCK PASS")
    quit(1 if failed else 0)
