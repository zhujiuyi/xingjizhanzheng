shader_type canvas_item;
render_mode unshaded;
uniform sampler2D metal_texture : source_color, filter_linear, repeat_enable;
uniform bool has_metal = false;
uniform float strength : hint_range(0.0, 1.0) = 0.12;
uniform vec4 tint : source_color = vec4(0.08, 0.10, 0.12, 1.0);
float grain(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
 vec2 pixel = FRAGCOORD.xy;
 float noise = grain(floor(pixel));
 float brushed = sin(pixel.y * 1.8) * 0.006;
 vec3 detail = has_metal ? texture(metal_texture, UV * vec2(2.0, 1.0)).rgb : vec3(noise);
 COLOR = vec4(mix(tint.rgb, detail * tint.rgb * 2.0, strength) + brushed, tint.a);
}
