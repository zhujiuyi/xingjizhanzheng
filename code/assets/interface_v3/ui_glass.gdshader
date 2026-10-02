shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(0.025, 0.052, 0.073, 0.28);
uniform vec2 panel_size = vec2(320.0, 180.0);
float noise(vec2 p) { return fract(sin(dot(p, vec2(17.137, 53.719))) * 43758.5453); }
void fragment() {
    vec2 pixel = UV * max(panel_size, vec2(1.0));
    vec2 edge = min(pixel, panel_size - pixel);
    float cut = step(10.0, edge.x + edge.y);
    float grid_x = 1.0 - step(0.55, mod(pixel.x, 32.0));
    float grid_y = 1.0 - step(0.55, mod(pixel.y, 32.0));
    float grid = max(grid_x, grid_y) * 0.012;
    float grain = (noise(floor(pixel * 2.0)) - 0.5) * 0.006;
    float glow = exp(-pixel.y / 42.0) * 0.018;
    vec3 color = tint.rgb + vec3(grid + grain) + vec3(0.22, 0.55, 0.70) * glow;
    COLOR = vec4(color, tint.a * cut);
}
