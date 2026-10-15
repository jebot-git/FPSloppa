shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://tools/voxel_battle/baked_lighting.gdshaderinc"
void fragment() {
 // Rubble is now outdoors: the intact map's ground atlas still contains a roof.
 // Approximate exposed illumination using the same sky, sun and weather blend.
 ALBEDO=COLOR.rgb*(jungle_baked_enabled?jungle_irradiance(vec4(.7,0,.8,.6),.6):vec3(1.0));
}
