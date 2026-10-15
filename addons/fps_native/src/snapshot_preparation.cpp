#include "backend.h"
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
using namespace godot;
// Cache string keys instead of allocating UTF-8 Strings for every field lookup.
#define K(text) ([]()->const String & {static const String key(text);return key;}())
#define N(text) ([]()->const StringName & {static const StringName key(text);return key;}())

namespace {
Object *object(const Variant &value){return value.get_type()==Variant::OBJECT?static_cast<Object *>(value):nullptr;}
// Match input_delivery/fire_delivery lifecycle guards before serializing ACKs.
void sync_life(Dictionary &state){
 if(state.get(K("jump_event_life"),-1)!=state[K("serial")]){
  state[K("jump_event_life")]=state[K("serial")];state[K("jump_received")]=0;state[K("jump_ack")]=0;
  state[K("jump_pending")]=false;state[K("jetpack_ack")]=0;state[K("jetpack_pending")]=false;
 }
 if(state.get(K("fire_event_life"),-1)!=state[K("serial")]){
  state[K("fire_event_life")]=state[K("serial")];state[K("fire_received")]=0;state[K("fire_ack")]=0;state[K("fire_pending")]=Array();
 }
}
}

Array FPSBackend::prepare_snapshot(Object *game) const{
 // Scene objects are sampled only on the thread that owns this backend.
 // This method is never dispatched to the encoder or compute pool.
 if(!game||std::this_thread::get_id()!=owner_thread)return Array();
 Dictionary players=game->get(N("players")),fighters=game->get(N("fighters")),projectiles=game->get(N("projectiles"));
 Array pickups=game->get(N("pickups")),gates=game->get(N("gates"));double clock=game->get(N("clock"));
 Object *match=object(game->get(N("match_mode"))),*lobby=object(game->get(N("lobby"))),*armory=object(game->get(N("armory")));
 Object *combat=object(game->get(N("variant_combat"))),*votes=object(game->get(N("votes")));
 if(!match||!lobby||!armory||!combat||!votes)return Array();
 Array data,shots,gate_states;PackedByteArray items;
 Array ids=players.keys();data.resize(ids.size());
 for(int i=0;i<ids.size();++i){
  Variant id=ids[i];Dictionary s=players[id];Object *actor=object(fighters.get(id,Variant()));
  Node3D *node=Object::cast_to<Node3D>(actor);if(!node)return Array();
  data[i]=Array::make(id,node->get_position(),actor->get(N("velocity")),s[K("yaw")],s[K("pitch")],s[K("hp")],s[K("armor")],s[K("dead")],s[K("weapon")],s[K("ammo")],s[K("owned")],s[K("kills")],s[K("deaths")],s[K("ping")],s[K("serial")],std::max(0.,double(s[K("respawn_at")])-clock),double(s[K("invulnerable")])>clock,s[K("cooldown")],s[K("xr")],s[K("offhand_cooldown")],s[K("spectator")],actor->get(N("blast_velocity")));
 }
 items.resize(pickups.size());for(int i=0;i<pickups.size();++i){Dictionary p=pickups[i];items.set(i,bool(p[K("available")])?1:0);}
 Array shot_ids=projectiles.keys();shots.resize(shot_ids.size());Dictionary ordnance;
 for(int i=0;i<shot_ids.size();++i){Variant id=shot_ids[i];Dictionary p=projectiles[id];
  shots[i]=Array::make(id,p[K("position")],p[K("owner")],p[K("weapon")],p[K("direction")],p[K("yaw")],p[K("pitch")]);
  if(p.has(K("definition"))){Dictionary row;row[K("extra")]=p[K("extra")];row[K("velocity")]=p[K("velocity")];row[K("life")]=p[K("life")];row[K("stuck")]=p[K("stuck")];ordnance[id]=row;}
 }
 gate_states.resize(gates.size());Array movers,elevators;
 for(int i=0;i<gates.size();++i){Dictionary gate=gates[i];gate_states[i]=gate[K("open")];
  if(bool(gate.get(K("bsp"),false))||bool(gate.get(K("elevator"),false))){
   Node3D *node=Object::cast_to<Node3D>(object(gate[K("node")]));if(!node)return Array();
   if(bool(gate.get(K("bsp"),false)))movers.append(Array::make(i,node->get_position()));
   if(bool(gate.get(K("elevator"),false)))elevators.append(Array::make(i,node->get_position()));
  }
 }
 Dictionary mode=match->call("snapshot");mode[K("lobby")]=lobby->call("snapshot");mode[K("weapon_rules")]=armory->get(N("kind"));
 Dictionary charging=combat->get(N("charging"));if(!charging.is_empty())mode[K("weapon_charge")]=combat->call("charge_snapshot");
 mode[K("ordnance")]=ordnance;
 Object *runtime=object(game->call("get_node_or_null",NodePath("Map/MapRuntime")));
 if(runtime){Object *triggers=object(runtime->get(N("triggers")));if(triggers){Dictionary killed=triggers->get(N("killed_targets"));if(!killed.is_empty())mode[K("bsp_killed")]=killed;}}
 mode[K("map_movers")]=movers;mode[K("elevators")]=elevators;
 Dictionary locomotion,ack;Array fighter_ids=fighters.keys();bool cq=match->get(N("kind"))==Variant("cq");
 for(int i=0;i<fighter_ids.size();++i){Variant id=fighter_ids[i];if(!players.has(id))return Array();Dictionary s=players[id];sync_life(s);
  Object *actor=object(fighters[id]);if(!actor)return Array();Dictionary row=actor->call("locomotion_state");
  row[K("jump_ack")]=s.get(K("jump_ack"),0);if(cq)row[K("jetpack_ack")]=s.get(K("jetpack_ack"),0);row[K("fire_ack")]=s.get(K("fire_ack"),0);locomotion[id]=row;
 }
 for(int i=0;i<ids.size();++i){Dictionary s=players[ids[i]];ack[ids[i]]=s[K("last_seq")];}
 mode[K("locomotion")]=locomotion;mode[K("movement_ack")]=ack;
 return Array::make(data,items,game->get(N("round_left")),game->get(N("intermission")),game->get(N("round_message")),game->get(N("frag_limit")),game->get(N("time_limit")),shots,gate_states,game->get(N("map_epoch")),mode,votes->call("snapshot"),clock,game->get(N("projectile_id")));
}

Dictionary FPSBackend::prepare_class_records(const Dictionary &states,const Dictionary &magazines,const Dictionary &spots,const Dictionary &locks,const Dictionary &charges,bool clone) const{
 Dictionary result;Array ids=states.keys();
 for(int i=0;i<ids.size();++i){Variant id=ids[i];Dictionary mag;
  if(magazines.has(id)){Dictionary c=magazines[id],physical=c[K("physical")],entries;
   Array weapons=physical.keys();for(int j=0;j<weapons.size();++j){Dictionary p=physical[weapons[j]],row;
    for(const String &key:{K("mag"),K("ready"),K("carry"),K("stroke"),K("locked")})row[key]=p[key];entries[weapons[j]]=row;
   }
   for(const String &key:{K("serial"),K("weapon")})mag[key]=c[key];
   Dictionary clips=c[K("clips")];mag[K("clips")]=clone?clips.duplicate():clips;
   for(const String &key:{K("reloading"),K("reload_at")})mag[key]=c[key];mag[K("cycling")]=c.get(K("cycling"),-1);mag[K("cycle_at")]=c.get(K("cycle_at"),0.);mag[K("physical")]=entries;
  }
  Dictionary state=states[id],lock=locks.get(id,Dictionary()),charge=charges.get(id,Dictionary());Array spot=spots.get(id,Array::make(0.,0.));Dictionary row;
  row[K("state")]=clone?state.duplicate(true):state;row[K("mag")]=mag;row[K("spot")]=clone?spot.duplicate():spot;row[K("lock")]=clone?lock.duplicate(true):lock;row[K("charge")]=clone?charge.duplicate(true):charge;
  result[String("cp:")+String::num_int64(int64_t(id))]=row;
 }
 return result;
}

Array FPSBackend::snapshot_records(const Array &snapshot) const{
 Array records;if(snapshot.size()!=14||snapshot[0].get_type()!=Variant::ARRAY||snapshot[7].get_type()!=Variant::ARRAY||snapshot[10].get_type()!=Variant::DICTIONARY)return records;
 for(int index:{1,2,3,4,5,6,8,9,11,12,13})records.append(Array::make(0,index,snapshot[index]));
 Dictionary source=snapshot[10],mode;Array source_keys=source.keys();
 for(int i=0;i<source_keys.size();++i){Variant key=source_keys[i];
  if(key==Variant("_native_class_source")){if(Variant(source[key]).get_type()!=Variant::ARRAY)return Array();Array fields=source[key];if(fields.size()!=5)return Array();for(int j=0;j<fields.size();++j)if(fields[j].get_type()!=Variant::DICTIONARY)return Array();Dictionary classes=prepare_class_records(fields[0],fields[1],fields[2],fields[3],fields[4],false);Array ids=classes.keys();for(int j=0;j<ids.size();++j)mode[ids[j]]=classes[ids[j]];}
  else mode[key]=source[key];
 }
 Array keys=mode.keys();
 for(int i=0;i<keys.size();++i){Variant key=keys[i];if(key!=Variant("locomotion")&&key!=Variant("movement_ack")&&key!=Variant("ordnance"))records.append(Array::make(1,key,mode[key]));}
 Dictionary locomotion=mode.get(K("locomotion"),Dictionary()),ack=mode.get(K("movement_ack"),Dictionary()),ordnance=mode.get(K("ordnance"),Dictionary());
 Array players=snapshot[0],shots=snapshot[7],ids,shot_ids;
 for(int i=0;i<players.size();++i){Array row=players[i];ids.append(row[0]);records.append(Array::make(2,row[0],row,locomotion.get(row[0],Dictionary()),ack.get(row[0],-1)));}
 for(int i=0;i<shots.size();++i){Array row=shots[i];shot_ids.append(row[0]);records.append(Array::make(3,row[0],row,ordnance.get(row[0],Dictionary())));}
 records.append(Array::make(4,0,ids,shot_ids,keys));return records;
}

bool FPSBackend::submit_snapshot_state(const Array &snapshot,const Array &header,int64_t token){return queue_snapshot_state(snapshot,header,token,false);}
bool FPSBackend::submit_snapshot_buffer(const Array &snapshot,const Array &header,int64_t token){return queue_snapshot_state(snapshot,header,token,true);}
Dictionary FPSBackend::snapshot_buffer_stats() const{Dictionary d;d["submitted"]=buffer_submitted;d["fallback"]=buffer_fallback;return d;}
bool FPSBackend::queue_snapshot_state(const Array &snapshot,const Array &header,int64_t token,bool buffer){
 if(header.size()!=3||Variant(header[0]).get_type()!=Variant::INT||Variant(header[1]).get_type()!=Variant::INT||Variant(header[2]).get_type()!=Variant::FLOAT)return false;
 if(std::this_thread::get_id()!=owner_thread||snapshot.size()!=14||snapshot[9].get_type()!=Variant::INT||snapshot[12].get_type()!=Variant::FLOAT||snapshot[0].get_type()!=Variant::ARRAY||snapshot[7].get_type()!=Variant::ARRAY||snapshot[10].get_type()!=Variant::DICTIONARY)return false;
 Array players=snapshot[0],shots=snapshot[7];Dictionary mode=snapshot[10];
 if(players.size()+shots.size()+mode.size()>32750)return false;
 for(int i=0;i<players.size();++i){Variant p=players[i];if(p.get_type()!=Variant::ARRAY)return false;Array row=p;if(row.size()!=22||row[0].get_type()!=Variant::INT)return false;}
 for(int i=0;i<shots.size();++i){Variant p=shots[i];if(p.get_type()!=Variant::ARRAY)return false;Array row=p;if(row.size()!=7||row[0].get_type()!=Variant::INT)return false;}
 for(const String &key:{K("locomotion"),K("movement_ack"),K("ordnance")})if(mode.has(key)&&mode[key].get_type()!=Variant::DICTIONARY)return false;
 if(mode.has(K("_native_class_source"))){Variant value=mode[K("_native_class_source")];if(value.get_type()!=Variant::ARRAY)return false;Array fields=value;if(fields.size()!=5)return false;for(int i=0;i<fields.size();++i)if(fields[i].get_type()!=Variant::DICTIONARY)return false;}
 std::lock_guard<std::mutex> lock(encode_mutex);
 if(encode_stopping||pending.size()+completed.size()+size_t(encoding)>=2)return false;
 // One ownership barrier. Record expansion now happens on the encoder thread.
 if(header[0]!=snapshot[9]||header[2]!=snapshot[12])return false;
 if(buffer){
  auto frozen=std::make_shared<FrozenValue>();size_t remaining=262144;
  if(freeze_value(snapshot,*frozen,remaining)){pending.push_back({Array(),header.duplicate(true),token,true,std::move(frozen)});++buffer_submitted;}
  else{pending.push_back({snapshot.duplicate(true),header.duplicate(true),token,true});++buffer_fallback;}
 }else pending.push_back({snapshot.duplicate(true),header.duplicate(true),token,true});
 if(!encoder.joinable())encoder=std::thread(&FPSBackend::encode_loop,this);encode_wake.notify_one();return true;
}

// Only detached value leaves cross to the encoder. Godot containers are rebuilt
// there, then expanded/encoded exactly as in the existing snapshot path.
bool FPSBackend::freeze_value(const Variant &source,FrozenValue &out,size_t &remaining,int depth){
 if(depth>64||remaining==0)return false;--remaining;
 if(source.get_type()==Variant::ARRAY){Array array=source;if(array.is_typed())return false;out.kind=FrozenValue::ARRAY;out.values.resize(array.size());for(int i=0;i<array.size();++i)if(!freeze_value(array[i],out.values[i],remaining,depth+1))return false;}
 else if(source.get_type()==Variant::DICTIONARY){Dictionary dictionary=source;if(dictionary.is_typed())return false;out.kind=FrozenValue::DICTIONARY;Array keys=dictionary.keys();out.keys.reserve(keys.size());out.values.resize(keys.size());for(int i=0;i<keys.size();++i){Variant k=keys[i];if(k.get_type()!=Variant::STRING&&k.get_type()!=Variant::STRING_NAME&&k.get_type()!=Variant::INT)return false;out.keys.push_back(k);if(!freeze_value(dictionary[k],out.values[i],remaining,depth+1))return false;}}
 else{switch(source.get_type()){case Variant::OBJECT:case Variant::CALLABLE:case Variant::SIGNAL:case Variant::RID:return false;default:out.leaf=source;}}
 return true;
}
Variant FPSBackend::thaw_value(const FrozenValue &source){
 if(source.kind==FrozenValue::ARRAY){Array array;array.resize(source.values.size());for(size_t i=0;i<source.values.size();++i)array[i]=thaw_value(source.values[i]);return array;}
 if(source.kind==FrozenValue::DICTIONARY){Dictionary dictionary;for(size_t i=0;i<source.values.size();++i)dictionary[source.keys[i]]=thaw_value(source.values[i]);return dictionary;}
 return source.leaf;
}
