shader_type spatial;

varying vec2 ground_position;
uniform vec4 asphalt : source_color = vec4(0.15, 0.19, 0.25, 1.0);
uniform vec4 aggregate : source_color = vec4(0.30, 0.35, 0.43, 1.0);
uniform vec4 paint : source_color = vec4(0.70, 0.53, 0.28, 1.0);

float hash_cell(vec2 cell) {
    return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float surface_noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 fraction = fract(point);
    vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
    return mix(mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), blend.x),
        mix(hash_cell(cell + vec2(0.0, 1.0)),
            hash_cell(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void vertex() {
    ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    vec2 p = ground_position;
    float water = smoothstep(0.38, 0.70, surface_noise(p * vec2(0.68, 0.27)));
    float grain = surface_noise(p * 24.0);
    float blur = length(fwidth(p));
    float grit = (grain - 0.5) * (1.0 - smoothstep(0.025, 0.13, blur));
    float salted = smoothstep(0.53, 0.78, surface_noise(p * vec2(2.9, 1.05)));
    float joint = 1.0 - smoothstep(0.008, 0.028 + blur, abs(fract((p.y + 0.8) * 0.43) - 0.5));
    float fine_grit = surface_noise(p * 6.3 + vec2(1.7, 3.1));
    float weather = smoothstep(0.35, 0.75, fine_grit);
    vec3 base = mix(asphalt.rgb, aggregate.rgb,
        clamp(0.24 + grit * 0.22 - water * 0.19 - joint * 0.13 + salted * 0.26 + weather * 0.11, 0.0, 1.0));
    float line = 1.0 - smoothstep(0.025, 0.059 + blur * 0.6, abs(p.x));
    line *= smoothstep(0.23, 0.27, fract((p.y + 1.8) * 0.71));
    line *= (1.0 - smoothstep(0.67, 0.72, fract((p.y + 1.8) * 0.71))) * smoothstep(-18.0, -16.9, p.y);
    float shoulder = 1.0 - smoothstep(0.011, 0.035 + blur * 0.6, abs(abs(p.x) - 1.94));
    ALBEDO = mix(base, paint.rgb, max(line, shoulder * 0.44) * (0.68 + grit * 0.21));
    ROUGHNESS = clamp(mix(0.87, 0.30, water) + grit * 0.045 + weather * 0.035, 0.20, 0.95);
    METALLIC = 0.035;
    SPECULAR = mix(0.33, 0.66, water);
    NORMAL_MAP = vec3(0.5 + grit * 0.13, 0.5 + (salted - water) * 0.044, 1.0);
    NORMAL_MAP_DEPTH = 0.38;
}
