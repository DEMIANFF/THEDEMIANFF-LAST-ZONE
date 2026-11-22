shader_type spatial;

uniform vec4 steel : source_color = vec4(0.24, 0.29, 0.35, 1.0);
uniform vec4 seam : source_color = vec4(0.105, 0.14, 0.19, 1.0);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
    float lateral = mix(world_position.x, world_position.z, abs(normalize(world_normal).x));
    float pitch = lateral * 10.1;
    float rib = 0.5 + 0.5 * cos(pitch * 6.283185);
    rib = mix(rib, 0.5, smoothstep(0.20, 0.85, fwidth(pitch)));
    float stain = 0.5 + 0.23 * sin(lateral * 9.0 + sin(world_position.y * 1.8))
        + 0.12 * cos(lateral * 23.1 - world_position.y * 0.93);
    float weathering = smoothstep(0.0, 0.43, world_position.y);
    ALBEDO = mix(seam.rgb, steel.rgb, (0.38 + rib * 0.56) * weathering + stain * 0.11);
    METALLIC = 0.43;
    ROUGHNESS = 0.78 - 0.22 * rib;
    SPECULAR = 0.35 + 0.12 * rib;
    NORMAL_MAP = vec3(0.5 + 0.07 * sin(pitch * 6.283185), 0.5, 1.0);
    NORMAL_MAP_DEPTH = 0.21;
}
