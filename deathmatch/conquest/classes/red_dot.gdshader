shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float aperture = 0.016;
void fragment() {
	vec3 eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec2 dot_center = vec2(0.5) + vec2(eye.x, -eye.y) / aperture;
	if (eye.z <= 0.0 || length(UV - dot_center) > 0.055) discard;
	ALBEDO = vec3(1.0, 0.04, 0.02);
	EMISSION = ALBEDO * 2.0;
}
