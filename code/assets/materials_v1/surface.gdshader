shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.24, 0.26, 0.28, 1.0);
uniform float base_metallic : hint_range(0.0, 1.0) = 0.82;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.47;
uniform float base_specular : hint_range(0.0, 1.0) = 0.5;
uniform int surface_role = 1;
uniform sampler2D micro_surface : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_strata : filter_linear_mipmap, repeat_enable;
uniform float texture_scale = 1.15;
uniform float micro_relief_m = 0.01;
uniform float roughness_variation = 0.07;
uniform float albedo_variation = 0.04;
uniform float clearcoat_amount = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_strength = 0.0;
uniform float emission_scale = 1.0;
uniform vec4 mineral_color : source_color = vec4(0.45, 0.32, 0.18, 1.0);
uniform float mineral_amount = 0.0;
uniform float mineral_scale = 0.025;
varying vec3 object_position;
varying vec3 object_normal;
varying float object_scale;

void vertex() {
    object_position = VERTEX;
    object_normal = NORMAL;
    object_scale = (length(MODEL_MATRIX[0].xyz) + length(MODEL_MATRIX[1].xyz) + length(MODEL_MATRIX[2].xyz)) / 3.0;
}

vec3 sample_strata(vec3 position, vec3 weights) {
    return texture(rock_strata, position.yz).rgb * weights.x
        + texture(rock_strata, position.xz).rgb * weights.y
        + texture(rock_strata, position.xy).rgb * weights.z;
}

vec3 sample_micro(vec3 position, vec3 weights) {
    return texture(micro_surface, position.yz).rgb * weights.x
        + texture(micro_surface, position.xz).rgb * weights.y
        + texture(micro_surface, position.xy).rgb * weights.z;
}

void fragment() {
    vec3 weights = pow(abs(normalize(object_normal)), vec3(4.0));
    weights /= max(weights.x + weights.y + weights.z, 0.0001);
    vec3 detail;
    vec3 rock_grain = vec3(0.5);
    if (surface_role == 5) {
        detail = sample_strata(object_position * texture_scale, weights);
        rock_grain = sample_micro(object_position * 0.08, weights);
    } else {
        detail = sample_micro(object_position * texture_scale, weights);
    }
    float height = detail.r - 0.5;
    if (surface_role == 5) {
        height += (rock_grain.r - 0.5) * 0.10;
    }
    if (surface_role == 0 || surface_role == 1 || surface_role == 6) {
        height += (detail.b - 0.5) * 0.18;
    }
    vec3 tint = base_color.rgb;
    if (surface_role == 7) {
        float luminance = dot(tint, vec3(0.2126, 0.7152, 0.0722));
        tint = mix(vec3(luminance), tint, 0.68);
    }
    ALBEDO = tint * (1.0 + height * albedo_variation);
    METALLIC = base_metallic;
    ROUGHNESS = clamp(base_roughness + (detail.g - 0.5) * roughness_variation, 0.06, 0.98);
    if (surface_role == 5) {
        // Mineral grains modulate diffuse color, not shiny metallic speckles.
        float fracture_width = max(0.012, fwidth(detail.b));
        float fracture = 1.0 - smoothstep(fracture_width, fracture_width * 3.0, abs(detail.b - 0.51));
        ALBEDO *= (1.0 + (rock_grain.g - 0.5) * 0.22) * (1.0 - fracture * 0.20);
        ROUGHNESS = clamp(ROUGHNESS + fracture * 0.025, 0.86, 0.99);
    }
    if (mineral_amount > 0.0) {
        vec3 mineral_sample = sample_strata(object_position * mineral_scale, weights);
        float footprint = max(length(dFdx(object_position * mineral_scale)), length(dFdy(object_position * mineral_scale)));
        float visibility = 1.0 - smoothstep(0.025, 0.09, footprint);
        float geological_region = smoothstep(0.53, 0.63, mineral_sample.g);
        float vein = (1.0 - smoothstep(0.006, 0.018, abs(mineral_sample.b - 0.5))) * geological_region;
        float patch = smoothstep(0.62, 0.72, mineral_sample.g);
        float mineral = clamp(max(vein * 0.60, patch * 0.55) * mineral_amount * visibility, 0.0, 1.0);
        ALBEDO = mix(ALBEDO, mineral_color.rgb * 0.82, mineral);
        METALLIC = mix(METALLIC, 0.12, mineral);
        ROUGHNESS = mix(ROUGHNESS, 0.80, mineral);
        height += mineral * 0.04;
    }
    SPECULAR = base_specular;
    CLEARCOAT = clearcoat_amount;
    CLEARCOAT_ROUGHNESS = 0.55;
    EMISSION = emission_color.rgb * emission_strength * emission_scale;
    // A mipmapped object-space micro-height perturbs shading only. No vertex,
    // collision, silhouette, time, world RNG or gameplay state is displaced.
    vec3 dx = dFdx(VERTEX);
    vec3 dy = dFdy(VERTEX);
    vec3 tangent_x = cross(dy, NORMAL);
    vec3 tangent_y = cross(NORMAL, dx);
    float determinant = dot(dx, tangent_x);
    if (abs(determinant) > 0.000001) {
        vec3 gradient = (tangent_x * dFdx(height) + tangent_y * dFdy(height)) / determinant;
        NORMAL = normalize(NORMAL - gradient * micro_relief_m * object_scale);
    }
}
