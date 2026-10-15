shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
void fragment() {
 vec3 eye=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
 // Bounded optical parallax keeps a small bright dot visible across the sight window.
 vec2 center=vec2(.5);
 float radius=length(UV-center);
 if(eye.z<=0.0 || radius>.075)discard;
 ALBEDO=vec3(1.0,.015,.005);EMISSION=ALBEDO*5.0;
 ALPHA=1.0-smoothstep(.035,.075,radius);
}
