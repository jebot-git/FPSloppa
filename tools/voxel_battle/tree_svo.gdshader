shader_type spatial;
render_mode unshaded, cull_front;
uniform sampler2D nodes : filter_nearest, repeat_disable;
varying vec3 local_position;
varying flat vec3 local_eye;
varying flat mat4 instance_model;
void vertex(){local_position=VERTEX;instance_model=MODEL_MATRIX;local_eye=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;}
vec2 box_interval(vec3 origin,vec3 inverse_ray,vec3 low,vec3 high){
	vec3 a=(low-origin)*inverse_ray; vec3 b=(high-origin)*inverse_ray;
	vec3 near=min(a,b);vec3 far=max(a,b);
	return vec2(max(max(near.x,near.y),near.z),min(min(far.x,far.y),far.z));
}
void fragment(){
	vec3 origin=local_eye;
	vec3 ray=normalize(local_position-origin);
	vec3 inverse_ray=1.0/(ray+vec3(0.000001));
	vec2 interval=box_interval(origin,inverse_ray,vec3(-7,0,-7),vec3(7,20,7));
	float t=max(interval.x,0.0)+0.0002;bool hit=false;float palette=0.0;
	vec3 point=origin+ray*t;
	for(int step=0;step<128;step++){
		if(t>interval.y)break;
		point=origin+ray*t;
		vec3 low=vec3(-7,0,-7);vec3 high=vec3(7,20,7);
		int index=0;vec4 node=vec4(0);
		for(int depth=0;depth<6;depth++){
			node=texelFetch(nodes,ivec2(index%1024,index/1024),0);
			if(node.a<1.5)break;
			vec3 mid=(low+high)*0.5;
			ivec3 c=ivec3(greaterThanEqual(point,mid));
			index=int(node.r)+c.x+c.y*2+c.z*4;
			low=mix(low,mid,vec3(c));high=mix(mid,high,vec3(c));
		}
		if(node.a>0.5 && node.a<1.5){hit=true;palette=node.g;break;}
		t=box_interval(origin,inverse_ray,low,high).y+0.0002;
	}
	if(!hit)discard;
	vec3 srgb=palette<1.5?vec3(.32,.23,.13):(palette<2.5?vec3(.19,.34,.17):vec3(.27,.43,.20));
	ALBEDO=pow(srgb,vec3(2.2));
	vec4 clip=PROJECTION_MATRIX*VIEW_MATRIX*instance_model*vec4(point,1.0);
	DEPTH=clip.z/clip.w;
}
