extends Control
## Original lightweight Aurora coast backdrop for lobby/welcome.
## Procedural CanvasItem artwork; no copied game images or false online indicators.

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)


func _draw() -> void:
    var w: float=size.x
    var h: float=size.y
    if w<=0 or h<=0:
        return
    for band in range(24):
        var fraction: float=float(band)/24.0
        var shade: Color=Color(.015,.045,.11).lerp(Color(.065,.27,.38),fraction)
        draw_rect(Rect2(0,h*fraction,w,h/24.0+2),shade)
    draw_circle(Vector2(w*.75,h*.29),h*.12,Color(.17,.63,.87,.12))
    draw_circle(Vector2(w*.75,h*.29),h*.08,Color(.43,.90,1,.14))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0,h*.64),Vector2(w*.14,h*.35),Vector2(w*.28,h*.63),
        Vector2(w*.46,h*.24),Vector2(w*.68,h*.66),
        Vector2(w*.81,h*.34),Vector2(w,h*.67),Vector2(w,h)]),Color(.06,.20,.31,.81))
    draw_colored_polygon(PackedVector2Array([
        Vector2(w*.14,h*.35),Vector2(w*.19,h*.45),Vector2(w*.12,h*.48),
        Vector2(w*.46,h*.24),Vector2(w*.54,h*.38),Vector2(w*.43,h*.34),
        Vector2(w*.81,h*.34),Vector2(w*.84,h*.42),Vector2(w*.78,h*.41)]),Color(.39,.68,.75,.29))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0,h*.72),Vector2(w*.19,h*.67),Vector2(w*.36,h*.72),
        Vector2(w*.58,h*.65),Vector2(w*.77,h*.75),Vector2(w,h*.68),
        Vector2(w,h),Vector2(0,h)]),Color(.018,.085,.14,.94))
    var shore_y: float=h*.76
    draw_line(Vector2(0,shore_y),Vector2(w,shore_y+h*.04),Color(.12,.78,.91,.32),2)
    _building(w*.10,h*.60,w*.115,h*.19,Color(.12,.23,.29))
    _building(w*.215,h*.54,w*.085,h*.25,Color(.12,.20,.30))
    _building(w*.58,h*.54,w*.088,h*.24,Color(.14,.24,.31))
    _building(w*.72,h*.59,w*.13,h*.19,Color(.10,.22,.30))
    for i in range(14):
        var x: float=w*(.04+float(i)*.071)
        var y: float=h*(.83+sin(float(i)*1.4)*.025)
        draw_line(Vector2(x,y),Vector2(x+12,y-24),Color(.21,.49,.57,.55),2)
        draw_circle(Vector2(x+12,y-25),5,Color(.17,.60,.65,.48))
    draw_line(Vector2(w*.028,h*.91),Vector2(w*.95,h*.91),Color(.14,.73,.91,.34),2.0)


func _building(x: float,y: float,w: float,h: float,wall: Color) -> void:
    draw_rect(Rect2(x,y,w,h),wall)
    draw_rect(Rect2(x-w*.04,y-h*.055,w*1.08,h*.07),wall.lightened(.30))
    draw_rect(Rect2(x+w*.41,y+h*.52,w*.18,h*.48),Color(.012,.06,.09))
    for c in [0.16,0.69]:
        draw_rect(Rect2(x+w*c,y+h*.20,w*.13,h*.17),Color(.09,.58,.66,.62))
    draw_rect(Rect2(x+w*.04,y+h*.45,w*.9,h*.022),Color(.36,.66,.71,.35))
