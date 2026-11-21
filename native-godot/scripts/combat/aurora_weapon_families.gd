extends RefCounted
## V75.129 - Weapon navigation for the REAL Aurora combat catalog.
## Values are filters only. Persistent weapon slots in aurora_weapon_catalog.gd
## must not change: inventories, saves and training use those original IDs.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")

const ALL: int=0
const ASSAULT: int=1
const MARKSMAN: int=2
const SMG: int=3
const SHOTGUN: int=4
const SNIPER: int=5
const PISTOL: int=6
const MELEE: int=7

const LABELS: Array[String]=[
    "TODAS","FUSILES DE ASALTO","DMR / TIRADOR","SUBFUSILES",
    "ESCOPETAS","FRANCOTIRADORES","PISTOLAS","CUERPO A CUERPO"]

# Every entry corresponds exactly to an existing catalog slot, not an
# independently ordered gallery or a simulated weapon/skin entitlement.
const FAMILIES_BY_SLOT: Array[int]=[
    ASSAULT,  # 0 AR-7
    SNIPER,   # 1 AWM
    ASSAULT,  # 2 SCAR
    SMG,      # 3 MP40
    SMG,      # 4 KRISS
    ASSAULT,  # 5 HK416 (requires licensed pack)
    SMG,      # 6 P90 (requires licensed pack)
    MARKSMAN, # 7 VSS (requires licensed pack)
    SMG,      # 8 MP5 (requires licensed pack)
    SHOTGUN,  # 9 escopeta (requires licensed pack)
    PISTOL,   # 10 Magnum (requires licensed pack)
    MELEE,    # 11 cuchillo (requires licensed pack)
    SNIPER    # 12 sniper (requires licensed pack)
]


static func family_for_slot(slot: int) -> int:
    if slot<0 or slot>=FAMILIES_BY_SLOT.size():
        return -1
    return FAMILIES_BY_SLOT[slot]


static func slots_for_family(family: int) -> Array[int]:
    var result: Array[int]=[]
    if family<ALL or family>=LABELS.size():
        return result
    for slot in range(CATALOG.ENTRIES.size()):
        if family==ALL or family_for_slot(slot)==family:
            result.append(slot)
    return result


static func selected_slot_for_family(family: int,previous_slot: int) -> int:
    # Keep the active weapon when selecting a family that contains it.
    # Never substitute filtered list row numbers for persistent save slots.
    var slots: Array[int]=slots_for_family(family)
    if previous_slot in slots:
        return previous_slot
    return slots[0] if not slots.is_empty() else -1


static func family_title(slot: int) -> String:
    var family: int=family_for_slot(slot)
    return LABELS[family] if family>=0 else "SIN CATEGORÍA"
