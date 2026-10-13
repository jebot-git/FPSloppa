shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
varying vec3 world_point;
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float ripple=sin(world_point.x*1.4+TIME*1.8)*sin(world_point.z*1.1-TIME*1.3);
 ALBEDO=mix(vec3(.07,.23,.26),vec3(.18,.40,.43),.5+ripple*.18);
 ROUGHNESS=.28;
 METALLIC=.08;
 ALPHA=.72;
}
