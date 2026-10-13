shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D positions : filter_nearest, repeat_disable;
uniform sampler2D skin_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int reference_frame;
uniform int vertex_count;
uniform int position_width;
instance uniform vec3 animation_frames = vec3(0.0);
instance uniform bool tracked_arms = false;
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
    VERTEX = mix(frame_position(int(animation_frames.x), id), frame_position(int(animation_frames.y), id), animation_frames.z);
    // CUSTOM0 = authored region (0 body, 1/2 arms, 3 neck/head),
    // inter-bone blend, influence. Complete welded seams share identical weights.
    vec3 weights=CUSTOM0.xyz;
    vec3 p=frame_position(reference_frame,id);
    if (tracked_arms && (weights.x==1.0 || weights.x==2.0)) {
        vec3 upper=weights.x==1.0 ? rotate_point(left_upper_q,p)+left_upper_t : rotate_point(right_upper_q,p)+right_upper_t;
        vec3 fore=weights.x==1.0 ? rotate_point(left_fore_q,p)+left_fore_t : rotate_point(right_fore_q,p)+right_fore_t;
        VERTEX=mix(VERTEX,mix(upper,fore,weights.y),weights.z);
    }
    if (tracked_head && weights.x==3.0) {
        vec3 n=rotate_point(neck_q,p)+neck_t;
        vec3 h=rotate_point(head_q,p)+head_t;
        VERTEX=mix(VERTEX,mix(n,h,weights.y),weights.z);
    }
}
void fragment() { ALBEDO = texture(skin_atlas, UV).rgb; }
