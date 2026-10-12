shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2DArray height_tiles : filter_linear, repeat_disable;
uniform sampler2DArray color_tiles : source_color, filter_linear, repeat_disable;
uniform sampler2D pages : filter_nearest, repeat_disable;
uniform sampler2D coarse_heights : filter_linear, repeat_disable;
uniform sampler2D coarse_colors : source_color, filter_linear, repeat_disable;
uniform bool coarse = false;
varying flat float tile_layer;
varying vec2 world_xz;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world.xz;
	tile_layer = INSTANCE_CUSTOM.r;
	if (coarse) {
		UV = ((world.xz + vec2(1024.0)) / 2048.0 * 128.0 + vec2(.5)) / 129.0;
		VERTEX.y = textureLod(coarse_heights, UV, 0.0).r;
	} else {
		UV = (UV * 64.0 + vec2(.5)) / 65.0;
		VERTEX.y = textureLod(height_tiles, vec3(UV, tile_layer), 0.0).r - COLOR.a * 3.0;
	}
}
void fragment() {
	if (coarse) {
		ivec2 cell = ivec2(floor((world_xz + vec2(1024.0)) / 32.0));
		cell = clamp(cell, ivec2(0), ivec2(63));
		if (texelFetch(pages, cell, 0).r > .5) { discard; }
		ALBEDO = texture(coarse_colors, UV).rgb;
	} else {
		ALBEDO = texture(color_tiles, vec3(UV, tile_layer)).rgb;
	}
}
