shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D heights : filter_linear, repeat_disable;
uniform sampler2D colors : source_color, filter_linear, repeat_disable;
uniform float extent = 250.0;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec2 uv=(p.xz+vec2(extent*.5))/extent;
 // Align heightfield samples with the 513 vertices, including edge texel centers.
 uv=(uv*512.0+vec2(.5))/513.0;
 VERTEX.y=textureLod(heights,uv,0.0).r-COLOR.a*.9;
 UV=uv;
}
void fragment() { ALBEDO=texture(colors,UV).rgb; }
