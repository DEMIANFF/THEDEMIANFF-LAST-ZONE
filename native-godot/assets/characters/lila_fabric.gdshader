shader_type spatial;
render_mode cull_disabled;

uniform sampler2D source_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 fabric_shadow : source_color;
uniform vec4 fabric_mid : source_color;
uniform vec4 fabric_light : source_color;
uniform float source_roughness = 0.74;

void fragment() {
    vec3 original = texture(source_albedo, UV).rgb;
    float value = dot(original, vec3(0.2126, 0.7152, 0.0722));
    vec3 dyed = mix(fabric_shadow.rgb, fabric_mid.rgb, smoothstep(0.015, 0.27, value));
    dyed = mix(dyed, fabric_light.rgb, smoothstep(0.25, 0.9, value));
    // Preserve warm skin texels even where the clothing mask crosses bare skin.
    float skin = smoothstep(0.025, 0.12, original.r - original.b)
        * smoothstep(0.10, 0.28, original.r);
    ALBEDO = mix(original, dyed, UV2.x * (1.0 - skin) * 0.83);
    ROUGHNESS = source_roughness;
}
