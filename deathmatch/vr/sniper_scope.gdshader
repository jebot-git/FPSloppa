shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform sampler2D optic : source_color, filter_linear, repeat_disable;
uniform bool enabled=false;
uniform mat4 world_to_optic;
void fragment() {
 vec2 uv=UV-.5;
 if(length(uv)>.495) discard;
 vec3 eye=(world_to_optic*INV_VIEW_MATRIX*vec4(EYE_OFFSET,1.0)).xyz;
 float pupil=1.0-smoothstep(.015,.040,length(eye.xy));
 float rim=1.0-smoothstep(.46,.495,length(uv));
 float visible=(enabled && eye.z>.025 && eye.z<.34)?pupil*rim:0.0;
 // The LDR viewport is sRGB; source_color prevents a second gamma lift.
 vec3 scene=texture(optic,UV).rgb*.85;
 float line=(min(abs(uv.x),abs(uv.y))<.003 && max(abs(uv.x),abs(uv.y))>.027)?1.0:0.0;
 float dotmark=1.0-smoothstep(.003,.006,length(uv));
 scene=mix(scene,vec3(.03,.025,.02),line*.9);
 scene=mix(scene,vec3(.5,.04,.01),dotmark);
 ALBEDO=mix(vec3(.012,.019,.022),scene,visible);
 ROUGHNESS=1.0;
}
