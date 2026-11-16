shader_type spatial;

varying vec2 ground_position;

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
    float dampness = surface_noise(ground_position * vec2(0.91, 0.48));
    float grain = surface_noise(ground_position * 15.0);
    float grain_weight = 1.0 - smoothstep(0.018, 0.08, length(fwidth(ground_position)));
    float variation = dampness * 0.22 + (grain - 0.5) * grain_weight * 0.14;
    ALBEDO = mix(vec3(0.062, 0.087, 0.128), vec3(0.22, 0.28, 0.36), variation);
    ROUGHNESS = mix(0.91, 0.58, dampness);
    METALLIC = 0.06;
}
