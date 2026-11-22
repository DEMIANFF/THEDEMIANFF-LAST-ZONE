shader_type spatial;
render_mode cull_disabled;

uniform sampler2D source_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 fabric_shadow : source_color;
uniform vec4 fabric_mid : source_color;
uniform vec4 fabric_light : source_color;
uniform float source_roughness = 0.74;
uniform float source_metallic = 0.0;
uniform float source_specular = 0.5;

void fragment() {
    vec3 original = texture(source_albedo, UV).rgb;
    float value = dot(original, vec3(0.2126, 0.7152, 0.0722));
    vec3 dyed = mix(fabric_shadow.rgb, fabric_mid.rgb, smoothstep(0.015, 0.27, value));
    dyed = mix(dyed, fabric_light.rgb, smoothstep(0.25, 0.9, value));
    // Preserve warm skin texels even where the clothing mask crosses bare skin.
    float skin = smoothstep(0.025, 0.12, original.r - original.b)
        * smoothstep(0.10, 0.28, original.r);
    // The imported weighted mesh is the authority for original skin and
    // leather. Only the actual garment mask is recoloured; no flat unlit
    // cartoon shading or metallic human skin is introduced.
    float garment = clamp(UV2.x * (1.0 - skin), 0.0, 1.0);
    ALBEDO = mix(original, dyed, garment * 0.83);
    // Real PBR response: matte woven fabric, less rough skin, original
    // source metallic detail on buckles instead of glossy fabric/face.
    ROUGHNESS = clamp(mix(source_roughness, 0.84, garment), 0.42, 0.96);
    METALLIC = clamp(source_metallic * (1.0 - garment), 0.0, 0.85);
    SPECULAR = mix(source_specular, 0.38, garment);
}
