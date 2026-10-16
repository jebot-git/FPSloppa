#include "client_services.h"
#include <godot_cpp/classes/json.hpp>
#include <cmath>
#include <cstring>
#include <set>
using namespace godot;
namespace {
Dictionary fail(const String &s){Dictionary d;d["error"]=s;return d;}
bool scalar(const Variant &v,double lo,double hi){return (v.get_type()==Variant::INT||v.get_type()==Variant::FLOAT)&&std::isfinite(double(v))&&double(v)>=lo&&double(v)<=hi;}
bool integer(const Variant &v,int64_t lo,int64_t hi){return scalar(v,double(lo),double(hi))&&std::floor(double(v))==double(v);}
bool list(const Variant &v,int64_t size){return v.get_type()==Variant::ARRAY&&Array(v).size()==size;}
bool point(const Variant &v,double limit){if(!list(v,3))return false;Array p=v;for(int i=0;i<3;++i)if(!scalar(p[i],-limit,limit))return false;return true;}
Vector3 vec(const Variant &v){Array a=v;return Vector3(a[0],a[1],a[2]);}
bool arm(const Variant &v){if(!list(v,3))return false;Array a=v;for(int i=0;i<3;++i)if(!point(a[i],3))return false;for(int i=0;i<2;++i){double d=vec(a[i]).distance_to(vec(a[i+1]));if(d<.02||d>1)return false;}return true;}
uint32_t le(const uint8_t*p){return uint32_t(p[0])|uint32_t(p[1])<<8|uint32_t(p[2])<<16|uint32_t(p[3])<<24;}
uint32_t be(const uint8_t*p){return uint32_t(p[0])<<24|uint32_t(p[1])<<16|uint32_t(p[2])<<8|p[3];}
}
Dictionary FPSClientServices::avatar_read(const String &path){
 Ref<FileAccess> f=FileAccess::open(path,FileAccess::READ);if(f.is_null())return fail("Cannot open avatar.");
 uint64_t size=f->get_length();if(size<16||size>25000000)return fail("Avatar must be between 16 bytes and 25 MB.");
 auto header=f->get_buffer(16);if(header.size()!=16||std::memcmp(header.ptr(),"UTAV",4)||le(header.ptr()+4)!=1||le(header.ptr()+8)!=size)return fail("Expected a UT99 .utavatar container (version 1).");
 uint32_t length=le(header.ptr()+12);if(length<2||length>2000000||length>size-16)return fail("Invalid avatar manifest length.");
 auto json=f->get_buffer(length);if(json.size()!=length)return fail("Truncated avatar manifest.");
 Ref<JSON> parser;parser.instantiate();if(parser->parse(json.get_string_from_utf8())!=OK||parser->get_data().get_type()!=Variant::DICTIONARY)return fail("Invalid avatar manifest.");Dictionary m=parser->get_data();
 for(auto key:{"title","author","license"})if(m.get(key,Variant()).get_type()!=Variant::STRING||String(m[key]).length()>256)return fail("Invalid avatar credit.");
 for(auto key:{"vertices","frames","width","height","position_bytes","skin_bytes","skin_width","skin_height","reference"})if(!integer(m.get(key,Variant()),0,25000000))return fail(String("Invalid avatar dimension: ")+String(key));
 int64_t vertices=m["vertices"],frames=m["frames"],positions=m["position_bytes"],skin_bytes=m["skin_bytes"];
 if(vertices<3||vertices>4096||frames<1||frames>4096||vertices*frames>1048576)return fail("Avatar geometry limits exceeded.");
 if(int64_t(m["width"])!=512||int64_t(m["height"])!=(vertices*frames+511)/512||positions!=512*int64_t(m["height"])*16||int64_t(m["reference"])>=frames)return fail("Invalid animation texture layout.");
 if(!integer(m["skin_width"],1,2048)||!integer(m["skin_height"],1,2048)||skin_bytes<32||16+length+positions+skin_bytes!=int64_t(size))return fail("Invalid skin or payload bounds.");
 if(m.get("corners",Variant()).get_type()!=Variant::ARRAY)return fail("Invalid triangles.");Array corners=m["corners"];
 if(corners.size()<3||corners.size()>24576||corners.size()%3)return fail("Invalid triangles.");
 for(int i=0;i<corners.size();++i){if(!list(corners[i],3))return fail("Invalid triangle vertex.");Array c=corners[i];if(!integer(c[0],0,vertices-1))return fail("Invalid triangle vertex.");if(!scalar(c[1],0,1)||!scalar(c[2],0,1))return fail("Invalid texture coordinate.");}
 if(m.get("clips",Variant()).get_type()!=Variant::ARRAY)return fail("Invalid animation sequences.");Array clips=m["clips"];if(clips.is_empty()||clips.size()>256)return fail("Invalid animation sequences.");std::set<String> names;
 for(int i=0;i<clips.size();++i){if(clips[i].get_type()!=Variant::DICTIONARY)return fail("Invalid animation name.");Dictionary c=clips[i];if(c.get("name",Variant()).get_type()!=Variant::STRING)return fail("Invalid animation name.");String name=c["name"];if(name.is_empty()||name.length()>60||!names.insert(name).second)return fail("Invalid animation name.");if(!integer(c.get("start",Variant()),0,frames-1)||!integer(c.get("count",Variant()),1,frames)||int64_t(c["start"])+int64_t(c["count"])>frames)return fail("Animation outside frame data.");if(!scalar(c.get("fps",Variant()),1,60))return fail("Invalid animation rate.");}
 if(!list(m.get("bounds",Variant()),6))return fail("Invalid animated bounds.");Array bounds=m["bounds"];for(int i=0;i<6;++i)if(!scalar(bounds[i],-20,20))return fail("Invalid animated bounds.");Vector3 lower(bounds[0],bounds[1],bounds[2]),extent(bounds[3],bounds[4],bounds[5]);if(extent.x<0||extent.y<0||extent.z<0)return fail("Invalid bound extent.");
 if(m.has("arm_profile")){
  if(m["arm_profile"].get_type()!=Variant::DICTIONARY||Dictionary(m["arm_profile"]).size()!=2||!list(m.get("arm_weights",Variant()),vertices))return fail("Invalid arm-only profile.");Dictionary profile=m["arm_profile"];for(auto side:{"left","right"})if(!arm(profile.get(side,Variant())))return fail("Invalid arm landmarks.");Array weights=m["arm_weights"];for(int i=0;i<weights.size();++i)if(!scalar(weights[i],-2,2))return fail("Invalid arm weight.");
 }
 if(m.has("ik_profile")){
  if(m["ik_profile"].get_type()!=Variant::DICTIONARY||!list(m.get("ik_weights",Variant()),vertices))return fail("Invalid constrained IK profile.");Dictionary ik=m["ik_profile"];if(ik.size()!=6&&ik.size()!=7)return fail("Invalid constrained IK profile.");
  if(ik.has("head_correction")){if(!list(ik["head_correction"],4))return fail("Invalid IK head bind rotation.");Array q=ik["head_correction"];double norm=0;for(int i=0;i<4;++i){if(!scalar(q[i],-1e100,1e100))return fail("Invalid IK head bind rotation.");norm+=double(q[i])*double(q[i]);}if(std::abs(norm-1)>.001)return fail("IK head bind rotation must be normalized.");}
  for(auto side:{"left","right"})if(!arm(ik.get(side,Variant())))return fail("Invalid IK arm length.");
  for(auto key:{"neck","head","eye"})if(!point(ik.get(key,Variant()),3))return fail("Invalid IK head landmark.");
  if(vec(ik["neck"]).distance_to(vec(ik["head"]))<.02||vec(ik["head"]).distance_to(vec(ik["eye"]))<.02)return fail("Collapsed IK neck/head.");
  if(!list(ik.get("sockets",Variant()),frames))return fail("Invalid animated IK sockets.");Array sockets=ik["sockets"];
  for(int i=0;i<sockets.size();++i){if(!list(sockets[i],9))return fail("Invalid animated socket row.");Array row=sockets[i];for(int j=0;j<9;++j)if(!scalar(row[j],-10,10))return fail("Invalid animated socket coordinate.");}
  Array weights=m["ik_weights"];for(int i=0;i<weights.size();++i){if(!list(weights[i],3))return fail("Invalid IK region.");Array w=weights[i];if(!integer(w[0],0,3))return fail("Invalid IK region.");if(!scalar(w[1],0,1)||!scalar(w[2],0,1))return fail("Invalid IK influence.");}
 }
 if(m.has("base_model")){std::set<String> allowed={"Soldier","Commando","SGirl","FCommando","Boss"};if(m["base_model"].get_type()!=Variant::STRING||!allowed.count(m["base_model"]))return fail("Invalid base model identity.");}
 auto raw=f->get_buffer(positions);if(raw.size()!=positions)return fail("Truncated animated positions.");
 for(int64_t i=0;i<vertices*frames;++i){float x[3];std::memcpy(x,raw.ptr()+i*16,12);Vector3 p(x[0],x[1],x[2]);if(!p.is_finite()||p.x<lower.x-.001||p.y<lower.y-.001||p.z<lower.z-.001||p.x>lower.x+extent.x+.001||p.y>lower.y+extent.y+.001||p.z>lower.z+extent.z+.001||std::abs(p.x)>10||std::abs(p.y)>10||std::abs(p.z)>10)return fail("Invalid animated vertex or bounds.");}
 auto skin=f->get_buffer(skin_bytes);if(skin.size()!=skin_bytes)return fail("Truncated avatar skin.");static const uint8_t signature[]={137,80,78,71,13,10,26,10};if(std::memcmp(skin.ptr(),signature,8)||std::memcmp(skin.ptr()+12,"IHDR",4))return fail("Expected an embedded PNG skin.");if(be(skin.ptr()+16)!=uint32_t(int64_t(m["skin_width"]))||be(skin.ptr()+20)!=uint32_t(int64_t(m["skin_height"])))return fail("Skin dimensions differ from manifest.");
 Dictionary out;out["manifest"]=m;out["positions"]=raw;out["skin"]=skin;out["size"]=int64_t(size);return out;
}
Dictionary FPSClientServices::avatar_inspect(const String &path,const String &expected){
 Ref<FileAccess> source=FileAccess::open(path,FileAccess::READ);if(source.is_null())return fail("Cannot open avatar.");if(source->get_length()<16||source->get_length()>25000000)return fail("Avatar must be between 16 bytes and 25 MB.");source.unref();
 if(!expected.is_empty()&&FileAccess::get_sha256(path)!=expected)return fail("Model checksum failed.");Dictionary decoded=avatar_read(path);if(decoded.has("error"))return decoded;Dictionary m=decoded["manifest"],reach=Dictionary(m.get("ik_profile",Dictionary())).duplicate(true);
 if(reach.has("sockets")){Array sockets=reach["sockets"];reach["sockets"]=Array::make(sockets[int64_t(m["reference"])]);}
 Dictionary out;for(auto key:{"title","author","license","vertices","frames"})out[key]=m[key];out["size"]=decoded["size"];out["version"]="UT99 vertex 1";out["triangles"]=Array(m["corners"]).size()/3;out["base_model"]=m.get("base_model",String());out["reach_profile"]=reach;return out;
}
