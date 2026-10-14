shader_type sky;
render_mode disable_fog;
uniform samplerCube room_map : source_color, filter_linear_mipmap;
void sky() {
    // Captured once from the actual room's static layer, independent of
    // camera motion and gameplay state. Reflections still follow view angle.
    COLOR = texture(room_map, EYEDIR).rgb * 0.85;
}
