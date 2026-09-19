shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void vertex(){ VERTEX.x += sin(TIME*.35+VERTEX.y*.3)*.65; }
void fragment(){
 float fade=pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),2.0)*sin(UV.y*3.14159);
 float wisps=.5+.5*sin(UV.y*25.0+TIME*.5+sin(UV.x*19.0));
 ALBEDO=vec3(.34,.43,.51);ALPHA=fade*wisps*.14;
}
