extends Control
## Tactical reticle overlay. Drawn dynamically for free TPS / AR optics / AWM.
## UI rendering only: raycast is driven by the same camera optical axis.
var zoom: float = 1.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()


func set_zoom(value: float) -> void:
    zoom = maxf(1.0,value)
    queue_redraw()


func _draw() -> void:
    var center: Vector2 = size * .5
    var thin: Color = Color(.85,.98,1.0,.92)
    if zoom >= 6.0:
        var radius: float = minf(size.y*.34,230.0)
        # Peripheral framing deliberately avoids a solid black opaque layer.
        draw_arc(center,radius,0.0,TAU,100,Color(.08,.12,.15,.94),8.0,true)
        draw_arc(center,radius-5.0,0.0,TAU,100,Color(.79,.91,.95,.9),1.7,true)
        draw_line(center+Vector2(-radius,0),center+Vector2(radius,0),thin,1.5)
        draw_line(center+Vector2(0,-radius),center+Vector2(0,radius),thin,1.5)
        for i in range(-4,5):
            if i!=0:
                var offset: float=float(i)*21.0
                draw_line(center+Vector2(-7,offset),center+Vector2(7,offset),thin,1.4)
        draw_circle(center,3.0,Color(.98,.36,.30,.90))
    elif zoom >= 1.8:
        var spacing: float = 14.0 if zoom>=3.8 else 20.0
        for sign in [-1.0,1.0]:
            draw_line(center+Vector2(sign*spacing,0),center+Vector2(sign*(spacing+25),0),thin,2.0)
            draw_line(center+Vector2(0,sign*spacing),center+Vector2(0,sign*(spacing+18)),thin,1.5)
        draw_circle(center,2.4,Color(.98,.36,.30))
    else:
        for sign in [-1.0,1.0]:
            draw_line(center+Vector2(sign*11,0),center+Vector2(sign*19,0),thin,2.0)
            draw_line(center+Vector2(0,sign*11),center+Vector2(0,sign*18),thin,2.0)
        draw_circle(center,2.0,Color(.94,.82,.60))
