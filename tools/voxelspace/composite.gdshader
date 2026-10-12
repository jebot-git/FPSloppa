shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
uniform sampler2D color_image : source_color, filter_nearest;
uniform sampler2D depth_image : filter_nearest;
void vertex() { POSITION=vec4(VERTEX.xy,1.0,1.0); }
void fragment() {
 // QuadMesh UV Y is opposite the compute image row convention.
 vec2 image_uv=vec2(UV.x,1.0-UV.y);
 float distance=texture(depth_image,image_uv).r;
 vec4 projected=PROJECTION_MATRIX*vec4(0.0,0.0,-distance,1.0);
 DEPTH=projected.z/projected.w;
 ALBEDO=texture(color_image,image_uv).rgb;
}
