#include "movement_runtime.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
#include <vector>
using namespace godot;
#define K(text) ([]()->const String&{static const String key(text);return key;}())
#define N(text) ([]()->const StringName&{static const StringName key(text);return key;}())
namespace {
void reconcile_jetpack(CharacterBody3D*actor,const Dictionary&authority,const Dictionary&reference){
 if(authority.is_empty())return;
 Dictionary current=actor->get(N("jetpack_state"));
 if(!reference.is_empty()&&int64_t(current.get(K("activation"),0))>int64_t(reference.get(K("activation"),0)))return;
 double time=current.get(K("time"),0.),elapsed=std::max(0.,time-double(reference.get(K("time"),time)));
 Dictionary next=authority.duplicate(true);next[K("cooldown")]=std::max(0.,double(next.get(K("cooldown"),0.))-elapsed);next[K("time")]=time;
 if(!reference.is_empty()&&authority.get(K("activation"),0)==reference.get(K("activation"),0)&&authority.get(K("mode"),0)==reference.get(K("mode"),0)){
  for(auto key:{K("age"),K("heading"),K("tap")})next[key]=current[key];
  next[K("distance")]=double(authority.get(K("distance"),0.))+std::max(0.,double(current.get(K("distance"),0.))-double(reference.get(K("distance"),0.)));
  if(int(current.get(K("mode"),0))==0&&bool(actor->call(N("is_supported"))))next[K("mode")]=0;
 }else{next[K("age")]=double(next.get(K("age"),0.))+elapsed;next[K("tap")]=std::max(0.,double(next.get(K("tap"),0.))-elapsed);}
 actor->set(N("jetpack_state"),next);
}
}
bool FPSMovement::snapshot_apply_fields(const Array&rows,const Dictionary&players,const Dictionary&fighters,int64_t mine,double clock)const{
 if(!std::isfinite(clock)||rows.size()>4096)return false;
 struct Row{Array data;Dictionary state;CharacterBody3D*actor;Vector2 blast;int64_t id;};std::vector<Row> work;work.reserve(rows.size());
 // Validate the batch before changing any state; malformed data uses the reference path.
 for(int i=0;i<rows.size();++i){if(rows[i].get_type()!=Variant::ARRAY)return false;Array row=rows[i];if(row.size()<22||row[0].get_type()!=Variant::INT||row[1].get_type()!=Variant::VECTOR3||row[2].get_type()!=Variant::VECTOR3||row[21].get_type()!=Variant::VECTOR2)return false;
  int64_t id=row[0];if(!fighters.has(id))continue;if(!players.has(id)||players[id].get_type()!=Variant::DICTIONARY)return false;
  Variant node=fighters[id];if(node.get_type()!=Variant::OBJECT)return false;auto*actor=Object::cast_to<CharacterBody3D>(static_cast<Object*>(node));if(!actor)return false;
  Variant previous=actor->get(N("blast_velocity"));if(previous.get_type()!=Variant::VECTOR2)return false;work.push_back({row,players[id],actor,previous,id});
 }
 static const String fields[]={K("yaw"),K("pitch"),K("hp"),K("armor"),K("dead"),K("weapon"),K("ammo"),K("owned"),K("kills"),K("deaths"),K("ping"),K("serial"),K("cooldown"),K("offhand_cooldown"),K("spectator")};
 static constexpr int indices[]={3,4,5,6,7,8,9,10,11,12,13,14,17,19,20};
 for(auto &entry:work){auto&row=entry.data;auto&state=entry.state;for(int j=0;j<15;++j)state[fields[j]]=row[indices[j]];
  state[K("respawn_at")]=clock+double(row[15]);state[K("invulnerable")]=bool(row[16])?clock+1.:0.;
  Vector2 blast=row[21];entry.actor->set(N("blast_velocity"),blast);
  if(entry.id!=mine){Vector3 velocity=entry.actor->get_velocity();velocity.x+=blast.x-entry.blast.x;velocity.z+=blast.y-entry.blast.y;entry.actor->set_velocity(velocity);}
  entry.actor->set(N("target"),row[1]);entry.actor->set(N("target_yaw"),row[3]);
 }
 return true;
}
void FPSMovement::prediction_reconcile(CharacterBody3D*actor,int64_t sequence,Vector3 position,Vector3 velocity,double height,bool grounded,const Dictionary&jetpack,double stamina,double max_stamina){
 if(!actor||!position.is_finite()||!velocity.is_finite()||!std::isfinite(height)||!std::isfinite(stamina)||!std::isfinite(max_stamina))return;
 Dictionary result=prediction_begin(actor,sequence,position,velocity,grounded);if(result.is_empty())return;
 bool missing=result.get(K("missing"),false);
 if(missing)reconcile_jetpack(actor,jetpack,Dictionary());
 else{
  if(bool(actor->get(N("cs16_enabled")))&&stamina>=0&&double(result.get(K("stamina"),-1.))>=0)actor->set(N("cs16_stamina"),std::clamp(double(actor->get(N("cs16_stamina")))+stamina-double(result[K("stamina")]),0.,max_stamina));
  reconcile_jetpack(actor,jetpack,result.get(K("jetpack"),Dictionary()));double old_height=result.get(K("height"),-1.),current_height=actor->get(N("collision_height"));
  if(height>=.65&&height<=1.65&&old_height>0&&Math::is_equal_approx(current_height,old_height)&&!Math::is_equal_approx(height,old_height))actor->call(N("update_height"),height,true);
 }
 if(bool(result.get(K("reset"),false))){actor->set_position(position);actor->set_velocity(velocity);actor->call(N("reset_view"));return;}
 if(missing)return;
 Vector3 applied=actor->call(N("correct_prediction"),result[K("correction")]);Vector3 impulse=result[K("impulse")];actor->set_velocity(actor->get_velocity()+impulse);prediction_finish(sequence,applied,impulse);
}
