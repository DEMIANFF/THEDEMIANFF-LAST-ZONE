shader_type sky;

uniform vec4 zenith : source_color = vec4(0.035, 0.057, 0.14, 1.0);
uniform vec4 horizon : source_color = vec4(0.31, 0.43, 0.60, 1.0);

float random_cell(vec2 cell) {
    return fract(sin(dot(cell, vec2(73.83, 91.27))) * 43758.5453);
}

void sky() {
    float elevation = clamp(EYEDIR.y, 0.0, 1.0);
    vec3 air = mix(horizon.rgb, zenith.rgb, pow(elevation, 0.46));
    float afterglow = pow(max(0.0, dot(EYEDIR, normalize(vec3(-0.8, 0.05, -1.0)))), 7.0);
    air += vec3(0.027, 0.008, 0.029) * afterglow * (1.0 - elevation);
    if (!AT_CUBEMAP_PASS) {
        vec2 sky_cell = SKY_COORDS * vec2(570.0, 240.0);
        float spark = step(0.993, random_cell(floor(sky_cell)));
        float star = 1.0 - smoothstep(0.024, 0.13, length(fract(sky_cell) - 0.5));
        air += vec3(0.37, 0.49, 0.62) * spark * star * smoothstep(0.14, 0.51, elevation);
    }
    COLOR = air;
}
