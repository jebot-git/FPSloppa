shader_type spatial;
render_mode unshaded,cull_disabled;
#include "res://tools/voxel_battle/baked_lighting.gdshaderinc"
uniform sampler2D albedo:source_color,filter_linear_mipmap,repeat_disable;
uniform vec4 tint:source_color=vec4(1.0);
uniform float alpha_cutoff:hint_range(0.0,1.0)=0.45;
varying vec3 point;
void vertex() {
	vec3 up=vec3(0.0,1.0,0.0);vec3 facing=normalize(vec3(INV_VIEW_MATRIX[2].x,0.0,INV_VIEW_MATRIX[2].z));
	vec3 right=normalize(cross(up,facing));
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(facing*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);
	point=(INV_VIEW_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {vec4 color=texture(albedo,UV);ALBEDO=color.rgb*tint.rgb*jungle_baked_light(point);ALPHA=color.a*tint.a;ALPHA_SCISSOR_THRESHOLD=alpha_cutoff;}
