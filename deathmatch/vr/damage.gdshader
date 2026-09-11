shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float underwater = 0.0;
uniform float burning = 0.0;
void vertex() {
	// The same clip-space quad is drawn independently for each XR eye.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	float edge = smoothstep(0.2, 0.68, length(UV - vec2(0.5)));
	float hurt = strength * (0.025 + edge * 0.16);
	float water = underwater * 0.14;
	ALBEDO = mix(vec3(0.035, 0.20, 0.28), vec3(0.55, 0.025, 0.018), hurt / max(0.001, hurt + water));
	float fire = burning * edge * (0.08 + 0.025 * sin(TIME * 4.0 + UV.x * 14.0));
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.24, 0.025), fire / max(0.001, hurt + water + fire));
	ALPHA = clamp(hurt + water + fire, 0.0, 0.45);
}
