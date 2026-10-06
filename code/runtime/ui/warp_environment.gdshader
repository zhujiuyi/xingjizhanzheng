shader_type canvas_item;
render_mode unshaded;

// This canvas renders after 3D and before the HUD. Dimensional controls are
// supplied from SQLite; the protected hull always keeps its original pixels.
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float effect_strength = 0.0;
uniform float blur_radius_px = 0.0;
uniform float blur_lod = 0.0;
uniform vec4 ship_rect_uv = vec4(0.0);
uniform bool protect_ship = false;
uniform float mask_feather_px = 0.0;
uniform float center_clear_ratio = 0.0;
uniform vec2 flow_focus_uv = vec2(0.5);
uniform vec2 flow_axis = vec2(0.0);
uniform float side_weight = 0.0;

float outside_hull(vec2 uv, vec2 pixel_size) {
	if (!protect_ship) {
		return 1.0;
	}
	vec2 center = (ship_rect_uv.xy + ship_rect_uv.zw) * 0.5;
	vec2 half_extent = (ship_rect_uv.zw - ship_rect_uv.xy) * 0.5;
	vec2 outside_px = max(abs(uv - center) - half_extent, vec2(0.0)) / pixel_size;
	return smoothstep(0.0, max(mask_feather_px, 0.0001), length(outside_px));
}

void fragment() {
	vec4 original = textureLod(scene_color, SCREEN_UV, 0.0);
	vec2 radial_px = (SCREEN_UV - flow_focus_uv) / SCREEN_PIXEL_SIZE;
	vec2 radial = radial_px / max(length(radial_px), 1.0);
	vec2 direction = mix(radial, flow_axis, side_weight);
	direction /= max(length(direction), 0.0001);
	vec2 center_offset = SCREEN_UV - vec2(0.5);
	float central_clear = smoothstep(center_clear_ratio, max(center_clear_ratio * 2.0, 0.0001), length(center_offset));
	float amount = effect_strength * outside_hull(SCREEN_UV, SCREEN_PIXEL_SIZE) * central_clear;
	vec4 total = original;
	float weights = 1.0;
	for (int index = 1; index <= 8; index++) {
		vec2 sample_uv = clamp(SCREEN_UV - direction * SCREEN_PIXEL_SIZE * blur_radius_px * amount * float(index) / 8.0, vec2(0.0), vec2(1.0));
		// Protected ship pixels must not smear out into surrounding scenery.
		float weight = outside_hull(sample_uv, SCREEN_PIXEL_SIZE);
		total += textureLod(scene_color, sample_uv, blur_lod * amount) * weight;
		weights += weight;
	}
	COLOR = vec4(mix(original.rgb, (total / weights).rgb, amount), 1.0);
}
