#include "res://tools/voxel_battle/baked_lighting.gdshaderinc"
varying vec3 jungle_point;
#ifdef AVATAR_VERTEX_BAKED_LIGHT
varying vec3 avatar_baked_light;
#endif
render_mode unshaded, cull_disabled;
uniform sampler2D positions : filter_nearest, repeat_disable;
uniform sampler2D skin_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int reference_frame;
uniform int vertex_count;
uniform int position_width;
instance uniform vec3 animation_frames = vec3(0.0);
instance uniform bool tracked_arms = false;
instance uniform float ik_weight = 0.0;
instance uniform vec4 left_upper_q = vec4(0.0,0.0,0.0,1.0);
instance uniform vec3 left_upper_t = vec3(0.0);
instance uniform vec4 left_fore_q = vec4(0.0,0.0,0.0,1.0);
instance uniform vec3 left_fore_t = vec3(0.0);
instance uniform vec4 right_upper_q = vec4(0.0,0.0,0.0,1.0);
instance uniform vec3 right_upper_t = vec3(0.0);
instance uniform vec4 right_fore_q = vec4(0.0,0.0,0.0,1.0);
instance uniform vec3 right_fore_t = vec3(0.0);
instance uniform bool tracked_head = false;
instance uniform vec4 neck_q = vec4(0.0,0.0,0.0,1.0);
instance uniform vec3 neck_t = vec3(0.0);
instance uniform vec4 head_q = vec4(0.0,0.0,0.0,1.0);
instance uniform vec3 head_t = vec3(0.0);
vec3 rotate_point(vec4 q,vec3 p) { return p+2.0*cross(q.xyz,cross(q.xyz,p)+q.w*p); }
vec3 frame_position(int frame, int id) {
    int address = frame * vertex_count + id;
    return texelFetch(positions, ivec2(address % position_width, address / position_width), 0).xyz;
}
void vertex() {
    int id = int(round(UV2.x));
    bool seated_bike=animation_frames.z<0.0;
    VERTEX = seated_bike ? frame_position(reference_frame,id) : mix(frame_position(int(animation_frames.x), id), frame_position(int(animation_frames.y), id), animation_frames.z);
    // CUSTOM0 = authored region (0 body, 1/2 arms, 3 neck/head),
    // inter-bone blend, influence. Complete welded seams share identical weights.
    vec3 weights=CUSTOM0.xyz;
    if (ik_weight > 0.0 && tracked_arms && (weights.x==1.0 || weights.x==2.0)) {
        vec3 p=frame_position(reference_frame,id);
        vec3 upper=weights.x==1.0 ? rotate_point(left_upper_q,p)+left_upper_t : rotate_point(right_upper_q,p)+right_upper_t;
        vec3 fore=weights.x==1.0 ? rotate_point(left_fore_q,p)+left_fore_t : rotate_point(right_fore_q,p)+right_fore_t;
        VERTEX=mix(VERTEX,mix(upper,fore,weights.y),weights.z*ik_weight);
    }
    if (ik_weight > 0.0 && tracked_head && weights.x==3.0) {
        vec3 p=frame_position(reference_frame,id);
        vec3 n=rotate_point(neck_q,p)+neck_t;
        vec3 h=rotate_point(head_q,p)+head_t;
        VERTEX=mix(VERTEX,mix(n,h,weights.y),weights.z*ik_weight);
    }
    // Stable straddling pose: thigh forward, shin down, feet beside the hull.
    // Use reference positions below the pelvis so the running clip cannot leak in.
    if (seated_bike && weights.x==0.0) {
        vec3 p=frame_position(reference_frame,id);
        if (p.y<0.82) {
            float t=clamp((0.78-p.y)/0.78,0.0,1.0);
            vec3 hip=vec3(sign(p.x)*0.18,0.78,0.0);
            vec3 knee=vec3(sign(p.x)*0.29,0.71,-0.36);
            vec3 foot=vec3(sign(p.x)*0.33,0.32,-0.28);
            vec3 axis=t<0.5 ? mix(hip,knee,t*2.0) : mix(knee,foot,(t-0.5)*2.0);
            VERTEX=axis+vec3(p.x-sign(p.x)*0.18,0.0,p.z);
        }
    }
	jungle_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
#ifdef AVATAR_VERTEX_BAKED_LIGHT
 avatar_baked_light=jungle_baked_light(jungle_point);
#endif
}
void fragment() {
#ifdef AVATAR_VERTEX_BAKED_LIGHT
 vec3 baked=avatar_baked_light;
#else
 vec3 baked=jungle_baked_light(jungle_point);
#endif
 ALBEDO=texture(skin_atlas,UV).rgb*(baked+cq_headlight(jungle_point));
}
