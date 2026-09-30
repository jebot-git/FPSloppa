#include "codec.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>
using namespace godot;
namespace {
constexpr size_t LIMIT=262144;
struct Writer {
 std::vector<uint8_t> bytes;
 bool valid=true;
 int nodes=0;
 Writer(){bytes.reserve(1024);}
 void integer(uint64_t value,int size){
  if(!valid||bytes.size()+size>LIMIT){valid=false;return;}
  for(int i=0;i<size;++i)bytes.push_back(uint8_t(value>>(i*8)));
 }
 void uint(uint64_t value){while(value>=128){integer((value&127)|128,1);value>>=7;}integer(value,1);}
 template<class T> void floating(T value){
  uint64_t bits=0;std::memcpy(&bits,&value,sizeof(T));
  // GDScript's float32 fields pass through a double Variant, which quiets sNaN.
  if constexpr(sizeof(T)==4){if((bits&0x7f800000)==0x7f800000&&(bits&0x007fffff))bits|=0x00400000;}
  integer(bits,sizeof(T));
 }
 void data(const PackedByteArray &value){
  if(!valid||value.size()>int64_t(LIMIT-bytes.size())){valid=false;return;}
  if(value.size())bytes.insert(bytes.end(),value.ptr(),value.ptr()+value.size());
 }
 void write(const Variant &value,int depth=0){
  if(!valid||++nodes>32768||depth>20){valid=false;return;}
  switch(value.get_type()){
   case Variant::NIL:integer(0,1);break;
   case Variant::BOOL:integer(bool(value)?2:1,1);break;
   case Variant::INT:{
    int64_t v=value;
    if(v<INT32_MIN||v>INT32_MAX){integer(14,1);integer(uint64_t(v),8);}
    else{integer(3,1);uint((uint32_t(v)<<1)^uint32_t(-(v<0)));}break;
   }
   case Variant::FLOAT:integer(4,1);floating(double(value));break;
   case Variant::STRING:case Variant::STRING_NAME:{
    PackedByteArray v=String(value).to_utf8_buffer();integer(5,1);uint(v.size());data(v);break;
   }
   case Variant::VECTOR2:{Vector2 v=value;integer(6,1);floating(float(v.x));floating(float(v.y));break;}
   case Variant::VECTOR3:{Vector3 v=value;integer(7,1);floating(float(v.x));floating(float(v.y));floating(float(v.z));break;}
   case Variant::TRANSFORM3D:{
    Transform3D v=value;integer(8,1);floating(float(v.origin.x));floating(float(v.origin.y));floating(float(v.origin.z));
    Quaternion q=v.basis.orthonormalized().get_rotation_quaternion();
    for(double component:{double(q.x),double(q.y),double(q.z),double(q.w)}){
     // Nonfinite local transforms must not invoke undefined float-to-int casts.
     integer(std::isfinite(component)?uint16_t(int16_t(std::round(std::clamp(component,-1.,1.)*32767.))):0,2);
    }
    break;
   }
   case Variant::ARRAY:{Array v=value;integer(9,1);uint(v.size());for(int64_t i=0;valid&&i<v.size();++i)write(v[i],depth+1);break;}
   case Variant::DICTIONARY:{Dictionary v=value;integer(10,1);uint(v.size());Array keys=v.keys();for(int64_t i=0;valid&&i<keys.size();++i){write(keys[i],depth+1);write(v[keys[i]],depth+1);}break;}
   case Variant::PACKED_BYTE_ARRAY:{PackedByteArray v=value;integer(11,1);uint(v.size());data(v);break;}
   case Variant::PACKED_FLOAT32_ARRAY:{PackedFloat32Array v=value;integer(12,1);uint(v.size());for(int64_t i=0;valid&&i<v.size();++i)floating(v[i]);break;}
   case Variant::COLOR:{Color v=value;integer(13,1);floating(v.r);floating(v.g);floating(v.b);floating(v.a);break;}
   default:valid=false;break;
  }
 }
};
struct Reader {
 const uint8_t *bytes;
 size_t size,offset=0;
 int nodes=0;
 bool valid=true;
 explicit Reader(const PackedByteArray &value):bytes(value.ptr()),size(value.size()){}
 bool take(size_t count){if(!valid||count>size-offset){valid=false;return false;}return true;}
 uint64_t integer(int count){if(!take(count))return 0;uint64_t v=0;for(int i=0;i<count;++i)v|=uint64_t(bytes[offset++])<<(i*8);return v;}
 uint64_t uint(){uint64_t v=0;for(int shift=0;shift<35;shift+=7){uint64_t b=integer(1);v|=(b&127)<<shift;if(!valid)return 0;if(b<128)return v;}valid=false;return 0;}
 template<class T> T floating(){
  uint64_t bits=integer(sizeof(T));
  if constexpr(sizeof(T)==4){if((bits&0x7f800000)==0x7f800000&&(bits&0x007fffff))bits|=0x00400000;}
  T value;std::memcpy(&value,&bits,sizeof(T));return value;
 }
 Variant read(int depth=0){
  if(++nodes>32768||depth>20||!take(1)){valid=false;return Variant();}
  const int tag=integer(1);
  switch(tag){
   case 0:return Variant();
   case 1:return false;
   case 2:return true;
   case 3:{uint64_t v=uint();return int64_t(v>>1)^-int64_t(v&1);}
   case 4:return floating<double>();
   case 5:case 11:{
    uint64_t count=uint();if(count>LIMIT||!take(count)){valid=false;return Variant();}
    PackedByteArray v;v.resize(count);if(count)std::memcpy(v.ptrw(),bytes+offset,count);offset+=count;
    return tag==5?Variant(v.get_string_from_utf8()):Variant(v);
   }
   case 6:{float x=floating<float>(),y=floating<float>();return Vector2(x,y);}
   case 7:{float x=floating<float>(),y=floating<float>(),z=floating<float>();return Vector3(x,y,z);}
   case 8:{
    float x=floating<float>(),y=floating<float>(),z=floating<float>();Vector3 origin(x,y,z);
    double a=int16_t(integer(2))/32767.,b=int16_t(integer(2))/32767.,c=int16_t(integer(2))/32767.,d=int16_t(integer(2))/32767.;Quaternion q(a,b,c,d);
    if(!valid||!origin.is_finite()||!q.is_finite()||q.length_squared()<.9){valid=false;return Variant();}
    return Transform3D(Basis(q.normalized()),origin);
   }
   case 9:case 10:case 12:{
    uint64_t count=uint();if(!valid||count>4096){valid=false;return Variant();}
    if(tag==12){if(!take(count*4))return Variant();PackedFloat32Array v;v.resize(count);for(uint64_t i=0;i<count;++i)v[i]=floating<float>();return v;}
    Array array;Dictionary dictionary;
    if(tag==9)array.resize(count);
    for(uint64_t i=0;i<count;++i){
     Variant key=read(depth+1);if(!valid)return Variant();
     if(tag==9)array[i]=key;
     else{if(key.get_type()!=Variant::STRING&&key.get_type()!=Variant::INT){valid=false;return Variant();}Variant value=read(depth+1);if(!valid)return Variant();dictionary[key]=value;}
    }
    return tag==9?Variant(array):Variant(dictionary);
   }
   case 13:{float r=floating<float>(),g=floating<float>(),b=floating<float>(),a=floating<float>();return Color(r,g,b,a);}
   case 14:return int64_t(integer(8));
   default:valid=false;return Variant();
  }
 }
};
}
void FPSCodec::_bind_methods(){
 ClassDB::bind_method(D_METHOD("pack_input","command"),&FPSCodec::pack_input);
 ClassDB::bind_method(D_METHOD("snapshot_records","snapshot","recipient","cadence","cached","shared"),&FPSCodec::snapshot_records);
 ClassDB::bind_method(D_METHOD("encode_records","records"),&FPSCodec::encode_records);
 ClassDB::bind_method(D_METHOD("pack_records","records","header"),&FPSCodec::pack_records);
 ClassDB::bind_method(D_METHOD("encode","value"),&FPSCodec::encode);
 ClassDB::bind_method(D_METHOD("decode","bytes"),&FPSCodec::decode);
}
PackedByteArray FPSCodec::encode(const Variant &value) const{
 Writer writer;writer.write(value);PackedByteArray result;if(!writer.valid)return result;
 result.resize(writer.bytes.size());if(result.size())std::memcpy(result.ptrw(),writer.bytes.data(),writer.bytes.size());return result;
}
Variant FPSCodec::decode(const PackedByteArray &bytes) const{
 if(bytes.size()>int64_t(LIMIT))return Variant();Reader reader(bytes);Variant value=reader.read();
 return reader.valid&&reader.offset==reader.size?value:Variant();
}
