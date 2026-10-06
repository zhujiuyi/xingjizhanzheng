shader_type canvas_item;
render_mode unshaded;

// This canvas renders after 3D and before the HUD. Dimensional controls are
// supplied from SQLite; the protected hull always keeps its original pixels.
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D ship_mask : repeat_disable, filter_linear;
uniform float effect_strength = 0.0;
uniform float blur_radius_px = 0.0;
uniform float blur_lod = 0.0;
uniform float reference_height_px = 1.0;
uniform vec4 ship_rect_uv = vec4(0.0);
uniform bool protect_ship = false;
uniform float mask_feather_px = 0.0;
uniform float center_clear_ratio = 0.0;
uniform vec2 flow_focus_uv = vec2(0.5);
uniform vec2 flow_axis = vec2(0.0);
uniform float side_weight = 0.0;

float hull_coverage(vec2 uv) {
	if (!protect_ship) {
		return 0.0;
	}
	return textureLod(ship_mask, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).r;
}

float outside_hull(vec2 uv, vec2 feather_uv) {
	// The mesh-only viewport includes actual hull holes, fins and silhouette,
	// unlike a projected bounding box that leaves a sharp patch of empty sky.
	float core = hull_coverage(uv);
	float edge = (hull_coverage(uv + vec2(feather_uv.x, 0.0))
		+ hull_coverage(uv - vec2(feather_uv.x, 0.0))
		+ hull_coverage(uv + vec2(0.0, feather_uv.y))
		+ hull_coverage(uv - vec2(0.0, feather_uv.y))) * 0.125;
	return 1.0 - max(core, edge);
}

void fragment() {
	vec4 original = textureLod(scene_color, SCREEN_UV, 0.0);
	vec2 radial_px = (SCREEN_UV - flow_focus_uv) / SCREEN_PIXEL_SIZE;
	vec2 radial = radial_px / max(length(radial_px), 1.0);
	vec2 direction = mix(radial, flow_axis, side_weight);
	direction /= max(length(direction), 0.0001);
	vec2 center_offset = SCREEN_UV - vec2(0.5);
	float central_clear = center_clear_ratio > 0.0 ? smoothstep(center_clear_ratio, center_clear_ratio * 2.0, length(center_offset)) : 1.0;
	// Derive density from the screen sampler itself. The ViewportTexture size
	// may include canvas oversampling under UI scaling and is not this size.
	float pixel_scale = 1.0 / max(SCREEN_PIXEL_SIZE.y * reference_height_px, 0.0001);
	vec2 feather_uv = SCREEN_PIXEL_SIZE * mask_feather_px * pixel_scale;
	float amount = effect_strength * outside_hull(SCREEN_UV, feather_uv) * central_clear;
	// Defocus all scenery first, including the low-contrast production star
	// panorama. Retaining a sharp center tap made fine stars remain crisp even
	// while a checker test could measure a small difference in the old effect.
	float lod = max(0.0, blur_lod + log2(pixel_scale)) * amount;
	vec4 total = textureLod(scene_color, SCREEN_UV, lod);
	float weights = 1.0;
	vec2 tangent = vec2(-direction.y, direction.x);
	for (int index = 1; index <= 8; index++) {
		vec2 sample_uv = clamp(SCREEN_UV - direction * SCREEN_PIXEL_SIZE * blur_radius_px * pixel_scale * amount * float(index) / 8.0, vec2(0.0), vec2(1.0));
		// Protected ship pixels must not smear out into surrounding scenery.
		float weight = (1.0 - hull_coverage(sample_uv)) * (1.0 - float(index) / 12.0);
		total += textureLod(scene_color, sample_uv, lod) * weight;
		weights += weight;
	}
	// A small transverse lens kernel gives actual background softness, rather
	// than an overlay of parallel lines or a directional ghost of sharp stars.
	for (int index = 0; index < 4; index++) {
		float side = index < 2 ? -1.0 : 1.0;
		float radius = index % 2 == 0 ? 0.12 : 0.24;
		vec2 sample_uv = clamp(SCREEN_UV + tangent * SCREEN_PIXEL_SIZE * blur_radius_px * pixel_scale * amount * side * radius, vec2(0.0), vec2(1.0));
		float weight = (1.0 - hull_coverage(sample_uv)) * 0.5;
		total += textureLod(scene_color, sample_uv, lod) * weight;
		weights += weight;
	}
	COLOR = vec4(mix(original.rgb, (total / weights).rgb, amount), 1.0);
}
