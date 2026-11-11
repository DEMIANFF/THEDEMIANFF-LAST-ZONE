extends SceneTree
## Motorola Training actually stopped after navigation_first_batch_after.
## Exercise sequential shape queries while retaining original real navigation.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V7520_NAV "+message)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var nav: Node3D=game.get_node("AuroraNavigation")
    var player: CharacterBody3D=game.get_node("Operator")
    check(nav.NODE_BATCH_SIZE==12 and nav.INITIAL_PHYSICS_WARMUP==18,
        "navigation startup is still a heavy 40-probe first frame")
    check(nav._warmup>=16 and nav._build_index==0,
        "expensive navigation started during the world first-render window")
    for i in range(28):
        await physics_frame
    check(nav._first_navigation_batch_logged,
        "navigation never left the start warmup")
    check(nav._build_index>0 and nav._build_index<=nav.NODE_BATCH_SIZE*10,
        "navigation ran an unbounded first-frame batch")
    check(nav.graph.get_point_count()>0,
        "real physics queries never generated walkable graph nodes")
    var history: String=str(TRACE.last().get("history",""))
    for event in ["navigation_first_batch_before","navigation_batch_before",
        "navigation_batch_after","navigation_first_batch_after"]:
        check(history.contains(event),
            "missing durable Training native handoff event "+event)
    var last: Dictionary=TRACE.last()
    check(str(last.get("phase",""))=="training",
        "Training exit diagnostics lost their phase after navigation queries")
    check(str(last.get("position",""))!="" and
        str(last.get("air_mode",""))=="ground",
        "navigation report omitted the real operator position/mode")
    for i in range(250):
        await physics_frame
        if nav.available:
            break
    check(nav.available and nav.graph.get_point_count()>150,
        "small batches did not complete the real navigation A* graph")
    check(player.global_position.is_finite(),
        "real Training character physics became invalid")
    print("V7520_NAV PASS staged 12-query batches after first 18 frames, ",
        "durable per-batch reports and complete actual A* navigation")
    quit(1 if failed else 0)
