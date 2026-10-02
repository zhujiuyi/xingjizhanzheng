shader_type spatial;
render_mode diffuse_burley;
void fragment(){
 vec2 p=UV;
 float edge=1.0-smoothstep(.012,.025,min(min(p.x,1.0-p.x),min(p.y,1.0-p.y)));
 float row=1.0-smoothstep(.03,.05,abs(fract(p.y*12.0)-.5));
 float page=step(.12,p.x)*(1.0-step(.77,p.x))*step(.12,p.y)*(1.0-step(.88,p.y));
 float bar=step(.79,p.x)*(1.0-step(.84,p.x))*step(.2,p.y)*(1.0-step(.70,p.y));
 float intensity=row*page*.30+edge*.12+bar*.42;
 ALBEDO=vec3(.008,.025,.033);METALLIC=.12;ROUGHNESS=.38;
 EMISSION=vec3(.04,.52,.66)*intensity;
}
