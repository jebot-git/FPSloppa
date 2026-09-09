shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void vertex() {
	// The same clip-space quad is drawn independently for each XR eye.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	float edge = smoothstep(0.2, 0.68, length(UV - vec2(0.5)));
	ALBEDO = vec3(0.55, 0.025, 0.018);
	ALPHA = strength * (0.025 + edge * 0.16);
}
