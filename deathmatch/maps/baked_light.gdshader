shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D base_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D bake_texture : filter_linear, repeat_disable;
uniform sampler2D glow_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool has_glow = false;
uniform bool alpha_cutout = false;
uniform vec4 base_colour : source_color = vec4(1.0);
void fragment() {
    vec4 texel = texture(base_texture, UV);
    if (alpha_cutout && texel.a < 0.5) discard;
    vec3 base = texel.rgb * base_colour.rgb;
    vec3 baked = texture(bake_texture, UV2).rgb;
    // The bake supplies static light and shadows; a restrained live component
    // retains muzzle/projectile illumination without doubling the map lighting.
    ALBEDO = base * 0.10;
    EMISSION = base * clamp(sqrt(baked) * 2.0, vec3(0.25), vec3(1.5));
    if (has_glow) EMISSION += texture(glow_texture, UV).rgb * 0.65;
    ROUGHNESS = 1.0;
}
