shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D vertex_frames : filter_nearest,repeat_disable;
uniform sampler2D skin : source_color,filter_nearest,repeat_disable;
uniform int clip_start=0;
uniform int clip_count=6;
uniform float clip_fps=6.0;
uniform float animation_clock=-1.0;
uniform bool clip_loop=true;
void vertex(){
 float clock=animation_clock<0.0?TIME:animation_clock;
 float f=clip_loop?mod(clock*clip_fps,float(clip_count)):min(clock*clip_fps,float(clip_count-1));
 int a=int(f);int b=clip_loop?(a+1)%clip_count:min(a+1,clip_count-1);
 VERTEX=mix(texelFetch(vertex_frames,ivec2(VERTEX_ID,clip_start+a),0).xyz,texelFetch(vertex_frames,ivec2(VERTEX_ID,clip_start+b),0).xyz,fract(f));
}
void fragment(){ALBEDO=texture(skin,UV).rgb;}
