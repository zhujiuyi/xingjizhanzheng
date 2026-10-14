shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 effect_color : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float emission_power = 1.0;
uniform float effect_strength = 1.0;
uniform float cooling = 0.0;
varying float phase;
void vertex() {
    // Retain each GPU particle's position and scale; only orient its quad.
    vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        vec4(INV_VIEW_MATRIX[0].xyz * scale.x, 0.0),
        vec4(INV_VIEW_MATRIX[1].xyz * scale.y, 0.0),
        vec4(INV_VIEW_MATRIX[2].xyz * scale.z, 0.0), MODEL_MATRIX[3]);
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
    phase = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
}
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float radius = length(p);
    float soft = pow(max(0.0, 1.0 - radius * radius), 2.5);
    float core = exp(-dot(p, p) * 18.0);
    float life = (1.0 - smoothstep(0.6, 1.0, phase));
    vec3 hot = mix(effect_color.rgb, vec3(1.0, 0.94, 0.8), (1.0 - phase) * 0.45);
    vec3 cooled = mix(hot, vec3(0.5, 0.12, 0.025), cooling * phase * 0.65);
    ALBEDO = cooled * emission_power * (soft + core * 0.45) * life * effect_strength;
    ALPHA = soft * life * COLOR.a * effect_color.a;
}
