from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tools/lighting_experiment/candidates1011'
original=(ROOT/'deathmatch/maps/baked_light.gdshader').read_text()
for variant in ['reflection','directional','combined']:
 headers='''
// ISOLATED recommendation 10/11 prototype. Never referenced by production.
uniform sampler2D candidate_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 0.35;
uniform float reflection_strength = 0.20;
'''
 if variant!='reflection':headers+='uniform sampler2D candidate_direction : filter_linear, repeat_disable;\n'
 if variant!='directional':headers+='''uniform samplerCube candidate_probe : source_color, filter_linear_mipmap;
uniform vec3 candidate_probe_position;
uniform vec3 candidate_probe_extent = vec3(24.0);
varying vec3 candidate_world_position;
varying vec3 candidate_world_normal;
void vertex() {
    candidate_world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    candidate_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
'''
 shader=original.replace('void fragment() {',headers+'\nvoid fragment() {')
 shader=shader.replace('    vec3 baked = texture(bake_texture, UV2).rgb;','    vec4 candidate_surface = texture(candidate_detail, surface_uv);\n    vec3 baked = texture(bake_texture, UV2).rgb;')
 if variant!='reflection':shader=shader.replace('    // The bake supplies','''    vec4 incoming = texture(candidate_direction, UV2);
    vec3 direction_raw = (incoming.rgb * 255.0 - vec3(128.0)) / 128.0;
    vec3 light_direction = direction_raw / max(length(direction_raw),0.001);
    // ericw stores (+S,-T,N). The authored height gradients use that same basis.
    vec3 detail_normal = normalize(vec3((candidate_surface.rg * 2.0 - 1.0) * normal_strength, max(candidate_surface.b*2.0-1.0,0.1)));
    // Subtract the flat-face incidence before modulation: flat normal = exact
    // baseline. Only the estimated direct portion changes; ambient/bounce remain.
    float incidence_delta = (dot(detail_normal,light_direction)-light_direction.z)/max(light_direction.z,0.25);
    float direct_fraction = min(incoming.a,0.75) * smoothstep(0.10,0.35,light_direction.z);
    baked *= 1.0 + direct_fraction * clamp(incidence_delta,-0.5,0.5);
    // The bake supplies''')
 if variant!='directional':shader=shader.replace('    if (has_glow) {','''    if (reflection_strength > 0.0) {
        vec3 n = normalize(candidate_world_normal);
        vec3 incident = normalize(candidate_world_position-CAMERA_POSITION_WORLD);
        vec3 ray = reflect(incident,n);
        // Approximate box projection around a local capture; fade before its edge.
        vec3 safe_ray = mix(vec3(-1.0),vec3(1.0),greaterThanEqual(ray,vec3(0.0))) * max(abs(ray),vec3(0.0001));
        vec3 a = (candidate_probe_position-candidate_probe_extent-candidate_world_position)/safe_ray;
        vec3 b = (candidate_probe_position+candidate_probe_extent-candidate_world_position)/safe_ray;
        vec3 far_plane = max(a,b);
        float reach = max(0.0,min(far_plane.x,min(far_plane.y,far_plane.z)));
        vec3 lookup = candidate_world_position+ray*reach-candidate_probe_position;
        vec3 reflected = textureLod(candidate_probe,lookup,3.0).rgb;
        float fresnel = pow(1.0-clamp(abs(dot(-incident,n)),0.0,1.0),4.0);
        float local_fade = 1.0-smoothstep(12.0,22.0,length(candidate_world_position-candidate_probe_position));
        float weight = candidate_surface.a * reflection_strength * (0.15+0.85*fresnel) * local_fade;
        EMISSION = mix(EMISSION,reflected*0.65,clamp(weight,0.0,0.35));
    }
    if (has_glow) {''')
 (OUT/(variant+'.gdshader')).write_text(shader)
