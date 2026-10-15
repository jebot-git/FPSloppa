#include "backend.h"
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/math.hpp>
#include <cmath>
using namespace godot;
namespace {
// String keys deliberately match existing String-keyed gameplay dictionaries.
const String &key(const char *name){static thread_local std::unordered_map<std::string,String> keys;auto it=keys.find(name);if(it==keys.end())it=keys.emplace(name,String(name)).first;return it->second;}
Variant read_field(const Dictionary &d,const char *k,Variant fallback=Variant()){return d.get(key(k),fallback);}
bool flag(const Dictionary &d,const char *k){return read_field(d,k,false)==Variant(true);}
void write_field(Dictionary &d,const char *k,const Variant &v){d[key(k)]=v;}
bool number(const Variant &v){return (v.get_type()==Variant::FLOAT||v.get_type()==Variant::INT)&&std::isfinite(double(v));}
bool same_number(const Variant &a,const Variant &b){return a.get_type()==b.get_type()?a==b:number(a)&&number(b)&&double(a)==double(b);}
}
void FPSBackend::bind_players(const Dictionary &states){
 if(std::this_thread::get_id()!=owner_thread)return;
 // Membership/life reconciliation also releases departed peers and old dictionaries.
 ++player_generation;Array ids=states.keys();
 for(int i=0;i<ids.size();++i){if(ids[i].get_type()!=Variant::INT||states[ids[i]].get_type()!=Variant::DICTIONARY)continue;
  int64_t id=ids[i];Dictionary s=states[ids[i]];int64_t serial=read_field(s,"serial",-1);PlayerState &row=player_states[id];
  if(row.serial!=serial)row=PlayerState();row.source=s;row.serial=serial;row.generation=player_generation;
 }
 for(auto it=player_states.begin();it!=player_states.end();)if(it->second.generation!=player_generation)it=player_states.erase(it);else ++it;
}
int FPSBackend::begin_player(int64_t id,double now){
 if(std::this_thread::get_id()!=owner_thread)return 0;auto it=player_states.find(id);if(it==player_states.end())return 0;Dictionary &s=it->second.source;
 if(now-double(read_field(s,"last_input",0.))>.35){
  write_field(s,"move",Vector2());write_field(s,"room",Vector3());write_field(s,"swim",Vector3());
  for(const char *k:{"jump","fire","offhand_fire","alt_fire","melee"})write_field(s,k,false);write_field(s,"input_blocked",true);
 }
 // Return jump/jetpack/release bits; scene mutation remains on the main thread.
 bool jet=flag(s,"jetpack_pending")&&!flag(s,"input_blocked");write_field(s,"jetpack_pending",false);
 bool edge=flag(s,"jump_pending");if(edge){write_field(s,"jump_pending",false);write_field(s,"jump_ack",read_field(s,"jump_received",0));}
 return ((edge||flag(s,"jump"))?1:0)|(jet?2:0)|(edge?4:0);
}
bool FPSBackend::advance_player(int64_t id,double delta){
 if(std::this_thread::get_id()!=owner_thread)return false;auto it=player_states.find(id);if(it==player_states.end())return false;PlayerState &p=it->second;Dictionary &s=p.source;
 // Import at the original commit point: damage, reloads and equipment may have
 // changed these fields earlier in this tick. Never pre-advance the whole roster.
 p.cooldown=std::max(0.,double(read_field(s,"cooldown",0.))-delta);p.offhand_cooldown=std::max(0.,double(read_field(s,"offhand_cooldown",0.))-delta);p.charge=read_field(s,"charge",0.);
 write_field(s,"cooldown",p.cooldown);write_field(s,"offhand_cooldown",p.offhand_cooldown);
 if(p.charge>0){p.charge-=delta;write_field(s,"charge",p.charge);return p.charge<=0;}return false;
}
Array FPSBackend::begin_player_fire(int64_t id,double now,bool buffer_primary){
 if(std::this_thread::get_id()!=owner_thread)return Array();auto it=player_states.find(id);if(it==player_states.end())return Array();Dictionary &s=it->second.source;
 Array previous=Array::make(read_field(s,"fire",false),read_field(s,"alt_fire",false),read_field(s,"offhand_fire",false));Array edge=read_field(s,"fire_pending",Array());write_field(s,"fire_pending",Array());
 if(edge.size()!=3||edge[0]!=read_field(s,"weapon")||now>double(edge[2])||flag(s,"input_blocked")||flag(s,"dead")||flag(s,"spectator"))return previous;
 int mask=edge[1];if(buffer_primary&&(mask&1)&&double(read_field(s,"cooldown",0.))>0){write_field(s,"fire_pending",Array::make(edge[0],1,edge[2]));mask&=~1;}
 int i=0;for(const char *k:{"fire","alt_fire","offhand_fire"}){write_field(s,k,bool(previous[i])||bool(mask&(1<<i)));++i;}return previous;
}
void FPSBackend::end_player_fire(int64_t id,const Array &previous){
 if(std::this_thread::get_id()!=owner_thread||previous.size()!=3)return;auto it=player_states.find(id);if(it==player_states.end())return;
 int i=0;for(const char *k:{"fire","alt_fire","offhand_fire"})write_field(it->second.source,k,previous[i++]);
}
bool FPSBackend::valid_input(const Dictionary &c) const{
 if(std::this_thread::get_id()!=owner_thread)return false;
 for(const char *k:{"seq","move","yaw","pitch","fire","weapon","slow","respawn"})if(!c.has(key(k)))return false;
 Variant move=read_field(c,"move");if(move.get_type()!=Variant::VECTOR2||!Vector2(move).is_finite()||!number(read_field(c,"yaw"))||!number(read_field(c,"pitch")))return false;
 for(const char *k:{"seq","weapon"})if(read_field(c,k).get_type()!=Variant::INT)return false;
 for(const char *k:{"fire","slow","respawn"})if(read_field(c,k).get_type()!=Variant::BOOL)return false;return true;
}
void FPSBackend::accept_input_header(const Dictionary &state,const Dictionary &c,double now){
 if(std::this_thread::get_id()!=owner_thread)return;Dictionary s=state;
 write_field(s,"last_seq",read_field(c,"seq"));write_field(s,"last_input",now);Variant view=read_field(c,"view_time",-1.);write_field(s,"view_time",number(view)?double(view):-1.);
 Variant serial=read_field(s,"serial");if(read_field(s,"jump_event_life",-1)!=serial){write_field(s,"jump_event_life",serial);for(const char *k:{"jump_received","jump_ack","jetpack_ack"})write_field(s,k,0);write_field(s,"jump_pending",false);write_field(s,"jetpack_pending",false);}
 Variant jet=read_field(c,"jetpack_event",0);int64_t ack=read_field(s,"jetpack_ack",0);
 if(jet.get_type()==Variant::INT&&int64_t(jet)>ack&&int64_t(jet)<=2147483647&&int64_t(jet)-ack<=32&&same_number(read_field(c,"input_life",-1),serial)){write_field(s,"jetpack_ack",jet);if(!flag(s,"dead")&&!flag(s,"spectator")&&!flag(c,"input_blocked"))write_field(s,"jetpack_pending",true);}
 Variant jump=read_field(c,"jump_event",0);int64_t received=read_field(s,"jump_received",0);
 if(jump.get_type()!=Variant::INT||int64_t(jump)<=0||int64_t(jump)>2147483647||!same_number(read_field(c,"input_life",-1),serial)||int64_t(jump)<=received||int64_t(jump)-received>32)return;
 write_field(s,"jump_received",jump);if(flag(s,"dead")||flag(s,"spectator")||flag(c,"input_blocked")){write_field(s,"jump_ack",jump);return;}
 write_field(s,"jump_pending",true);Variant seq=read_field(c,"jump_seq",-1);write_field(s,"jump_pending_seq",seq.get_type()==Variant::INT&&int64_t(seq)>=0&&int64_t(seq)<=int64_t(read_field(c,"seq",-1))?seq:Variant(-1));
}
void FPSBackend::apply_input_fields(const Dictionary &state,const Dictionary &c,bool dual){
 if(std::this_thread::get_id()!=owner_thread)return;Dictionary s=state;
 write_field(s,"move",Vector2(read_field(c,"move")).limit_length(1.));Variant fly=read_field(c,"fly",0.);write_field(s,"fly",number(fly)?std::clamp(double(fly),-1.,1.):0.);
 write_field(s,"yaw",Math::wrapf(double(read_field(c,"yaw")),-3.14159265358979323846,3.14159265358979323846));write_field(s,"pitch",std::clamp(double(read_field(c,"pitch")),-1.45,1.45));
 for(const char *k:{"fire","slow"})write_field(s,k,read_field(c,k));
 for(const char *k:{"alt_fire","input_blocked","melee","jump","crouch","prone","physical"})write_field(s,k,flag(c,k));
 write_field(s,"offhand_fire",dual&&flag(c,"offhand_fire"));write_field(s,"want_respawn",read_field(c,"respawn"));write_field(s,"vr_device",c.has(key("xr")));
}
void FPSBackend::accept_fire_event(const Dictionary &state,const Dictionary &c,double now){
 if(std::this_thread::get_id()!=owner_thread)return;Dictionary s=state;Variant serial=read_field(s,"serial");
 if(read_field(s,"fire_event_life",-1)!=serial){write_field(s,"fire_event_life",serial);write_field(s,"fire_received",0);write_field(s,"fire_ack",0);write_field(s,"fire_pending",Array());}
 Variant v=read_field(c,"fire_event",Array());if(v.get_type()!=Variant::ARRAY||!same_number(read_field(c,"input_life",-1),serial))return;Array edge=v;if(edge.size()!=3)return;
 for(int i=0;i<3;++i)if(edge[i].get_type()!=Variant::INT)return;
 int64_t received=read_field(s,"fire_received",0);if(int64_t(edge[0])<=received||int64_t(edge[0])-received>32||edge[1]!=read_field(c,"weapon")||int64_t(edge[2])<1||int64_t(edge[2])>7)return;
 write_field(s,"fire_received",edge[0]);write_field(s,"fire_ack",edge[0]);if(flag(s,"dead")||flag(s,"spectator")||flag(s,"input_blocked"))return;
 write_field(s,"fire_pending",Array::make(edge[1],edge[2],now+.25));
}
bool FPSBackend::send_snapshot_batch(Object *game,Object *budget,const Array &normal,const Array &large,const Array &recipients,double now){
 if(std::this_thread::get_id()!=owner_thread||!game||!budget)return false;Node *node=Object::cast_to<Node>(game);if(!node)return false;
 // Validate before sending anything, so a rejected batch can use the reference.
 for(const Array &packets:{normal,large})for(int i=0;i<packets.size();++i)if(packets[i].get_type()!=Variant::PACKED_BYTE_ARRAY)return false;
 for(int i=0;i<recipients.size();++i)if(recipients[i].get_type()!=Variant::INT||int64_t(recipients[i])<=0)return false;
 for(int group=0;group<2;++group){const Array &packets=group?large:normal;StringName method(group?"_state_large":"_state_packet");
  for(int p=0;p<packets.size();++p){PackedByteArray bytes=packets[p];budget->call("reserve",int64_t(bytes.size()+64)*recipients.size(),now);
   for(int r=0;r<recipients.size();++r)node->rpc_id(int64_t(recipients[r]),method,bytes);
  }
 }return true;
}

Dictionary FPSBackend::sample_reload_motion(const Dictionary &state,const Dictionary &pose,Transform3D weapon,Transform3D hand,double stamp){
 Dictionary result;if(std::this_thread::get_id()!=owner_thread)return result;Dictionary p=state;
 Transform3D raw_weapon=read_field(pose,"weapon"),head=read_field(pose,"head");
 Vector3 local=weapon.affine_inverse().xform(hand.origin),relative_weapon=raw_weapon.origin-head.origin,relative_support=hand.origin-head.origin;
 Dictionary current;write_field(current,"time",stamp);write_field(current,"hand",local);write_field(current,"weapon",relative_weapon);write_field(current,"support",relative_support);write_field(current,"raw_weapon",raw_weapon.origin);write_field(current,"raw_support",hand.origin);write_field(current,"basis",raw_weapon.basis);write_field(current,"head_basis",head.basis);
 Dictionary before=read_field(p,"motion",Dictionary());
 if(!before.is_empty()&&stamp<=double(read_field(before,"time"))){write_field(result,"valid",false);write_field(result,"duplicate",true);return result;}
 write_field(p,"motion",current);if(before.is_empty()){write_field(result,"valid",false);return result;}
 double dt=stamp-double(read_field(before,"time"));Basis previous_basis=read_field(before,"basis"),previous_head=read_field(before,"head_basis");Basis inverse=previous_basis.inverse();
 Vector3 from=read_field(before,"hand"),hand_step=(local-from)*.65;
 Vector3 weapon_step=inverse.xform(relative_weapon-Vector3(read_field(before,"weapon"))),support_step=inverse.xform(relative_support-Vector3(read_field(before,"support")));
 if(raw_weapon.origin.distance_to(Vector3(read_field(before,"raw_weapon")))<weapon_step.length()*.35)weapon_step=Vector3();
 if(hand.origin.distance_to(Vector3(read_field(before,"raw_support")))<support_step.length()*.35)support_step=Vector3();
 bool valid=dt>=.008&&dt<=.16&&hand_step.length()<.32&&weapon_step.length()<.32&&support_step.length()<.32;
 if(!valid)write_field(p,"gestures",Dictionary());
 Vector3 body_step=(previous_head.inverse()*previous_basis).xform(weapon_step);
 write_field(result,"valid",valid);write_field(result,"dt",dt);write_field(result,"from",from);write_field(result,"to",local);write_field(result,"hand_step",hand_step);write_field(result,"weapon_step",weapon_step);write_field(result,"body_step",body_step);write_field(result,"support_step",support_step);write_field(result,"time",stamp);return result;
}
