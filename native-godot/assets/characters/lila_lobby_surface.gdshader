shader_type spatial;
render_mode cull_disabled;

uniform sampler2D source_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

void fragment() {
    vec3 source = texture(source_albedo, UV).rgb;
    float warm = source.r - source.b;
    float skin = smoothstep(0.015, 0.11, warm) * smoothstep(0.13, 0.34, source.r);
    float lilac = smoothstep(0.006, 0.070, source.b - source.g)
        * smoothstep(0.03, 0.16, source.r) * (1.0 - skin) * (1.0 - UV2.x * 0.68);
    float jacket = clamp(UV2.x * (1.0 - skin), 0.0, 1.0);
    ALBEDO = source * mix(vec3(0.91, 0.95, 1.0), vec3(0.95, 0.87, 0.86), skin);
    ALBEDO += vec3(0.025, 0.011, 0.039) * lilac;
    ROUGHNESS = mix(mix(0.73, 0.60, skin), 0.42, lilac);
    ROUGHNESS = mix(ROUGHNESS, 0.66, jacket);
    SPECULAR = mix(0.38, 0.25, skin) + lilac * 0.09;
    METALLIC = 0.045 * jacket;
    RIM = 0.23 * lilac;
    RIM_TINT = 0.70;
}
