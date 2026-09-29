shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back;
// Rounded, translucent edge for low-cost smoke/mist instances.
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * pow(max(0.0, dot(NORMAL, VIEW)), 1.6);
}
