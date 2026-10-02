shader_type spatial;
render_mode unshaded,cull_disabled;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV;float cloud=noise(p*6.0)*.5+noise(p*13.0)*.27+noise(p*29.0)*.13;
 float band=exp(-pow((p.y-.55+sin(p.x*6.0)*.10)*4.0,2.0));
 vec3 sky=vec3(.004,.009,.022)+vec3(.025,.07,.10)*cloud*band;
 vec2 cell=floor(p*vec2(180.0,80.0)),f=fract(p*vec2(180.0,80.0))-.5;
 float star=step(.985,h(cell))*exp(-dot(f,f)*250.0);
 vec2 planet=(p-vec2(.72,.43))*vec2(2.1,1.0);float r=length(planet);
 float disk=1.0-smoothstep(.145,.149,r);float rim=exp(-abs(r-.149)*300.0);
 float lit=clamp((planet.x+planet.y)*5.0+.38,0.02,1.0);
 sky=mix(sky,vec3(.025,.12,.21)*lit+noise(p*130.0)*.024,disk);
 ALBEDO=sky+star*vec3(.58,.75,.85)+rim*vec3(.025,.15,.22);
}
