extends RefCounted
## A/B field diagnosis of the physical Android parachute exit.
## The canopy physics, terrain collisions and HUD are ALWAYS real.
## These toggles only affect optional visual subsystems while testing.
const SETTINGS_PATH: String="user://aurora_flight_safety.cfg"
const MODE_NORMAL: int=0
const MODE_NO_SKELETAL_CANOPY: int=1
const MODE_NO_CANOPY_MESH: int=2
const MODE_MINIMAL_VISUALS: int=3

static func current_mode() -> int:
    var cfg:=ConfigFile.new()
    if cfg.load(SETTINGS_PATH)!=OK:
        return MODE_NORMAL
    return clampi(int(cfg.get_value("diagnosis","mode",MODE_NORMAL)),0,3)

static func save_mode(value: int) -> Error:
    var cfg:=ConfigFile.new()
    cfg.set_value("diagnosis","mode",clampi(value,0,3))
    return cfg.save(SETTINGS_PATH)

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
