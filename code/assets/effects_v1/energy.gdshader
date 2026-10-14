shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 effect_color : source_color = vec4(0.7, 0.85, 1.0, 1.0);
uniform float emission_power = 1.0;
uniform float effect_strength = 1.0;
uniform float age = 0.0;
uniform float visual_time = 0.0;
uniform float halo = 0.0;
void fragment() {
    // A volume-shaped radiance profile, not an opaque emissive primitive.
    float facing = max(0.0, dot(normalize(NORMAL), normalize(VIEW)));
    float soft_edge = smoothstep(0.0, 0.5, facing);
    float core = pow(facing, mix(5.0, 1.5, halo));
    float fade = pow(max(0.0, 1.0 - age), 1.65);
    vec3 tint = mix(effect_color.rgb, vec3(1.0), core * 0.38 * (1.0 - halo));
    // Godot's unshaded path outputs ALBEDO directly, including HDR radiance.
    ALBEDO = tint * emission_power * (0.18 + core * 0.82) * fade * effect_strength;
    ALPHA = soft_edge * fade * mix(0.85, 0.3, halo);
}
