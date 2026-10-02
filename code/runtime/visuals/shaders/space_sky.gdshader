shader_type sky;
uniform vec3 nebula_color : source_color = vec3(0.07, 0.22, 0.34);
uniform vec3 nebula_accent : source_color = vec3(0.29, 0.14, 0.41);
uniform float visual_seed = 0.0;

float hash3(vec3 p) {
	p = fract(p * 0.1031 + visual_seed * 0.013);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i+vec3(1,0,0)), f.x), mix(hash3(i+vec3(0,1,0)), hash3(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i+vec3(0,0,1)), hash3(i+vec3(1,0,1)), f.x), mix(hash3(i+vec3(0,1,1)), hash3(i+vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float v=0.0; float a=0.5;
	for(int i=0;i<5;i++) {v+=a*noise3(p);p=p*2.03+vec3(1.1,3.7,2.5);a*=0.5;}
	return v;
}
void sky() {
	vec3 d = normalize(EYEDIR);
	float cloud = fbm(d*3.5+vec3(visual_seed*0.017));
	float filaments = pow(max(0.0, cloud-0.22), 2.0)*6.0;
	float ribbon = exp(-pow((d.y+0.18*sin(d.x*4.0))/0.55,2.0));
	vec3 n = mix(nebula_color, nebula_accent, fbm(d*8.0));
	vec2 star_uv=SKY_COORDS*vec2(1200.0,600.0);
	vec3 cell=vec3(floor(star_uv),0.0);
	vec2 offset=vec2(hash3(cell+13.0),hash3(cell+29.0));
	vec2 local=fract(star_uv)-offset;
	float star = step(0.996,hash3(cell))*exp(-dot(local,local)*220.0);
	vec3 star_color = mix(vec3(0.55,0.72,1.0),vec3(1.0,0.83,0.57),hash3(cell+7.0));
	COLOR = vec3(0.002,0.004,0.009)+n*filaments*ribbon+star_color*star*2.8;
}
