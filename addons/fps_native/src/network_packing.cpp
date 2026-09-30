#include "codec.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
using namespace godot;
namespace {
constexpr int64_t LIMIT=262144;
constexpr int64_t BUDGET=1100;
PackedByteArray envelope(const PackedByteArray &raw,uint8_t version){
 PackedByteArray result;
 if(raw.is_empty()||raw.size()>LIMIT)return result;
 result.resize(5);result.set(0,version);result.encode_u32(1,raw.size());
 result.append_array(raw.compress(0)); // Godot COMPRESSION_FASTLZ, same as reference.
 return result;
}
Dictionary dictionary(const Dictionary &d,const char *key){
 Variant v=d.get(key,Dictionary());return v.get_type()==Variant::DICTIONARY?Dictionary(v):Dictionary();
}
Array array(const Dictionary &d,const char *key){
 Variant v=d.get(key,Array());return v.get_type()==Variant::ARRAY?Array(v):Array();
}
}
PackedByteArray FPSCodec::pack_input(const Dictionary &command) const{
 PackedByteArray bytes=envelope(encode(command),1);
 if(bytes.size()<=BUDGET)return bytes;
 // Copy only on overflow. The caller's live input/history must remain immutable.
 Dictionary wire=command.duplicate(true);
 while(bytes.size()>BUDGET){
  Array moves=array(wire,"move_commands"),events=array(wire,"fire_events");
  Dictionary pose=dictionary(wire,"xr"),body=dictionary(pose,"body");
  if(moves.size()>2)moves.pop_front();
  else if(pose.has("face"))pose.erase("face");
  else if(body.size()>1){
   Dictionary gameplay;
   if(body.has("hips"))gameplay["hips"]=body["hips"];
   pose["body"]=gameplay;
  }
  else if(events.size()>1)events.pop_back();
  else if(moves.size()>1)moves.pop_front();
  else return PackedByteArray();
  bytes=envelope(encode(wire),1);
 }
 return bytes;
}
Dictionary FPSCodec::pack_records(const Array &records,const Array &header) const{
 Array normal,large;Dictionary result;result["normal"]=normal;result["large"]=large;result["invalid"]=false;
 if(header.size()!=3||records.size()>32768){result["invalid"]=true;return result;}
 Array message;message.resize(4);
 for(int i=0;i<3;++i)message[i]=header[i];
 int64_t cursor=0,previous_count=8;
 while(cursor<records.size()){
  const int64_t remaining=records.size()-cursor;
  int64_t count=std::min(previous_count,remaining),low=0,high=remaining+1;
  PackedByteArray accepted;
  while(true){
   message[3]=records.slice(cursor,cursor+count);
   PackedByteArray bytes=envelope(UtilityFunctions::var_to_bytes(message),2);
   if(!bytes.is_empty()&&bytes.size()<=BUDGET){
    low=count;accepted=bytes;
    if(low==remaining)break;
    if(high==remaining+1){count=std::min(remaining,std::max(low+1,low*2));continue;}
   }else{
    high=count;
    if(count==1){
     if(!bytes.is_empty())large.append(bytes);else result["invalid"]=true;
     low=1;break;
    }
   }
   if(high-low<=1)break;
   count=(low+high)/2;
  }
  if(!accepted.is_empty())normal.append(accepted);
  cursor+=low;previous_count=std::max(int64_t(1),low);
 }
 return result;
}

Array FPSCodec::encode_records(const Array &records) const{
 Array result;result.resize(records.size());
 for(int64_t i=0;i<records.size();++i){
  if(records[i].get_type()!=Variant::ARRAY)return Array();
  Array row=records[i];
  const bool player=row.size()==5&&row[0]==Variant(int64_t(2));
  PackedByteArray bytes;bytes.append(player?1:0);
  bytes.append_array(player?encode(row):UtilityFunctions::var_to_bytes(row));
  result[i]=bytes;
 }
 return result;
}

// Recipient-specific policy mirrors replication.gd. Caches are caller-owned:
// cadence/control state belongs to one peer; shared bytes to one snapshot only.
Dictionary FPSCodec::snapshot_records(const Array &snapshot,int64_t recipient,Dictionary cadence,Dictionary cached,Dictionary shared) const {
 Dictionary output;Array common,personal;output["common"]=common;output["personal"]=personal;
 if(snapshot.size()!=14)return output;
 const double now=snapshot[12];Dictionary mode=snapshot[10];Array records;
 for(int index:{1,2,3,4,5,6,8,9,11,12,13})records.append(Array::make(0,index,snapshot[index]));
 Array mode_keys=mode.keys();
 for(int i=0;i<mode_keys.size();++i){
  String key=mode_keys[i];if(key=="locomotion"||key=="movement_ack"||key=="ordnance")continue;
  Variant value=mode[key];
  if(recipient!=0&&key=="cs16"){
   Dictionary rows=Dictionary(value).duplicate(true);Array ids=rows.keys();
   for(int j=0;j<ids.size();++j)if(int64_t(ids[j])!=recipient){Array row=rows[ids[j]];row[2]=0;row[11]=0;}
   value=rows;
  }
  if(recipient!=0&&(key=="tribes"||key=="defusal")&&!Dictionary(value).is_empty()){
   Dictionary state=Dictionary(value).duplicate(true);
   if(key=="tribes"){
    Dictionary people=dictionary(state,"players");Array keys=people.keys();
    for(int j=0;j<keys.size();++j)if(int64_t(keys[j])!=recipient){
     Dictionary person=people[keys[j]];person["ammo"]=Array::make(0,0,0,0,0,0,0,0,0,0,0,0);person["kit"]=false;person["paid"]=0;
     person["next"]="light";person["next_pack"]="energy";person["guns"]=Array::make(3,2,4);person["grenade"]=9;
     if(person.has("beacons"))person["beacons"]=0;
    }
   }else{
    Dictionary accounts=dictionary(state,"accounts");Array keys=accounts.keys();
    for(int j=0;j<keys.size();++j)if(int64_t(keys[j])!=recipient){Array row=accounts[keys[j]];row[0]=0;row[4]="";}
    Dictionary inventory=dictionary(dictionary(state,"utility"),"inventory");keys=inventory.keys();
    for(int j=0;j<keys.size();++j)if(int64_t(keys[j])!=recipient){Array row=inventory[keys[j]];row[0]=Array::make(0,0,0);}
   }
   value=state;
  }
  records.append(Array::make(1,key,value));
 }
 Array players=snapshot[0],ids,shots;Variant observer;
 for(int i=0;i<players.size();++i){Array row=players[i];if(int64_t(row[0])==recipient&&!bool(row[20]))observer=row[1];}
 Dictionary states=dictionary(mode,"locomotion"),acks=dictionary(mode,"movement_ack"),ordnance=dictionary(mode,"ordnance");
 for(int i=0;i<players.size();++i){
  Array row=players[i];Variant id=row[0];Dictionary locomotion=states.get(id,Dictionary());Variant ack=acks.get(id,-1);
  if(recipient!=0&&int64_t(id)!=recipient){
   row=row.duplicate();row[9]=Array();row[10]=Array();row[17]=0.;row[19]=0.;
   locomotion=locomotion.duplicate();
   for(const char *field:{"replay","jump_ack","jetpack_ack","fire_ack","shot_counts","fire_results"})locomotion.erase(field);
   ack=-1;
   const Vector3 position=row[1];const bool tracked=!Dictionary(row[18]).is_empty();
   double distance=observer.get_type()==Variant::VECTOR3?Vector3(observer).distance_to(position):0.;
   double interval=distance>40.?.2:distance>20.?.1:0.;Dictionary prior=cadence.get(id,Dictionary());
   bool force=prior.is_empty()||prior.get("serial",-1)!=row[14]||prior.get("dead",false)!=row[7]||bool(prior.get("tracked",false))!=tracked||Vector3(prior.get("position",position)).distance_to(position)>3.||interval<double(prior.get("interval",0.));
   if(!force&&now-double(prior["time"])<interval)row[18]=Variant();
   else {Dictionary entry;entry["time"]=now;entry["serial"]=row[14];entry["dead"]=row[7];entry["tracked"]=tracked;entry["position"]=position;entry["interval"]=interval;cadence[id]=entry;}
  }
  locomotion=locomotion.duplicate();
  Variant replay=locomotion.get("replay",Variant());
  if(replay.get_type()==Variant::DICTIONARY){
   Dictionary state=replay;Array wire;
   for(const char *field:{"jump_held","jump_queued","blast_velocity","floor_grace","stepped_last_frame","water_jump_used","water_deep_time","water_exit_grace","water_boost","was_in_water","in_water","underwater","water_surface"})wire.append(state[field]);
   locomotion["replay"]=wire;
  }
  ids.append(id);records.append(Array::make(2,id,row,locomotion,ack));
 }
 Array stale=cadence.keys();for(int i=0;i<stale.size();++i)if(!ids.has(stale[i]))cadence.erase(stale[i]);
 Array projectiles=snapshot[7];
 for(int i=0;i<projectiles.size();++i){Array row=projectiles[i];shots.append(row[0]);records.append(Array::make(3,row[0],row,ordnance.get(row[0],Dictionary())));}
 records.append(Array::make(4,0,ids,shots,mode_keys));
 for(int i=0;i<records.size();++i){
  Array record=records[i];const int type=record[0];
  String base=String::num_int64(type)+":"+String(record[1]);String key=base;
  if(type==2){Array row=record[2];key+=String(":")+(recipient==0||int64_t(record[1])==recipient?"true":"false")+":"+(row[18].get_type()==Variant::NIL?"true":"false");}
  else if(type==1&&(String(record[1])=="cs16"||String(record[1])=="tribes"||String(record[1])=="defusal"))key+=":"+String::num_int64(recipient);
  PackedByteArray bytes;
  if(shared.has(key))bytes=shared[key];
  else {bytes.append(type==2?1:0);bytes.append_array(type==2?encode(record):UtilityFunctions::var_to_bytes(record));shared[key]=bytes;}
  int index=type==0?int(record[1]):-1;
  if((type==0||type==1||type==4)&&!(type==0&&(index==2||index==3||index==12||index==13))){
   Dictionary prior=cached.get(base,Dictionary());
   if(prior.has("bytes")&&PackedByteArray(prior["bytes"])==bytes&&now-double(prior["time"])<1.)continue;
   Dictionary entry;entry["bytes"]=bytes;entry["time"]=now;cached[base]=entry;
  }
  if(type==2||(type==1&&(String(record[1])=="cs16"||String(record[1])=="tribes"||String(record[1])=="defusal")))personal.append(bytes);else common.append(bytes);
 }
 return output;
}
