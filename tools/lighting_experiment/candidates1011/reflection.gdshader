shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bake_texture : filter_linear, repeat_disable;
uniform sampler2D glow_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// All filter choices share one shader/pipeline. The aliases use the same image.
uniform sampler2D base_nearest : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D base_linear : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D glow_nearest : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D glow_linear : source_color, filter_linear_mipmap, repeat_enable;
uniform int texture_filter_mode = 2;
// FPSloppa baked lighting: cached scenes are upgraded by filtering.gd.
uniform bool contrast_lighting = false;
uniform bool has_glow = false;
uniform bool alpha_cutout = false;
uniform vec4 base_colour : source_color = vec4(1.0);
// Opt-in cosmetic conveyor textures; all ordinary maps retain the zero offset.
uniform vec2 map_uv_offset = vec2(0.0);
uniform bool liquid_warp = false;
uniform bool surface_variation = false;

// ISOLATED recommendation 10/11 prototype. Never referenced by production.
uniform sampler2D candidate_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 0.35;
uniform float reflection_strength = 0.20;
uniform samplerCube candidate_probe : source_color, filter_linear_mipmap;
uniform vec3 candidate_probe_position;
uniform vec3 candidate_probe_extent = vec3(24.0);
varying vec3 candidate_world_position;
varying vec3 candidate_world_normal;
void vertex() {
    candidate_world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    candidate_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec2 surface_uv = UV + map_uv_offset;
    if (liquid_warp) surface_uv += sin(UV.yx * 6.2831853 + vec2(TIME * 0.8, TIME * 0.7)) * 0.025;
    vec4 texel;
    if (texture_filter_mode == 0) texel = texture(base_nearest, surface_uv);
    else if (texture_filter_mode == 1) texel = texture(base_linear, surface_uv);
    else texel = texture(base_texture, surface_uv);
    if (alpha_cutout && texel.a < 0.5) discard;
    vec3 base = texel.rgb * base_colour.rgb;
    if (surface_variation) base *= COLOR.rgb;
    vec4 candidate_surface = texture(candidate_detail, surface_uv);
    vec3 baked = texture(bake_texture, UV2).rgb;
    // The bake supplies static light and shadows; a restrained live component
    // retains muzzle/projectile illumination without doubling the map lighting.
    ALBEDO = base * 0.10;
    EMISSION = base * clamp(sqrt(baked) * 2.0, vec3(0.25), vec3(1.5));
    if (contrast_lighting) {
        // Calibrated shared shoulder: retain coloured gradients while lifting
        // readable midtones. Neutral floor, no per-channel clipping or exposure
        // adaptation. Same samples/pass as the original Contrast response.
        float peak = max(baked.r, max(baked.g, baked.b));
        EMISSION = base * (vec3(0.08) + baked * (2.6 / (0.65 + peak)));
    }
    if (reflection_strength > 0.0) {
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
    if (has_glow) {
        vec3 glow;
        if (texture_filter_mode == 0) glow = texture(glow_nearest, surface_uv).rgb;
        else if (texture_filter_mode == 1) glow = texture(glow_linear, surface_uv).rgb;
        else glow = texture(glow_texture, surface_uv).rgb;
        EMISSION += glow * 0.65;
    }
    ROUGHNESS = 1.0;
}
