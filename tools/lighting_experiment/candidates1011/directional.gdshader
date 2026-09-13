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
uniform sampler2D candidate_direction : filter_linear, repeat_disable;

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
    vec4 incoming = texture(candidate_direction, UV2);
    vec3 direction_raw = (incoming.rgb * 255.0 - vec3(128.0)) / 128.0;
    vec3 light_direction = direction_raw / max(length(direction_raw),0.001);
    // ericw stores (+S,-T,N). The authored height gradients use that same basis.
    vec3 detail_normal = normalize(vec3((candidate_surface.rg * 2.0 - 1.0) * normal_strength, max(candidate_surface.b*2.0-1.0,0.1)));
    // Subtract the flat-face incidence before modulation: flat normal = exact
    // baseline. Only the estimated direct portion changes; ambient/bounce remain.
    float incidence_delta = (dot(detail_normal,light_direction)-light_direction.z)/max(light_direction.z,0.25);
    float direct_fraction = min(incoming.a,0.75) * smoothstep(0.10,0.35,light_direction.z);
    baked *= 1.0 + direct_fraction * clamp(incidence_delta,-0.5,0.5);
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
    if (has_glow) {
        vec3 glow;
        if (texture_filter_mode == 0) glow = texture(glow_nearest, surface_uv).rgb;
        else if (texture_filter_mode == 1) glow = texture(glow_linear, surface_uv).rgb;
        else glow = texture(glow_texture, surface_uv).rgb;
        EMISSION += glow * 0.65;
    }
    ROUGHNESS = 1.0;
}
