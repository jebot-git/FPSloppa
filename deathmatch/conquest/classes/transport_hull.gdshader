shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://tools/voxel_battle/baked_lighting.gdshaderinc"
uniform sampler2D albedo:source_color,filter_linear_mipmap;
varying vec3 local_point;
varying vec3 world_point;
void vertex(){local_point=VERTEX;world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 // The source cockpit glass was baked into the opaque hull. Open a real
 // windshield aperture while retaining the roof, pillars and lower armour.
 if(local_point.z < -2.70 && abs(local_point.x)<1.22 && local_point.y>1.60 && local_point.y<2.35)discard;
 ALBEDO=texture(albedo,UV).rgb*jungle_baked_light(world_point);
}
