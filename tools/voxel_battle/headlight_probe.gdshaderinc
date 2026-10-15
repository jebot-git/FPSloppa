// Comparison fixture only: identical unshadowed cone math for both sampling modes.
uniform bool headlights_on=false;
uniform bool headlights_per_pixel=false;
uniform int headlight_count=2;
uniform vec4 headlight_positions[8]; // xyz world position, w range in metres
uniform vec4 headlight_axes[8]; // xyz normalized forward direction, w intensity
varying vec3 headlight_vertex;
vec3 headlight_sample(vec3 point) {
 float energy=0.0;
 for(int i=0;i<8;i++) {
  if(i>=headlight_count)break;
  vec3 delta=point-headlight_positions[i].xyz;
  float distance=length(delta), range=headlight_positions[i].w;
  float cone=smoothstep(0.91354546,0.97814760,dot(delta/max(distance,.001),headlight_axes[i].xyz));
  float fade=max(0.0,1.0-distance/range);
  energy+=headlight_axes[i].w*cone*fade*fade/(1.0+.015*distance*distance);
 }
 return vec3(1.0,.94,.80)*energy;
}
vec3 headlight_value(vec3 point) {
 if(!headlights_on)return vec3(0.0);
 return headlights_per_pixel?headlight_sample(point):headlight_vertex;
}
