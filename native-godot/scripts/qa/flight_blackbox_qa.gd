extends SceneTree
## Fast, real GDScript test; does not need Blender, graphics or Android SDK.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("FLIGHT_BLACKBOX "+message)

func _verify() -> void:
    check(TRACE.checkpoint("active","aircraft",null,"start")==OK,
        "could not initialize durable flight snapshot")
    check(TRACE.checkpoint("active","freefall",null,"jump_committed",
        "x=0 clearance=35.0m")==OK,"jump record not saved")
    for i in range(65):
        check(TRACE.checkpoint("active","parachute",null,"record_"+str(i),
            "stage=operator_physics index="+str(i))==OK,
            "could not persist journal sample "+str(i))
    var last: Dictionary=TRACE.last()
    var hist: String=str(last.get("history",""))
    check(int(last.get("sequence",0))==67,
        "sequence counter missing or reset")
    check(hist.contains("record_64") and not hist.contains("record_0 ["),
        "journal did not retain latest events")
    check(hist.split("\n").size()==TRACE.MAX_EVENTS,
        "journal is not capped at exactly 48 events")
    check(int(last.get("physics_frames",-1))>=0 and
        int(last.get("process_frames",-1))>=0,
        "engine tick counters omitted")
    check(str(last.get("operating_system",""))!="",
        "host OS not captured")
    check(str(last.get("context","")).contains("index=64"),
        "last event detail omitted")
    check(TRACE.report().contains("Historial de hasta 48 eventos") and
        TRACE.report().contains("Fotogramas física/render"),
        "complete in-app diagnostic report is missing")
    check(not FileAccess.file_exists(TRACE.TEMP_PATH),
        "temporary journal snapshot should have been renamed atomically")
    # Simulate a hard process kill *during* a future write: leave only a
    # broken pending file and verify the previous complete report survives.
    var unfinished:=FileAccess.open(TRACE.TEMP_PATH,FileAccess.WRITE)
    check(unfinished!=null,"failed to stage interrupted write")
    if unfinished:
        unfinished.store_string("incomplete-config-during-android-kill")
        unfinished.close()
    check(TRACE.last().get("note","")=="record_64",
        "partial pending write destroyed the last valid flight report")
    check(TRACE.checkpoint("active","aircraft",null,"start")==OK,
        "next match could not start")
    var saved: Dictionary=TRACE.last(true)
    check(int(saved.get("sequence",0))==67 and
        str(saved.get("note",""))=="record_64" and
        str(saved.get("state",""))=="active",
        "previous interrupted flight snapshot was not retained")
    check(TRACE.report(true).contains("record_64"),
        "previous crash copy report cannot recover details")
    check(str(TRACE.last().get("history","")).split("\n").size()==1,
        "new flight did not reset the live ring buffer")
    check(TRACE.checkpoint("completed","ground",null,
        "landed_and_match_started")==OK,"completed match did not persist")
    check(str(TRACE.last().get("state",""))=="completed",
        "successful game should not show an unfinished crash")
    print("FLIGHT_BLACKBOX PASS 48-event capped journal, device/engine counters, ",
        "context, previous interrupted snapshot and completed state")
    quit(1 if failed else 0)
