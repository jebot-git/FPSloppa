shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D colors : source_color, filter_linear, repeat_disable;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment() {
 vec2 uv=((world_position.xz+vec2(125.0))/250.0*512.0+vec2(.5))/513.0;
 ALBEDO=texture(colors,uv).rgb*mix(.7,1.0,max(0.0,world_normal.y));
}
