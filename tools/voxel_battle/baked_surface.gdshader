shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://tools/voxel_battle/baked_lighting.gdshaderinc"
uniform vec4 tint:source_color=vec4(1.0);
uniform sampler2D albedo:source_color,filter_linear_mipmap,repeat_enable;
uniform bool textured=false;
uniform bool vertex_tint=true;
uniform bool baked_vertices=false;
varying vec3 point;
varying vec4 light_pair;
varying float dawn;
vec3 linear_color(vec3 color) {return mix(color/12.92,pow((color+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),color));}
void vertex() {point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;light_pair=CUSTOM0;dawn=CUSTOM1.r;}
void fragment() {
	vec3 base=tint.rgb*(textured?texture(albedo,UV).rgb:vec3(1.0))*(vertex_tint?linear_color(COLOR.rgb):vec3(1.0));
	ALBEDO=base*((baked_vertices && jungle_baked_enabled ? jungle_irradiance(light_pair,dawn):jungle_baked_light(point))+cq_headlight(point));
}
