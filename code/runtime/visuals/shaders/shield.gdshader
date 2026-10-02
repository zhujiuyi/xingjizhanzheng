shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 effect_color : source_color = vec4(0.14,0.65,1.0,1.0);
uniform float age = 0.0;
void fragment() {
	float fresnel=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.1);
	float cells=pow(0.5+0.5*sin(UV.x*150.0)*sin(UV.y*90.0),8.0);
	float fade=pow(max(0.0,1.0-age),1.8);
	ALBEDO=effect_color.rgb; EMISSION=effect_color.rgb*(fresnel*1.8+cells*0.3)*fade;
	ALPHA=(fresnel*0.7+cells*0.12)*fade;
}
