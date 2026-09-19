// Exact segment/solid-leaf traversal of a Quake BSP. No screen-space dependency.
uniform sampler2D occlusion_tree : filter_nearest, repeat_disable;
uniform int occlusion_nodes = 0;
uniform int occlusion_head = -1;
uniform bool occlusion_enabled = true;
uniform bool occlusion_local = false;
uniform int occlusion_local_heads[8];
uniform int occlusion_brush_count = 0;
uniform int occlusion_brush_heads[4];
uniform mat4 occlusion_brush_inverse[4];

vec4 occlusion_texel(int index) {
    int width = textureSize(occlusion_tree, 0).x;
    return texelFetch(occlusion_tree, ivec2(index % width, index / width), 0);
}
bool occlusion_clear_tree(vec3 a, vec3 b, int root) {
    int pending_node[32];
    vec2 pending_interval[32];
    int pending = 0;
    int node = root;
    vec2 interval = vec2(0.0, 1.0);
    for (int visit = 0; visit < 192; visit++) {
        if (node == -2) return false;
        if (node < 0) {
            if (pending == 0) return true;
            pending--;
            node = pending_node[pending];
            interval = pending_interval[pending];
            continue;
        }
        // Corrupt trees, exhausted stack or visit budget fail dark, never leak.
        if (node >= occlusion_nodes) return false;
        vec4 plane = occlusion_texel(node * 2);
        vec4 children = occlusion_texel(node * 2 + 1);
        float da = dot(plane.xyz, mix(a, b, interval.x)) - plane.w;
        float db = dot(plane.xyz, mix(a, b, interval.y)) - plane.w;
        int front = int(children.x);
        int back = int(children.y);
        if (da >= 0.0 && db >= 0.0) { node = front; continue; }
        if (da <= 0.0 && db <= 0.0) { node = back; continue; }
        float middle = mix(interval.x, interval.y, clamp(da / (da - db), 0.0, 1.0));
        if (pending >= 32) return false;
        pending_node[pending] = da >= 0.0 ? back : front;
        pending_interval[pending] = vec2(middle, interval.y);
        pending++;
        node = da >= 0.0 ? front : back;
        interval.y = middle;
    }
    return false;
}
bool occlusion_clear_head(vec3 a, vec3 b, int root) {
    if (!occlusion_enabled) return true;
    if (!occlusion_clear_tree(a, b, root)) return false;
    for (int i = 0; i < occlusion_brush_count; i++) {
        vec3 local_a = (occlusion_brush_inverse[i] * vec4(a, 1.0)).xyz;
        vec3 local_b = (occlusion_brush_inverse[i] * vec4(b, 1.0)).xyz;
        if (!occlusion_clear_tree(local_a, local_b, occlusion_brush_heads[i])) return false;
    }
    return true;
}
bool occlusion_clear(vec3 a, vec3 b) {
    return occlusion_clear_head(a,b,occlusion_head);
}
bool occlusion_clear_emitter(vec3 a, vec3 b, int emitter) {
    return occlusion_clear_head(a,b,occlusion_local ? occlusion_local_heads[emitter] : occlusion_head);
}
