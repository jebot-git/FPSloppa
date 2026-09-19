shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
// No ALPHA output: this is a solid visual curtain with no physics body.
uniform vec4 tint : source_color = vec4(0.25,0.8,1.0,1.0);
void fragment() {
 vec2 p=UV*2.0-1.0;
 float border=step(0.94,abs(p.x))+step(0.93,abs(p.y));
 float arch=1.0-smoothstep(0.008,0.023,abs(length(vec2(p.x*.8, p.y*.63+.27))-0.72));
 float ribs=1.0-smoothstep(.008,.015,abs(fract(UV.x*12.0)-.5));
 float grid=step(.975,fract(UV.y*48.0))*0.12+step(.982,fract(UV.x*36.0))*.08;
 float slow_scan=pow(.5+.5*sin(UV.y*22.0-TIME*.7),12.0)*.025;
 float chevron=1.0-smoothstep(.015,.025,abs(abs(p.x)-(.26+abs(p.y+.3)*.4)));
 float marks=chevron*step(-.63,p.y)*step(p.y,-.22);
 vec3 base=vec3(.012,.022,.035)+tint.rgb*(.038+grid+slow_scan);
 ALBEDO=base+tint.rgb*(border*.7+arch*.55+ribs*.035+marks*.25);
}
