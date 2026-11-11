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
        animation.loop_mode=Animation.LOOP_NONE if clip in ["AuroraFire","AuroraReloadAR","AuroraReloadAWM","AuroraHit","AuroraLand","AuroraJump"] else Animation.LOOP_LINEAR
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
            var gait: bool=(from=="AuroraArmedWalk" and to=="AuroraArmedRun") or \
                (from=="AuroraArmedRun" and to=="AuroraArmedWalk")
            transition.xfade_time=.20 if gait else .14
            if gait:
                transition.switch_mode=AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC
                transition.reset=false
            states.add_transition(from,to,transition)
    var one_shot:=AnimationNodeOneShot.new()
    one_shot.fadein_time=.04
    one_shot.fadeout_time=.12
    one_shot.filter_enabled=true
    var sample:=source.get_animation("AuroraFire")
    for i in range(sample.get_track_count()):
        var path:=sample.track_get_path(i)
        var bone:=str(path.get_subname(0)).to_lower() if path.get_subname_count()>0 else ""
        if "arm" in bone or "hand" in bone or "spine" in bone or "neck" in bone or "head" in bone or "shoulder" in bone:
            one_shot.set_filter_path(path,true)
            upper_tracks.append(path)
    action_clip.animation="AuroraFire"
    var blend:=AnimationNodeBlendTree.new()
    blend.add_node("Locomotion",states)
    blend.add_node("Action",action_clip)
    blend.add_node("ActionSpeed",AnimationNodeTimeScale.new())
    blend.add_node("UpperBody",one_shot)
    blend.connect_node("ActionSpeed",0,"Action")
    blend.connect_node("UpperBody",0,"Locomotion")
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
