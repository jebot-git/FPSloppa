shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment() {
 ALBEDO=pow(COLOR.rgb,vec3(2.2));
 float storey=mod(world_position.y-2.4,4.0);
 float bay=mod(abs(world_normal.z)>.5?world_position.x+32.0:world_position.z+30.0,5.0);
 if(abs(world_normal.y)<.5&&world_position.y<18.4&&storey>1.05&&storey<2.75&&bay>.4&&bay<4.6)ALBEDO=vec3(.025,.045,.06);
}
