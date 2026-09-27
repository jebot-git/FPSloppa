shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform float clock_time = 0.0;
varying vec2 stamp;
void vertex() {
	stamp = INSTANCE_CUSTOM.rg;
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x) + stamp.y * 6.283185;
	float rim = 0.68 + 0.10 * sin(angle * 7.0) + 0.06 * sin(angle * 13.0);
	float coverage = 1.0 - smoothstep(rim - 0.10, rim, r);
	float edge = smoothstep(0.22, 0.55, r);
	ALBEDO = mix(vec3(0.025), vec3(0.17, 0.155, 0.14), edge);
	float age = clock_time - stamp.x;
	float fade = (1.0 - smoothstep(25.0, 30.0, age)) * (1.0 - smoothstep(25.0, 40.0, length(VERTEX)));
	ALPHA = coverage * fade;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
}
