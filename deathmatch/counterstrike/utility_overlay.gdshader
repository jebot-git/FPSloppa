shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform float flash = 0.0;
uniform float smoke = 0.0;
void vertex(){POSITION=vec4(VERTEX.xy,1.0,1.0);}
void fragment(){ALBEDO=mix(vec3(.57,.60,.58),vec3(1.0),flash);ALPHA=flash+smoke*(1.0-flash);}
