shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform float clock_time = 0.0;
varying vec3 stamp;
void vertex() {
	stamp = INSTANCE_CUSTOM.rgb;
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x) + stamp.y * 6.283185;
	float rim = 0.68 + 0.10 * sin(angle * 7.0) + 0.06 * sin(angle * 13.0);
	float coverage = 1.0 - smoothstep(rim - 0.10, rim, r);
	float edge = smoothstep(0.22, 0.55, r);
	ALBEDO = mix(vec3(0.025), vec3(0.17, 0.155, 0.14), edge);
	// One batch holds all damage materials; the style travels per instance.
	if (stamp.z > 0.5 && stamp.z < 1.5) {
		float cut = abs(p.y + 0.025 * sin(p.x * 17.0));
		coverage = (1.0 - smoothstep(0.045, 0.14, cut)) * (1.0 - smoothstep(0.65, 0.95, abs(p.x)));
		ALBEDO = mix(vec3(0.035), vec3(0.24, 0.21, 0.17), smoothstep(0.03, 0.12, cut));
	} else if (stamp.z > 1.5 && stamp.z < 2.5) {
		ALBEDO = mix(vec3(0.10), vec3(0.27, 0.25, 0.22), edge);
		coverage *= 0.78;
	} else if (stamp.z > 2.5 && stamp.z < 3.5) {
		float soot_rim = 0.78 + 0.05 * sin(angle * 7.0) + 0.03 * sin(angle * 13.0);
		coverage = (1.0 - smoothstep(0.05, soot_rim, r)) * (0.85 + 0.15 * sin(p.x * 51.0) * sin(p.y * 43.0));
		ALBEDO = vec3(0.055, 0.042, 0.03);
	} else if (stamp.z > 3.5 && stamp.z < 4.5) {
		ALBEDO = mix(vec3(0.018, 0.035, 0.045), vec3(0.12, 0.26, 0.29), edge);
		coverage *= 0.85 + 0.15 * sin(angle * 11.0);
	} else if (stamp.z > 4.5 && stamp.z < 5.5) {
		ALBEDO = mix(vec3(0.09, 0.16, 0.018), vec3(0.25, 0.32, 0.055), edge);
		coverage = 1.0 - smoothstep(rim - 0.07, rim, r);
	}
	float age = clock_time - stamp.x;
	float fade = (1.0 - smoothstep(25.0, 30.0, age)) * (1.0 - smoothstep(25.0, 40.0, length(VERTEX)));
	ALPHA = coverage * fade;
	ALPHA_SCISSOR_THRESHOLD = stamp.z > 2.5 && stamp.z < 3.5 ? 0.08 : 0.35;
}
