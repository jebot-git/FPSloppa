shader_type spatial;
render_mode unshaded;
#include "res://tools/voxel_battle/baked_lighting.gdshaderinc"
varying vec3 point;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 tint=vec3(.05,.55,.6);
 ALBEDO=tint*jungle_baked_light(point);
 EMISSION=tint*(.12+.025*sin(TIME*3.));
}
