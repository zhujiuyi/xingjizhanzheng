shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 effect_color : source_color = vec4(0.3, 0.65, 0.8, 1.0);
uniform float visual_time = 0.0;
uniform float intensity = 1.0;
uniform float effect_strength = 1.0;
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float r = length(p);
    float a = atan(p.y, p.x);
    float band = exp(-pow((r - 0.80) * 22.0, 2.0));
    float glow = exp(-pow((r - 0.79) * 7.0, 2.0));
    float filament = pow(0.5 + 0.5 * sin(a * 5.0 - r * 31.0 + visual_time * 1.25), 8.0);
    float inner = filament * smoothstep(0.15, 0.6, r) * (1.0 - smoothstep(0.65, 0.88, r));
    float edge = 1.0 - smoothstep(0.86, 1.0, r);
    float signal = (band * 0.8 + glow * 0.14 + inner * 0.2) * edge;
    ALBEDO = mix(effect_color.rgb, vec3(0.8, 0.93, 1.0), band * 0.4) * intensity * signal * effect_strength;
    ALPHA = clamp(signal * 0.7, 0.0, 0.85);
}
