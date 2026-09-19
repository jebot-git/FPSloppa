shader_type spatial;
render_mode unshaded;
uniform vec4 tint : source_color;
uniform bool gothic = false;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float edge=step(abs(p.x),.9)*step(abs(p.y),.96);
 float lead=(1.0-step(.07,abs(fract(UV.x*4.0)-.5)))+(1.0-step(.035,abs(fract(UV.y*8.0)-.5)));
 float arch=step(length(vec2(p.x,p.y*.7+.35)),1.05);
 float pane=gothic?arch:1.0;
 float faceted=.45+.22*sin(floor(UV.x*4.0)*4.0+floor(UV.y*8.0)*2.0);
 ALBEDO=mix(vec3(.015,.025,.035),tint.rgb*faceted,edge*pane*(1.0-clamp(lead,0.0,1.0)));
}
