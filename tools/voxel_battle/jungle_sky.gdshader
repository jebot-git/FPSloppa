shader_type sky;
render_mode disable_fog;
uniform vec3 sky_stage=vec3(0.0);
uniform vec3 weather_state=vec3(0.0);
uniform vec2 lightning_state=vec2(0.0);
uniform sampler2D skybox:filter_linear,repeat_disable;
vec3 layer_color(vec2 coords,float layer) {
	vec2 tile=vec2(mod(layer,4.0),floor(layer/4.0));
	vec2 uv=clamp(coords,vec2(.5/1024.0,.5/512.0),vec2(1.0-.5/1024.0,1.0-.5/512.0));
	return texture(skybox,(tile+uv)/vec2(4.0,2.0)).rgb;
}
float bolt_jitter(float elevation) {
 float cell=elevation*34.0;
 float a=fract(sin(floor(cell)*127.1+lightning_state.x*311.7)*43758.5453);
 float b=fract(sin((floor(cell)+1.0)*127.1+lightning_state.x*311.7)*43758.5453);
 return (mix(a,b,fract(cell))-.5)*.035;
}
void sky() {
	vec2 coords=vec2(fract(atan(EYEDIR.x,-EYEDIR.z)/6.28318530718+1.0),acos(clamp(EYEDIR.y,-1.0,1.0))/3.14159265359);
	COLOR=mix(layer_color(coords,sky_stage.x),layer_color(coords,sky_stage.y),sky_stage.z);
 float clouds=.9+.05*sin(EYEDIR.x*19.0+EYEDIR.z*13.0)+.05*sin(EYEDIR.z*31.0-EYEDIR.y*27.0);
 vec3 overcast=vec3(.45,.5,.56)*max(.001,length(COLOR))*.48;
 COLOR=mix(COLOR,overcast,clamp(weather_state.x*clouds,0.0,1.0));
 COLOR+=vec3(.65,.76,1.0)*weather_state.y*.5;
 if (lightning_state.y>.001) {
  float azimuth=atan(EYEDIR.x,EYEDIR.z);
  float offset=atan(sin(azimuth-lightning_state.x),cos(azimuth-lightning_state.x));
  float angle=abs(offset-bolt_jitter(EYEDIR.y));
  float bolt=(1.0-smoothstep(.001,.003,angle))+.15*(1.0-smoothstep(.003,.015,angle));
  bolt*=smoothstep(.02,.08,EYEDIR.y)*(1.0-smoothstep(.45,.55,EYEDIR.y));
  float fork=abs(offset-bolt_jitter(EYEDIR.y+1.0)*.5-(.27-EYEDIR.y)*.2);
  bolt+=(1.0-smoothstep(.0008,.002,fork))*smoothstep(.08,.12,EYEDIR.y)*(1.0-smoothstep(.25,.27,EYEDIR.y))*.65;
  COLOR+=vec3(.8,.9,1.0)*bolt*lightning_state.y*4.0;
 }
}
