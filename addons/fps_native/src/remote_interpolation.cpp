#include "remote_interpolation.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/array.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;
void FPSRemoteInterpolation::_bind_methods(){
 ClassDB::bind_method(D_METHOD("reset"),&FPSRemoteInterpolation::reset);
 ClassDB::bind_method(D_METHOD("erase","id"),&FPSRemoteInterpolation::erase);
 ClassDB::bind_method(D_METHOD("push","id","stamp","position","velocity","yaw","serial","now"),&FPSRemoteInterpolation::push);
 ClassDB::bind_method(D_METHOD("push_rows","rows","sample_times","stamp","now","mine","fighters"),&FPSRemoteInterpolation::push_rows);
 ClassDB::bind_method(D_METHOD("advance","now"),&FPSRemoteInterpolation::advance);
 ClassDB::bind_method(D_METHOD("sample","id"),&FPSRemoteInterpolation::sample);
 ClassDB::bind_method(D_METHOD("apply","fighters","mine","delta"),&FPSRemoteInterpolation::apply);
 ClassDB::bind_method(D_METHOD("stats"),&FPSRemoteInterpolation::stats);
 ClassDB::bind_method(D_METHOD("tracks"),&FPSRemoteInterpolation::tracks);
}
void FPSRemoteInterpolation::reset(){tracks_.clear();server_time_=-1;arrived_=jitter_=0;render_time_=last_advance_=-1;delay_=.075;underruns_=0;}
void FPSRemoteInterpolation::push(int64_t id,double stamp,Vector3 position,Vector3 velocity,double yaw,int64_t serial,double now){
 if(stamp<0||!std::isfinite(stamp)||!std::isfinite(now)||!position.is_finite()||!velocity.is_finite()||!std::isfinite(yaw))return;
 if(stamp>server_time_){if(server_time_>=0)jitter_=Math::lerp(jitter_,std::min(.1,std::abs((now-arrived_)-(stamp-server_time_))),.1);server_time_=stamp;arrived_=now;delay_=std::clamp(.075+jitter_*2,.075,.15);}
 auto &samples=tracks_[id];if(!samples.empty()){const auto&last=samples.back();if(stamp<=last.time)return;if(last.serial!=serial||last.position.distance_to(position)>3.)samples.clear();}
 samples.push_back({stamp,position,velocity,yaw,serial});while(samples.size()>12)samples.pop_front();
}
void FPSRemoteInterpolation::push_rows(const Array&rows,const Dictionary&sample_times,double stamp,double now,int64_t mine,const Dictionary&fighters){
 for(int i=0;i<rows.size();++i){if(rows[i].get_type()!=Variant::ARRAY)continue;Array r=rows[i];if(r.size()<15||r[0].get_type()!=Variant::INT||r[1].get_type()!=Variant::VECTOR3||r[2].get_type()!=Variant::VECTOR3)continue;int64_t id=r[0];if(id==mine||!fighters.has(id))continue;push(id,sample_times.get(id,stamp),r[1],r[2],r[3],r[14],now);}
}
double FPSRemoteInterpolation::advance(double now){
 if(server_time_<0||!std::isfinite(now))return -1;
 double target=server_time_+std::max(0.,now-arrived_)-delay_;
 if(render_time_<0||last_advance_<0)render_time_=std::min(server_time_,target);
 else{double elapsed=std::clamp(now-last_advance_,0.,.1);double rate=std::clamp(1.+(target-render_time_)*2.,.9,1.1);double next=render_time_+elapsed*rate;if(next>server_time_)++underruns_;render_time_=std::min(server_time_,next);}last_advance_=now;return render_time_;
}
bool FPSRemoteInterpolation::lookup(int64_t id,Pose&out){
 auto found=tracks_.find(id);if(found==tracks_.end()||found->second.empty())return false;auto &samples=found->second;
 while(samples.size()>2&&samples[1].time<render_time_)samples.pop_front();
 const Sample*last=&samples.back();if(render_time_<=samples.front().time)last=&samples.front();
 else for(size_t i=1;i<samples.size();++i)if(samples[i].time>=render_time_){const auto&a=samples[i-1];const auto&b=samples[i];double f=std::clamp((render_time_-a.time)/std::max(.001,b.time-a.time),0.,1.);out={a.position.lerp(b.position,f),Math::lerp_angle(a.yaw,b.yaw,f)};return true;}
 out={last->position,last->yaw};return true;
}
Dictionary FPSRemoteInterpolation::row(const Sample&s){Dictionary d;d["time"]=s.time;d["position"]=s.position;d["velocity"]=s.velocity;d["yaw"]=s.yaw;d["serial"]=s.serial;return d;}
Dictionary FPSRemoteInterpolation::sample(int64_t id){
 auto found=tracks_.find(id);if(found==tracks_.end()||found->second.empty())return {};Pose pose;lookup(id,pose);const auto&samples=found->second;
 if(render_time_<=samples.front().time)return row(samples.front());if(render_time_>samples.back().time)return row(samples.back());
 // At the exact final timestamp the reference returns the interpolated two-key row.
 if(samples.size()==1)return row(samples.back());Dictionary d;d["position"]=pose.position;d["yaw"]=pose.yaw;return d;
}
void FPSRemoteInterpolation::apply(const Dictionary&fighters,int64_t mine,double delta){
 if(!std::isfinite(delta))return;Array ids=fighters.keys();double weight=std::min(delta*16,1.);
 static const StringName target("target"),target_yaw("target_yaw");
 for(int i=0;i<ids.size();++i){int64_t id=ids[i];if(id==mine)continue;Variant value=fighters[ids[i]];if(value.get_type()!=Variant::OBJECT)continue;Node3D*actor=Object::cast_to<Node3D>(static_cast<Object*>(value));if(!actor)continue;
  Pose pose;if(!lookup(id,pose)){Variant to=actor->get(target),yaw=actor->get(target_yaw);if(to.get_type()!=Variant::VECTOR3||(yaw.get_type()!=Variant::FLOAT&&yaw.get_type()!=Variant::INT))continue;pose={actor->get_position().lerp(Vector3(to),weight),Math::lerp_angle(double(actor->get_rotation().y),double(yaw),weight)};}
  actor->set_position(pose.position);Vector3 rotation=actor->get_rotation();rotation.y=pose.yaw;actor->set_rotation(rotation);
 }
}
Dictionary FPSRemoteInterpolation::stats()const{Dictionary d;d["server_time"]=server_time_;d["arrived"]=arrived_;d["jitter"]=jitter_;d["render_time"]=render_time_;d["delay"]=delay_;d["last_advance"]=last_advance_;d["underruns"]=underruns_;return d;}
Dictionary FPSRemoteInterpolation::tracks()const{Dictionary d;for(const auto &entry:tracks_){Array rows;for(const auto&s:entry.second)rows.append(row(s));d[entry.first]=rows;}return d;}
