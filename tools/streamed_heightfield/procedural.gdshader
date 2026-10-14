shader_type spatial;
#include "res://tools/voxel_battle/baked_lighting.gdshaderinc"
varying vec3 jungle_point;
render_mode unshaded, cull_disabled;
// Same deterministic landscape as landscape.gd, evaluated directly on the GPU.
uniform sampler2D pages : filter_nearest, repeat_disable;
uniform bool coarse = false;
varying vec2 world_xz;
vec4 surface(vec2 p) {
	ivec2 site = clamp(ivec2(floor((p + vec2(1024.0)) / 512.0)), ivec2(0), ivec2(3));
	int kind = (site.x + site.y) % 4;
	vec2 local = p - (vec2(site) * 512.0 - vec2(768.0));
	vec4 pad_heights = vec4(14.0, 18.0, 2.4, 24.0);
	vec4 pad_radii = vec4(100.0, 90.0, 110.0, 104.0);
	float distance = max(abs(local.x), abs(local.y));
	float pad = 1.0 - smoothstep(pad_radii[kind], pad_radii[kind] + 40.0, distance);
	float rough = sin(p.x * .018 + p.y * .014) * 2.5;
	float natural = 18.0 + sin(p.x * .006) * cos(p.y * .005) * 9.0 + rough;
	float height = mix(natural, pad_heights[kind], pad);
	float shade = .5 + .5 * sin(p.x * .065 + sin(p.y * .07) * 2.0);
	vec3 color = mix(vec3(.24, .34, .19), vec3(.42, .40, .25), shade * .55);
	if (pad > .99) {
		if (kind == 0) { color = vec3(.45, .43, .34); }
		else if (kind == 1) { color = vec3(.42, .42, .39); }
		else if (kind == 2) { color = vec3(.52, .46, .33); }
		else { color = vec3(.36, .39, .29); }
	}
	if (abs(local.x) < 6.0 || abs(local.y) < 6.0) {
		color = vec3(.21, .23, .23);
		if ((abs(local.x) < .3 && mod(abs(p.y), 12.0) < 6.0) || (abs(local.y) < .3 && mod(abs(p.x), 12.0) < 6.0)) {
			color = vec3(.77, .72, .46);
		}
	}
	if (kind == 2) {
		float water = (1.0 - smoothstep(105.0, 130.0, abs(local.x))) * smoothstep(55.0, 85.0, local.y) * (1.0 - smoothstep(190.0, 220.0, local.y));
		height = mix(height, -3.0, water);
		color = mix(color, vec3(.25, .32, .30), water);
	}
	return vec4(height, color);
}
vec3 srgb_to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + .055) / 1.055, vec3(2.4)), step(vec3(.04045), color));
}
void vertex() {
	jungle_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y = surface(world_xz).x - (coarse ? 0.0 : COLOR.a * 3.0);
}
void fragment() {
	if (coarse) {
		ivec2 cell = clamp(ivec2(floor((world_xz + vec2(1024.0)) / 32.0)), ivec2(0), ivec2(63));
		if (texelFetch(pages, cell, 0).r > .5) { discard; }
	}
	// Match the source_color conversion used by the atlas renderer.
	ALBEDO = srgb_to_linear(surface(world_xz).yzw);

	ALBEDO *= jungle_baked_light(jungle_point);
}
