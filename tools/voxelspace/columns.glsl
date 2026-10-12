#[compute]
#version 450
// One GPU invocation per screen column: front-to-back VoxelSpace skyline fill.
layout(local_size_x=64,local_size_y=1,local_size_z=1) in;
layout(set=0,binding=0,std430) readonly buffer HeightMap { float h[]; } height_map;
layout(set=0,binding=1,std430) readonly buffer ColorMap { uint c[]; } color_map;
layout(rgba8,set=0,binding=2) uniform writeonly image2D image_out;
layout(r32f,set=0,binding=3) uniform writeonly image2D depth_out;
layout(push_constant,std430) uniform Parameters {
 vec4 camera; // x,y,z,yaw; yaw-only projection deliberately matches reference.
 vec4 view; // width,height,vertical focal length,far distance
 vec4 terrain; // extent,samples,distance step,adaptive step factor
} p;
vec3 decode(uint value) {return vec3(value&255u,(value>>8u)&255u,(value>>16u)&255u)/255.0;}
vec3 facade(vec3 c,uint kind,vec2 position,float world_y,float roof) {
 if(kind==0u)return c;
 if(world_y>roof-.25)return kind==1u?vec3(.27,.31,.30):vec3(.22,.24,.23);
 float storey=mod(world_y-2.4,4.0);
 vec2 windows=mod(position+vec2(100.0),5.0);
 float window=max(windows.x,windows.y);
 vec3 wall=vec3(.52,.35,.25);
 if(storey>1.05&&storey<2.75&&window>.9&&window<4.2&&kind==1u)wall=vec3(.17,.25,.29);
 if(storey<.14||storey>3.85)wall=vec3(.42,.43,.40);
 return wall;
}
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
  ivec2 cell=ivec2(uv*(p.terrain.y-1.0));int index=cell.y*int(p.terrain.y)+cell.x;
  float h=height_map.h[index];uint packed=color_map.c[index];uint kind=packed>>24u;
  float projected=p.view.y*.5+(p.camera.y-h)*p.view.z/distance;
  int top=clamp(int(ceil(projected)),0,height);
  if(top<skyline) {
   vec3 base=decode(packed);float fog=clamp(distance/p.view.w,0.0,.80);
   for(int y=top;y<skyline;y++) {
    float world_y=p.camera.y+(p.view.y*.5-(float(y)+.5))*distance/p.view.z;
    vec3 color=facade(base,kind,pos,world_y,h);
    color=mix(color,vec3(.58,.66,.70),fog*fog*.7);
    imageStore(image_out,ivec2(x,y),vec4(color,1.0));imageStore(depth_out,ivec2(x,y),vec4(distance));
   }
   skyline=top;
  }
  distance+=p.terrain.z+distance*p.terrain.w;
 }
}
