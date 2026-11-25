extends Control
## Original vector pictograms. Pure presentation: the existing Button owns
## input, state, text contract, signals and persisted HUD identity.
static var _textures: Dictionary={}
const ART: Dictionary={
    "rifle": '<path d="M4 24h13l8-5h23v5h13v6H38l-4 16H23l6-16H17L4 36z" fill="white" stroke="none"/><path d="M30 19v-6h13v6"/>',
    "sniper": '<path d="M3 28h14l9-6h21v4h15v5H35l-5 14h-8l4-14H16L3 38z" fill="white" stroke="none"/><path d="M26 17h18m-14 5v-5m10 5v-5"/>',
    "pistol": '<path d="M9 18h43v15H30l-5 22H13l4-23H9z" fill="white" stroke="none"/><path d="M35 33v7H24"/>',
    "knife": '<path d="M50 5 58 8 39 37 27 40 23 36zM21 35l13 13M24 42 8 58l-5-5 16-16" fill="white"/>',
    "fire": '<path d="M13 48 33 28 45 40 25 60 10 62z M36 25 47 14 58 25 48 37z M48 11 61 3 58 22z" fill="white" stroke="none"/><path d="m6 39 10-4m8-18 4-10m33 35-10 3" />',
    "aim": '<circle cx="32" cy="32" r="19"/><path d="M32 4v16m0 24v16M4 32h16m24 0h16"/><circle cx="32" cy="32" r="3" fill="white"/>',
    "reload": '<path d="M49 18A21 21 0 1 0 52 43M49 8v14H35"/><rect x="27" y="24" width="11" height="24" rx="3" fill="white" stroke="none"/><path d="M32 15v8"/>',
    "swap": '<path d="M8 19h45l-9-9M56 45H11l9 9M44 28l9-9M20 36l-9 9"/><path d="M19 28h24v8H19z" fill="white" stroke="none"/>',
    "run": '<circle cx="40" cy="9" r="6" fill="white" stroke="none"/><path d="m35 19-10 16 15 8-9 16M25 35 12 50 4 50M35 19l14 13 10-8M33 20l-14 2-8 11" stroke-width="7"/>',
    "jump": '<circle cx="32" cy="9" r="6" fill="white" stroke="none"/><path d="M32 20v17m0-15L14 12m18 10 18-10M32 37l-13 13 7 10m6-23 14 11-7 12" stroke-width="7"/>',
    "crouch": '<circle cx="40" cy="15" r="6" fill="white" stroke="none"/><path d="m35 25-15 11 18 4 13 15H30m-10-19-8 17H4m31-28 13 9 12-5" stroke-width="7"/>',
    "heal": '<rect x="9" y="18" width="46" height="35" rx="7"/><path d="M23 18v-7h18v7M32 26v19M23 35h18" stroke-width="6"/>',
    "cover": '<path d="M8 16 32 7l24 9v20c0 11-10 19-24 24C18 55 8 47 8 36z"/><path d="M15 25h34M15 38h34M24 25v13m16 0v12"/>',
    "grenade": '<rect x="25" y="8" width="15" height="12" rx="2"/><path d="M39 10h12v17M23 18c-7 6-12 15-12 25a21 17 0 0 0 42 0c0-10-5-19-12-25z"/><path d="M14 35h36M12 46h40M26 22l-4 32m16-32 4 32"/><circle cx="48" cy="9" r="4"/>',
    "bag": '<path d="M23 13V8h18v5M12 25a12 12 0 0 1 12-12h16a12 12 0 0 1 12 12v30H12z"/><rect x="20" y="32" width="24" height="17" rx="4"/><path d="M20 21h24"/>',
    "settings": '<path d="m27 5 10 0 2 8 8 4 8-3 5 9-6 6v8l6 5-5 9-8-3-8 4-2 8H27l-2-8-8-4-8 3-5-9 6-5v-8l-6-6 5-9 8 3 8-4z"/><circle cx="32" cy="32" r="9"/>',
    "exit": '<path d="M28 10H9v44h19M23 32h34m-13-13 13 13-13 13"/>',
    "vehicle": '<path d="m12 27 7-14h26l7 14 5 6v18H7V33zM12 27h40M15 37h7m20 0h7M13 51v6m38-6v6"/>',
    "use": '<path d="M19 32V16a4 4 0 0 1 8 0v13-20a4 4 0 0 1 8 0v20-13a4 4 0 0 1 8 0v17-7a4 4 0 0 1 8 0v17c0 11-8 17-19 17-10 0-15-8-20-17l-5-9a4 4 0 0 1 7-4l5 5"/>',
    "parachute": '<path d="M5 29a27 23 0 0 1 54 0H5zm0 0 23 26m31-26L36 55M22 29l10 26 10-26M32 55v5"/>'
}
const IDS: Dictionary={
    "MIRA":"aim","RECARGA":"reload","ARMA":"swap","CORRER":"run",
    "SALTAR":"jump","AGACHAR":"crouch","CURAR 2":"heal",
    "BARRERA 0":"cover","GRANADA":"grenade","MOCHILA":"bag",
    "AJUSTES":"settings","LOBBY":"exit","CONDUCIR":"vehicle",
    "ABRIR DEPÓSITO":"use"
}
var action: String=""
var _last_state: String=""
var _owner_button: Button

static func texture_for(key: String) -> Texture2D:
    if not ART.has(key):
        return null
    if not _textures.has(key):
        var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><g fill="none" stroke="white" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round">'+str(ART[key])+'</g></svg>'
        var img:=Image.new()
        if img.load_svg_from_string(svg)!=OK:
            return null
        _textures[key]=ImageTexture.create_from_image(img)
    return _textures[key] as Texture2D

func _ready() -> void:
    _owner_button=get_parent() as Button
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    queue_redraw()

func _process(_delta: float) -> void:
    if not is_instance_valid(_owner_button):
        return
    var state: String="%s:%s:%s:%s"%[
        _owner_button.text,_owner_button.disabled,_owner_button.button_pressed,
        _owner_button.get_meta("hud_cooldown",0)]
    if state!=_last_state:
        _last_state=state
        queue_redraw()

func _draw() -> void:
    if not is_instance_valid(_owner_button):
        return
    var caption: String=_owner_button.text
    var blocked: bool=_owner_button.disabled
    var active: bool=_owner_button.button_pressed or caption in ["CORRIENDO","LEVANTAR","CANCELAR","BAJAR","2X","4X","8X"]
    var center: Vector2=size*.5
    var radius: float=maxf(1.0,minf(size.x,size.y)*.5-3.0)
    var air: bool=action=="jump" and caption!="SALTAR"
    var key: String="parachute" if air else action
    var texture: Texture2D=texture_for(key)
    var tint: Color=Color(.70,.77,.80,.72) if blocked else Color(.96,.99,1.0,.98)
    draw_circle(center,radius,Color(.025,.045,.065,.46 if not active else .72))
    draw_arc(center,radius,0,TAU,48,Color(.80,.91,.97,.34 if blocked else .72),1.5,true)
    if active:
        draw_arc(center,radius-3.0,0,TAU,48,Color(.32,.87,1.0,.95),2.0,true)
    var side: float=radius*1.20
    if texture!=null:
        draw_texture_rect(texture,Rect2(center-Vector2.ONE*side*.5,Vector2.ONE*side),false,tint)
    var badge: String=""
    if action in ["heal","cover","grenade","bag","reload"]:
        var tail: String=caption.replace("\n"," ").get_slice(" ",caption.replace("\n"," ").get_slice_count(" ")-1)
        if tail.begins_with("N"):
            tail=tail.substr(1)
        if tail.is_valid_int():
            badge=tail
    if action=="aim" and caption.ends_with("X"):
        badge=caption
    if action=="heal" and caption=="CANCELAR":
        badge="×"
    var cd: float=float(_owner_button.get_meta("hud_cooldown",0.0))
    if cd>0.0:
        draw_arc(center,radius-4.0,-PI*.5,-PI*.5+TAU*clampf(cd/3.0,0.0,1.0),32,Color(1,.73,.31,.95),3.0,true)
        badge=str(ceili(cd))+"s"
    if not badge.is_empty():
        var font: Font=ThemeDB.fallback_font
        var fs: int=clampi(roundi(radius*.43),11,23)
        var tw: float=font.get_string_size(badge,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
        var pos: Vector2=center+Vector2(radius*.44,radius*.48)
        draw_circle(pos+Vector2(0,1),maxf(fs*.64,tw*.55+3),Color(.02,.06,.09,.92))
        draw_string(font,pos+Vector2(-tw*.5,fs*.32),badge,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(1,1,1))
    if air:
        var font: Font=ThemeDB.fallback_font
        var fs: int=12
        draw_string(font,Vector2(center.x-radius*.65,center.y+radius*.82), "SALTAR" if caption.begins_with("SALTAR") else "ABRIR",HORIZONTAL_ALIGNMENT_LEFT,-1,fs,tint)
