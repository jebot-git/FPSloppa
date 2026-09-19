// Isolated experiment: bounded capsule illumination, no light nodes or shadows.
uniform int trajectory_count = 0;
uniform vec4 trajectory_start[8]; // xyz start, w radius
uniform vec4 trajectory_end[8]; // xyz end, w energy
uniform vec4 trajectory_color[8];
varying vec3 trajectory_world;
varying vec3 trajectory_normal;
void vertex() {
    trajectory_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    trajectory_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 trajectory_illumination() {
    vec3 illumination = vec3(0.0);
    for (int i = 0; i < trajectory_count; i++) {
        vec3 a = trajectory_start[i].xyz;
        vec3 segment = trajectory_end[i].xyz - a;
        float t = clamp(dot(trajectory_world - a, segment) / max(dot(segment, segment), 0.00001), 0.0, 1.0);
        vec3 toward = a + t * segment - trajectory_world;
        float distance_squared = dot(toward, toward);
        float radius = trajectory_start[i].w;
        float falloff = max(0.0, 1.0 - distance_squared / (radius * radius));
        float facing = max(dot(normalize(trajectory_normal), toward * inversesqrt(max(distance_squared, 0.00001))), 0.0);
        illumination += trajectory_color[i].rgb * trajectory_end[i].w * falloff * falloff * facing;
    }
    return illumination;
}
