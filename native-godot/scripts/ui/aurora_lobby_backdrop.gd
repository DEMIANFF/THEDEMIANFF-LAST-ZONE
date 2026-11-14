extends Control
## Original Base Aurora winter vista behind native interactive lobby.
## Efficient CanvasItem geometry: no copied gameplay screenshots, third-party
## branding, external network textures or persistent GPU allocations.
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)


func _draw() -> void:
    var w: float=size.x
    var h: float=size.y
    if w<2 or h<2:
        return
    for band in range(38):
        var t: float=float(band)/37.0
        var tint: Color=Color(.016,.013,.065).lerp(Color(.12,.13,.30),t)
        draw_rect(Rect2(0,h*t,w,h/37.0+2),tint)
    # Aurora curtains are layered translucent original curves rather than
    # single solid bars: teal and magenta hues frame Lila without covering UI.
    for layer in range(4):
        var phase: float=float(layer)*1.6
        var hue: Color=Color(.12,.92,.86,.14) if layer%2==0 else Color(.76,.23,.99,.14)
        for row in range(3):
            var last:=Vector2(0,h*(.16+float(row)*.028))
            for step in range(1,50):
                var x: float=float(step)*w/49.0
                var y: float=h*(.12+float(layer)*.07+float(row)*.028)+(
                    sin(float(step)*.155+phase)*h*.062)
                var next:=Vector2(x,y)
                draw_line(last,next,hue,3.0+float(row)*2.0,true)
                last=next
    # Fixed low-cost stars, deterministic per device frame / resolution.
    for i in range(110):
        var ix: float=float((i*37+13)%109)/109.0
        var iy: float=float((i*59+23)%113)/113.0
        if iy>.67:
            continue
        var radius: float=1.0 if i%5 else 2.0
        draw_circle(Vector2(w*ix,h*iy),radius,
            Color(.77,.84,1,.30+.30*float(i%3)/2.0))
    for peak in [
        Vector3(.06,.80,.28),Vector3(.23,.80,.34),
        Vector3(.46,.82,.30),Vector3(.69,.82,.32),
        Vector3(.85,.81,.27)
    ]:
        var cx: float=peak.x
        var span: float=peak.z
        var tip: float=peak.y-span
        draw_colored_polygon(PackedVector2Array([
            Vector2(w*(cx-span),h*.80),Vector2(w*cx,h*tip),
            Vector2(w*(cx+span),h*.80)
        ]),Color(.07,.105,.23,.94))
        draw_colored_polygon(PackedVector2Array([
            Vector2(w*(cx-span*.17),h*(tip+span*.21)),
            Vector2(w*cx,h*tip),
            Vector2(w*(cx+span*.17),h*(tip+span*.21))
        ]),Color(.72,.81,.96,.70))
    _building(w*.05,h*.53,w*.18,h*.25)
    _building(w*.21,h*.59,w*.12,h*.20)
    _building(w*.61,h*.58,w*.12,h*.22)
    _building(w*.77,h*.51,w*.18,h*.28)
    # Tower beacons and purple vertical banners.
    for x_ratio in [.15,.815]:
        var x: float=w*x_ratio
        draw_rect(Rect2(x,h*.37,w*.028,h*.43),Color(.045,.075,.14))
        draw_rect(Rect2(x+w*.007,h*.43,w*.014,h*.21),Color(.47,.14,.74,.80))
        draw_line(Vector2(x,h*.38),Vector2(x+w*.07,h*.38),Color(.18,.83,1,.65),2)
        draw_circle(Vector2(x+w*.014,h*.36),h*.007,Color(1,.18,.54))
    draw_rect(Rect2(0,h*.78,w,h*.22),Color(.035,.075,.14,.90))
    for strip in range(17):
        var yy: float=h*(.79+float(strip)*.014)
        draw_line(Vector2(0,yy),Vector2(w,yy),
            Color(.55,.29,.93,.15*(1.0-float(strip)/20.0)),1)
    for step in range(24):
        var xx: float=w*float(step)/23.0
        draw_line(Vector2(xx,h*.79),Vector2(w*.5+(xx-w*.5)*1.24,h),
            Color(.25,.63,.91,.10),1)
    # Ice and faint snow. Foreground reflections stay below play controls.
    for i in range(52):
        var xx: float=w*float((i*47+9)%101)/100.0
        var yy: float=h*(.78+.20*float((i*17+3)%47)/47.0)
        draw_circle(Vector2(xx,yy),float(i%3)+.5,Color(.84,.91,1,.26))


func _building(x: float,y: float,wide: float,tall: float) -> void:
    draw_rect(Rect2(x,y,wide,tall),Color(.055,.086,.16,.96))
    draw_rect(Rect2(x-wide*.04,y-tall*.07,wide*1.08,tall*.09),
        Color(.17,.22,.36))
    draw_line(Vector2(x,y+tall*.29),Vector2(x+wide,y+tall*.29),
        Color(.54,.28,.92,.75),2)
    draw_rect(Rect2(x+wide*.40,y+tall*.49,wide*.22,tall*.51),
        Color(.027,.04,.09))
    for col in range(3):
        var xx: float=x+wide*(.11+float(col)*.30)
        draw_rect(Rect2(xx,y+tall*.40,wide*.12,tall*.15),
            Color(.17,.74,.94,.77))
        draw_line(Vector2(xx,y+tall*.57),Vector2(xx+wide*.12,y+tall*.57),
            Color(.82,.37,1,.6),2)
