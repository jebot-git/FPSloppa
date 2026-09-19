// Exact segment/solid-leaf traversal of a Quake BSP. No screen-space dependency.
uniform sampler2D weapon_occlusion_tree : filter_nearest, repeat_disable;
uniform int weapon_occlusion_nodes = 0;
uniform int weapon_occlusion_head = -1;
uniform bool weapon_occlusion_enabled = true;
uniform bool weapon_occlusion_local = false;
uniform int weapon_occlusion_local_heads[2];
uniform int weapon_occlusion_brush_count = 0;
uniform int weapon_occlusion_brush_heads[4];
uniform mat4 weapon_occlusion_brush_inverse[4];

vec4 weapon_occlusion_texel(int index) {
    int width = textureSize(weapon_occlusion_tree, 0).x;
    return texelFetch(weapon_occlusion_tree, ivec2(index % width, index / width), 0);
}
bool weapon_occlusion_clear_tree(vec3 a, vec3 b, int root) {
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
        if (node >= weapon_occlusion_nodes) return false;
        vec4 plane = weapon_occlusion_texel(node * 2);
        vec4 children = weapon_occlusion_texel(node * 2 + 1);
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
bool weapon_occlusion_clear_head(vec3 a, vec3 b, int root) {
    if (!weapon_occlusion_enabled) return true;
    if (!weapon_occlusion_clear_tree(a, b, root)) return false;
    for (int i = 0; i < weapon_occlusion_brush_count; i++) {
        vec3 local_a = (weapon_occlusion_brush_inverse[i] * vec4(a, 1.0)).xyz;
        vec3 local_b = (weapon_occlusion_brush_inverse[i] * vec4(b, 1.0)).xyz;
        if (!weapon_occlusion_clear_tree(local_a, local_b, weapon_occlusion_brush_heads[i])) return false;
    }
    return true;
}
bool weapon_occlusion_clear(vec3 a, vec3 b) {
    return weapon_occlusion_clear_head(a,b,weapon_occlusion_head);
}
bool weapon_occlusion_clear_emitter(vec3 a, vec3 b, int emitter) {
    return weapon_occlusion_clear_head(a,b,weapon_occlusion_local ? weapon_occlusion_local_heads[emitter] : weapon_occlusion_head);
}

// At most two nearby weapon sources on desktop and XR; evaluated in the baked pass.
uniform int weapon_count = 0;
uniform vec4 weapon_start[2];
uniform vec4 weapon_end[2];
uniform vec4 weapon_color[2];
vec3 weapon_illumination(vec3 position, vec3 normal) {
    vec3 result = vec3(0.0);
    for (int i = 0; i < min(weapon_count, 2); i++) {
        vec3 a = weapon_start[i].xyz;
        vec3 segment = weapon_end[i].xyz - a;
        float t = clamp(dot(position - a, segment) / max(dot(segment, segment), .00001), 0.0, 1.0);
        vec3 source = a + t * segment;
        vec3 toward = source - position;
        float d = dot(toward, toward);
        float falloff = max(0.0, 1.0 - d / max(.00001, weapon_start[i].w * weapon_start[i].w));
        float facing = max(dot(normal, toward * inversesqrt(max(d, .00001))), 0.0);
        if (falloff <= 0.0 || facing <= 0.0) continue;
        if (!weapon_occlusion_clear_emitter(position + normal * .002, source, i)) continue;
        result += weapon_color[i].rgb * weapon_end[i].w * falloff * falloff * facing;
    }
    return min(result, vec3(.55));
}
