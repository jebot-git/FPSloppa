shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D image : source_color, filter_linear;
uniform mat4 head_view;
uniform float view_tangent = 1.7320508;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	// Map each runtime eye projection onto one head-centred digital image.
	// Do not change the XR camera projection or stretch an image over eye UVs.
	vec4 eye = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 ray = mat3(head_view) * mat3(INV_VIEW_MATRIX) * eye.xyz;
	vec2 uv = vec2(0.5) + vec2(ray.x, -ray.y) / max(0.0001, -ray.z) / (2.0 * view_tangent);
	ALBEDO = ray.z < 0.0 && all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0))) ? texture(image, uv).rgb : vec3(0.0);
}
