#[compute]
#version 450
// Classic skyline columns, sampling the SAME bounded tile cache as raster terrain.
layout(local_size_x=64,local_size_y=1,local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2DArray height_tiles;
layout(set=0,binding=1) uniform sampler2DArray color_tiles;
layout(rgba8,set=0,binding=2) uniform writeonly image2D image_out;
layout(r32f,set=0,binding=3) uniform writeonly image2D depth_out;
layout(set=0,binding=4) uniform sampler2D pages;
layout(set=0,binding=5) uniform sampler2D coarse_heights;
layout(set=0,binding=6) uniform sampler2D coarse_colors;
layout(push_constant,std430) uniform Parameters {
 vec4 camera;
 vec4 view;
 vec4 terrain;
} p;
void main() {
 int x=int(gl_GlobalInvocationID.x);int width=int(p.view.x);int height=int(p.view.y);
 if(x>=width)return;
 for(int y=0;y<height;y++) {
  float t=float(y)/float(height);
  vec3 sky=mix(vec3(.20,.34,.47),vec3(.67,.73,.73),clamp(t*1.8,0.0,1.0));
  imageStore(image_out,ivec2(x,y),vec4(sky,1.0));imageStore(depth_out,ivec2(x,y),vec4(p.view.w));
 }
 float yaw=p.camera.w;vec2 forward=vec2(-sin(yaw),-cos(yaw));vec2 right=vec2(cos(yaw),-sin(yaw));
 float sx=(float(x)+.5-p.view.x*.5)/p.view.z;
 vec2 direction=forward+right*sx;float distance=.4;int skyline=height;
 for(int step=0;step<2048;step++) {
  if(distance>p.view.w||skyline<=0)break;
  vec2 pos=p.camera.xz+direction*distance;
  vec2 uv=(pos+p.terrain.x*.5)/p.terrain.x;
  if(any(lessThan(uv,vec2(0.0)))||any(greaterThanEqual(uv,vec2(1.0)))) {distance+=p.terrain.z+distance*p.terrain.w;continue;}
  ivec2 cell=ivec2(floor(uv*64.0));
  float layer=texelFetch(pages,cell,0).r-1.0;
  float h;vec3 color;
  if(layer>=0.0) {
   vec2 local=(fract(uv*64.0)*64.0+vec2(.5))/65.0;
   h=textureLod(height_tiles,vec3(local,layer),0.0).r;
   color=textureLod(color_tiles,vec3(local,layer),0.0).rgb;
  } else {
   vec2 coarse_uv=(uv*128.0+vec2(.5))/129.0;
   h=textureLod(coarse_heights,coarse_uv,0.0).r;
   color=textureLod(coarse_colors,coarse_uv,0.0).rgb;
  }
  float projected=p.view.y*.5+(p.camera.y-h)*p.view.z/distance;
  int top=clamp(int(ceil(projected)),0,height);
  if(top<skyline) {
   for(int y=top;y<skyline;y++) {
    imageStore(image_out,ivec2(x,y),vec4(color,1.0));
    imageStore(depth_out,ivec2(x,y),vec4(distance));
   }
   skyline=top;
  }
  distance+=p.terrain.z+distance*p.terrain.w;
 }
}
