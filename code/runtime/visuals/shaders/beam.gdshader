shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;
uniform vec4 effect_color : source_color = vec4(0.2,0.7,1.0,1.0);
uniform float age = 0.0;
void fragment() {
	float fade=max(0.0,1.0-age);
	ALBEDO=effect_color.rgb; EMISSION=effect_color.rgb*3.0*fade;
	ALPHA=fade;
}
