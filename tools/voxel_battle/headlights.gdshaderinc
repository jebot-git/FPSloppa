// Mixed vehicle headlights: terrain samples in vertex(), other receivers in fragment().
global uniform vec4 cq_lamp_position0;
global uniform vec4 cq_lamp_position1;
global uniform vec4 cq_lamp_position2;
global uniform vec4 cq_lamp_position3;
global uniform vec4 cq_lamp_axis0;
global uniform vec4 cq_lamp_axis1;
global uniform vec4 cq_lamp_axis2;
global uniform vec4 cq_lamp_axis3;
vec3 cq_lamp(vec3 point,vec4 position,vec4 axis) {
 if(position.w<=0.0)return vec3(0.0);
 vec3 offset=point-position.xyz;float distance=length(offset);
 if(distance>=position.w)return vec3(0.0);
 float cone=smoothstep(0.91354546,0.97814760,dot(offset/max(distance,0.001),axis.xyz));
 float fade=1.0-distance/position.w;
 return vec3(1.0,0.94,0.8)*(axis.w*cone*fade*fade/(1.0+0.015*distance*distance));
}
vec3 cq_headlight(vec3 point) {
 return cq_lamp(point,cq_lamp_position0,cq_lamp_axis0)+cq_lamp(point,cq_lamp_position1,cq_lamp_axis1)+cq_lamp(point,cq_lamp_position2,cq_lamp_axis2)+cq_lamp(point,cq_lamp_position3,cq_lamp_axis3);
}
