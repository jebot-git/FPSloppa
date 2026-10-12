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
