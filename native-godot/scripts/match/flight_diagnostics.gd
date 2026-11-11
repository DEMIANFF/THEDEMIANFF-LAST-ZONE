extends RefCounted
## A tiny on-device flight breadcrumb. A hard native Android exit cannot run
## GDScript exception handlers, so persist the last observed flight phase.
## This is diagnostic evidence, NOT a native crash stack trace.
const TRACE_PATH: String="user://aurora_flight_trace.cfg"
const TEMP_PATH: String="user://aurora_flight_trace_pending.tmp"
const PREVIOUS_PATH: String="user://aurora_previous_interrupted_flight.cfg"
const MAX_EVENTS: int=48
static var _sequence: int=0
const FLIGHT_SAFETY_MODE=preload("res://scripts/persistence/flight_safety_mode.gd")
static var _last_transition: String=""
# Recent durable breadcrumbs survive process death and show callback ordering.
static var _recent_transitions: Array[String]=[]


static func checkpoint(state: String,phase: String,player: Node3D=null,note: String="",context: String="") -> Error:
    # Before a new flight starts, keep the old unfinished flight in its own
    # file. Starting a second match no longer destroys the previous evidence.
    if phase=="aircraft" and note=="start":
        var previous: Dictionary=last()
        if str(previous.get("state",""))=="active":
            var old_file:=FileAccess.open(TRACE_PATH,FileAccess.READ)
            if old_file:
                var old_text: String=old_file.get_as_text()
                old_file.close()
                var backup:=FileAccess.open(PREVIOUS_PATH,FileAccess.WRITE)
                if backup:
                    backup.store_string(old_text)
                    backup.flush()
                    backup.close()
        _recent_transitions.clear()
        _last_transition=""
        _sequence=0

    _sequence+=1
    var periodical: bool=note=="flight_tick" or note.begins_with("aircraft_tick_") or \
        note.begins_with("freefall_tick_") or note.begins_with("parachute_tick_")
    if not periodical:
        _last_transition=note

    var event: String="#"+str(_sequence)+" +"+str(Time.get_ticks_msec())+"ms "+phase+" / "+note
    event+=" [fis="+str(Engine.get_physics_frames())+" vid="+str(Engine.get_process_frames())+"]"
    if context!="":
        event+=" | "+context.substr(0,240)
    _recent_transitions.append(event)
    while _recent_transitions.size()>MAX_EVENTS:
        _recent_transitions.remove_at(0)

    var cfg:=ConfigFile.new()
    cfg.set_value("flight","state",state)
    cfg.set_value("flight","phase",phase)
    cfg.set_value("flight","note",note)
    cfg.set_value("flight","sequence",_sequence)
    cfg.set_value("flight","last_transition",_last_transition)
    cfg.set_value("flight","recent_transitions",PackedStringArray(_recent_transitions))
    cfg.set_value("flight","context",context.substr(0,512))
    cfg.set_value("flight","diagnostic_mode",FLIGHT_SAFETY_MODE.current_mode())
    cfg.set_value("flight","build",str(ProjectSettings.get_setting("application/config/name","")))
    cfg.set_value("flight","render_backend",str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile","")))
    cfg.set_value("flight","operating_system",OS.get_name())
    cfg.set_value("flight","device_model",OS.get_model_name())
    cfg.set_value("flight","timestamp_unix",int(Time.get_unix_time_from_system()))
    cfg.set_value("flight","uptime_ms",Time.get_ticks_msec())
    cfg.set_value("flight","physics_frames",Engine.get_physics_frames())
    cfg.set_value("flight","process_frames",Engine.get_process_frames())
    cfg.set_value("flight","fps",Engine.get_frames_per_second())
    cfg.set_value("flight","static_memory_bytes",int(Performance.get_monitor(Performance.MEMORY_STATIC)))
    if player!=null and is_instance_valid(player):
        cfg.set_value("flight","position",player.global_position)
        if player is CharacterBody3D:
            var body: CharacterBody3D=player as CharacterBody3D
            cfg.set_value("flight","velocity",body.velocity)
            cfg.set_value("flight","on_floor",body.is_on_floor())
            cfg.set_value("flight","air_mode",str(body.get("air_mode")))
            cfg.set_value("flight","animation_clip",str(body.get("_current_clip")))
            cfg.set_value("flight","visual_mode",int(body.get("canopy_diagnostic_mode")))
    # A process death DURING a telemetry write must not truncate the last
    # valid report. Write and flush a sibling file first; replace the main
    # snapshot with a same-directory rename only when complete.
    var file:=FileAccess.open(TEMP_PATH,FileAccess.WRITE)
    if file==null:
        return FileAccess.get_open_error()
    file.store_string(cfg.encode_to_text())
    file.flush()
    file.close()
    return DirAccess.rename_absolute(TEMP_PATH,TRACE_PATH)

static func last(previous: bool=false) -> Dictionary:
    var cfg:=ConfigFile.new()
    if cfg.load(PREVIOUS_PATH if previous else TRACE_PATH)!=OK:
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
        "sequence":int(cfg.get_value("flight","sequence",0)),
        "context":str(cfg.get_value("flight","context","")),
        "operating_system":str(cfg.get_value("flight","operating_system","")),
        "device_model":str(cfg.get_value("flight","device_model","")),
        "physics_frames":int(cfg.get_value("flight","physics_frames",0)),
        "process_frames":int(cfg.get_value("flight","process_frames",0)),
        "air_mode":str(cfg.get_value("flight","air_mode","")),
        "animation_clip":str(cfg.get_value("flight","animation_clip","")),
        "on_floor":str(cfg.get_value("flight","on_floor","")),
        "visual_mode":int(cfg.get_value("flight","visual_mode",0)),
        "diagnostic_mode":int(cfg.get_value("flight","diagnostic_mode",0)),
        "static_memory_bytes":int(cfg.get_value("flight","static_memory_bytes",0)),
        "position":str(cfg.get_value("flight","position","")),
        "velocity":str(cfg.get_value("flight","velocity","")),
        "history":"\n".join(cfg.get_value("flight","recent_transitions",PackedStringArray()))
    }


static func report(previous: bool=false) -> String:
    var data: Dictionary=last(previous)
    if data.is_empty():
        return "Aurora: aún no hay un registro de vuelo."
    var rows: Array[String]=[
        "THEDEMIANFF GODOT / diagnóstico de vuelo",
        "Estado: "+str(data["state"]),
        "Fase: "+str(data["phase"]),
        "Detalle: "+str(data["note"]),
        "Última transición: "+str(data["last_transition"]),
        "Versión: "+str(data["build"]),
        "Dispositivo: "+str(data["device_model"])+" / "+str(data["operating_system"]),
        "Evento N°: "+str(data["sequence"]),
        "Render: "+str(data["render_backend"]),
        "Tiempo Unix: "+str(data["timestamp_unix"]),
        "Tiempo motor (ms): "+str(data["uptime_ms"]),
        "FPS: "+str(data["fps"]),
        "Fotogramas física/render: "+str(data["physics_frames"])+" / "+str(data["process_frames"]),
        "Modo físico del personaje: "+str(data["air_mode"]),
        "Animación seleccionada: "+str(data["animation_clip"]),
        "En suelo: "+str(data["on_floor"]),
        "Modo visual de vuelo: "+FLIGHT_SAFETY_MODE.label_for(int(data["diagnostic_mode"])),
        "Memoria estática del motor (MB; no RAM total): "+str(snappedf(float(data["static_memory_bytes"])/1048576.0,.1)),
        "Posición juego: "+str(data["position"]),
        "Velocidad: "+str(data["velocity"]),
        "Nota: último estado guardado; no es una pila de error nativo Android."
    ]
    if str(data["context"])!="":
        rows.append("Contexto del último evento: "+str(data["context"]))
    if str(data["history"])!="":
        rows.append("Historial de hasta "+str(MAX_EVENTS)+" eventos:\n"+str(data["history"]))
    return "\n".join(rows)
