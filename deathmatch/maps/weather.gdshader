shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;
uniform bool rain=false;
uniform vec3 focus;
uniform vec2 grid_origin;
uniform sampler2D roof_map : filter_nearest, repeat_disable;
varying float visibility;
void vertex() {
    vec4 seed=INSTANCE_CUSTOM;
    float speed=rain ? 19.0 : 1.8+seed.w;
    // World-anchored phases avoid precipitation being dragged with head motion.
    vec2 drift=rain ? vec2(TIME*1.0,0.0) : vec2(TIME*.45,sin(TIME*.3+seed.w*20.0));
    vec2 xz=focus.xz+mod(seed.xy*32.0+drift-focus.xz+16.0,vec2(32.0))-16.0;
    float y=focus.y+mod(seed.z*24.0-TIME*speed-focus.y+12.0,24.0)-12.0;
    vec3 p=vec3(xz.x,y,xz.y);
    vec2 roof_uv=(xz-grid_origin)/32.0;
    float roof=texture(roof_map,roof_uv).r;
    float edge=max(abs(p.x-focus.x),abs(p.z-focus.z));
    visibility=(1.0-smoothstep(13.0,16.0,edge))*smoothstep(1.0,2.0,distance(p,focus));
    visibility*=step(roof+.2,p.y)*step(0.0,roof_uv.x)*step(roof_uv.x,1.0)*step(0.0,roof_uv.y)*step(roof_uv.y,1.0);
    vec3 right=INV_VIEW_MATRIX[0].xyz;
    vec3 up=rain ? vec3(0.0,1.0,0.0) : INV_VIEW_MATRIX[1].xyz;
    float width=rain ? .012 : .035+seed.w*.025;
    float height=rain ? .5+seed.w*.3 : width;
    p+=right*VERTEX.x*width+up*VERTEX.y*height;
    VERTEX=(VIEW_MATRIX*vec4(p,1.0)).xyz;
}
void fragment() {
    float shape=rain ? (1.0-abs(UV.x*2.0-1.0)) : (1.0-smoothstep(.25,.5,length(UV-.5)));
    ALBEDO=rain ? vec3(.62,.73,.80) : vec3(.88,.93,1.0);
    ALPHA=shape*visibility*(rain ? .34 : .75);
}
