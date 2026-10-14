shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 effect_color : source_color = vec4(0.45, 0.7, 0.9, 1.0);
uniform vec3 hit_direction = vec3(0.0, 0.0, -1.0);
uniform float age = 0.0;
uniform float effect_strength = 1.0;
uniform float visual_time = 0.0;
varying vec3 surface_direction;
void vertex() { surface_direction = normalize(VERTEX); }
void fragment() {
    float angle = acos(clamp(dot(normalize(surface_direction), normalize(hit_direction)), -1.0, 1.0));
    float radius = 0.08 + age * 0.74;
    float width = 0.018 + age * 0.022;
    float ring = exp(-pow((angle - radius) / max(width, fwidth(angle)), 2.0));
    float halo = exp(-pow((angle - radius) / (width * 3.0), 2.0));
    float center = exp(-angle * angle * 65.0) * pow(1.0 - age, 3.0);
    float fade = pow(max(0.0, 1.0 - age), 1.8);
    float signal = (ring * 0.75 + halo * 0.16 + center * 0.8) * fade;
    ALBEDO = mix(effect_color.rgb, vec3(0.93, 0.98, 1.0), center * 0.45) * signal * 1.6 * effect_strength;
    ALPHA = clamp(signal * 0.48, 0.0, 0.75);
}
