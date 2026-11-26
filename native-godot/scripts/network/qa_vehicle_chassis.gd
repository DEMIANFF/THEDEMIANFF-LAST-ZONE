extends "res://scripts/world/aurora_driveable_vehicle.gd"
## Private QA only: exercise original physics without distributing private GLBs.
func _ready() -> void:
    if OS.get_environment("AURORA_ONLINE_QA_FIXTURE")!="1" or OS.get_environment("AURORA_ONLINE_QA_VEHICLE")!="1":
        queue_free()
        return
    mass=1250.0
    linear_damp=.24
    angular_damp=1.1
    center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass=Vector3(0,-.42,0)
    collision_layer=1
    collision_mask=1
    _build_chassis()
    _build_wheels()
    _model_ready=true
    freeze=true
    sleeping=true
