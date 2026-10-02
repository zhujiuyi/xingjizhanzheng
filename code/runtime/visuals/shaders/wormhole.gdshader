shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 effect_color : source_color = vec4(0.12,0.65,1.0,1.0);
uniform float visual_time = 0.0;
uniform float intensity = 0.0;
void fragment() {
	vec2 p = (UV-0.5)*2.0;
	float r=length(p); float a=atan(p.y,p.x);
	float rim=exp(-pow((r-0.82)*17.0,2.0));
	float swirl=pow(0.5+0.5*sin(a*7.0-r*23.0+visual_time*1.8),5.0);
	float inner=max(0.0,1.0-r)*swirl*0.55;
	float aperture=1.0-smoothstep(0.9,1.0,r);
	ALBEDO=effect_color.rgb; EMISSION=effect_color.rgb*intensity*(rim+inner);
	ALPHA=clamp((rim+inner)*aperture,0.0,1.0);
}
