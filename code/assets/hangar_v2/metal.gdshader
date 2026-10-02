shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 metal_tint : source_color = vec4(0.22,0.29,0.34,1.0);
uniform sampler2D metal_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo = false;
varying vec3 local_p;
varying vec3 local_n;
void vertex(){local_p=VERTEX;local_n=NORMAL;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec3 n=abs(local_n);
 vec2 p=n.y>n.x && n.y>n.z ? local_p.xz : (n.x>n.z ? local_p.zy : local_p.xy);
 float mottled=hash(floor(p*12.0));
 float brush=sin(p.x*153.0+sin(p.y*0.6))*0.008;
 vec3 coat=metal_tint.rgb*(0.96+mottled*0.05+brush);
 if(has_albedo){coat=mix(coat,texture(metal_albedo,p*.18).rgb*metal_tint.rgb*2.3,0.40);}
 ALBEDO=coat;METALLIC=0.64;ROUGHNESS=0.65+mottled*.05;SPECULAR=0.4;
}
