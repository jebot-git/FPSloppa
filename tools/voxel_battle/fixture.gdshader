shader_type spatial;
render_mode unshaded;
#include "res://tools/voxel_battle/baked_lighting.gdshaderinc"
void fragment(){ ALBEDO=vec3(1.0,0.72,0.40)*mix(0.95,0.25,jungle_day_mix); }
