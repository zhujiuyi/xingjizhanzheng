shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 effect_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec3 hit_direction = vec3(0.0, 0.0, -1.0);
uniform float age = 0.0;
varying vec3 surface_direction;
void vertex() {
    surface_direction = normalize(VERTEX);
}
void fragment() {
    float angle = acos(clamp(dot(normalize(surface_direction), normalize(hit_direction)), -1.0, 1.0));
    float radius = 0.12 + age * 0.7;
    float wave = exp(-pow((angle - radius) * 13.0, 2.0));
    float contact = exp(-angle * angle * 20.0) * (1.0 - age);
    float fade = pow(max(0.0, 1.0 - age), 1.5);
    float strength = (wave * 0.6 + contact * 0.45) * fade;
    ALBEDO = effect_color.rgb;
    EMISSION = effect_color.rgb * strength * 1.8;
    ALPHA = strength * 0.55;
}
