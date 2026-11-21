extends RefCounted
## Original Aurora inventory navigation, not an independent source of loot.
## Indices 0..4 are the existing inventory-control IDs and must remain stable.
const ALL: int=0
const PROTECTION: int=1
const SUPPLIES: int=2
const THROWABLES: int=3

const LABELS: Array[String]=[
    "TODOS","PROTECCIÓN","SUMINISTROS","ARROJADIZOS"]
const ITEM_NAMES: Array[String]=[
    "MOCHILA","CASCO","CHALECO","BOTIQUÍN","GRANADA"]
const CATEGORY_BY_SLOT: Array[int]=[
    PROTECTION,PROTECTION,PROTECTION,SUPPLIES,THROWABLES]
const DESCRIPTIONS: Array[String]=[
    "MOCHILA · niveles 1–3. Amplía la capacidad de carga durante las partidas.",
    "CASCO · niveles 1–3. Protege al encontrarlo y equiparlo en el Battle Royale.",
    "CHALECO · niveles 1–3. Protección contra daño; se recoge en el mapa.",
    "BOTIQUÍN · consumible de curación recogido durante la partida.",
    "GRANADA · consumible arrojadizo: se obtiene y utiliza en combate."
]


static func slots_for_category(category: int) -> Array[int]:
    var slots: Array[int]=[]
    if category<ALL or category>=LABELS.size():
        return slots
    for slot in range(ITEM_NAMES.size()):
        if category==ALL or CATEGORY_BY_SLOT[slot]==category:
            slots.append(slot)
    return slots


static func select_slot(category: int,previous_slot: int) -> int:
    var slots: Array[int]=slots_for_category(category)
    if previous_slot in slots:
        return previous_slot
    return slots[0] if not slots.is_empty() else -1


static func family_for_slot(slot: int) -> String:
    if slot<0 or slot>=CATEGORY_BY_SLOT.size():
        return "NO DISPONIBLE"
    return LABELS[CATEGORY_BY_SLOT[slot]]
