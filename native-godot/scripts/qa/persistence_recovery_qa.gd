extends SceneTree
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
var failed: bool=false

func check(ok: bool, message: String) -> void:
    if not ok:
        failed=true
        push_error("RECOVERY "+message)

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var path: String="user://qa/recovery_"+str(Time.get_ticks_usec())+".json"
    var store=RECORDS.new(path)
    check(store.record_result(1,true,2,30),"first commit")
    var backup: String=ProjectSettings.globalize_path(path+".bak")
    DirAccess.make_dir_absolute(backup)
    check(not store.record_result(2,false,1,20),"injected backup failure not detected")
    # Reopen a complete staged result after an interrupted/failed primary commit.
    var recovered=RECORDS.new(path)
    check(int(recovered.snapshot().played)==2,"lost staged result after process restart")
    DirAccess.remove_absolute(backup)
    check(recovered.retry_pending(),"pending result not recoverable")
    check(not recovered.record_result(2,false,1,20),"duplicate recovery")
    check(int(RECORDS.new(path).snapshot().played)==2,"recovery did not persist")
    # Old files have plain JSON and must remain readable.
    var legacy:=FileAccess.open(path,FileAccess.WRITE)
    legacy.store_string(JSON.stringify(recovered.snapshot()))
    legacy.close()
    check(RECORDS.new(path).next_match_id()==3,"legacy profile unreadable")
    # A newer malformed temporary snapshot must not outrank committed data.
    var bad:=FileAccess.open(path+".tmp",FileAccess.WRITE)
    bad.store_string('{"payload":"truncated","sha256":"wrong"}')
    bad.close()
    check(RECORDS.new(path).next_match_id()==3,"corrupt temporary replaced valid profile")
    # Round integration must retry the same completed result exactly once.
    var game: Node=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director=game.get_node("AuroraSectorMatch")
    director._records=RECORDS.new(path)
    director.start_sector_battle()
    DirAccess.remove_absolute(backup)
    DirAccess.make_dir_absolute(backup)
    director._finish(true)
    check(not director.last_match_saved,"failure incorrectly reported as saved")
    DirAccess.remove_absolute(backup)
    check(director.retry_result() and director.last_match_saved,"round retry failed")
    director._finish(true)
    check(RECORDS.new(path).next_match_id()==4,"round duplicated on retry")
    # If no existing snapshot is valid, do not start an unsaveable new round
    # or overwrite the damaged profile with a fresh zeroed ledger.
    for suffix in ["",".bak"]:
        var broken:=FileAccess.open(path+suffix,FileAccess.WRITE)
        broken.store_string("truncated")
        broken.close()
    director._records=RECORDS.new(path)
    director.begin_aircraft_phase()
    check(director.match_ended and director.mode=="sector_battle","invalid profile allowed deployment")
    director.start_sector_battle()
    check(director.match_ended and FileAccess.get_file_as_string(path)=="truncated","invalid profile overwritten")
    for suffix in ["",".tmp",".bak"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
    print("PERSISTENCE_RECOVERY PASS staged recovery, legacy, corrupt temporary, integrated retry, invalid-profile guard")
    quit(1 if failed else 0)
