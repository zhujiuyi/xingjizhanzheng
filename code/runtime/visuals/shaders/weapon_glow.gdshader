shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 effect_color : source_color = vec4(0.9, 0.35, 0.15, 1.0);
uniform float age = 0.0;
uniform float emission_power = 1.5;
void fragment() {
    float fade = pow(max(0.0, 1.0 - age), 1.4);
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
    ALBEDO = effect_color.rgb;
    EMISSION = effect_color.rgb * emission_power * fade;
    ALPHA = (0.18 + rim * 0.35) * fade;
}
