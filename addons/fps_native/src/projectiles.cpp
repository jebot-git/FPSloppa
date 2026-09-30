#include "projectiles.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/static_body3d.hpp>
#include <godot_cpp/classes/animatable_body3d.hpp>
#include <godot_cpp/classes/area3d.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;
static constexpr double INF=std::numeric_limits<double>::infinity();
void FPSProjectiles::_bind_methods() {
 ClassDB::bind_method(D_METHOD("configure_bodies","rows"),&FPSProjectiles::configure_bodies);
 ClassDB::bind_method(D_METHOD("build","players","fighters","movement"),&FPSProjectiles::build);
 ClassDB::bind_method(D_METHOD("candidates","start","end","radius"),&FPSProjectiles::candidates);
 ClassDB::bind_static_method("FPSProjectiles",D_METHOD("box_fraction","start","end","half","radius"),&FPSProjectiles::box_fraction);
 ClassDB::bind_method(D_METHOD("player_fraction","start","end","height","yaw","radius"),&FPSProjectiles::player_fraction);
 ClassDB::bind_static_method("FPSProjectiles",D_METHOD("trace_structures","buildings","start","end","limit","radius"),&FPSProjectiles::trace_structures);
 ClassDB::bind_method(D_METHOD("trace","game","start","end","exclude","radius","movement","candidates","historical"),&FPSProjectiles::trace,DEFVAL(Dictionary()));
 ClassDB::bind_method(D_METHOD("step","game","delta","movement","weapons","native_trace"),&FPSProjectiles::step);
}
FPSProjectiles::FPSProjectiles() {
 ray.instantiate();ray->set_collision_mask(1);
 shape_query.instantiate();sphere.instantiate();shape_query->set_shape(sphere);shape_query->set_collision_mask(1);shape_query->set_margin(.001);
}
uint64_t FPSProjectiles::key(int x,int z){return (uint64_t(uint32_t(x))<<32)|uint32_t(z);}
bool FPSProjectiles::safe(Vector3 p){return p.is_finite() && std::abs(p.x)<=1000000 && std::abs(p.z)<=1000000;}
bool FPSProjectiles::large(int x,int z,int xx,int zz){int64_t w=int64_t(xx)-x+1,d=int64_t(zz)-z+1;return w<1||d<1||w>64||d>64||w*d>64;}
void FPSProjectiles::configure_bodies(const Array &rows) {
 bodies.clear();bodies.resize(rows.size());
 for(int i=0;i<rows.size();++i){Array parts=rows[i];for(int j=0;j<parts.size();++j){Dictionary part=parts[j];Transform3D pose=part["pose"];bodies[i].push_back({pose.affine_inverse(),pose.origin,Vector3(part["size"])*.5,pose});}}
}
void FPSProjectiles::build(const Dictionary &players,const Dictionary &fighters,const Dictionary &movement) {
 cells.clear();overflow.clear();ids.clear();Array keys=players.keys();
 for(int i=0;i<keys.size();++i) {
  Variant id=keys[i];Dictionary state=players[id];if(bool(state["dead"])||bool(state["spectator"]))continue;
  int order=ids.size();ids.push_back(id);Node3D *fighter=Object::cast_to<Node3D>(fighters[id]);
  Vector3 current=fighter->get_position(),previous=current;
  if(movement.has(id)){Dictionary old=movement[id];if(old["serial"]==state["serial"])previous=old["position"];}
  if(!safe(current)||!safe(previous)){overflow.push_back(order);continue;}
  int x=std::floor((std::min(current.x,previous.x)-1.500001)/4),z=std::floor((std::min(current.z,previous.z)-1.500001)/4);
  int xx=std::floor((std::max(current.x,previous.x)+1.500001)/4),zz=std::floor((std::max(current.z,previous.z)+1.500001)/4);
  if(large(x,z,xx,zz)){overflow.push_back(order);continue;}
  for(int a=x;a<=xx;++a)for(int b=z;b<=zz;++b)cells[key(a,b)].push_back(order);
 }
}
Array FPSProjectiles::candidates(Vector3 start,Vector3 end,double radius) {
 if(!safe(start)||!safe(end)||!std::isfinite(radius)||radius>1000000)return ids;
 double pad=std::max(0.,radius)+.000001;
 int x=std::floor((std::min(start.x,end.x)-pad)/4),z=std::floor((std::min(start.z,end.z)-pad)/4);
 int xx=std::floor((std::max(start.x,end.x)+pad)/4),zz=std::floor((std::max(start.z,end.z)+pad)/4);
 if(large(x,z,xx,zz))return ids;
 std::vector<int> found=overflow;
 for(int a=x;a<=xx;++a)for(int b=z;b<=zz;++b){auto cell=cells.find(key(a,b));if(cell!=cells.end())found.insert(found.end(),cell->second.begin(),cell->second.end());}
 std::sort(found.begin(),found.end());found.erase(std::unique(found.begin(),found.end()),found.end());
 Array result;for(int index:found)result.push_back(ids[index]);return result;
}
double FPSProjectiles::box_fraction(Vector3 start,Vector3 end,Vector3 half,double radius) {
 Vector3 motion=end-start;double enter=0,leave=1;
 for(int axis=0;axis<3;++axis){double extent=half[axis]+radius+.000001;if(std::abs(motion[axis])<1e-10){if(std::abs(start[axis])>extent)return INF;}else{double a=(-extent-start[axis])/motion[axis],b=(extent-start[axis])/motion[axis];enter=std::max(enter,std::min(a,b));leave=std::min(leave,std::max(a,b));if(enter>leave)return INF;}}
 if(radius<=0)return enter;
 double cuts[8]={enter,leave};int count=2;
 for(int axis=0;axis<3;++axis){if(std::abs(motion[axis])<1e-10)continue;for(double sign:{-1.,1.}){double t=(sign*half[axis]-start[axis])/motion[axis];if(t>enter&&t<leave)cuts[count++]=t;}}
 for(int i=1;i<count;++i){double value=cuts[i];int j=i;while(j>0&&cuts[j-1]>value){cuts[j]=cuts[j-1];--j;}cuts[j]=value;}
 Vector3 point=start.lerp(end,enter);if(point.distance_squared_to(point.clamp(-half,half))<=radius*radius+1e-10)return enter;
 for(int i=0;i<count-1;++i){double low=cuts[i],high=cuts[i+1];Vector3 mid=start.lerp(end,(low+high)*.5),offset,velocity;
  for(int axis=0;axis<3;++axis)if(std::abs(mid[axis])>half[axis]){offset[axis]=start[axis]-(mid[axis]>0?1.f:-1.f)*half[axis];velocity[axis]=motion[axis];}
  double a=velocity.length_squared(),b=offset.dot(velocity),c=offset.length_squared()-radius*radius;if(a<1e-12)continue;double disc=b*b-a*c;if(disc<0)continue;
  double contact=(-b-std::sqrt(disc))/a;if(contact>=low-1e-7&&contact<=high+1e-7)return std::clamp(contact,low,high);
 }
 return INF;
}
double FPSProjectiles::player_fraction(Vector3 start,Vector3 end,double height,double yaw,double radius) {
 if(bodies.size()!=101)return INF;
 Basis inverse(Vector3(0,1,0),-yaw);start=inverse.xform(start);end=inverse.xform(end);
 if(!std::isfinite(box_fraction(start-Vector3(0,.8,0),end-Vector3(0,.8,0),Vector3(1.5,.9,1.5),radius)))return INF;
 double first=INF;int stance=std::clamp(int(std::round(height*100)),65,165)-65;
 for(const Part &part:bodies[stance])first=std::min(first,box_fraction(part.inverse.xform(start),part.inverse.xform(end),part.half,radius));
 return first;
}
namespace {
double sphere_entry(Vector3 start,Vector3 motion,Vector3 center,double radius){
 Vector3 offset=start-center;double c=offset.length_squared()-radius*radius;if(c<=0)return 0.;
 double a=motion.length_squared();if(a<1e-12)return INF;
 double b=offset.dot(motion),disc=b*b-a*c;if(disc<0)return INF;
 double t=(-b-std::sqrt(disc))/a;return t>=0&&t<=1?t:INF;
}
double structure_entry(Vector3 start,Vector3 end,double radius){
 const double bottom=.4,top=1.4,bound=radius+.000001;
 if(std::min(start.x,end.x)>bound||std::max(start.x,end.x)<-bound||std::min(start.z,end.z)>bound||std::max(start.z,end.z)<-bound||std::min(start.y,end.y)>top+bound||std::max(start.y,end.y)<bottom-bound)return INF;
 Vector3 motion=end-start,closest(0,std::clamp(double(start.y),bottom,top),0);
 if(start.distance_squared_to(closest)<=radius*radius)return 0.;
 double first=std::min(sphere_entry(start,motion,Vector3(0,bottom,0),radius),sphere_entry(start,motion,Vector3(0,top,0),radius));
 double a=double(motion.x)*motion.x+double(motion.z)*motion.z;
 if(a>1e-12){double b=double(start.x)*motion.x+double(start.z)*motion.z,c=double(start.x)*start.x+double(start.z)*start.z-radius*radius,disc=b*b-a*c;
  if(disc>=0){double t=(-b-std::sqrt(disc))/a,height=start.y+motion.y*t;if(t>=0&&t<=1&&height>=bottom&&height<=top)first=std::min(first,t);}}
 return first;
}
}
Dictionary FPSProjectiles::trace_structures(const Dictionary &buildings,Vector3 start,Vector3 end,double limit,double radius){
 Dictionary result;Array keys=buildings.keys();
 for(int i=0;i<keys.size();++i){Dictionary row=buildings[keys[i]];Vector3 position=row["position"];
  double fraction=structure_entry(start-position,end-position,.55+radius);
  if(fraction<limit){limit=fraction;result["key"]=keys[i];result["fraction"]=fraction;}}
 return result;
}
Dictionary FPSProjectiles::trace(Node3D *game,Vector3 start,Vector3 end,int64_t exclude,double radius,const Dictionary &movement,const Variant &candidate_ids,const Dictionary &historical) {
 Dictionary players=game->get("players"),fighters=game->get("fighters");
 PhysicsDirectSpaceState3D *space=game->get_world_3d()->get_direct_space_state();
 ray->set_from(start);ray->set_to(end);ray->set_collide_with_areas(false);ray->set_hit_from_inside(true);
 double wall=INF;
 if(radius<=0){Dictionary hit=space->intersect_ray(ray);if(!hit.is_empty())wall=start.distance_to(Vector3(hit["position"]))/std::max(double(start.distance_to(end)),.00001);}
 else {
  if(sphere->get_radius()!=radius)sphere->set_radius(radius);shape_query->set_transform(Transform3D(Basis(),start));shape_query->set_motion(Vector3());
  if(!space->intersect_shape(shape_query,1).is_empty())wall=0;
  else{shape_query->set_motion(end-start);PackedFloat32Array fractions=space->cast_motion(shape_query);if(fractions[0]<1)wall=fractions[0];}
 }
 Object *mode=game->get("match_mode"),*fortress=mode->get("fortress"),*walkers=fortress->get("walkers"),*tribes=mode->get("tribes");
 Dictionary robots=walkers->get("robots"),mounted;
 int64_t hull=0;
 if(!robots.is_empty()){
  hull=walkers->call("trace_pilot",start,end,radius,wall);
  Array keys=robots.keys();for(int i=0;i<keys.size();++i){Dictionary row=robots[keys[i]];mounted[row["pilot"]]=true;}
 }
 double nearest=wall;Vector3 point=start.lerp(end,std::min(1.,nearest));int64_t target=hull!=exclude?hull:0;bool head=false;
 Array candidates_here=candidate_ids.get_type()==Variant::NIL?players.keys():Array(candidate_ids);
 ray->set_hit_from_inside(false);
 for(int i=0;i<candidates_here.size();++i) {
  Variant id=candidates_here[i];Dictionary state=players[id];if(int64_t(id)==exclude||bool(state["dead"])||bool(state["spectator"])||mounted.has(id))continue;
  Node3D *fighter=Object::cast_to<Node3D>(fighters[id]);Vector3 position=fighter->get_position(),previous=position;double height,yaw;
  Dictionary row=historical.get(id,Dictionary());
  if(!row.is_empty()&&row["serial"]==state["serial"]){position=row["position"];previous=position;height=row["height"];yaw=row["yaw"];}
  else{height=fighter->get("collision_height");yaw=fighter->call("damage_yaw");}
  if(movement.has(id)){Dictionary old=movement[id];if(old["serial"]==state["serial"]){previous=old["position"];height=std::max(height,double(old.get("height",height)));}}
  double fraction=player_fraction(start-previous,end-position,height,yaw,radius);
  if(!(fraction<nearest))continue;
  Vector3 impact=start.lerp(end,fraction),at=previous.lerp(position,fraction);Basis basis(Vector3(0,1,0),yaw);Vector3 local=basis.inverse().xform(impact-at),closest;double distance=INF;
  const auto &parts=bodies[std::clamp(int(std::round(height*100)),65,165)-65];
  for(const Part &part:parts){Vector3 p=part.pose.xform(part.inverse.xform(local).clamp(-part.half,part.half));double gap=local.distance_squared_to(p);if(gap<distance){distance=gap;closest=part.center;}}
  ray->set_from(impact);ray->set_to(at+Vector3(0,closest.y,0));if(!space->intersect_ray(ray).is_empty())continue;
  nearest=fraction;point=impact;target=id;
  const Part &h=parts[1];Vector3 head_local=h.inverse.xform(Basis(Vector3(0,1,0),-yaw).xform(impact-at));head=head_local.distance_squared_to(head_local.clamp(-h.half,h.half))<=radius*radius+1e-8;
 }
 if(bool(fortress->call("structures_enabled"))){
  Dictionary structure=trace_structures(fortress->get("buildings"),start,end,nearest,radius);
  if(!structure.is_empty()){Dictionary hit;hit["id"]=0;hit["building"]=structure["key"];hit["position"]=start.lerp(end,double(structure["fraction"]));hit["hit"]=true;return hit;}
 }
 Dictionary result;result["id"]=target;result["position"]=point;result["headshot"]=head;result["hit"]=target!=0||std::isfinite(wall);result["vehicle"]=target!=0&&target==hull;
 ray->set_from(start);ray->set_to(point+(end-start).normalized()*.04);ray->set_collide_with_areas(true);
 Dictionary contact=space->intersect_ray(ray);
 if(!contact.is_empty()) {
  Object *collider=contact["collider"];Vector3 position=contact["position"];Node *runtime=game->get_node_or_null(NodePath("Map/MapRuntime"));Dictionary rows;
  if(runtime){Object *triggers=runtime->get("triggers");rows=triggers->get("rows");}
  if(target==0){if(Object::cast_to<StaticBody3D>(collider)&&!Object::cast_to<AnimatableBody3D>(collider)&&position.distance_squared_to(point)<.000025&&!rows.has(collider))result[StringName("surface_normal")]=contact["normal"];result[StringName("impact_normal")]=contact["normal"];}
  if((target==0||start.distance_to(position)<start.distance_to(point))&&runtime&&rows.has(collider)){result["map_node"]=collider;if(Object::cast_to<Area3D>(collider)){result["id"]=0;result["vehicle"]=false;result["hit"]=true;result["position"]=position;}}
 }
 // Keep live special-mode overlays in their authoritative order. Their engine
 // hull contacts and damage identities must not be replaced with body proxies.
 if(bool(tribes->call("enabled"))){
  Object *vehicles=tribes->get("vehicles"),*combat=tribes->get("combat"),*deployables=tribes->get("deployables"),*targeting=tribes->get("targeting");
  result=vehicles->call("trace",start,end,result,radius);
  result=combat->call("trace_mines",start,end,result,radius);
  result=deployables->call("trace",start,end,result,radius);
  result=targeting->call("trace",start,end,result,radius);
  Object *pads=tribes->call("stations");if(pads)result=pads->call("trace",result);
 }
 return result;
}
void FPSProjectiles::step(Node3D *game,double delta,const Dictionary &movement,const Array &weapons,bool native_trace) {
 Dictionary projectiles=game->get("projectiles");if(projectiles.is_empty())return;
 build(game->get("players"),game->get("fighters"),movement);Array keys=projectiles.keys();
 for(int i=0;i<keys.size();++i) {
  Variant id=keys[i];if(!projectiles.has(id))continue;Dictionary p=projectiles[id];bool fresh=p["fresh"];
  if(!fresh)p["previous_position"]=p["position"];
  if(p.has("definition")){Object *combat=game->get("variant_combat");combat->call("tick_projectile",id,delta,movement,this);continue;}
  p["life"]=double(p["life"])-delta;int weapon=p["weapon"];Dictionary definition=weapons[weapon];
  Vector3 start=p["position"],direction=p["direction"],end=start+direction*double(definition["speed"])*delta;double radius=definition["radius"];
  Dictionary prior=fresh?Dictionary():movement;Array possible=candidates(start,end,radius);
  Dictionary hit=native_trace?trace(game,start,end,p["owner"],radius,prior,possible):Dictionary(game->call("_trace_reference",start,end,p["owner"],0.,radius,prior,possible));
  p["fresh"]=false;
  if(bool(hit["hit"])||double(p["life"])<=0)game->call("_projectile_contact",id,hit,p,end);
  else p["position"]=end;
 }
}
