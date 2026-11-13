extends Node
## Skeletal upper-body one-shots keep the locomotion/stance running underneath.
var tree: AnimationTree
var states: AnimationNodeStateMachine
var playback: AnimationNodeStateMachinePlayback
var action_clip:=AnimationNodeAnimation.new()
var animator: AnimationPlayer
var upper_tracks: Array[NodePath]=[]

func setup(source: AnimationPlayer) -> void:
    animator=source
    states=AnimationNodeStateMachine.new()
    var names: Array[String]=[]
    for clip in source.get_animation_list():
        if not clip.begins_with("Aurora"):
            continue
        var animation:=source.get_animation(clip)
        animation.loop_mode=(Animation.LOOP_NONE if clip in [
            "AuroraFire","AuroraFireAWM","AuroraReloadAR","AuroraReloadAWM",
            "AuroraHeal","AuroraHit","AuroraHitFront","AuroraHitBack",
            "AuroraHitLeft","AuroraHitRight","AuroraLand","AuroraJump"]
            else Animation.LOOP_LINEAR)
        var node:=AnimationNodeAnimation.new()
        node.animation=clip
        states.add_node(clip,node)
        names.append(clip)
    for from in names:
        for to in names:
            if from==to:
                continue
            var transition:=AnimationNodeStateMachineTransition.new()
            # Synchronise footstep phase between the two grounded gait clips.
            # Restarting a run at frame zero on every speed change caused the
            # operator's feet to snap, especially under sustained gunfire.
            var grounded_gaits: Array[String]=[
                "AuroraArmedWalk","AuroraArmedRun",
                "AuroraArmedStrafeLeft","AuroraArmedStrafeRight",
                "AuroraArmedBackpedal"]
            var gait: bool=(from in grounded_gaits and to in grounded_gaits)
            # Fully blend into/out of authored crouch, ADS and landing
            # poses instead of snapping the skinned rig at a stance edge.
            var stance: bool=("Crouch" in from or "Crouch" in to or
                "Aim" in from or "Aim" in to)
            var airborne: bool=("Jump" in from or "Land" in to)
            transition.xfade_time=.10 if airborne else .24 if stance else .20 if gait else .14
            if gait:
                transition.switch_mode=AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC
                transition.reset=false
            states.add_transition(from,to,transition)
    var one_shot:=AnimationNodeOneShot.new()
    one_shot.fadein_time=.04
    one_shot.fadeout_time=.12
    one_shot.filter_enabled=true
    # Build the real upper-body mask from ALL action clips. The old mask
    # sampled AuroraFire only: its keyframes omit Neck/Head tracks used by
    # directional injury and future two-handed/medical gestures.
    # This union is constructed once, never in the render/physics loop.
    var selected_paths: Dictionary={}
    for clip_name in ["AuroraFire","AuroraFireAWM",
            "AuroraHit","AuroraHitFront","AuroraHitBack",
            "AuroraHitLeft","AuroraHitRight",
            "AuroraReloadAR","AuroraReloadAWM","AuroraHeal"]:
        if not source.has_animation(clip_name):
            continue
        var sample: Animation=source.get_animation(clip_name)
        for i in range(sample.get_track_count()):
            var path: NodePath=sample.track_get_path(i)
            var bone: String=(str(path.get_subname(0)).to_lower()
                if path.get_subname_count()>0 else "")
            if ("arm" in bone or "hand" in bone or "spine" in bone
                    or "neck" in bone or "head" in bone or
                    "shoulder" in bone):
                var key: String=str(path)
                if not selected_paths.has(key):
                    selected_paths[key]=true
                    one_shot.set_filter_path(path,true)
                    upper_tracks.append(path)
    action_clip.animation="AuroraFire"
    var blend:=AnimationNodeBlendTree.new()
    blend.add_node("Locomotion",states)
    # Keep gait animation phase proportional to the real CharacterBody
    # speed, instead of playing fast run clips during a blocked doorway.
    blend.add_node("GaitSpeed",AnimationNodeTimeScale.new())
    blend.add_node("Action",action_clip)
    blend.add_node("ActionSpeed",AnimationNodeTimeScale.new())
    blend.add_node("UpperBody",one_shot)
    blend.connect_node("ActionSpeed",0,"Action")
    blend.connect_node("GaitSpeed",0,"Locomotion")
    blend.connect_node("UpperBody",0,"GaitSpeed")
    blend.connect_node("UpperBody",1,"ActionSpeed")
    blend.connect_node("output",0,"UpperBody")
    tree=AnimationTree.new()
    tree.name="AuroraAnimationTree"
    tree.tree_root=blend
    add_child(tree)
    tree.anim_player=tree.get_path_to(source)
    tree.root_node=tree.get_path_to(source.get_node(source.root_node))
    # Lila's rig is visual-only; player collision/movement is driven by
    # CharacterBody3D, not root motion. Evaluate blended bones on render
    # frames, outside the Android physics/shape-query callback.
    tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
    source.stop()
    tree.active=true
    playback=tree.get("parameters/Locomotion/playback")
    playback.start("AuroraArmedIdle")

## Bounded playback adjustment for existing authored and rigged gait clips.
## Does not change collider movement, firing cadence or AnimationTree phase.
static func gait_multiplier(actual_speed: float,reference_speed: float) -> float:
    if not is_finite(actual_speed) or not is_finite(reference_speed) or reference_speed<=0:
        return 1.0
    return clampf(actual_speed/reference_speed,.75,1.30)


func set_gait_speed(actual_speed: float,reference_speed: float) -> void:
    if tree!=null:
        tree.set("parameters/GaitSpeed/scale",
            gait_multiplier(actual_speed,reference_speed))


func play(clip: String) -> void:
    if states.has_node(clip) and playback.get_current_node()!=clip:
        playback.travel(clip)

func action(clip: String,duration: float) -> void:
    if not animator.has_animation(clip):
        return
    action_clip.animation=clip
    tree.set("parameters/ActionSpeed/scale",animator.get_animation(clip).length/maxf(duration,.05))
    tree.set("parameters/UpperBody/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func cancel_action() -> void:
    tree.set("parameters/UpperBody/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
