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
uniform bool has_glow = false;
uniform bool alpha_cutout = false;
uniform vec4 base_colour : source_color = vec4(1.0);
// Opt-in cosmetic conveyor textures; all ordinary maps retain the zero offset.
uniform vec2 map_uv_offset = vec2(0.0);
void fragment() {
    vec2 surface_uv = UV + map_uv_offset;
    vec4 texel;
    if (texture_filter_mode == 0) texel = texture(base_nearest, surface_uv);
    else if (texture_filter_mode == 1) texel = texture(base_linear, surface_uv);
    else texel = texture(base_texture, surface_uv);
    if (alpha_cutout && texel.a < 0.5) discard;
    vec3 base = texel.rgb * base_colour.rgb;
    vec3 baked = texture(bake_texture, UV2).rgb;
    // The bake supplies static light and shadows; a restrained live component
    // retains muzzle/projectile illumination without doubling the map lighting.
    ALBEDO = base * 0.10;
    EMISSION = base * clamp(sqrt(baked) * 2.0, vec3(0.25), vec3(1.5));
    if (has_glow) {
        vec3 glow;
        if (texture_filter_mode == 0) glow = texture(glow_nearest, UV).rgb;
        else if (texture_filter_mode == 1) glow = texture(glow_linear, UV).rgb;
        else glow = texture(glow_texture, UV).rgb;
        EMISSION += glow * 0.65;
    }
    ROUGHNESS = 1.0;
}
