extends RefCounted
## A/B diagnosis for exits common to Training and Battle Royale on Android.
## Visual-only isolation: real player controls, collision, terrain and bots stay.
const PATH: String="user://aurora_scene_startup_diagnostic.cfg"
const FULL: int=0
const NO_DECORATIVE_WORLD: int=1
const NO_ENEMY_SKINNED_RIGS: int=2
const MINIMAL_VISUAL_LOAD: int=3
static var _cached: int=-1

static func mode() -> int:
    if _cached>=0:
        return _cached
    var config:=ConfigFile.new()
    _cached=FULL
    if config.load(PATH)==OK:
        _cached=clampi(int(config.get_value("startup","mode",0)),0,3)
    return _cached

static func save(value: int) -> Error:
    var next: int=clampi(value,0,3)
    var cfg:=ConfigFile.new()
    cfg.set_value("startup","mode",next)
    var result: Error=cfg.save(PATH)
    if result==OK:
        _cached=next
    return result

static func without_decorations() -> bool:
    return mode()==NO_DECORATIVE_WORLD or mode()==MINIMAL_VISUAL_LOAD

static func without_enemy_rigs() -> bool:
    return mode()==NO_ENEMY_SKINNED_RIGS or mode()==MINIMAL_VISUAL_LOAD

static func label() -> String:
    match mode():
        NO_DECORATIVE_WORLD:
            return "1 / SIN ESCENOGRAFÍA DECORATIVA"
        NO_ENEMY_SKINNED_RIGS:
            return "2 / SIN MODELOS 3D DE ENEMIGOS"
        MINIMAL_VISUAL_LOAD:
            return "3 / AMBAS OPCIONES (DIAGNÓSTICO)"
        _:
            return "0 / ESCENARIO COMPLETO"
