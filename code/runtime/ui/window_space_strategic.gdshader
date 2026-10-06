shader_type spatial;
render_mode unshaded, cull_disabled;

// Only directions and physical angular ratios reach the GPU. AU positions
// remain float64 scalars in the catalog reader on the CPU.
uniform mat3 stage_to_sector = mat3(1.0);
uniform vec3 planet_direction = vec3(0.0, 0.0, -1.0);
uniform vec3 planet_light_direction = vec3(0.0, 0.0, -1.0);
uniform float planet_sin_radius = 0.0;
uniform vec3 star_direction = vec3(0.0, 0.0, -1.0);
uniform float star_sin_radius = 0.0;
uniform vec4 star_color : source_color = vec4(1.0);
uniform vec4 surface_color : source_color = vec4(1.0);
uniform vec4 cloud_color : source_color = vec4(1.0);
uniform float visual_seed = 0.0;
uniform sampler2D space_panorama : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D surface_map : source_color, repeat_enable, filter_linear_mipmap;

vec2 sphere_uv(vec3 direction) {
	return vec2(atan(direction.x, direction.z) / 6.28318530718 + 0.5,
		acos(clamp(direction.y, -1.0, 1.0)) / 3.14159265359);
}

void fragment() {
	// VERTEX is the actual pane fragment in view space; w=0 removes the camera
	// translation. Looking at the same pane point from a different room position
	// changes this ray rather than sliding a prepainted disk along fixed UVs.
	vec3 world_ray = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	vec3 ray = normalize(stage_to_sector * world_ray);
	vec3 sky = texture(space_panorama, sphere_uv(ray)).rgb;
	float radius = max(planet_sin_radius, 0.000001);
	float ratio = length(cross(ray, planet_direction)) / radius;
	float edge = max(fwidth(ratio), 0.0001);
	float planet_disk = (1.0 - smoothstep(1.0 - edge, 1.0 + edge, ratio))
		* step(0.0, dot(ray, planet_direction)) * step(0.000001, planet_sin_radius);
	// Ray/sphere intersection in radius-normalized coordinates. This preserves
	// the real limb and illumination phase without sending a distant center.
	float along = dot(ray, planet_direction) / radius;
	float hit_distance = along - sqrt(max(1.0 - ratio * ratio, 0.0));
	vec3 normal = normalize(ray * hit_distance - planet_direction / radius);
	vec2 map_uv = sphere_uv(normal);
	map_uv.x = fract(map_uv.x + visual_seed * 0.013);
	vec3 ground = texture(surface_map, map_uv).rgb;
	vec3 tint = mix(vec3(1.0), surface_color.rgb * 1.7, 0.16);
	float illumination = max(dot(normal, planet_light_direction), 0.0);
	vec3 planet = ground * tint * (0.025 + illumination * 0.975);
	float atmosphere = pow(clamp(1.0 - abs(dot(normal, -ray)), 0.0, 1.0), 3.0);
	planet += cloud_color.rgb * atmosphere * illumination * 0.035;
	sky = mix(sky, planet, planet_disk);
	float solar_ratio = length(cross(ray, star_direction)) / max(star_sin_radius, 0.000001);
	float solar_edge = max(fwidth(solar_ratio), 0.0001);
	float star_disk = (1.0 - smoothstep(1.0 - solar_edge, 1.0 + solar_edge, solar_ratio))
		* step(0.0, dot(ray, star_direction)) * step(0.000001, star_sin_radius);
	// A nearer planet occludes the star; no oversized UV halo is fabricated.
	ALBEDO = sky + star_color.rgb * star_disk * (1.0 - planet_disk);
}
