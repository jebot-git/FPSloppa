shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec4 pools;
void vertex() {pools=INSTANCE_CUSTOM;}
void fragment() {
	float edge=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.5);
	vec2 grid=UV*vec2(48.0,24.0);
	float lines=1.0-smoothstep(0.025,0.075,min(abs(fract(grid.x)-0.5),abs(fract(grid.y)-0.5)));
	vec3 colour=mix(vec3(0.08,0.42,0.74),vec3(0.1,0.75,0.42),step(0.001,pools.g));
	ALBEDO=mix(colour,vec3(0.7,1.0,0.85),pools.b);
	ALPHA=(0.025+edge*0.22+lines*0.065+pools.b*0.13)*mix(0.65,1.0,pools.r);
}
