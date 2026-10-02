shader_type spatial;
render_mode cull_back;
uniform vec4 surface_color : source_color = vec4(.3,.4,.45,1.);
uniform vec4 cloud_color : source_color = vec4(.7,.75,.8,1.);
uniform float visual_seed = 0.;
uniform sampler2D surface_map : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 local_surface;
void vertex() { local_surface = normalize(VERTEX); }
float h(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7))+visual_seed)*43758.5453); }
float n(vec3 p) {
 vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.-2.*f);
 return mix(mix(mix(h(i),h(i+vec3(1,0,0)),f.x),mix(h(i+vec3(0,1,0)),h(i+vec3(1,1,0)),f.x),f.y),mix(mix(h(i+vec3(0,0,1)),h(i+vec3(1,0,1)),f.x),mix(h(i+vec3(0,1,1)),h(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void fragment() {
 vec3 p=normalize(local_surface)*5.;
 vec2 map_uv=vec2(fract(UV.x+visual_seed*.013),UV.y);
 vec3 ground=texture(surface_map,map_uv).rgb;
 vec3 tint=mix(vec3(1.),surface_color.rgb*1.7,.16);
 float cloud_detail=n(p*14.6+vec3(visual_seed*.1));
 ALBEDO=ground*tint+cloud_color.rgb*cloud_detail*.012;
 ROUGHNESS=.86;
 METALLIC=0.;
}
