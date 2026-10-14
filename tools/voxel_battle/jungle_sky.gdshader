shader_type sky;
render_mode disable_fog;
global uniform vec3 jungle_sky_stage;
uniform sampler2D skybox:filter_linear,repeat_disable;
vec3 layer_color(vec2 coords,float layer) {
	vec2 tile=vec2(mod(layer,4.0),floor(layer/4.0));
	vec2 uv=clamp(coords,vec2(.5/1024.0,.5/512.0),vec2(1.0-.5/1024.0,1.0-.5/512.0));
	return texture(skybox,(tile+uv)/vec2(4.0,2.0)).rgb;
}
void sky() {
	vec2 coords=vec2(fract(atan(EYEDIR.x,-EYEDIR.z)/6.28318530718+1.0),acos(clamp(EYEDIR.y,-1.0,1.0))/3.14159265359);
	COLOR=mix(layer_color(coords,jungle_sky_stage.x),layer_color(coords,jungle_sky_stage.y),jungle_sky_stage.z);
}
