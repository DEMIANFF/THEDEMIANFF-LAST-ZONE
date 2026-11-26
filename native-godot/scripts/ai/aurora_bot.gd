extends CharacterBody3D
const ANIMATION_BUDGET=preload("res://scripts/ai/aurora_enemy_animation_budget.gd")
const STARTUP_DIAG=preload("res://scripts/persistence/scene_startup_diagnostics.gd")
const IMPACT=preload("res://scripts/player/third_person_operator.gd")
const WEAPON_VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
const AURORA_COVER=preload("res://scripts/combat/aurora_deployable_cover.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const CANOPY_VISUAL=preload("res://scripts/match/rival_canopy_visual.gd")
## Aurora V73 offline training opponent: rigged glTF visual, bounded ray-LOS,
## grounded patrol and actual damage. This is not a networked human player.
signal eliminated(agent: CharacterBody3D, killer: Node3D)
signal weapon_fired(world_position: Vector3)
signal foot_contact(world_position: Vector3,running: bool,on_stone: bool)
## This line is derived from the actual PhysicsServer hit; never a fake shot.
signal shot_trace(from: Vector3,to: Vector3)

const WALK_SPEED: float = 2.5
const CHASE_SPEED: float = 4.15
var _foot_contacts=preload("res://scripts/animation/aurora_foot_contacts.gd").new()
const SIGHT_RANGE: float = 31.0
const SHOOT_RANGE: float = 21.0
const HEARING_RANGE: float = 42.0
const GRAVITY: float = 17.5
# All agents use actual ammo/reload time; combat cannot fire infinitely.
const MAGAZINE_CAPACITY: int=18
const RELOAD_SECONDS: float=2.25
const BURST_ROUNDS: int=2
const BURST_SHOT_GAP: float=.37
const BURST_RECOVERY: float=1.10
# Keep only the nearest five candidates before executing bounded physical
# occlusion rays. Sorting full 50-actor lists every 0.2s causes needless
# allocation churn across 49 autonomous agents on Android.
const MAX_VISION_RAYS: int=5
const TARGET_STICKINESS_METERS: float=3.5
const STRAFE_SWITCH_SECONDS: float=2.7
const ZONE_SAFE_FRACTION: float=.80
const NEXT_ZONE_ROTATE_SECONDS: int=45
# Every real AI opponent carries exactly ONE field medkit. The channel
# is vulnerable, time-bound and can be interrupted by physical damage.
const FIELD_MEDKIT_CAPACITY: int=1
const FIELD_MEDKIT_SECONDS: float=3.0
const FIELD_MEDKIT_HEAL: float=40.0
# A physical rifle impact now applies the same damage to Lila and other rivals.
const RIFLE_DAMAGE: float=20.0
const MAX_HEALTH: float=IMPACT.MAX_HEALTH
const FIELD_MEDKIT_HEALTH_THRESHOLD: float=115.0
const FIELD_MEDKIT_INTERRUPTED_COOLDOWN: float=1.25
const PROACTIVE_RELOAD_THRESHOLD: int=4
# 17 separate CPU buckets prevent 49 real agents from replanning together.
const ROUTE_REPLAN_BUCKETS: int=17
# Throttle cover sound-investigation probes independently of real firing.
# No omniscient vision through a wall that happens to be destructible.
const COVER_PROBE_SECONDS: float=.55
const MAX_ENEMY_COVERS: int=8
const ENEMY_COVER_HEALTH_THRESHOLD: float=145.0
const ENEMY_COVER_COOLDOWN: float=16.0
# Physical death is registered instantly; the existing skinned visual gets
# a short non-colliding reaction. No persistent bodies/particles on mobile.
const DEFEAT_PRESENTATION_SECONDS: float=.75
# Keyed incoming-hit clips temporarily replace locomotion visuals ONLY.
const IMPACT_REACTION_SECONDS: float=.28
const IMPACT_REACTION_VIEW_DISTANCE: float=48.0
# Show actual skinned firearm actions only on already-allocated nearby
# rigs. The bullet, magazine and physical damage remain authoritative.
const FIRE_PRESENTATION_SECONDS: float=.26
# 14 or fewer already-allocated rigs carry one reusable unlit flash each.
const REAL_MUZZLE_FLASH_SECONDS: float=.09
const MAX_MUZZLE_TRACER_OFFSET: float=4.5
# The AI reacts to a physically heard grenade only inside this radius.
const GRENADE_HEARING_RADIUS: float=10.5
const GRENADE_ESCAPE_METERS: float=8.5

var navigation: Node3D
var behavior: String="patrol"
var shots_fired: int=0
var shots_hit: int=0
var heard_shots: int=0
var reloads_completed: int=0
var vision_rays_last: int=0
var vision_rays_total: int=0
var _magazine: int=MAGAZINE_CAPACITY
var weapon_slot: int=WEAPONS.AR
var _reload_remaining: float=0.0
var _grenade_evasion_left: float=0.0
var _grenade_last_at: Vector3=Vector3(INF,INF,INF)
var grenade_dodges: int=0
var _field_medkits: int=FIELD_MEDKIT_CAPACITY
var _heal_remaining: float=0.0
var _heal_cooldown: float=0.0
var heal_channels_completed: int=0
var heal_channels_interrupted: int=0
var _burst_count: int=0
var _strafe_clock: float=0.0
var _random:=RandomNumberGenerator.new()
var _movement_probe:=KinematicCollision3D.new()
var _route:=PackedVector3Array()
var _route_goal:=Vector3(INF,INF,INF)
var _route_clock: float=0.0
var _cover_clock: float=0.0
var _cover_probe_clock: float=0.0
var _cover_deploy_clock: float=0.0
var _cover_charges: int=1
var _airdrop_stage: String="inactive"
var _airdrop_delay: float=0.0
var _airdrop_origin: Vector3=Vector3.ZERO
var _airdrop_canopy: MeshInstance3D
var _cover_deploy_queued: bool=false
var covers_deployed: int=0
var _owned_covers: Array[StaticBody3D]=[]
var _suppression_seconds: float=0.0
var _last_attacker: Node3D
var _cover_point:=Vector3(INF,INF,INF)
var terrain: StaticBody3D
var operator: CharacterBody3D
var spawn_coordinates: Vector2 = Vector2.ZERO
var health: float = MAX_HEALTH
var sector_battle: bool = false
var respawn_enabled: bool = true
var _foes: Array[CharacterBody3D] = []
var _target_actor: CharacterBody3D
var _anchor: Vector3
var _idle_phase: float = 0.0
var _sense_clock: float = 0.0
var _attack_clock: float = 1.3
var _target_visible: bool = false
var _last_seen: Vector3 = Vector3.ZERO
var _alert_time: float = 0.0
var _dead_time: float = 0.0
# Own the training respawn deadline; no global SceneTreeTimer survives a bot.
var _respawn_timer: Timer
var _rig: Node3D
var _enemy_right_hand_socket: BoneAttachment3D
var _enemy_hand_rifle: Node3D
var _enemy_muzzle_flash: MeshInstance3D
var _animation: AnimationPlayer
var _clip: String = ""
var safe_center: Vector2=Vector2.ZERO
var safe_radius: float=INF
var next_safe_center: Vector2=Vector2.ZERO
var next_safe_radius: float=INF
var zone_seconds_remaining: int=0
var next_zone_active: bool=false
var _avoid_side: float=1.0
## V75.183: all 49 opponents render the SAME source character at near
## and far distances; only 14 animated/weapon-action detail leases are
## active at once. Distant actors retain original meshes, UVs and materials,
## with their AnimationPlayer frozen (no substitute cuboid silhouettes).
## The physical 49 CharacterBody3D agents, AI and ballistics are untouched.
const MAX_DETAILED_ENEMY_RIGS: int=14
const DETAILED_ENEMY_GROUP: String="AuroraDetailedEnemyRig"
var distance_lod: bool=false
var _lod_rig: Node3D
var _lod_clock: float=0.0
var _lod_pending: bool=false
var _death_tween: Tween
var _impact_reaction_remaining: float=0.0
var _weapon_action_remaining: float=0.0
var _muzzle_flash_remaining: float=0.0
var muzzle_flashes_shown: int=0
var weapon_actions_shown: int=0
var reload_actions_shown: int=0
var last_hit_reaction: String=""
var hit_reactions_shown: int=0
var _rig_rest_transform: Transform3D=Transform3D.IDENTITY
var _lod_rest_transform: Transform3D=Transform3D.IDENTITY


func _ready() -> void:
    add_to_group("training_target")
    _random.seed=7503+int(absf(spawn_coordinates.x)*31+absf(spawn_coordinates.y)*17)
    _magazine=_loadout_capacity()
    var marker := Label3D.new()
    marker.name = "TrainingTargetMarker"
    marker.text = "ENEMIGO IA"
    marker.font_size = 42
    marker.pixel_size = .006
    marker.position = Vector3(0, 2.25, 0)
    marker.modulate = Color(1.0, .52, .32)
    marker.no_depth_test = false
    add_child(marker)
    _anchor = Vector3(spawn_coordinates.x, terrain.height_at(spawn_coordinates.x,spawn_coordinates.y)+.15, spawn_coordinates.y)
    global_position = _anchor
    _idle_phase = float(get_instance_id()%41)*.31
    _avoid_side=1.0 if get_instance_id()%2==0 else -1.0

    var shape := CollisionShape3D.new()
    shape.name = "OpponentCollider"
    var capsule := CapsuleShape3D.new()
    capsule.radius = .37
    capsule.height = 1.74
    shape.shape = capsule
    shape.position.y=.88
    add_child(shape)

    if distance_lod:
        _create_lod_visual()
    else:
        _create_full_rig()


## Restore the same actual health/collider-bearing agent at its new
## terrain-correct match spawn BEFORE the next BR round becomes active.
## Never teleport a live opponent away from a player during combat.
## Actual collidable bot bodies descend from the aircraft route. They are
## NOT repositioned onto the ground at the first player touchdown.
func begin_real_airdrop(origin: Vector3,delay: float) -> void:
    if not origin.is_finite() or not is_inside_tree():
        return
    _cancel_respawn_timer()
    _airdrop_origin=origin
    _airdrop_delay=maxf(0.0,delay)
    _airdrop_stage="waiting"
    sector_battle=false
    health=MAX_HEALTH
    # Departure and descent are part of BR, not enemy-marked training.
    var name_plate:=get_node_or_null("TrainingTargetMarker") as Label3D
    if name_plate:
        name_plate.visible=false
    visible=false
    collision_layer=0
    velocity=Vector3.ZERO
    set_physics_process(true)


func _create_real_parachute() -> void:
    if _airdrop_canopy!=null and is_instance_valid(_airdrop_canopy):
        _airdrop_canopy.show()
        return
    _airdrop_canopy=CANOPY_VISUAL.create()
    add_child(_airdrop_canopy)


func _advance_real_airdrop(dt: float) -> void:
    if health<=0.0:
        cancel_real_airdrop()
        return
    if _airdrop_stage=="waiting":
        _airdrop_delay=maxf(0.0,_airdrop_delay-dt)
        if _airdrop_delay>0.0:
            return
        global_position=_airdrop_origin
        velocity=Vector3.ZERO
        collision_layer=1
        visible=true
        _airdrop_stage="descending"
        _create_real_parachute()
    var to_destination: Vector2=spawn_coordinates-Vector2(
        global_position.x,global_position.z)
    var drift: Vector2=(to_destination.normalized()*
        minf(20.0,to_destination.length()*.40))
    velocity=Vector3(drift.x,-7.8,drift.y)
    move_and_slide()
    if is_on_floor():
        _airdrop_stage="landed"
        velocity=Vector3.ZERO
        if _airdrop_canopy!=null:
            _airdrop_canopy.hide()
        if not sector_battle:
            set_physics_process(false)


func retarget_real_airdrop(at: Vector2) -> void:
    if not at.is_finite() or terrain==null:
        return
    spawn_coordinates=at
    _anchor=Vector3(at.x,terrain.height_at(at.x,at.y)+.15,at.y)
    if _airdrop_stage=="landed":
        # Physical pre-combat landing clearance: never move live fighters.
        global_position=_anchor


func cancel_real_airdrop() -> void:
    if _airdrop_canopy!=null and is_instance_valid(_airdrop_canopy):
        _airdrop_canopy.queue_free()
    _airdrop_canopy=null
    _airdrop_stage="inactive"
    _airdrop_delay=0.0
    collision_layer=1
    visible=true


func set_match_spawn(at: Vector2) -> void:
    # A reused bot keeps sector_battle=true after its previous finished
    # match. Its physics process is disabled at that boundary, so permit
    # legitimate next-round placement while rejecting an active combatant.
    if (not at.is_finite() or terrain==null or
            (sector_battle and is_physics_processing())):
        return
    spawn_coordinates=at
    _anchor=Vector3(at.x,terrain.height_at(at.x,at.y)+.15,at.y)
    global_position=_anchor


## Every distant enemy is an original Aurora character, not a substitute
## low-poly mannequin. PackedScene and GLB mesh/material resources are shared
## by Godot across the roster; only the static pose is frozen at distance.
## Detail leasing reuses THIS exact node (no duplicate skinned character).
func _create_lod_visual() -> void:
    if STARTUP_DIAG.without_enemy_rigs():
        return
    _instantiate_original_distant_visual()


func _instantiate_original_distant_visual() -> void:
    if not ResourceLoader.exists("res://assets/characters/aurora_operator.glb"):
        push_error("Aurora enemy source model unavailable; cannot show original appearance at distance")
        return
    var original: PackedScene=load(
        "res://assets/characters/aurora_operator.glb") as PackedScene
    if original==null:
        return
    _lod_rig=original.instantiate() as Node3D
    if _lod_rig==null:
        return
    _lod_rig.name="DistantOriginalEnemyRig"
    add_child(_lod_rig)
    var kit: MeshInstance3D=_lod_rig.find_child(
        "LilaAuroraSignatureKit",true,false) as MeshInstance3D
    if kit!=null:
        kit.visible=false
        kit.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var hair: MeshInstance3D=_lod_rig.find_child(
        "LilaAuroraOriginalHair",true,false) as MeshInstance3D
    if hair!=null:
        hair.visible=false
        hair.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if is_instance_valid(operator) and operator.has_method(
            "fit_operator_visual"):
        operator.fit_operator_visual(_lod_rig)
    _lod_rest_transform=_lod_rig.transform
    _rig_rest_transform=_lod_rig.transform
    var idle: AnimationPlayer=_lod_rig.find_child(
        "AnimationPlayer",true,false) as AnimationPlayer
    if idle!=null:
        if idle.has_animation("AuroraIdle"):
            idle.play("AuroraIdle")
            idle.advance(.16)
        idle.active=false
        var budget:=ANIMATION_BUDGET.new()
        budget.name="EnemyAnimationBudget"
        _lod_rig.add_child(budget)
        budget.configure(idle,self,operator)
    # Same rifle model and skeletal hand mount on either side of 39m.
    # A promotion only enables the existing animator; it creates no
    # second rig and does not swap a square head for a normal face.
    _rig=_lod_rig
    _attach_original_hand_rifle()
    _rig=null


func _reserve_detailed_rig_slot() -> bool:
    # A close, combat-visible rival can replace a much farther detailed
    # LOD agent without exceeding the mobile 14-rig allocation.
    var detail_nodes: Array[Node]=get_tree().get_nodes_in_group(
        DETAILED_ENEMY_GROUP)
    if detail_nodes.size()<MAX_DETAILED_ENEMY_RIGS:
        return true
    if not is_instance_valid(operator):
        return false
    var my_distance: float=global_position.distance_to(
        operator.global_position)
    var worst_distance: float=my_distance+8.0
    var furthest: Node3D
    for detail in detail_nodes:
        var holder: Node3D=detail.get_parent() as Node3D
        if holder==null or holder==self or not (
                bool(holder.get("distance_lod"))):
            continue
        var distance: float=holder.global_position.distance_to(
            operator.global_position)
        if distance>worst_distance:
            worst_distance=distance
            furthest=holder
    if furthest==null:
        return false
    furthest.call("_set_full_visual",false)
    return get_tree().get_nodes_in_group(
        DETAILED_ENEMY_GROUP).size()<MAX_DETAILED_ENEMY_RIGS


func _create_full_rig() -> void:
    if _rig!=null or STARTUP_DIAG.without_enemy_rigs():
        return
    if distance_lod and not _reserve_detailed_rig_slot():
        return
    if distance_lod and is_instance_valid(_lod_rig):
        # Reuse the SAME authored mesh and appearance; only animate when
        # a lease is available. No GPU double allocation on promotion.
        _rig=_lod_rig
        _rig.add_to_group(DETAILED_ENEMY_GROUP)
        _rig_rest_transform=_lod_rest_transform
        _animation=_rig.find_child(
            "AnimationPlayer",true,false) as AnimationPlayer
        if _animation!=null:
            _animation.active=true
            _animation.speed_scale=1.0
            _animation.play("AuroraIdle")
            _animation.advance(.16)
        if not is_instance_valid(_enemy_right_hand_socket):
            _attach_original_hand_rifle()
        return
    if not ResourceLoader.exists("res://assets/characters/aurora_operator.glb"):
        return
    var source:=load("res://assets/characters/aurora_operator.glb") as PackedScene
    _rig=source.instantiate() as Node3D
    _rig.name="OpponentRig"
    add_child(_rig)
    _rig.add_to_group(DETAILED_ENEMY_GROUP)
    # The underlying CC0 rig is shared to keep one character GLB and
    # existing 30-agent collision/LOD performance. However Lila's
    # individually authored Aurora field kit belongs ONLY to the player:
    # enemies must not appear dressed as the protagonist.
    var protagonist_kit: MeshInstance3D=_rig.find_child(
        "LilaAuroraSignatureKit",true,false) as MeshInstance3D
    if protagonist_kit!=null:
        protagonist_kit.visible=false
        protagonist_kit.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var protagonist_hair: MeshInstance3D=_rig.find_child(
        "LilaAuroraOriginalHair",true,false) as MeshInstance3D
    if protagonist_hair!=null:
        protagonist_hair.visible=false
        protagonist_hair.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if operator.has_method("fit_operator_visual"):
        operator.fit_operator_visual(_rig)
    _rig_rest_transform=_rig.transform
    _animation=_rig.find_child("AnimationPlayer",true,false) as AnimationPlayer
    if _animation:
        _animation.play("AuroraIdle")
        _animation.advance(.16)
        var budget:=ANIMATION_BUDGET.new()
        budget.name="EnemyAnimationBudget"
        _rig.add_child(budget)
        budget.configure(_animation,self,operator)
    _attach_original_hand_rifle()


## Both animated and far-static rivals carry their actual 3D weapon
## attached to the same original hand bone, regardless of camera range.
## The authoritative bullets and raycast collision are independent.

## Each combatant is assigned a real, installed weapon catalog slot.
## Existing training rigs retain the original AR/18-round QA contract.
func _loadout_capacity() -> int:
    if weapon_slot==WEAPONS.AR:
        return MAGAZINE_CAPACITY
    return int(WEAPONS.ENTRIES[weapon_slot]["capacity"])


func _loadout_range() -> float:
    match weapon_slot:
        WEAPONS.AWM:
            return 65.0
        WEAPONS.VSS:
            return 46.0
        WEAPONS.SCAR,WEAPONS.HK416:
            return 30.0
        WEAPONS.MP40,WEAPONS.KRISS,WEAPONS.P90:
            return 18.0
    return SHOOT_RANGE


func _loadout_sight_range() -> float:
    return maxf(SIGHT_RANGE,_loadout_range()*1.08)


func _loadout_damage() -> float:
    match weapon_slot:
        WEAPONS.AWM:
            return 72.0
        WEAPONS.VSS:
            return 31.0
        WEAPONS.SCAR,WEAPONS.HK416:
            return 22.0
        WEAPONS.MP40,WEAPONS.P90:
            return 16.0
        WEAPONS.KRISS:
            return 14.0
    return RIFLE_DAMAGE


## Different weapons must not share the same slow AR burst pacing.
## Keep two real rounds per burst and the existing bounded LOS budget.
## Fast SMGs recover sooner; an AWM still waits one second per bolt.
func _loadout_shot_gap() -> float:
    if weapon_slot==WEAPONS.AWM:
        return 1.0
    return clampf(float(WEAPONS.ENTRIES[weapon_slot]["cadence"])*2.4,
        .20,BURST_SHOT_GAP)


func _loadout_burst_rest() -> float:
    if weapon_slot==WEAPONS.AWM:
        return BURST_RECOVERY
    return clampf(float(WEAPONS.ENTRIES[weapon_slot]["cadence"])*7.5,
        .67,BURST_RECOVERY)


func _loadout_reload_seconds() -> float:
    if weapon_slot==WEAPONS.AR:
        return RELOAD_SECONDS
    return float(WEAPONS.ENTRIES[weapon_slot]["reload"])


func _loadout_visual_path() -> String:
    if weapon_slot==WEAPONS.AWM:
        return WEAPON_VISUALS.AWM_PATH
    if weapon_slot==WEAPONS.AR:
        return WEAPON_VISUALS.AK_PATH
    return str(WEAPONS.ENTRIES[weapon_slot].get("asset",""))


func _attach_original_hand_rifle() -> void:
    _enemy_hand_rifle=null
    _enemy_right_hand_socket=null
    _enemy_muzzle_flash=null
    _muzzle_flash_remaining=0.0
    var equipped_path: String=_loadout_visual_path()
    if _rig==null or equipped_path.is_empty() or not ResourceLoader.exists(equipped_path):
        return
    var skeleton: Skeleton3D=_rig.find_child(
        "Skeleton3D",true,false) as Skeleton3D
    if skeleton==null:
        return
    var hand_index: int=-1
    for i in range(skeleton.get_bone_count()):
        if skeleton.get_bone_name(i).to_lower().ends_with("righthand"):
            hand_index=i
            break
    if hand_index<0:
        push_warning("Aurora detailed enemy missing actual right-hand bone")
        return
    var imported_scale: float=skeleton.global_transform.basis.get_scale().x
    if not is_finite(imported_scale) or imported_scale<=.00001:
        push_warning("Aurora detailed enemy rifle bone scale invalid")
        return
    _enemy_right_hand_socket=BoneAttachment3D.new()
    _enemy_right_hand_socket.name="OpponentRightHandRifleSocket"
    _enemy_right_hand_socket.bone_name=skeleton.get_bone_name(hand_index)
    skeleton.add_child(_enemy_right_hand_socket)
    var mount:=Node3D.new()
    mount.name="OpponentRightHandRifleMount"
    _enemy_right_hand_socket.add_child(mount)
    mount.scale=Vector3.ONE/imported_scale
    mount.position=Vector3(0,-.012,-.075)/imported_scale
    mount.rotation_degrees=Vector3(-12,0,90)
    # One temporary helper owns no scene-processing loop. It reuses Lila's
    # GLB normalization; the returned mesh becomes a skeleton child.
    var visual_loader: Node3D=WEAPON_VISUALS.new()
    _enemy_hand_rifle=visual_loader._load_visual(
        equipped_path,"AK74TacticalOpponentVisual" if weapon_slot==WEAPONS.AR else "RivalWeapon3DVisual",mount)
    visual_loader.free()
    if _enemy_hand_rifle==null:
        _enemy_right_hand_socket.queue_free()
        _enemy_right_hand_socket=null
        return
    # Use Lila's existing AK mount coordinates; never move the true ray.
    _enemy_muzzle_flash=MeshInstance3D.new()
    _enemy_muzzle_flash.name="OpponentPhysicalMuzzleFlash"
    var flash_mesh:=SphereMesh.new()
    flash_mesh.radius=.075
    flash_mesh.height=.18
    flash_mesh.radial_segments=8
    flash_mesh.rings=4
    _enemy_muzzle_flash.mesh=flash_mesh
    _enemy_muzzle_flash.position=Vector3(0,.03,-.43 if weapon_slot in [WEAPONS.MP40,WEAPONS.KRISS,WEAPONS.P90] else -.78)
    var flash_material:=StandardMaterial3D.new()
    flash_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_material.albedo_color=Color(1.0,.51,.17)
    _enemy_muzzle_flash.material_override=flash_material
    _enemy_muzzle_flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _enemy_muzzle_flash.visible=false
    mount.add_child(_enemy_muzzle_flash)


func _set_full_visual(closer: bool) -> void:
    _lod_pending=false
    if not is_inside_tree():
        return
    if closer:
        _create_full_rig()
    elif _rig!=null:
        # If a detailed corpse must yield its GPU slot before the brief
        # visual reaction ends, cancel the tween before freeing its node.
        if health<=0.0 and _death_tween!=null and _death_tween.is_valid():
            _death_tween.kill()
            visible=false
        # The group lease is freed immediately, not after the next
        # render frame, to allow another nearby opponent to use the slot.
        _rig.remove_from_group(DETAILED_ENEMY_GROUP)
        if distance_lod and _rig==_lod_rig:
            # Freeze original skeleton in a neutral AuroraIdle pose.
            # Keep 3D meshes, clothing, original weapon and materials
            # visible. No pop into a different model at 56 metres.
            if _animation!=null:
                _animation.speed_scale=1.0
                if _animation.has_animation("AuroraIdle"):
                    _animation.play("AuroraIdle")
                    _animation.advance(.16)
                _animation.active=false
            _rig.transform=_lod_rest_transform
        else:
            _rig.queue_free()
            _enemy_hand_rifle=null
            _enemy_right_hand_socket=null
            _enemy_muzzle_flash=null
        _rig=null
        _muzzle_flash_remaining=0.0
        if is_instance_valid(_enemy_muzzle_flash):
            _enemy_muzzle_flash.visible=false
        _animation=null
        _clip=""
        _impact_reaction_remaining=0.0
        _weapon_action_remaining=0.0
    if is_instance_valid(_lod_rig):
        _lod_rig.visible=true


func _update_distance_lod(dt: float) -> void:
    if not distance_lod or not sector_battle or not is_instance_valid(operator):
        return
    _lod_clock-=dt
    if _lod_clock>0.0:
        return
    _lod_clock=.55+float(get_instance_id()%7)*.045
    var distance_sq: float=global_position.distance_squared_to(operator.global_position)
    var wants_full: bool=distance_sq<39.0*39.0 if _rig==null else distance_sq<56.0*56.0
    if not _lod_pending and wants_full!=(_rig!=null):
        _lod_pending=true
        call_deferred("_set_full_visual",wants_full)


func _physics_process(dt: float) -> void:
    # Live physics-only descent precedes shooting, healing and pathfinding.
    if _airdrop_stage in ["waiting","descending"]:
        _advance_real_airdrop(dt)
        return
    _update_distance_lod(dt)
    # Distant bots update in staggered frames to limit path and physics
    # cost. They are still active agents, may shoot each other and take
    # damage; no simulated eliminations or fictitious "players".
    if distance_lod and sector_battle and is_instance_valid(operator) and             global_position.distance_squared_to(operator.global_position)>75.0*75.0:
        if Engine.get_physics_frames()%3!=get_instance_id()%3:
            return
        dt=minf(dt*3.0,.125)
    if health<=0:
        _dead_time-=dt
        if _dead_time<=0:
            _respawn()
        return
    _grenade_evasion_left=maxf(0.0,_grenade_evasion_left-dt)
    _impact_reaction_remaining=maxf(0.0,_impact_reaction_remaining-dt)
    _weapon_action_remaining=maxf(0.0,_weapon_action_remaining-dt)
    if _muzzle_flash_remaining>0.0:
        _muzzle_flash_remaining=maxf(0.0,_muzzle_flash_remaining-dt)
        if _muzzle_flash_remaining<=0.0 and _enemy_muzzle_flash!=null:
            _enemy_muzzle_flash.visible=false
    # A one-shot visual is rescaled to the real reload/fire duration;
    # restore gait speed as soon as the authoritative action ends.
    if (_weapon_action_remaining<=0.0 and _animation!=null and
            _clip in ["AuroraFire","AuroraReloadAR"]):
        _animation.speed_scale=1.0
    _route_clock-=dt
    _cover_clock-=dt
    _cover_probe_clock=maxf(0.0,_cover_probe_clock-dt)
    _cover_deploy_clock=maxf(0.0,_cover_deploy_clock-dt)
    _strafe_clock-=dt
    if _reload_remaining>0.0:
        _reload_remaining=maxf(0.0,_reload_remaining-dt)
        if _reload_remaining<=0.0:
            _magazine=_loadout_capacity()
            reloads_completed+=1
    _suppression_seconds=maxf(0.0,_suppression_seconds-dt)
    _heal_cooldown=maxf(0.0,_heal_cooldown-dt)
    # A healing enemy must keep sensing threats. Previously the early
    # medkit return stopped LOS checks for the full three seconds, so an
    # enemy entering view could not interrupt a helpless stationary bot.
    if _heal_remaining>0.0:
        _sense_clock-=dt
        if _sense_clock<=0.0:
            _sense_clock=.22+float(get_instance_id()%5)*.025
            _sense_player()
        if (_target_visible or _grenade_evasion_left>0.0 or
                (sector_battle and should_escape_current_zone(global_position,
                    safe_center,safe_radius))):
            _interrupt_field_heal()
    # Medicines are a real timed, interruptible action on CharacterBody3D.
    # An opponent cannot move/fire while channeling, and mobile distant
    # AI frame staggering preserves the same elapsed seconds through dt.
    if _advance_field_heal(dt):
        velocity.x=move_toward(velocity.x,0.0,10.0*dt)
        velocity.z=move_toward(velocity.z,0.0,10.0*dt)
        velocity.y-=GRAVITY*dt
        move_and_slide()
        if _animation and _clip!="AuroraCrouch":
            _animation.play("AuroraCrouch",.18)
            _clip="AuroraCrouch"
        return
    _sense_clock-=dt
    _attack_clock-=dt
    _alert_time=maxf(0.0,_alert_time-dt)
    if _sense_clock<=0:
        _sense_clock=.22+float(get_instance_id()%5)*.025
        _sense_player()

    # Heal only out of immediate sight and inside the real safe ring;
    # taking damage, resuming fire or entering zone hazard interrupts it.
    if _grenade_evasion_left<=0.0 and _should_field_heal():
        _begin_field_heal()
        return
    # Reload a nearly empty physical magazine while hidden from opponents;
    # a visible close target must never pause a live firefight unnecessarily.
    if (_reload_remaining<=0.0 and _magazine>0 and
            _magazine<=PROACTIVE_RELOAD_THRESHOLD and not _target_visible):
        _begin_reload()

    # Only a CONFIRMED physical line of sight gives exact current actor
    # position. After gunfire behind a wall, follow the stationary last
    # audible location; never secretly rotate toward Lila's live position.
    var contact_position: Vector3=confirmed_contact_position(
        _last_seen,_target_actor,_target_visible)
    var delta_to_contact: Vector3=contact_position-global_position
    delta_to_contact.y=0
    var distance: float=delta_to_contact.length()
    var destination: Vector3
    var target_speed: float=WALK_SPEED
    if _target_visible and distance < _loadout_sight_range():
        _last_seen=contact_position
        _alert_time=2.9
    behavior="patrol"
    if _alert_time>0:
        behavior="pursuit"
        var flank: Vector3=Vector3(-delta_to_contact.z,0,delta_to_contact.x).normalized()
        destination=_last_seen+flank*sin(_idle_phase)*2.2
        target_speed=CHASE_SPEED
        # Reposition to the side of a visible opponent rather than always
        # rushing to the same target point. Stable for several seconds to
        # avoid churn in navigation requests and mobile physics queries.
        if _target_visible and distance<_loadout_range()*.9 and distance>4.0:
            if _strafe_clock<=0.0:
                _avoid_side*=-1.0
                _strafe_clock=STRAFE_SWITCH_SECONDS+float(get_instance_id()%3)*.19
            var maintain_range: Vector3=delta_to_contact.normalized()*clampf(distance-12.0,-2.0,2.0)
            destination=global_position+flank*_avoid_side*3.7+maintain_range
            behavior="strafe"
    else:
        _idle_phase+=dt*.31
        destination=_anchor+Vector3(cos(_idle_phase)*4.0,0,sin(_idle_phase)*4.0)

    # Storm exposure is NOT enemy fire. Avoid expensive cover queries and
    # false attacker pursuit while a real body must escape the hazard.
    var escaping_storm: bool=sector_battle and should_escape_current_zone(
        global_position,safe_center,safe_radius)
    if (not escaping_storm and
            (health<=45.0 or (health<=70.0 and _suppression_seconds>0.0) or
            _reload_remaining>0.0) and _alert_time>0 and
            navigation and navigation.available):
        if _cover_clock<=0:
            if not sector_battle or navigation.try_live_plan():
                var cover_started: int=Time.get_ticks_usec()
                _cover_point=navigation.find_cover(global_position,_last_seen)
                if sector_battle:
                    navigation.finish_live_plan(cover_started)
                _cover_clock=4.0
            else:
                # Retry with a per-agent phase; no fake route or cover result.
                _cover_clock=.10+float(get_instance_id()%7)*.017
        if _cover_point.is_finite() and _cover_clock>1.0:
            destination=_cover_point
            behavior="cover"
    # Rotate toward the next ACTUAL circle near the end of the phase.
    # Prioritize live engagements and physical cover, but avoid waiting
    # until the storm is already damaging a distant rival.
    var engaged: bool=(_target_visible and distance<_loadout_range()) or behavior=="cover"
    if sector_battle and next_zone_active and should_rotate_to_next_zone(
            global_position,next_safe_center,next_safe_radius,
            zone_seconds_remaining,engaged):
        behavior="zone_rotate"
        destination=safe_zone_destination(global_position,
            next_safe_center,next_safe_radius)
        target_speed=CHASE_SPEED
    # On a tiny endgame ring, ordinary patrol waypoints can lie metres
    # outside a 0.75m safety circle. Hold in real walkable space instead
    # of repeatedly walking into the hazard and turning back. Real nearby
    # enemies and next-circle rotation remain independent priorities.
    if (sector_battle and behavior=="patrol" and
            should_hold_final_zone(destination,safe_center,safe_radius,false)):
        behavior="zone_hold"
        destination=safe_zone_destination(global_position,
            safe_center,safe_radius)
        target_speed=WALK_SPEED
    # One nearby physical fuse may temporarily override pursuit, flanking
    # and planned zone rotations; imminent real storm still takes priority.
    if (_grenade_evasion_left>0.0 and _grenade_last_at.is_finite() and
            not escaping_storm):
        var retreat: Vector3=global_position-_grenade_last_at
        retreat.y=0.0
        if retreat.length_squared()<.01:
            retreat=Vector3(_avoid_side,0.0,0.0)
        destination=global_position+retreat.normalized()*GRENADE_ESCAPE_METERS
        behavior="grenade_escape"
        target_speed=CHASE_SPEED
    # Immediate storm threat always overrides the next-phase rotation.
    # Scale the margin with the ring: the old fixed four-metre buffer
    # marked EVERY bot as escaping forever when the ring was 0.75m wide.
    if escaping_storm:
        behavior="zone_escape"
        destination=safe_zone_destination(global_position,
            safe_center,safe_radius)
        target_speed=CHASE_SPEED
    if navigation and navigation.available:
        if _route_clock<=0 and (destination.distance_squared_to(_route_goal)>6.25 or _route.is_empty()):
            if not sector_battle or navigation.try_live_plan():
                var route_started: int=Time.get_ticks_usec()
                _route=navigation.route(global_position,destination)
                if sector_battle:
                    navigation.finish_live_plan(route_started)
                _route_goal=destination
                _route_clock=route_replan_interval(get_instance_id())
            else:
                # Keep the last checked waypoints and local obstacle avoidance.
                _route_clock=.05+float(get_instance_id()%11)*.013
        while not _route.is_empty() and Vector2(_route[0].x-global_position.x,_route[0].z-global_position.z).length()<.65:
            _route.remove_at(0)
        if not _route.is_empty():
            destination=_route[0]
    var direction: Vector3=destination-global_position
    direction.y=0
    if direction.length()>.75:
        var heading: Vector3=direction.normalized()
        if _blocked_ahead(heading):
            for angle in [PI/3,PI/2,PI*2/3,PI]:
                var candidate: Vector3=heading.rotated(Vector3.UP,angle*_avoid_side)
                if not _blocked_ahead(candidate):
                    heading=candidate
                    break
        var step: Vector3=heading*target_speed
        velocity.x=move_toward(velocity.x,step.x,9.0*dt)
        velocity.z=move_toward(velocity.z,step.z,9.0*dt)
        rotation.y=lerp_angle(rotation.y,atan2(-heading.x,-heading.z),minf(1.0,dt*7.0))
    else:
        velocity.x=move_toward(velocity.x,0.0,8.0*dt)
        velocity.z=move_toward(velocity.z,0.0,8.0*dt)
    velocity.y-=GRAVITY*dt
    var before_move: Vector3=global_position
    move_and_slide()
    var offset: Vector3=global_position-before_move
    var moving: bool=is_on_floor() and Vector2(offset.x,offset.z).length()>.8*dt
    var running: bool=moving and Vector2(offset.x,offset.z).length()>2.15*dt

    if (_target_visible and distance<_loadout_range() and
            _attack_clock<=0.0 and _reload_remaining<=0.0 and
            _has_line_of_fire(_target_actor)):
        if _magazine<=0:
            _begin_reload()
        elif _fire_at_target(_target_actor):
            _magazine-=1
            _burst_count+=1
            if _magazine<=0:
                _begin_reload()
            elif _burst_count>=BURST_ROUNDS:
                _burst_count=0
                _attack_clock=_loadout_burst_rest()+float(get_instance_id()%4)*.14
            else:
                _attack_clock=_loadout_shot_gap()
    # A previously seen/heard enemy behind destructible cover is no
    # longer visually locked. Fire at the last ACTUAL contact coordinate
    # only if a fresh physics ray hits real Aurora cover first.
    if (sector_battle and not _target_visible and _alert_time>0.0 and
            _attack_clock<=0.0 and _cover_probe_clock<=0.0):
        _fire_at_last_known_cover()
    if (_animation and _impact_reaction_remaining<=0.0 and
            _weapon_action_remaining<=0.0):
        # Keep real gait, AI and bullet cadence live underneath authored
        # firearm/impact visuals. The state returns after a bounded time.
        var action: String="AuroraIdle"
        if moving:
            action="AuroraRun" if running and _animation.has_animation("AuroraRun") else "AuroraWalk"
        if action!=_clip:
            _animation.play(action,.18)
            _clip=action
    if moving and _animation and is_instance_valid(operator) and (
            global_position.distance_squared_to(operator.global_position)<32.0*32.0):
        var gait: StringName=_animation.current_animation
        if _foot_contacts.advance(gait,_animation.current_animation_position,
                _animation.current_animation_length,dt):
            foot_contact.emit(global_position,gait==&"AuroraRun",_foot_contacts.stone_footing(self))
    else:
        _foot_contacts.advance(&"",0.0,0.0,dt)


## This function is the AI's sole position source for pursuit/flanking.
## Visual detection is granted only by the existing real PhysicsServer LOS.
## If the target is occluded, preserve the last confirmed audio/visual
## contact as immutable information, even if the real player moves elsewhere.
static func confirmed_contact_position(last_contact: Vector3,
        target: CharacterBody3D, has_visual: bool) -> Vector3:
    if has_visual and is_instance_valid(target):
        return target.global_position
    return last_contact


## Build a bounded sorted list of actual nearby CharacterBody3D
## opponents. Each bot examines at most five nearest candidates with real
## PhysicsServer raycast checks; farther bodies still exist, fight and take
## damage normally. No artificial eliminations or fake distant targets.
func _insert_sight_candidate(picks: Array[Dictionary],
        foe: CharacterBody3D,origin: Vector3,range_sq: float) -> void:
    if not _is_live_foe(foe):
        return
    var distance_sq: float=origin.distance_squared_to(foe.global_position)
    if distance_sq>=range_sq:
        return
    # Reject an out-of-budget candidate before scanning the insertion list.
    # Strict ordering and ties retain the historical first-seen order.
    if picks.size()==MAX_VISION_RAYS and distance_sq>=float(picks[-1]["distance_sq"]):
        return
    var place: int=picks.size()
    while place>0 and distance_sq<float(picks[place-1]["distance_sq"]):
        place-=1
    if place>=MAX_VISION_RAYS:
        return
    picks.insert(place,{"foe":foe,"distance_sq":distance_sq})
    if picks.size()>MAX_VISION_RAYS:
        picks.pop_back()


func _nearest_sight_candidates() -> Array[Dictionary]:
    var picks: Array[Dictionary]=[]
    var origin: Vector3=global_position
    var sight: float=_loadout_sight_range()
    var range_sq: float=sight*sight
    if is_instance_valid(operator):
        _insert_sight_candidate(picks,operator,origin,range_sq)
    if sector_battle:
        for foe in _foes:
            _insert_sight_candidate(picks,foe,origin,range_sq)
    return picks


## A prior confirmed target may be retained within a 3.5m switching margin,
## but only after a new real collision-aware line-of-sight verification.
func _sense_player() -> void:
    var previous: CharacterBody3D=_target_actor
    _target_visible=false
    _target_actor=null
    vision_rays_last=0
    # No full 50-person sorted allocation: cap memory and LOS work to
    # the same nearest-five observable physical agents.
    var candidates: Array[Dictionary]=_nearest_sight_candidates()
    var found: CharacterBody3D=null
    var found_distance: float=INF
    for item in candidates:
        if vision_rays_last>=MAX_VISION_RAYS:
            break
        var foe: CharacterBody3D=item["foe"] as CharacterBody3D
        vision_rays_last+=1
        vision_rays_total+=1
        if _has_verified_sight(foe):
            found=foe
            found_distance=float(item["distance_sq"])
            break
    # Prefer a recently verified enemy within a small switching margin,
    # as long as it remains alive, visible and within the sight radius.
    if (found!=null and is_instance_valid(previous) and previous!=found and
            vision_rays_last<MAX_VISION_RAYS and
            (previous==operator or previous.health>0.0)):
        var prior_distance: float=global_position.distance_squared_to(previous.global_position)
        if prior_distance<_loadout_sight_range()*_loadout_sight_range() and prior_distance<=(
                sqrt(found_distance)+TARGET_STICKINESS_METERS)*(
                sqrt(found_distance)+TARGET_STICKINESS_METERS):
            vision_rays_last+=1
            vision_rays_total+=1
            if _has_verified_sight(previous):
                found=previous
    if found!=null:
        _target_visible=true
        _target_actor=found

## Perception of audible gunfire is not visual detection. Move toward the
## last noise source, then use ordinary LOS checks before shooting.
func hear_gunshot(at: Vector3, originator: Node3D) -> void:
    if not sector_battle or health<=0 or originator==self or not at.is_finite():
        return
    if global_position.distance_squared_to(at)>HEARING_RANGE*HEARING_RANGE:
        return
    if _target_visible and is_instance_valid(_target_actor):
        # An enemy already in sight takes priority over an unconfirmed sound.
        return
    _last_seen=at
    _alert_time=maxf(_alert_time,4.5)
    _sense_clock=minf(_sense_clock,.10)
    # Schedule an urgent but staggered real navigation request. One loud
    # gunfight must not make up to 49 agents request A* on the same frame.
    _route_clock=minf(_route_clock,.025+
        float(get_instance_id()%ROUTE_REPLAN_BUCKETS)*.012)
    _route.clear()
    _route_goal=Vector3(INF,INF,INF)
    heard_shots+=1


## Hearing a nearby live fuse is not omniscient grenade awareness.
## Return true for a newly warned real opponent; event budget is tracked
## separately from physical deaths, ammo, and incoming hit reactions.
func warn_explosive(at: Vector3,seconds_left: float) -> bool:
    if (not sector_battle or health<=0.0 or
            _airdrop_stage in ["waiting","descending"] or
            not at.is_finite() or not is_finite(seconds_left) or
            seconds_left<=0.0 or
            global_position.distance_squared_to(at)>
                GRENADE_HEARING_RADIUS*GRENADE_HEARING_RADIUS):
        return false
    var new_warning: bool=_grenade_evasion_left<=0.0
    _grenade_last_at=at
    _grenade_evasion_left=maxf(_grenade_evasion_left,
        minf(1.0,seconds_left+.18))
    if _heal_remaining>0.0:
        _interrupt_field_heal()
    # Existing route planner remains authoritative, with its own
    # staggered budget; flee from the real grenade, not from the player.
    _route_clock=minf(_route_clock,.045+
        float(get_instance_id()%ROUTE_REPLAN_BUCKETS)*.012)
    if new_warning:
        _route.clear()
        _route_goal=Vector3(INF,INF,INF)
        grenade_dodges+=1
    return new_warning


func configure_sector_battle(actors: Array[CharacterBody3D],
        preserve_airdrop: bool=false) -> void:
    _cancel_respawn_timer()
    _reset_death_presentation()
    muzzle_flashes_shown=0
    weapon_actions_shown=0
    reload_actions_shown=0
    hit_reactions_shown=0
    last_hit_reaction=""
    sector_battle=true
    respawn_enabled=false
    _foes=actors.duplicate()
    health=MAX_HEALTH
    visible=not (preserve_airdrop and _airdrop_stage=="waiting")
    var collider:=get_node_or_null("OpponentCollider") as CollisionShape3D
    if collider:
        collider.set_deferred("disabled",false)
    set_physics_process(true)
    velocity=Vector3.ZERO
    if not preserve_airdrop:
        cancel_real_airdrop()
        global_position=_anchor
    elif _airdrop_stage=="landed":
        _airdrop_stage="inactive"
    _target_visible=false
    _target_actor=null
    _attack_clock=1.3
    _magazine=_loadout_capacity()
    _reload_remaining=0.0
    _grenade_evasion_left=0.0
    _grenade_last_at=Vector3(INF,INF,INF)
    grenade_dodges=0
    _field_medkits=FIELD_MEDKIT_CAPACITY
    _heal_remaining=0.0
    _heal_cooldown=0.0
    _clear_owned_covers()
    _cover_deploy_clock=0.0
    _cover_charges=1
    _cover_deploy_queued=false
    covers_deployed=0
    heal_channels_completed=0
    heal_channels_interrupted=0
    var name_plate:=get_node_or_null("TrainingTargetMarker") as Label3D
    if name_plate:
        # Debug nameplates, including the 'RIVAL / CURANDO' state, are
        # training-only. A BR opponent must be identified by its real 3D
        # body, weapon and audio, not a floating prototype caption.
        name_plate.text="ENEMIGO IA"
        name_plate.visible=false
    _burst_count=0
    _strafe_clock=0.0
    reloads_completed=0
    shots_fired=0
    shots_hit=0
    vision_rays_last=0
    vision_rays_total=0
    _alert_time=0.0
    _suppression_seconds=0.0
    _last_attacker=null
    heard_shots=0
    _last_seen=Vector3.ZERO
    _route.clear()
    next_zone_active=false
    next_safe_center=Vector2.ZERO
    next_safe_radius=INF
    zone_seconds_remaining=0
    # Do not start 49 path planners and vision scans on the same landing
    # physics frame. All agents stay physical, move and fight after a short
    # deterministic stagger; no one is disabled or silently culled.
    _route_clock=.08+float(get_instance_id()%13)*.035
    _sense_clock=.04+float(get_instance_id()%17)*.020
    _cover_probe_clock=.10+float(get_instance_id()%11)*.031
    _route_goal=Vector3(INF,INF,INF)
    _cover_point=Vector3(INF,INF,INF)
    _cover_clock=0.0


func take_training_damage(damage: float,attacker: Node3D=null) -> bool:
    if health<=0.0 or not is_finite(damage) or damage<=0.0:
        return false
    _interrupt_field_heal()
    health=maxf(0,health-damage)
    if is_instance_valid(attacker):
        _last_attacker=attacker
        _last_seen=attacker.global_position
        _suppression_seconds=5.0
        # Enter cover planning at most once per incident; the existing
        # route budget still bounds PhysicsServer queries on Motorola.
        _cover_clock=0.0
        _sense_clock=0.0
        _alert_time=maxf(_alert_time,5.5)
        _request_defensive_cover()
    # A null attacker means ambient/zone damage: interrupt healing and
    # reduce real HP, but do not fabricate a shooter, reset cover queries
    # or refresh pursuit against an unrelated player.
    if health<=0:
        _dead_time=7.0
        if sector_battle:
            _play_death_presentation(attacker)
        else:
            visible=false
        var collider:=get_node_or_null("OpponentCollider") as CollisionShape3D
        if collider:
            collider.set_deferred("disabled",true)
        set_physics_process(false)
        if respawn_enabled:
            # Keep original training respawn; BR eliminates permanently.
            _schedule_training_respawn()
        eliminated.emit(self,attacker)
        return true
    if sector_battle and is_instance_valid(attacker):
        _play_directional_hit(attacker.global_position)
    return false


## Hit origin uses the SAME body-local directional classification as Lila.
## Never allocate new skeletons for 41 LOD enemies; their real health, cover
## and collisions continue unmodified when no detailed rig is present.

## Same physical, destructible Aurora cover as Lila. A rival carries one
## wall per round, deployed after real damage and bounded for mobile.
func _request_defensive_cover() -> void:
    if (not sector_battle or health<=0.0 or
            health>ENEMY_COVER_HEALTH_THRESHOLD or
            _cover_charges<=0 or _cover_deploy_clock>0.0 or
            _cover_deploy_queued or not _last_seen.is_finite()):
        return
    _cover_deploy_queued=true
    call_deferred("_try_deploy_cover")


func _try_deploy_cover() -> bool:
    _cover_deploy_queued=false
    if (not is_inside_tree() or not sector_battle or health<=0.0 or
            health>ENEMY_COVER_HEALTH_THRESHOLD or
            _cover_charges<=0 or _cover_deploy_clock>0.0 or terrain==null):
        return false
    if get_tree().get_nodes_in_group("aurora_deployable_cover").size()>=MAX_ENEMY_COVERS:
        _cover_deploy_clock=2.0
        return false
    var forward: Vector3=_last_seen-global_position
    forward.y=0.0
    if (not forward.is_finite() or forward.length_squared()<16.0 or
            forward.length_squared()>SHOOT_RANGE*SHOOT_RANGE*2.25):
        return false
    forward=forward.normalized()
    var center: Vector3=global_position+forward*2.9
    var side: Vector3=Vector3(-forward.z,0.0,forward.x)
    var floor_y: float=terrain.height_at(center.x,center.z)
    if (not is_finite(floor_y) or
            absf(floor_y-global_position.y)>1.3 or
            absf(terrain.height_at(center.x+side.x*1.6,
                    center.z+side.z*1.6)-floor_y)>.65 or
            absf(terrain.height_at(center.x-side.x*1.6,
                    center.z-side.z*1.6)-floor_y)>.65):
        _cover_deploy_clock=2.0
        return false
    var angle: float=atan2(-forward.x,-forward.z)
    var shape:=BoxShape3D.new()
    shape.size=Vector3(3.45,2.30,.62)
    var probe:=PhysicsShapeQueryParameters3D.new()
    probe.shape=shape
    probe.collision_mask=1
    probe.exclude=[get_rid()]
    probe.transform=Transform3D(Basis(Vector3.UP,angle),
        Vector3(center.x,floor_y+1.18,center.z))
    for hit in get_world_3d().direct_space_state.intersect_shape(probe,12):
        if hit.get("collider")!=terrain:
            _cover_deploy_clock=2.0
            return false
    var wall: StaticBody3D=AURORA_COVER.new()
    wall.name="RivalAuroraCover"+str(get_instance_id())
    # A static barrier stays on the world, never following a moving bot.
    get_parent().add_child(wall)
    wall.global_position=Vector3(center.x,floor_y,center.z)
    wall.rotation.y=angle
    _owned_covers.append(wall)
    _cover_charges-=1
    _cover_deploy_clock=ENEMY_COVER_COOLDOWN
    covers_deployed+=1
    behavior="deploy_cover"
    return true


func _clear_owned_covers() -> void:
    for wall in _owned_covers:
        if is_instance_valid(wall):
            wall.queue_free()
    _owned_covers.clear()


func _play_directional_hit(origin: Vector3) -> void:
    if (_rig==null or _animation==null or not origin.is_finite() or
            not is_instance_valid(operator) or
            global_position.distance_squared_to(operator.global_position)>
            IMPACT_REACTION_VIEW_DISTANCE*IMPACT_REACTION_VIEW_DISTANCE):
        return
    var clip: String=IMPACT.directional_hit_clip(
        origin,global_position,global_basis)
    if not _animation.has_animation(clip):
        return
    # A new real hit takes precedence over interrupted weapon recoil.
    _animation.speed_scale=1.0
    _animation.play(clip,.06)
    _clip=clip
    _weapon_action_remaining=0.0
    _impact_reaction_remaining=IMPACT_REACTION_SECONDS
    last_hit_reaction=clip
    hit_reactions_shown+=1


## Play actual existing GLB upper-body weapon clips only after a
## legitimate physics shot/reload. This never consumes ammunition itself,
## creates a missing skeleton, nor changes the attacker or target hitbox.
## Incoming damage takes precedence over visual recoil on the same rig.
func _play_weapon_action(clip: String,seconds: float) -> bool:
    if (_rig==null or _animation==null or health<=0.0 or
            _impact_reaction_remaining>0.0 or _heal_remaining>0.0 or
            not _animation.has_animation(clip)):
        return false
    var authored_length: float=_animation.get_animation(clip).length
    if not is_finite(authored_length) or authored_length<=0.0:
        return false
    # ReloadAR is authored for a different time scale; match the actual
    # per-weapon physical magazine timer without altering its ballistics.
    _animation.speed_scale=authored_length/maxf(.05,seconds)
    _animation.play(clip,.06)
    _clip=clip
    _weapon_action_remaining=maxf(.05,seconds)
    weapon_actions_shown+=1
    if clip=="AuroraReloadAR":
        reload_actions_shown+=1
    return true


## The real health death and combat signal happen immediately. Only
## the visual presentation is deferred: no collisions, shooting, pathfinding,
## ragdoll mesh allocations or additional death rewards during this window.
func _play_death_presentation(lethal_attacker: Node3D) -> void:
    if _death_tween!=null and _death_tween.is_valid():
        _death_tween.kill()
    var visual: Node3D=_rig if _rig!=null else _lod_rig
    if not is_instance_valid(visual):
        visible=false
        return
    var marker:=get_node_or_null("TrainingTargetMarker") as Label3D
    if marker!=null:
        marker.visible=false
    visible=true
    _impact_reaction_remaining=0.0
    _weapon_action_remaining=0.0
    _muzzle_flash_remaining=0.0
    if _enemy_muzzle_flash!=null:
        _enemy_muzzle_flash.visible=false
    # Only this fatal physical hit determines the original skeleton clip.
    # Environmental damage cannot reuse a shooter from an earlier injury.
    var reaction: String="AuroraHit"
    if is_instance_valid(lethal_attacker):
        reaction=IMPACT.directional_hit_clip(
            lethal_attacker.global_position,global_position,global_basis)
    if _animation!=null and _animation.has_animation(reaction):
        _animation.speed_scale=1.0
        _animation.play(reaction,.08)
        _clip=reaction
    _death_tween=create_tween()
    _death_tween.set_parallel(true)
    _death_tween.tween_property(visual,"rotation:z",
        visual.rotation.z+1.10,.43).set_trans(Tween.TRANS_SINE).set_ease(
            Tween.EASE_OUT)
    _death_tween.tween_property(visual,"position:y",
        visual.position.y-.28,.43).set_trans(Tween.TRANS_SINE).set_ease(
            Tween.EASE_OUT)
    _death_tween.set_parallel(false)
    _death_tween.tween_interval(DEFEAT_PRESENTATION_SECONDS-.43)
    _death_tween.tween_callback(_complete_death_presentation)


func _complete_death_presentation() -> void:
    if health>0.0:
        return
    # The callback is running INSIDE this Tween; do not attempt to kill
    # the same Tween while returning a freed distant rig to the LOD pool.
    _death_tween=null
    visible=false
    # Reclaim a distant visual's high-detail budget after its real death.
    if distance_lod and _rig!=null:
        _set_full_visual(false)


func _reset_death_presentation() -> void:
    if _death_tween!=null and _death_tween.is_valid():
        _death_tween.kill()
    _death_tween=null
    _impact_reaction_remaining=0.0
    _weapon_action_remaining=0.0
    _muzzle_flash_remaining=0.0
    if _enemy_muzzle_flash!=null:
        _enemy_muzzle_flash.visible=false
    if _rig!=null:
        _rig.transform=_rig_rest_transform
        if _animation!=null and _animation.has_animation("AuroraIdle"):
            _animation.speed_scale=1.0
            _animation.play("AuroraIdle")
            _clip="AuroraIdle"
    if is_instance_valid(_lod_rig):
        _lod_rig.transform=_lod_rest_transform
        _lod_rig.visible=true
    var marker:=get_node_or_null("TrainingTargetMarker") as Label3D
    if marker!=null:
        # The death animation resets the mesh across rounds; do not let
        # its reset resurrect a debug label during a live 50-player BR.
        marker.visible=not sector_battle


func _cancel_respawn_timer() -> void:
    if is_instance_valid(_respawn_timer):
        _respawn_timer.stop()
    _dead_time=0.0


func _schedule_training_respawn() -> void:
    if not is_instance_valid(_respawn_timer):
        _respawn_timer=Timer.new()
        _respawn_timer.name="TrainingRespawnTimer"
        _respawn_timer.one_shot=true
        _respawn_timer.process_mode=Node.PROCESS_MODE_ALWAYS
        _respawn_timer.timeout.connect(_respawn)
        add_child(_respawn_timer)
    _respawn_timer.start(_dead_time)


func _respawn() -> void:
    # A late callback must never reset a living or BR combatant.
    if not respawn_enabled or sector_battle or health>0.0 or not is_inside_tree():
        return
    _cancel_respawn_timer()
    _grenade_evasion_left=0.0
    _grenade_last_at=Vector3(INF,INF,INF)
    _reset_death_presentation()
    muzzle_flashes_shown=0
    weapon_actions_shown=0
    reload_actions_shown=0
    hit_reactions_shown=0
    last_hit_reaction=""
    health=MAX_HEALTH
    _field_medkits=FIELD_MEDKIT_CAPACITY
    _heal_remaining=0.0
    _heal_cooldown=0.0
    _clear_owned_covers()
    _cover_deploy_clock=0.0
    _cover_charges=1
    _cover_deploy_queued=false
    covers_deployed=0
    heal_channels_completed=0
    heal_channels_interrupted=0
    var name_plate:=get_node_or_null("TrainingTargetMarker") as Label3D
    if name_plate:
        name_plate.text="ENEMIGO IA"
        name_plate.visible=not sector_battle
    global_position=_anchor
    visible=true
    var collider:=get_node_or_null("OpponentCollider") as CollisionShape3D
    if collider:
        collider.set_deferred("disabled",false)
    velocity=Vector3.ZERO
    _alert_time=0
    _suppression_seconds=0.0
    _last_attacker=null
    _target_visible=false
    _dead_time=0
    set_physics_process(true)

## Battle Royale medkits do not regenerate magically. They are limited
## to one item in this opponent's actual spawn inventory, then consumed.
func _should_field_heal() -> bool:
    if not sector_battle or health<=0.0 or health>FIELD_MEDKIT_HEALTH_THRESHOLD:
        return false
    if (_field_medkits<=0 or _heal_remaining>0.0 or
            _heal_cooldown>0.0 or _reload_remaining>0.0):
        return false
    if _target_visible:
        return false
    var distance_to_safe: float=Vector2(global_position.x,global_position.z).distance_to(safe_center)
    return distance_to_safe<=safe_radius


func _begin_field_heal() -> bool:
    if not _should_field_heal():
        return false
    _heal_remaining=FIELD_MEDKIT_SECONDS
    var name_plate:=get_node_or_null("TrainingTargetMarker") as Label3D
    if name_plate:
        name_plate.text="RIVAL / CURANDO"
    return true


## True only when a heal was active at the beginning of this physics
## callback; ending the channel never grants a free attack in the same tick.
func _advance_field_heal(dt: float) -> bool:
    if _heal_remaining<=0.0:
        return false
    if health<=0.0 or not sector_battle:
        _interrupt_field_heal()
        return true
    _heal_remaining=maxf(0.0,_heal_remaining-maxf(0.0,dt))
    if _heal_remaining<=0.0:
        var restored: float=minf(MAX_HEALTH,health+FIELD_MEDKIT_HEAL)
        if restored>health and _field_medkits>0:
            health=restored
            _field_medkits-=1
            heal_channels_completed+=1
        _attack_clock=maxf(_attack_clock,.35)
        var name_plate:=get_node_or_null("TrainingTargetMarker") as Label3D
        if name_plate:
            name_plate.text="ENEMIGO IA"
    return true


func _interrupt_field_heal() -> void:
    if _heal_remaining<=0.0:
        return
    _heal_remaining=0.0
    _heal_cooldown=maxf(_heal_cooldown,FIELD_MEDKIT_INTERRUPTED_COOLDOWN)
    heal_channels_interrupted+=1
    var name_plate:=get_node_or_null("TrainingTargetMarker") as Label3D
    if name_plate:
        name_plate.text="ENEMIGO IA"


## Exclude real eliminated actors from both physics sight and firearm use.
## Visual contact and ballistic clearance are different questions.
func _is_live_foe(foe: CharacterBody3D) -> bool:
    if foe==self or not is_instance_valid(foe):
        return false
    if foe==operator:
        return not operator.royale_eliminated
    return foe.health>0.0


func _has_verified_sight(foe: CharacterBody3D) -> bool:
    if not _is_live_foe(foe):
        return false
    var ray:=PhysicsRayQueryParameters3D.create(
        global_position+Vector3.UP*1.35,
        foe.global_position+Vector3.UP*1.0)
    ray.exclude=[get_rid()]
    var collider: Object=get_world_3d().direct_space_state.intersect_ray(
        ray).get("collider")
    # A wall (even destructible Aurora cover) is NOT visual proof of the
    # person's CURRENT position. Never use its contact as a player lock.
    return collider==foe


func _has_line_of_fire(foe: CharacterBody3D) -> bool:
    if not _is_live_foe(foe):
        return false
    var ray:=PhysicsRayQueryParameters3D.create(
        global_position+Vector3.UP*1.35,
        foe.global_position+Vector3.UP*1.0)
    ray.exclude=[get_rid()]
    var obstacle: Object=get_world_3d().direct_space_state.intersect_ray(
        ray).get("collider")
    # Ballistics can hit a physical destructible wall even though the
    # target behind it is NOT confirmed visible by the sensing ray.
    return obstacle==foe or (obstacle is StaticBody3D and
        (obstacle as StaticBody3D).is_in_group("aurora_deployable_cover"))


## Only REAL committed shots can illuminate the original gun.
## The raycast physics/damage origin remains the same gameplay muzzle;
## only the pooled visual tracer may start at this animated rifle muzzle.
func _show_real_muzzle_flash() -> void:
    # The far actor keeps the same weapon mesh but not 49 simultaneous
    # muzzle VFX; only a leased near animator may display this flash.
    if (_rig==null or health<=0.0 or
            not is_instance_valid(_enemy_muzzle_flash)):
        return
    _enemy_muzzle_flash.visible=true
    _muzzle_flash_remaining=REAL_MUZZLE_FLASH_SECONDS
    muzzle_flashes_shown+=1


func _visible_trace_origin(physics_origin: Vector3) -> Vector3:
    if (_rig==null or health<=0.0 or
            not is_instance_valid(_enemy_muzzle_flash)):
        return physics_origin
    var rifle_point: Vector3=_enemy_muzzle_flash.global_position
    if (not rifle_point.is_finite() or
            rifle_point.distance_squared_to(physics_origin)>
            MAX_MUZZLE_TRACER_OFFSET*MAX_MUZZLE_TRACER_OFFSET):
        return physics_origin
    return rifle_point


func _fire_at_last_known_cover() -> bool:
    # No live target coordinates are accessed here. A bounded probe
    # tests a real wall on the route to a *previously verified* location.
    if (_target_visible or _alert_time<=0.0 or _attack_clock>0.0 or
            _reload_remaining>0.0 or _magazine<=0 or
            not _last_seen.is_finite() or health<=0.0):
        return false
    if global_position.distance_squared_to(_last_seen)>_loadout_range()*_loadout_range():
        return false
    _cover_probe_clock=COVER_PROBE_SECONDS+float(get_instance_id()%5)*.06
    var muzzle: Vector3=global_position+Vector3.UP*1.35
    var destination: Vector3=_last_seen+Vector3.UP*1.0
    var ray:=PhysicsRayQueryParameters3D.create(muzzle,destination)
    ray.exclude=[get_rid()]
    var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
    var body: Object=hit.get("collider")
    if (not (body is StaticBody3D) or
            not (body as StaticBody3D).is_in_group(
                "aurora_deployable_cover") or
            not body.has_method("is_active") or
            not bool(body.call("is_active"))):
        return false
    shots_fired+=1
    _magazine-=1
    _play_weapon_action("AuroraFire",FIRE_PRESENTATION_SECONDS)
    _show_real_muzzle_flash()
    weapon_fired.emit(global_position)
    shot_trace.emit(_visible_trace_origin(muzzle),
        hit.get("position",destination))
    body.call("take_damage",12.0)
    _burst_count=0
    _attack_clock=BURST_RECOVERY
    if _magazine<=0:
        _begin_reload()
    return true


func _fire_at_target(foe: CharacterBody3D) -> bool:
    if not _is_live_foe(foe) or _reload_remaining>0.0 or _magazine<=0:
        return false
    shots_fired+=1
    _play_weapon_action("AuroraFire",FIRE_PRESENTATION_SECONDS)
    _show_real_muzzle_flash()
    weapon_fired.emit(global_position)
    var distance: float=global_position.distance_to(foe.global_position)
    var spread: float=clampf(distance/_loadout_range(),0.0,1.0)*(.22 if weapon_slot==WEAPONS.AWM else .52)
    var sideways: Vector3=(foe.global_position-global_position).cross(Vector3.UP).normalized()
    var endpoint: Vector3=foe.global_position+Vector3.UP*(1.0+_random.randf_range(-spread*.6,spread*.6))+sideways*_random.randf_range(-spread,spread)
    var muzzle: Vector3=global_position+Vector3.UP*1.35
    var ray:=PhysicsRayQueryParameters3D.create(muzzle,endpoint)
    ray.exclude=[get_rid()]
    var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
    shot_trace.emit(_visible_trace_origin(muzzle),
        hit.get("position",endpoint))
    var actor: Object=hit.get("collider")
    if actor==operator and not operator.royale_eliminated:
        operator.receive_training_hit(_loadout_damage(),false,global_position,hit["position"])
        shots_hit+=1
    elif actor is CharacterBody3D and actor.is_in_group("training_target") and actor.health>0:
        actor.take_training_damage(_loadout_damage(),self)
        shots_hit+=1
    elif actor is StaticBody3D and actor.is_in_group("aurora_deployable_cover"):
        actor.call("take_damage",12.0)
    return true


## Reloading consumes time in physical combat, without emitting fake shots.
func _begin_reload() -> void:
    if _reload_remaining>0.0 or health<=0.0:
        return
    _reload_remaining=_loadout_reload_seconds()
    _burst_count=0
    _attack_clock=_reload_remaining
    _play_weapon_action("AuroraReloadAR",_loadout_reload_seconds())


## Move inside the next safe circle without stacking all rivals at center.
static func should_rotate_to_next_zone(position: Vector3,next_center: Vector2,
        next_radius: float,seconds_remaining: int,engaged: bool) -> bool:
    if (engaged or not position.is_finite() or not next_center.is_finite()
            or not is_finite(next_radius) or next_radius<=0.0):
        return false
    if seconds_remaining<=0 or seconds_remaining>NEXT_ZONE_ROTATE_SECONDS:
        return false
    var current: Vector2=Vector2(position.x,position.z)
    return current.distance_to(next_center)>maxf(0.0,next_radius-2.0)


## Only use the current ring's real center/radius: no invulnerable safe
## states or simulated movement. A proportional safety buffer is essential
## when the last ring contracts below 4m.
static func route_replan_interval(id: int) -> float:
    return .90+float(posmod(id,ROUTE_REPLAN_BUCKETS))*.027


static func should_escape_current_zone(position: Vector3,center: Vector2,
        radius: float) -> bool:
    if (not position.is_finite() or not center.is_finite() or
            not is_finite(radius) or radius<=0.0):
        return false
    var border_margin: float=minf(4.0,radius*.20)
    var allowed: float=maxf(0.0,radius-border_margin)
    return Vector2(position.x,position.z).distance_to(center)>allowed


static func should_hold_final_zone(destination: Vector3,center: Vector2,
        radius: float,engaged: bool) -> bool:
    if (engaged or not destination.is_finite() or not center.is_finite()
            or not is_finite(radius) or radius<=0.0 or radius>12.0):
        return false
    return Vector2(destination.x,destination.z).distance_to(
        center)>maxf(0.05,radius*.80)


static func safe_zone_destination(position: Vector3,center: Vector2,
        safe_radius_value: float) -> Vector3:
    if (not position.is_finite() or not center.is_finite() or
            not is_finite(safe_radius_value) or safe_radius_value<=0.0):
        return position
    var radial:=Vector2(position.x-center.x,position.z-center.y)
    if radial.length_squared()<.0001:
        return Vector3(center.x,position.y,center.y)
    # Radius below 5m previously made the destination EXACTLY the ring
    # center for every rival. Keep distinct radial approaches inside the
    # true safe circle; physical collisions and storm damage remain active.
    var inner_radius: float=(safe_radius_value*.55 if safe_radius_value<=5.0
        else maxf(0.0,minf(safe_radius_value*ZONE_SAFE_FRACTION,
        safe_radius_value-5.0)))
    var target: Vector2=center+radial.normalized()*inner_radius
    return Vector3(target.x,position.y,target.y)


func _blocked_ahead(direction: Vector3) -> bool:
    var collision:=_movement_probe
    if not test_move(global_transform,direction,collision):
        return false
    # Sloped floor contact is expected. Treating it as a wall made avoidance
    # turn away from valid uphill paths on the island.
    for i in range(collision.get_collision_count()):
        if collision.get_normal(i).y<.65:
            return true
    return false
