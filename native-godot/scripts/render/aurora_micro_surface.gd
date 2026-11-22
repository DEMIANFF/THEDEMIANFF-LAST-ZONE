extends RefCounted
## Original seamless, deterministic Aurora micro-normal materials.
## Generated once during world assembly: 128x128 RGB8 (~48 KiB raw per map),
## no downloaded game textures, triplanar sampling or frame-time CPU updates.
## World-sized physics terrain and navigation triangles are untouched.
const SIZE: int=128


static func _height(u: float,v: float,water: bool) -> float:
    # Integer-period circular harmonics tile perfectly at the UV seam.
    # Wavelets use different phase offsets, so the ground no longer shows
    # conspicuous regularly spaced sine-grid dimples.
    if water:
        return (
            .58*sin(4.0*u+.73*sin(3.0*v))+
            .28*cos(8.0*v-1.0*sin(2.0*u))+
            .14*sin(13.0*u+11.0*v))
    return (
        .36*sin(4.0*u+2.0*v)+
        .24*cos(9.0*v-3.0*u)+
        .20*sin(11.0*u+5.0*v)+
        .12*cos(17.0*u-13.0*v)+
        .08*sin(23.0*v+19.0*u))


static func normal_image(water: bool) -> Image:
    var image:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGB8)
    var pitch: float=TAU/float(SIZE)
    for py in range(SIZE):
        var v: float=TAU*float(py)/float(SIZE)
        for px in range(SIZE):
            var u: float=TAU*float(px)/float(SIZE)
            var dx: float=(_height(u+pitch,v,water)-
                _height(u-pitch,v,water))*.5
            var dy: float=(_height(u,v+pitch,water)-
                _height(u,v-pitch,water))*.5
            var strength: float=.76 if water else 1.12
            var normal:=Vector3(-dx*strength,-dy*strength,1.0).normalized()
            image.set_pixel(px,py,Color(
                normal.x*.5+.5,normal.y*.5+.5,normal.z*.5+.5))
    image.generate_mipmaps()
    return image


static func texture(water: bool) -> ImageTexture:
    return ImageTexture.create_from_image(normal_image(water))
