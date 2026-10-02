shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.19, 0.215, 0.22, 1.0);
uniform float base_metallic : hint_range(0.0, 1.0) = 0.62;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.78;
uniform sampler2D metal_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo = false;
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
    local_position = VERTEX;
    local_normal = NORMAL;
}

void fragment() {
    vec3 blend = pow(abs(normalize(local_normal)), vec3(4.0));
    blend /= max(blend.x + blend.y + blend.z, 0.0001);
    vec3 p = local_position * 0.18;
    float detail = 0.4;
    if (has_albedo) {
        vec3 sampled = texture(metal_albedo, p.yz).rgb * blend.x
            + texture(metal_albedo, p.xz).rgb * blend.y
            + texture(metal_albedo, p.xy).rgb * blend.z;
        detail = clamp(dot(sampled, vec3(0.2126, 0.7152, 0.0722)) * 3.5, 0.05, 0.85);
    }
    ALBEDO = base_color.rgb * (0.84 + detail * 0.4);
    METALLIC = base_metallic;
    ROUGHNESS = clamp(base_roughness + (detail - 0.4) * 0.12, 0.64, 0.92);
    SPECULAR = 0.25;
    vec3 dx = dFdx(VERTEX);
    vec3 dy = dFdy(VERTEX);
    vec3 r1 = cross(dy, NORMAL);
    vec3 r2 = cross(NORMAL, dx);
    float determinant = dot(dx, r1);
    if (abs(determinant) > 0.000001) {
        vec3 gradient = (r1 * dFdx(detail) + r2 * dFdy(detail)) / determinant;
        NORMAL = normalize(NORMAL - gradient * 0.02);
    }
}
