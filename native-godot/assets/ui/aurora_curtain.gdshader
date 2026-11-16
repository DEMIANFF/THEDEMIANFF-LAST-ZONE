shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;

uniform float strength = 0.7;
uniform float fold_offset = 0.0;
uniform vec4 cyan : source_color = vec4(0.14, 0.82, 0.64, 1.0);
uniform vec4 violet : source_color = vec4(0.44, 0.34, 0.81, 1.0);

void fragment() {
    float crest = smoothstep(0.0, 0.16, UV.y) * pow(1.0 - UV.y, 2.45);
    float side = smoothstep(0.0, 0.18, UV.x) * (1.0 - smoothstep(0.81, 1.0, UV.x));
    float fold = 0.54 + 0.43 * sin(46.0 * UV.x + 3.1 * sin(UV.x * 17.0) + fold_offset);
    float filaments = 0.67 + 0.19 * sin(UV.x * 283.0 + UV.y * 3.3 + TIME * 0.31);
    float drift = 0.83 + 0.17 * sin(UV.x * 35.0 + fold_offset - TIME * 0.32);
    ALBEDO = mix(cyan.rgb, violet.rgb, smoothstep(0.18, 0.72, UV.y));
    ALPHA = crest * side * fold * filaments * drift * strength;
}
