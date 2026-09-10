shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float visibility : hint_range(0.0,1.0) = 1.0;
uniform vec4 tint : source_color = vec4(0.4,0.7,1.0,1.0);
void fragment() {
	// Screen-door dissolve works with skinned meshes without transparent sorting.
	float noise = fract(sin(dot(floor(FRAGCOORD.xy / 2.0), vec2(12.9898,78.233))) * 43758.5453);
	if (noise > visibility) { discard; }
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = tint.rgb * (0.35 + edge * 0.65);
	EMISSION = tint.rgb * edge * 0.3;
}
