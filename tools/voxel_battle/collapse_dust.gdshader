shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
global uniform float jungle_day_mix;
void vertex() {
 mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
 billboard[0].xyz *= length(MODEL_MATRIX[0].xyz);
 billboard[1].xyz *= length(MODEL_MATRIX[1].xyz);
 billboard[2].xyz *= length(MODEL_MATRIX[2].xyz);
 MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 ALBEDO = vec3(0.42, 0.39, 0.32) * mix(0.12, 1.0, jungle_day_mix);
 float radial=max(0.0,1.0-length(UV-vec2(.5))*2.0);
 ALPHA = radial*radial*.45*mix(.35,1.0,noise(UV*9.0));
}
