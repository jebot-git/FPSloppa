// Flattened convex solid cells from a conservatively pruned BSP domain.
// No traversal stack: clip a segment against each solid cell's half-spaces.
uniform sampler2D occlusion_tree : filter_nearest, repeat_disable;
uniform bool occlusion_enabled = true;
uniform int occlusion_local_heads[8];
vec4 occlusion_texel(int index) {
    int width = textureSize(occlusion_tree, 0).x;
    return texelFetch(occlusion_tree, ivec2(index % width, index / width), 0);
}
bool occlusion_clear_emitter(vec3 a, vec3 b, int emitter) {
    if (!occlusion_enabled) return true;
    int cursor = occlusion_local_heads[emitter];
    int cells = int(occlusion_texel(cursor).x);
    cursor++;
    if (cells > 32) return false;
    vec3 delta = b - a;
    for (int cell = 0; cell < 32; cell++) {
        if (cell >= cells) break;
        int planes = int(occlusion_texel(cursor).x);
        cursor++;
        if (planes > 32) return false;
        float enter = 0.0;
        float leave = 1.0;
        for (int p = 0; p < 32; p++) {
            if (p >= planes || enter > leave) break;
            vec4 plane = occlusion_texel(cursor + p);
            float start = dot(plane.xyz, a) - plane.w;
            float slope = dot(plane.xyz, delta);
            if (abs(slope) < 0.0000001) {
                if (start > 0.0) { enter = 2.0; leave = -1.0; }
            } else {
                float hit = -start / slope;
                if (slope < 0.0) enter = max(enter, hit);
                else leave = min(leave, hit);
            }
        }
        if (enter <= leave) return false;
        cursor += planes;
    }
    return true;
}
bool occlusion_clear(vec3 a, vec3 b) { return occlusion_clear_emitter(a,b,0); }
