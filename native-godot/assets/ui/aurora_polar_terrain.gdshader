shader_type spatial;

uniform vec4 shale : source_color = vec4(0.135, 0.184, 0.255, 1.0);
uniform vec4 slate : source_color = vec4(0.28, 0.36, 0.46, 1.0);
uniform vec4 snow_blue : source_color = vec4(0.49, 0.61, 0.74, 1.0);
uniform vec4 snow_lit : source_color = vec4(0.72, 0.79, 0.86, 1.0);

varying vec3 surface_position;
varying vec3 surface_normal;

void vertex() {
    surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    surface_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
    vec3 pos = surface_position;
    float up = max(0.0, normalize(surface_normal).y);
    float layers = 0.5 + 0.5 * sin(pos.y * 5.1 + pos.x * 0.89 + pos.z * 0.48
        + sin(pos.x * 2.6 + pos.z * 1.9) * 1.1);
    float gully = 0.5 + 0.5 * sin(pos.x * 2.7 - pos.z * 0.98 + sin(pos.z * 1.4));
    float coverage = smoothstep(0.42, 0.83, up * 0.62 + COLOR.r * 0.48
        + gully * 0.24 - layers * 0.13);
    vec3 rock = mix(shale.rgb, slate.rgb, layers * 0.45 + gully * 0.28);
    vec3 frost = mix(snow_blue.rgb, snow_lit.rgb, up * 0.51 + layers * 0.20);
    ALBEDO = mix(rock, frost, coverage);
    ROUGHNESS = mix(0.92, 0.81, coverage);
    METALLIC = 0.0;
}
