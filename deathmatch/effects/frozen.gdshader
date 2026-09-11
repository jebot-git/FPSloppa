shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = mix(vec3(0.38, 0.67, 0.8), vec3(0.85, 0.97, 1.0), rim);
	METALLIC = 0.15;
	ROUGHNESS = 0.38;
	EMISSION = vec3(0.09, 0.23, 0.3) + rim * vec3(0.18, 0.3, 0.35);
}
