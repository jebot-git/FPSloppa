#include "vr_interaction.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/physics_shape_query_parameters3d.hpp>
#include <godot_cpp/classes/sphere_shape3d.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;
namespace {
bool has(int w,std::initializer_list<int> values){return std::find(values.begin(),values.end(),w)!=values.end();}
double toward(double a,double b,double d){return a<b?std::min(a+d,b):std::max(a-d,b);}
}
void FPSVRInteraction::swim_reset(){sampled=false;travel[0]=travel[1]=0;thrust=Vector3();strength=0;}
Vector3 FPSVRInteraction::swim(Transform3D head,Vector3 left,Vector3 right,double dt,bool allowed){
 if(!allowed||dt<=0||dt>.1||!head.is_finite()||!left.is_finite()||!right.is_finite()){swim_reset();return thrust;}
 Vector3 hands[2]={left-head.origin,right-head.origin};
 if(!sampled){previous[0]=hands[0];previous[1]=hands[1];sampled=true;return thrust;}
 Vector3 forward=-head.basis.get_column(2).normalized();double effort=0;
 for(int i=0;i<2;++i){
  Vector3 change=hands[i]-previous[i];
  if(change.length()>.25){swim_reset();return thrust;}
  Vector3 pull=-change/dt;double ahead=std::max(0.,double(pull.dot(forward))),up=std::max(0.,double(pull.y));
  if(std::max(ahead,up)>.15){travel[i]+=change.length();if(travel[i]>=.035)effort+=std::max(ahead,up);}else travel[i]=0;
 }
 previous[0]=hands[0];previous[1]=hands[1];double desired=std::clamp(effort*1.25,0.,1.);
 strength+=(desired-strength)*(1.-std::exp(-dt*(desired>strength?12.:4.)));
 thrust=forward*strength;if(thrust.length()<.01)thrust=Vector3();return thrust;
}
void FPSVRInteraction::advance(double delta){blend=toward(blend,engaged?1.:0.,delta/.08);}
void FPSVRInteraction::reset(){engaged=false;last_weapon=-1;blend=0;alignment=Basis();}
bool FPSVRInteraction::supports(int w,const String &r,bool stock){
 if(r=="cq")return stock?has(w,{1,3,4,5,9,10,11,12,13,14,15,16}):has(w,{0,1,2,3,4,5,9,10,11,12,13,14,15,16});
 if(r=="cs16")return has(w,{3,4,5,6,7,8,9,11});
 if(r=="quake")return has(w,{2,3,4,5,6,7,8,9});
 if(r=="ut99")return has(w,{1,3,4,5,6,7,8,9,10});
 if(r=="tribes")return has(w,{0,1,2,3,4,5,6,7,8,11});
 return has(w,{1,3,4,5,6,7,8,9});
}
Transform3D FPSVRInteraction::aim(Transform3D p,Transform3D s,int w,bool holding,bool valid,const String &r,bool smooth,Vector3 anchor){
 if(w!=last_weapon){engaged=false;last_weapon=w;blend=0;}
 if(!supports(w,r,false)||!holding||!valid){engaged=false;blend=0;return p;}
 Vector3 offset=s.origin-p.origin,forward=-p.basis.get_column(2);
 double distance=offset.length();bool cq=r=="cq",physical=cq||r=="cs16",pistol=cq&&has(w,{0,2,9});
 if(!(physical&&engaged)&&(distance<(pistol?.035:physical||engaged?.075:.12)||distance>(engaged?.95:.80)||offset.dot(forward)<(pistol?.02:.06))){engaged=false;return p;}
 if(!engaged&&offset.distance_to(p.basis.xform(anchor))>(physical?.16:.24))return p;
 engaged=true;
 if(pistol)return p;
 Basis target;
 if(physical){target=distance>.01?Basis(Quaternion(p.basis.xform(anchor).normalized(),offset.normalized()))*p.basis:p.basis;}
 else{Vector3 direction=offset.normalized(),up=p.basis.get_column(1);if(std::abs(up.dot(direction))>.95)up=p.basis.get_column(0);target=Basis::looking_at(direction,up);}
 return Transform3D(smooth?p.basis.slerp(target,blend):target,p.origin);
}
Transform3D FPSVRInteraction::stock(Transform3D p,Transform3D s,Transform3D h,int w,bool left,bool valid,const String &r,bool smooth){
 if(w!=last_weapon){reset();last_weapon=w;}
 if(!valid||!supports(w,r,true)){engaged=false;return p;}
 Vector3 look=-h.basis.get_column(2);look.y=0;
 if(look.length_squared()<.001){engaged=false;return p;}
 Basis yaw=Basis::looking_at(look.normalized(),Vector3(0,1,0));
 Vector3 shoulder=h.origin+yaw.xform(Vector3(left?-.18:.18,-.23,.10));
 double distance=p.origin.distance_to(shoulder);
 if(r=="cq"&&w==9){
  if(distance>(engaged?.55:.40)||distance<.15){engaged=false;return p;}
  Vector3 axis=p.origin-shoulder;
  if(axis.dot(-p.basis.get_column(2))<.10){engaged=false;return p;}
  Basis stock_basis=Basis::looking_at(axis.normalized(),Vector3(0,1,0));
  if(!engaged)alignment=stock_basis.inverse()*p.basis;
  engaged=true;
  return Transform3D(p.basis.slerp(stock_basis*alignment,.72*(smooth?blend:1.)),p.origin);
 }
 if(distance>(engaged?.55:.40)){engaged=false;return p;}
 Vector3 axis=s.origin-shoulder;
 if(axis.length()<.22||axis.dot(-p.basis.get_column(2))<.12){engaged=false;return p;}
 engaged=true;
 Vector3 direction=(-p.basis.get_column(2)).slerp(axis.normalized(),.72).normalized(),up=p.basis.get_column(1);
 if(std::abs(up.dot(direction))>.95)up=p.basis.get_column(0);
 Basis target=Basis::looking_at(direction,up);
 return Transform3D(smooth?p.basis.slerp(target,blend):target,p.origin);
}
Vector3 FPSVRInteraction::launch(Vector3 v){
 if(!v.is_finite())return Vector3();
 Vector3 bounded=v.limit_length(12);double t=std::clamp((double(bounded.length())-.65)/1.35,0.,1.);
 return (bounded*(1.+3.8*t)).limit_length(40);
}
Vector3 FPSVRInteraction::guided(Transform3D weapon,Vector3 v){
 Vector3 result=launch(v);return result.length()<.8?result:-weapon.basis.get_column(2).normalized()*result.length();
}
PackedVector3Array FPSVRInteraction::arc(PhysicsDirectSpaceState3D *space,Vector3 start,Vector3 v,double duration,double gravity){
 PackedVector3Array result;result.push_back(start);if(!space)return result;
 Ref<PhysicsShapeQueryParameters3D> query;query.instantiate();Ref<SphereShape3D> sphere;sphere.instantiate();sphere->set_radius(.12);
 query->set_shape(sphere);query->set_collision_mask(1);query->set_margin(.001);query->set_transform(Transform3D(Basis(),start));
 if(!space->intersect_shape(query,1).is_empty())return result;
 for(int i=0;i<int(std::ceil(std::min(duration,2.)*30));++i){
  v.y-=gravity/30.;Vector3 end=start+v/30.;query->set_transform(Transform3D(Basis(),start));query->set_motion(end-start);
  auto sweep=space->cast_motion(query);
  if(sweep.size()&&sweep[0]<1.){result.push_back(start.lerp(end,std::max(0.,double(sweep[0]))));break;}
  start=end;result.push_back(start);
 }
 return result;
}
void FPSVRInteraction::_bind_methods(){
 ClassDB::bind_method(D_METHOD("swim","head","left","right","dt","allowed"),&FPSVRInteraction::swim);
 ClassDB::bind_method(D_METHOD("swim_reset"),&FPSVRInteraction::swim_reset);
 ClassDB::bind_method(D_METHOD("get_strength"),&FPSVRInteraction::get_strength);
 ClassDB::bind_method(D_METHOD("get_thrust"),&FPSVRInteraction::get_thrust);
 ClassDB::bind_method(D_METHOD("advance","delta"),&FPSVRInteraction::advance);
 ClassDB::bind_method(D_METHOD("reset"),&FPSVRInteraction::reset);
 ClassDB::bind_method(D_METHOD("aim","primary","support","weapon","holding","valid","rules","smooth","anchor"),&FPSVRInteraction::aim);
 ClassDB::bind_method(D_METHOD("stock","primary","support","head","weapon","left_handed","valid","rules","smooth"),&FPSVRInteraction::stock);
 ClassDB::bind_static_method("FPSVRInteraction",D_METHOD("supports","weapon","rules","stock"),&FPSVRInteraction::supports);
 ClassDB::bind_static_method("FPSVRInteraction",D_METHOD("launch","velocity"),&FPSVRInteraction::launch);
 ClassDB::bind_static_method("FPSVRInteraction",D_METHOD("guided","weapon","velocity"),&FPSVRInteraction::guided);
 ClassDB::bind_static_method("FPSVRInteraction",D_METHOD("arc","space","start","velocity","duration","gravity"),&FPSVRInteraction::arc);
#define PROPERTY(type,name) ClassDB::bind_method(D_METHOD("get_" #name),&FPSVRInteraction::get_##name);ClassDB::bind_method(D_METHOD("set_" #name,"value"),&FPSVRInteraction::set_##name);ADD_PROPERTY(PropertyInfo(Variant::type,#name),"set_" #name,"get_" #name);
 PROPERTY(BOOL,engaged) PROPERTY(INT,last_weapon) PROPERTY(FLOAT,blend) PROPERTY(BASIS,alignment)
#undef PROPERTY
}
