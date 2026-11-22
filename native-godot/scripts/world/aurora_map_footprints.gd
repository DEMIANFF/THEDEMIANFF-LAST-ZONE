extends RefCounted
## V75.160 authoritative two-dimensional geometry shared by the ACTUAL
## Puerto Aurora 3D world builders and both in-game maps. No external
## battle-royale art, decorative fake roads, or duplicated POI placement.
## Coordinates are world X/Z metres; dimensions are physical ground plans.
const DISTRICT_BUILDINGS: Array[Dictionary]=[
    {"at":Vector2(18.0,-8.0),"name":"CENTRO DE EXPLORACION",
        "size":Vector2(16.0,12.0),"height":6.4,"heavy":false},
    {"at":Vector2(-19.0,-29.0),"name":"TALLER HELIOS",
        "size":Vector2(14.0,11.0),"height":5.8,"heavy":true},
    {"at":Vector2(46.0,-36.0),"name":"ESTACION METEOROLOGICA",
        "size":Vector2(11.0,10.0),"height":5.4,"heavy":false},
    {"at":Vector2(-48.0,22.0),"name":"PUESTO VORTEX",
        "size":Vector2(12.0,12.0),"height":6.0,"heavy":true}
]
const DISTRICT_ROADS: Array[Dictionary]=[
    {"from":Vector2(0,4),"to":Vector2(18,-8),"width":4.8},
    {"from":Vector2(18,-8),"to":Vector2(-19,-29),"width":3.6},
    {"from":Vector2(18,-8),"to":Vector2(46,-36),"width":3.5},
    {"from":Vector2(-19,-29),"to":Vector2(-48,22),"width":3.0}
]
const COASTAL_PLAZAS: Array[Dictionary]=[
    {"center":Vector2(20,28),"size":Vector2(64,25)},
    {"center":Vector2(2,60),"size":Vector2(65,12)},
    {"center":Vector2(-31,31),"size":Vector2(48,11)}
]
const FREIGHT_CACHES: Array[Vector2]=[Vector2(13,13),Vector2(38,12)]
const COVER_BLOCKS: Array[Vector2]=[
    Vector2(4,-24),Vector2(32,-22),Vector2(-32,-8),
    Vector2(-8,-48),Vector2(40,8),Vector2(-35,35)
]

## Surface categories are semantic only; radar and tactical map consume
## the identical rendered image while the 3D scene remains authoritative.
static func physical_building_count() -> int:
    return DISTRICT_BUILDINGS.size()
