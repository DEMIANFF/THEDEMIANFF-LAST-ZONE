shader_type sky;

// Aurora native stage, physically based color values and low-cost
// curved-light model. Not a pre-rendered still or third-party sky.
uniform vec4 zenith : source_color = vec4(0.012, 0.026, 0.085, 1.0);
uniform vec4 horizon : source_color = vec4(0.17, 0.27, 0.43, 1.0);
uniform vec4 polar_cyan : source_color = vec4(0.025, 0.43, 0.37, 1.0);
uniform vec4 polar_violet : source_color = vec4(0.19, 0.075, 0.31, 1.0);

float aurora_star_hash(vec2 cell) {
    return fract(sin(dot(cell, vec2(73.83, 91.27))) * 43758.5453);
}

void sky() {
    float elevation = clamp(EYEDIR.y, 0.0, 1.0);
    float zenith_mix = pow(elevation, 0.63);
    vec3 air = mix(horizon.rgb, zenith.rgb, zenith_mix);
    // Lower horizon retains depth separation from snow and hangars.
    float twilight = pow(max(0.0,
        dot(EYEDIR, normalize(vec3(-0.8, 0.03, -1.0)))), 7.0);
    air += vec3(0.036, 0.014, 0.032) * twilight * (1.0-elevation);

    // Aurora ribbons are evaluated only in the viewport background; sky
    // cubemap updates stay static to avoid per-frame reflection churn.
    if (!AT_CUBEMAP_PASS) {
        float wave = sin(EYEDIR.x * 14.0 + EYEDIR.z * 3.1)
            * 0.045 + sin(EYEDIR.x * 31.0 - EYEDIR.z * 9.0) * 0.021;
        float center = 0.39 + wave;
        float polar_luminance = exp(-pow((elevation-center)*8.0,2.0));
        float fold = 0.64 + 0.36 * sin(EYEDIR.x * 55.0 +
            sin(EYEDIR.z * 11.0) * 2.5);
        float tint = smoothstep(-0.6, 0.65, EYEDIR.x +
            0.25 * sin(EYEDIR.z * 5.0));
        vec3 curtain = mix(polar_cyan.rgb,polar_violet.rgb,tint);
        air += curtain * polar_luminance * fold * 0.45;

        vec2 sky_cell = SKY_COORDS * vec2(570.0, 240.0);
        float spark = step(0.995, aurora_star_hash(floor(sky_cell)));
        float star = 1.0 - smoothstep(0.024, 0.13,
            length(fract(sky_cell)-0.5));
        air += vec3(0.48, 0.57, 0.73) * spark * star *
            smoothstep(0.14, 0.51, elevation);
    }
    COLOR = max(air,vec3(0.0));
}
