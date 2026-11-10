extends RefCounted
## A tiny on-device flight breadcrumb. A hard native Android exit cannot run
## GDScript exception handlers, so persist the last observed flight phase.
## This is diagnostic evidence, NOT a native crash stack trace.
const TRACE_PATH: String="user://aurora_flight_trace.cfg"
static var _last_transition: String=""


static func checkpoint(state: String,phase: String,player: Node3D=null,note: String="") -> Error:
    var cfg:=ConfigFile.new()
    cfg.set_value("flight","state",state)
    cfg.set_value("flight","phase",phase)
    cfg.set_value("flight","note",note)
    # Periodic telemetry must not erase the last meaningful transition
    # (e.g. jump_requested) just before a hard Android process exit.
    if note!="flight_tick" and not note.begins_with("aircraft_tick_") and \
        not note.begins_with("freefall_tick_") and not note.begins_with("parachute_tick_"):
        _last_transition=note
    cfg.set_value("flight","last_transition",_last_transition)
    cfg.set_value("flight","build",str(ProjectSettings.get_setting("application/config/name","")))
    cfg.set_value("flight","render_backend",str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile","")))
    cfg.set_value("flight","timestamp_unix",int(Time.get_unix_time_from_system()))
    cfg.set_value("flight","uptime_ms",Time.get_ticks_msec())
    cfg.set_value("flight","fps",Engine.get_frames_per_second())
    cfg.set_value("flight","static_memory_bytes",int(Performance.get_monitor(Performance.MEMORY_STATIC)))
    if player!=null and is_instance_valid(player):
        cfg.set_value("flight","position",player.global_position)
        if player is CharacterBody3D:
            cfg.set_value("flight","velocity",(player as CharacterBody3D).velocity)
    var file:=FileAccess.open(TRACE_PATH,FileAccess.WRITE)
    if file==null:
        return FileAccess.get_open_error()
    file.store_string(cfg.encode_to_text())
    file.flush()
    file.close()
    return OK


static func last() -> Dictionary:
    var cfg:=ConfigFile.new()
    if cfg.load(TRACE_PATH)!=OK:
        return {}
    return {
        "state":str(cfg.get_value("flight","state","")),
        "phase":str(cfg.get_value("flight","phase","")),
        "note":str(cfg.get_value("flight","note","")),
        "last_transition":str(cfg.get_value("flight","last_transition","")),
        "build":str(cfg.get_value("flight","build","")),
        "render_backend":str(cfg.get_value("flight","render_backend","")),
        "timestamp_unix":int(cfg.get_value("flight","timestamp_unix",0)),
        "uptime_ms":int(cfg.get_value("flight","uptime_ms",0)),
        "fps":int(cfg.get_value("flight","fps",0)),
        "static_memory_bytes":int(cfg.get_value("flight","static_memory_bytes",0)),
        "position":str(cfg.get_value("flight","position","")),
        "velocity":str(cfg.get_value("flight","velocity",""))
    }


static func report() -> String:
    var data: Dictionary=last()
    if data.is_empty():
        return "Aurora: aún no hay un registro de vuelo."
    var rows: Array[String]=[
        "THEDEMIANFF GODOT / diagnóstico de vuelo",
        "Estado: "+str(data["state"]),
        "Fase: "+str(data["phase"]),
        "Detalle: "+str(data["note"]),
        "Última transición: "+str(data["last_transition"]),
        "Versión: "+str(data["build"]),
        "Render: "+str(data["render_backend"]),
        "Tiempo Unix: "+str(data["timestamp_unix"]),
        "Tiempo motor (ms): "+str(data["uptime_ms"]),
        "FPS: "+str(data["fps"]),
        "Memoria estática del motor (MB; no RAM total): "+str(snappedf(float(data["static_memory_bytes"])/1048576.0,.1)),
        "Posición juego: "+str(data["position"]),
        "Velocidad: "+str(data["velocity"]),
        "Nota: estado previo, no diagnóstico de causa nativa."
    ]
    return "\n".join(rows)
