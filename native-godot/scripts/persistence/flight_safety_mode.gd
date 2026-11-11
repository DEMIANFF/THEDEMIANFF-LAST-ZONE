extends RefCounted
## A/B field diagnosis of the physical Android parachute exit.
## The canopy physics, terrain collisions and HUD are ALWAYS real.
## These toggles only affect optional visual subsystems while testing.
const SETTINGS_PATH: String="user://aurora_flight_safety.cfg"
const MODE_NORMAL: int=0
const MODE_NO_SKELETAL_CANOPY: int=1
const MODE_NO_CANOPY_MESH: int=2
const MODE_MINIMAL_VISUALS: int=3
static var _cached_mode: int=-1

static func current_mode() -> int:
    # Do not repeat disk IO inside flight telemetry or physics.
    if _cached_mode>=0:
        return _cached_mode
    var cfg:=ConfigFile.new()
    _cached_mode=MODE_NORMAL
    if cfg.load(SETTINGS_PATH)==OK:
        _cached_mode=clampi(int(cfg.get_value("diagnosis","mode",MODE_NORMAL)),0,3)
    return _cached_mode

static func save_mode(value: int) -> Error:
    var selected: int=clampi(value,0,3)
    var cfg:=ConfigFile.new()
    cfg.set_value("diagnosis","mode",selected)
    var result: Error=cfg.save(SETTINGS_PATH)
    if result==OK:
        _cached_mode=selected
    return result

static func label_for(value: int) -> String:
    match clampi(value,0,3):
        MODE_NO_SKELETAL_CANOPY:
            return "1 / SIN ANIMACION PARACAIDAS"
        MODE_NO_CANOPY_MESH:
            return "2 / SIN MALLA PARACAIDAS"
        MODE_MINIMAL_VISUALS:
            return "3 / SIN AMBAS (DIAGNOSTICO)"
        _:
            return "0 / NORMAL (COMPLETO)"

static func skip_canopy_animation(value: int) -> bool:
    return value==MODE_NO_SKELETAL_CANOPY or value==MODE_MINIMAL_VISUALS

static func skip_canopy_mesh(value: int) -> bool:
    return value==MODE_NO_CANOPY_MESH or value==MODE_MINIMAL_VISUALS
