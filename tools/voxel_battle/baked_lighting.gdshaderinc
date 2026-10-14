global uniform bool jungle_baked_enabled;
global uniform float jungle_day_mix;
global uniform float jungle_extent;
global uniform sampler2D jungle_light_atlas;
global uniform sampler2D jungle_dawn_atlas;
global uniform vec3 jungle_sun_mix;
global uniform vec3 jungle_sky_color;
vec3 jungle_irradiance(vec4 field,float dawn) {
	vec3 direct=vec3(1.0,.95,.85)*field.r*jungle_sun_mix.x;
	direct+=vec3(1.0,.48,.22)*field.a*jungle_sun_mix.y;
	direct+=vec3(1.0,.66,.42)*dawn*jungle_sun_mix.z;
	return direct+jungle_sky_color*field.b*.48+vec3(1.0,.66,.34)*field.g*(1.0-jungle_day_mix);
}
vec3 jungle_baked_light(vec3 point) {
	if (!jungle_baked_enabled) return vec3(1.0);
	vec2 uv=clamp(point.xz/jungle_extent+vec2(0.5),vec2(0.0),vec2(1.0));
	return jungle_irradiance(texture(jungle_light_atlas,uv),texture(jungle_dawn_atlas,uv).r);
}
