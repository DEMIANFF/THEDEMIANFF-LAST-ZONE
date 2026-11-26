extends SceneTree
## Local review of the real production player + weapon modifiers.
## Baseline runs on the public model. Private candidate is SHA-pinned,
## instantiated only in memory via approved_operator_scene. Never export it.
const OPERATOR=preload("res://scripts/player/third_person_operator.gd")
const VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const PRIVATE_SHA: String="c9b755349a4dc2692f45f3bec1918001d72a05f01b3bcad4aff406c743afb74b"
const SLOTS: Array[int]=[WEAPONS.AR,WEAPONS.AWM,WEAPONS.SCAR,WEAPONS.MP40,WEAPONS.KRISS,WEAPONS.P90]
const POSES: Array[String]=["AuroraArmedIdle","AuroraAim","AuroraCrouch","AuroraArmedWalk"]
const DIGITS: Array[String]=["Index","Middle","Ring","Pinky"]
const SLEEVE_SHA: String="a98b6cca5b51fff38ff1570704dedbe58b4be90edbc84f0685b9bd282d74e6b1"
const HAIR_SHA: String="7e01f72eced0556b29c6232f999e1a6351fcc4e39563e6a32f5cf2ab13f274a8"
var candidate_digest: String=""
var failed: bool=false
var latest: Dictionary={}
var results: Array[Dictionary]=[]
var stage: Node3D
var use_palm: bool=false

func _initialize() -> void:
    call_deferred("_review")

func check(ok: bool, reason: String) -> void:
    if not ok:
        failed=true
        push_error("LILA_ARMORY_REVIEW "+reason)

func _private_scene(path: String) -> PackedScene:
    if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) not in [PRIVATE_SHA,SLEEVE_SHA,HAIR_SHA]:
        push_error("LILA_ARMORY_REVIEW candidate missing or wrong SHA")
        return null
    candidate_digest=FileAccess.get_sha256(path)
    var doc:=GLTFDocument.new()
    var state:=GLTFState.new()
    if doc.append_from_file(path,state)!=OK:
        return null
    var visual: Node=doc.generate_scene(state)
    if visual==null:
        return null
    # Ensure the generated local scene includes all of its children when packed.
    _own_children(visual,visual)
    var packed:=PackedScene.new()
    var status: Error=packed.pack(visual)
    visual.free()
    if status!=OK:
        return null
    return packed

func _own_children(parent: Node, owner_node: Node) -> void:
    for child in parent.get_children():
        child.owner=owner_node
        _own_children(child,owner_node)

func _bone_world(rig: Skeleton3D, id: int) -> Vector3:
    return rig.to_global(rig.get_bone_global_pose(id).origin)

func _palm_proxy(rig: Skeleton3D, side: String, wrist: Vector3) -> Vector3:
    # A skeletal midpoint is a diagnostic only; it is NOT skin-surface
    # contact or a new target for the existing wrist-based solver.
    var knuckles:=Vector3.ZERO
    for digit in DIGITS:
        var id: int=rig.find_bone(side+"Hand"+digit+"1")
        if id<0:
            return Vector3(INF,INF,INF)
        knuckles+=_bone_world(rig,id)
    return wrist.lerp(knuckles/4.0,.5)

func _capture(rig: Skeleton3D, visuals: Node3D) -> void:
    var ik: Node=visuals._support_ik
    if ik==null or not ik.solved:
        return
    var anchor: Node3D=visuals.support_grip_anchor()
    if not is_instance_valid(anchor):
        return
    var left: Vector3=_bone_world(rig,rig.find_bone("LeftHand"))
    var right: Vector3=_bone_world(rig,rig.find_bone("RightHand"))
    var lp: Vector3=_palm_proxy(rig,"Left",left)
    var rp: Vector3=_palm_proxy(rig,"Right",right)
    latest={"left_wrist_solver_error_m":ik.last_error_m,
        "right_wrist_solver_error_m":ik.right_error_m,
        "left_wrist_to_support_anchor_m":left.distance_to(anchor.global_position),
        "left_wrist_to_palm_proxy_m":left.distance_to(lp),
        "right_wrist_to_palm_proxy_m":right.distance_to(rp),
        "left_palm_proxy_to_support_anchor_m":lp.distance_to(anchor.global_position),
        "projection_iterations":ik.projection_iterations}
    # Some authored weapons have an actual Grip node; never fabricate it.
    var equipped: Node3D=visuals.currently_equipped()
    var grip: Node3D=equipped.find_child("Grip",true,false) as Node3D
    if grip!=null:
        latest["right_palm_proxy_to_grip_marker_m"]=rp.distance_to(grip.global_position)

func _review() -> void:
    var args: PackedStringArray=OS.get_cmdline_user_args()
    var baseline: bool=args.size()==1 and args[0] in ["--baseline","--baseline-palm"]
    use_palm=args.size()>0 and args[0] in ["--baseline-palm","--candidate-palm"]
    if not baseline and (args.size()!=2 or args[0] not in ["--candidate","--candidate-palm"]):
        push_error("Use -- --baseline[-palm] or -- --candidate[-palm] /absolute/private.glb")
        quit(2)
        return
    var candidate: PackedScene
    if not baseline:
        candidate=_private_scene(args[1])
        if candidate==null:
            push_error("LILA_ARMORY_REVIEW failed to import private candidate")
            quit(2)
            return
    stage=Node3D.new()
    root.add_child(stage)
    var floor:=StaticBody3D.new()
    floor.collision_layer=3
    var collider:=CollisionShape3D.new()
    var shape:=BoxShape3D.new()
    shape.size=Vector3(20,1,20)
    collider.shape=shape
    floor.position.y=-.5
    floor.add_child(collider)
    stage.add_child(floor)
    var player: CharacterBody3D=OPERATOR.new()
    player.name="Operator"
    if candidate!=null:
        player.approved_operator_scene=candidate
    player.position.y=.12
    stage.add_child(player)
    if player._avatar==null or player._animation_controller==null:
        push_error("LILA_ARMORY_REVIEW missing player avatar or AnimationTree")
        quit(1)
        return
    var rig: Skeleton3D=player._avatar.find_child("Skeleton3D",true,false) as Skeleton3D
    if rig==null or rig.find_bone("LeftHand")<0 or rig.find_bone("RightHand")<0:
        push_error("LILA_ARMORY_REVIEW missing required skeleton")
        quit(1)
        return
    check(rig.get_bone_count()==56,"unexpected character bone count")
    if not baseline:
        check(player.approved_operator_scene==candidate,"private scene not supplied to player")
    var visuals: Node3D=VISUALS.new()
    stage.add_child(visuals)
    visuals.attach_to_player(player)
    if visuals._support_ik==null or not visuals.attachment_uses_hand:
        push_error("LILA_ARMORY_REVIEW missing real support IK")
        quit(1)
        return
    visuals._support_ik.review_support_palm=use_palm
    visuals.set_awm_owned(true)
    for slot in SLOTS:
        if slot>=WEAPONS.SCAR:
            check(visuals.add_expansion(slot),"installed visual missing "+str(slot))
    for frame in range(30):
        await physics_frame
    check(player.is_on_floor(),"physical player did not settle on platform")
    # Same manual AnimationTree path as existing P90 grip fixtures.
    # Do not drive actual movement or advance unrelated match state.
    player.set_physics_process(false)
    var controller: Node=player._animation_controller
    controller.set_process(false)
    controller.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    rig.skeleton_updated.connect(func(): _capture(rig,visuals))
    for slot in SLOTS:
        visuals.equip(slot)
        player.set_equipped_weapon(slot)
        if visuals.currently_equipped()==null:
            check(false,"equipped visual absent "+str(slot))
            continue
        for clip in POSES:
            check(controller.animator.has_animation(clip),"required clip missing "+clip)
            if not controller.animator.has_animation(clip):
                continue
            controller.reset_ground_pose()
            controller.playback.start(clip)
            latest.clear()
            for frame in range(24):
                controller.tree.advance(1.0/60.0)
                await process_frame
            check(not latest.is_empty(),"no solved skeletal sample "+str(slot)+" "+clip)
            if latest.is_empty():
                continue
            var row: Dictionary=latest.duplicate()
            row["slot"]=slot
            row["weapon"]=WEAPONS.ENTRIES[slot]["short"]
            row["clip"]=clip
            for key in latest:
                check(is_finite(float(latest[key])),"nonfinite "+key+" "+clip)
            check(float(row["left_wrist_solver_error_m"])<.045 and
                float(row["right_wrist_solver_error_m"])<.045,
                "wrist IK exceeds historical tolerance "+str(slot)+" "+clip)
            check(int(row["projection_iterations"])<=24,"projection iterations exceeded")
            if use_palm:
                check(float(row["left_palm_proxy_to_support_anchor_m"])<.010,
                    "experimental palm target misses marker "+str(slot)+" "+clip)
                check(absf(float(row["left_palm_proxy_to_support_anchor_m"])-
                    visuals._support_ik.left_palm_proxy_error_m)<.001,
                    "independent palm diagnostic differs from solver")
            results.append(row)
    check(results.size()==SLOTS.size()*POSES.size(),"incomplete weapon/pose matrix")
    print("LILA_ARMORY_REVIEW_JSON ",JSON.stringify({"baseline":baseline,
        "candidate_sha256":"" if baseline else candidate_digest,
        "experimental_palm":use_palm,"production_approved":false,"poses":results,"pass":not failed}))
    stage.queue_free()
    await process_frame
    if not failed:
        print("LILA_ARMORY_REVIEW PASS poses=",results.size()," baseline=",baseline," experimental_palm=",use_palm)
    quit(1 if failed else 0)
