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
    // Storm-borne mineral staining and panel oxidation are deterministic
    // WORLD-SPACE variations. No texture uploads or extra material passes.
    vec2 weather_cell = floor(world_position.xz * 1.4 +
        vec2(world_position.y * 0.31, world_position.y * 0.17));
    float oxidation = fract(sin(dot(weather_cell, vec2(127.1, 311.7))) * 43758.5453);
    oxidation = smoothstep(0.56, 0.91, oxidation) *
        (1.0 - smoothstep(0.15, 1.40, world_position.y));
    float vertical_streak = 0.5 + 0.5 *
        sin(lateral * 3.7 + sin(world_position.y * 2.1) * 0.24);
    vec3 cold_steel = mix(seam.rgb, steel.rgb,
        (0.37 + rib * 0.52) * weathering + stain * 0.13);
    cold_steel *= 1.0 - oxidation * 0.12 -
        vertical_streak * (1.0 - rib) * 0.045;
    ALBEDO = cold_steel;
    METALLIC = 0.43 - oxidation * 0.08;
    ROUGHNESS = clamp(0.81 - 0.19 * rib + oxidation * 0.12, 0.50, 0.96);
    SPECULAR = 0.32 + 0.11 * rib;
    NORMAL_MAP = vec3(0.5 + 0.063 * sin(pitch * 6.283185),
        0.5 + vertical_streak * 0.013, 1.0);
    NORMAL_MAP_DEPTH = 0.20;
}
