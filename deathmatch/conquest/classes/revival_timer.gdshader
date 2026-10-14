shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float remaining : hint_range(0.0, 1.0) = 1.0;
void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float radius = length(p);
 if (radius > 1.0) discard;
 float angle = mod(atan(p.x, -p.y) + 6.2831853, 6.2831853) / 6.2831853;
 vec3 tint = mix(vec3(1.0, 0.15, 0.08), vec3(0.55, 1.0, 0.22), remaining);
 ALBEDO = radius > 0.91 ? vec3(0.95) : angle < remaining ? tint : vec3(0.045, 0.055, 0.06);
}
